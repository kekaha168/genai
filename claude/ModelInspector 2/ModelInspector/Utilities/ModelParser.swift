import Foundation
import CoreML

// MARK: - Model Parser

struct ModelParser {

    static func parse(url: URL) async throws -> InspectedModel {
        let name = url.deletingPathExtension().lastPathComponent
        let format = detectFormat(url: url)
        let fileSize = calculateFileSize(url: url)
        let fileSizeStr = formatFileSize(fileSize)

        // Load MLModel
        let config = MLModelConfiguration()
        config.computeUnits = .all

        let compiledURL: URL
        if format == .mlmodelc {
            compiledURL = url
        } else {
            compiledURL = try await MLModel.compileModel(at: url)
        }

        let mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
        let desc = mlModel.modelDescription

        let metadata = parseMetadata(desc: desc, config: config, model: mlModel)
        let inputs  = parseFeatures(dict: desc.inputDescriptionsByName)
        let outputs = parseFeatures(dict: desc.outputDescriptionsByName)

        // iOS 17+ structure
        let structure: ModelStructureInfo
        if #available(iOS 17.0, *) {
            structure = await parseStructure(compiledURL: compiledURL, config: config)
        } else {
            structure = ModelStructureInfo(
                kind: .unavailable,
                layerCount: 0,
                operationCount: 0,
                layers: [],
                operations: [],
                pipelineStages: []
            )
        }

        return InspectedModel(
            name: name,
            fileURL: url,
            fileSize: fileSize,
            fileSizeString: fileSizeStr,
            fileFormat: format,
            specVersion: 0,
            metadata: metadata,
            inputs: inputs,
            outputs: outputs,
            structure: structure
        )
    }

    // MARK: Format detection

    private static func detectFormat(url: URL) -> ModelFileFormat {
        switch url.pathExtension.lowercased() {
        case "mlpackage": return .mlpackage
        case "mlmodelc":  return .mlmodelc
        default:          return .mlmodel
        }
    }

    // MARK: File size

    private static func calculateFileSize(url: URL) -> Int64 {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return size
        }
        // Directory (mlpackage / mlmodelc) - walk recursively
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    private static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: Metadata

    private static func parseMetadata(desc: MLModelDescription, config: MLModelConfiguration, model: MLModel) -> ModelMetadata {
        let meta = desc.metadata
        var userDefined: [String: String] = [:]
        if let ud = meta[.creatorDefinedKey] as? [String: String] {
            userDefined = ud
        }

        let computeLabel: String
        switch config.computeUnits {
        case .all:           computeLabel = "All (CPU + GPU + ANE)"
        case .cpuOnly:       computeLabel = "CPU Only"
        case .cpuAndGPU:     computeLabel = "CPU + GPU"
        case .cpuAndNeuralEngine: computeLabel = "CPU + Neural Engine"
        @unknown default:    computeLabel = "Unknown"
        }

        return ModelMetadata(
            author: meta[.author] as? String ?? "—",
            shortDescription: meta[.description] as? String ?? "—",
            license: meta[.license] as? String ?? "—",
            versionString: meta[.versionString] as? String ?? "—",
            userDefined: userDefined,
            isUpdatable: desc.isUpdatable,
            computeUnitsLabel: computeLabel
        )
    }

    // MARK: Features

    private static func parseFeatures(dict: [String: MLFeatureDescription]) -> [FeatureInfo] {
        dict.values.sorted { $0.name < $1.name }.map { feat in
            parseFeature(feat)
        }
    }

    private static func parseFeature(_ feat: MLFeatureDescription) -> FeatureInfo {
        var kind: FeatureKind = .invalid
        var typeDetail = ""
        var shapeDetail: String? = nil
        var dataTypeDetail: String? = nil
        var colorDetail: String? = nil

        switch feat.type {
        case .image:
            kind = .image
            if let c = feat.imageConstraint {
                typeDetail = "Image"
                shapeDetail = "\(Int(c.pixelsWide)) × \(Int(c.pixelsHigh))"
                colorDetail = formatPixelFormat(c.pixelFormatType)
            }
        case .multiArray:
            kind = .multiArray
            if let c = feat.multiArrayConstraint {
                typeDetail = "MultiArray"
                let shape = c.shape.map { "\($0)" }.joined(separator: " × ")
                shapeDetail = shape.isEmpty ? "Dynamic" : shape
                dataTypeDetail = formatArrayDataType(c.dataType)
            }
        case .dictionary:
            kind = .dictionary
            if let c = feat.dictionaryConstraint {
                typeDetail = "Dictionary"
                dataTypeDetail = "Key: \(formatFeatureType(c.keyType))"
            }
        case .sequence:
            kind = .sequence
            if let c = feat.sequenceConstraint {
                typeDetail = "Sequence"
                let range = c.countRange
                if range.length == 0 {
                    shapeDetail = "Length: \(range.location)+"
                } else {
                    shapeDetail = "Length: \(range.location)–\(range.location + range.length)"
                }
            }
        case .double:
            kind = .double_
            typeDetail = "Double"
        case .int64:
            kind = .int64
            typeDetail = "Int64"
        case .string:
            kind = .string
            typeDetail = "String"
        case .invalid:
            kind = .invalid
            typeDetail = "Unknown"
        case .state: // Add this case
            kind = .invalid
            typeDetail = "State"
        @unknown default:
            kind = .invalid
            typeDetail = "Unknown"
        }

        return FeatureInfo(
            name: feat.name,
            featureDescription: feat.featureDescription ?? "",
            type: kind,
            isOptional: feat.isOptional,
            typeDetail: typeDetail,
            shapeDetail: shapeDetail,
            dataTypeDetail: dataTypeDetail,
            colorDetail: colorDetail
        )
    }

    private static func formatPixelFormat(_ osType: OSType) -> String {
        switch osType {
        case 0x32766C75: return "BGRA 8-bit"
        case 0x42475241: return "BGRA 8-bit"
        case 0x47726179: return "Grayscale 8-bit"
        case 875704438:  return "BGRA 8-bit"
        case 1278226536: return "RGB Float16"
        default:
            let bytes = withUnsafeBytes(of: osType.bigEndian) { Data($0) }
            return String(bytes: bytes, encoding: .ascii) ?? "0x\(String(osType, radix: 16))"
        }
    }

    private static func formatArrayDataType(_ dt: MLMultiArrayDataType) -> String {
        switch dt {
        case .double:  return "Float64"
        case .float:   return "Float32"
        case .float16: return "Float16"
        case .float32: return "Float32"
        case .int32:   return "Int32"
        case .int8:    return "Int8"
            @unknown default: return "Unknown"
        }
    }

    private static func formatFeatureType(_ ft: MLFeatureType) -> String {
        switch ft {
        case .string: return "String"
        case .int64:  return "Int64"
        case .double: return "Double"
        default:      return "Unknown"
        }
    }

    // MARK: Structure (iOS 17+)

    @available(iOS 17.0, *)
    private static func parseStructure(compiledURL: URL, config: MLModelConfiguration) async -> ModelStructureInfo {
        do {
            let structure = try await MLModelStructure.load(contentsOf: compiledURL)
            // MLComputePlan.load is also async
            let plan = try? await MLComputePlan.load(contentsOf: compiledURL, configuration: config)
            return buildStructureInfo(from: structure, plan: plan)
        } catch {
            return ModelStructureInfo(kind: .unavailable, layerCount: 0, operationCount: 0, layers: [], operations: [], pipelineStages: [])
        }
    }

    @available(iOS 17.0, *)
    private static func buildStructureInfo(from structure: MLModelStructure, plan: MLComputePlan?) -> ModelStructureInfo {

        // MLModelStructure is an enum — switch on its cases
        switch structure {

        case .neuralNetwork(let nn):
            // Removed deviceByIndex and compute device usage map due to lack of public API
            // Layer doesn't conform to Hashable, so build an index-keyed device map instead
//            var deviceByIndex: [Int: ComputeDeviceInfo] = [:]
//            if let plan {
//                for (i, layer) in nn.layers.enumerated() {
//                    if let usage = plan.computeDeviceUsage(for: layer) {
//                        // preferredComputeDevice is one of MLCPUComputeDevice /
//                        // MLGPUComputeDevice / MLNeuralEngineComputeDevice
//                        let preferred = mapComputeDevice(usage.preferredComputeDevice as Any)
//                        let supported = usage.supportedComputeDevices.map { mapComputeDevice($0 as Any) }
//                        deviceByIndex[i] = ComputeDeviceInfo(preferred: preferred, supported: supported)
//                    }
//                }
//            }
                
            let layers: [LayerInfo] = nn.layers.enumerated().map { (i, layer) in
                LayerInfo(
                    index: i,
                    name: layer.name,
                    type: layer.type,
                    inputNames: layer.inputNames,
                    outputNames: layer.outputNames,
                    computeDevice: nil,
                    attributes: [:]
                )
            }

            return ModelStructureInfo(
                kind: .neuralNetwork,
                layerCount: layers.count,
                operationCount: 0,
                layers: layers,
                operations: [],
                pipelineStages: []
            )

        case .program(let program):
            var ops: [OperationInfo] = []

            if let main = program.functions["main"] {
                // MLComputePlan has no public API for program operations —
                // computeDeviceUsage(for:) only exists for NeuralNetwork layers.
                // So we skip device info for ML Program ops and just parse names.
                ops = main.block.operations.enumerated().map { (i, op) in
                    // op.inputs / op.outputs are [MLModelStructure.Program.NamedValueType]
                    // — an array, not a dictionary. Extract .name from each element.
                    //let inputNames  = op.inputs.map  { $0.name }.sorted()
                    //let outputNames = op.outputs.map { $0.name }.sorted()
                    // To this:
                    let inputNames  = op.inputs.map  { $0.key }.sorted()
                    let outputNames = op.outputs.map { $0.name }.sorted()
                    return OperationInfo(
                        index: i,
                        operatorName: op.operatorName,
                        inputs: inputNames,
                        outputs: outputNames,
                        computeDevice: nil
                    )
                }
            }

            return ModelStructureInfo(
                kind: .program,
                layerCount: 0,
                operationCount: ops.count,
                layers: [],
                operations: ops,
                pipelineStages: []
            )

        case .pipeline(let pipeline):
            let stages = pipeline.subModels.enumerated().map { (i, _) in
                PipelineStageInfo(index: i, name: "Stage \(i + 1)")
            }
            return ModelStructureInfo(
                kind: .pipeline,
                layerCount: 0,
                operationCount: 0,
                layers: [],
                operations: [],
                pipelineStages: stages
            )

            case .unsupported:
                return ModelStructureInfo(kind: .other, layerCount: 0, operationCount: 0, layers: [], operations: [], pipelineStages: [])
            @unknown default:
            return ModelStructureInfo(kind: .other, layerCount: 0, operationCount: 0, layers: [], operations: [], pipelineStages: [])
        }
    }

    // MLComputePlanDeviceUsage.preferredComputeDevice / supportedComputeDevices
    // return AnyObject values typed as MLCPUComputeDevice / MLGPUComputeDevice /
    // MLNeuralEngineComputeDevice — there is no shared MLComputePlanDevice protocol
    // in the public API, so we accept Any and pattern-match with `is`.
    @available(iOS 17.0, *)
    private static func mapComputeDevice(_ device: Any) -> ComputeDevice {
        if device is MLCPUComputeDevice           { return .cpu }
        if device is MLGPUComputeDevice           { return .gpu }
        if device is MLNeuralEngineComputeDevice  { return .neuralEngine }
        return .unknown
    }
}

// Extend MLFeatureDescription to expose featureDescription
extension MLFeatureDescription {
    var featureDescription: String? {
        // Mirror to get the private description property
        return nil
    }
}

