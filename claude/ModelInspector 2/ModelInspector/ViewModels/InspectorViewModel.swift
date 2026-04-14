import Foundation
import CoreML
import SwiftUI

@Observable
class InspectorViewModel {

    enum State {
        case empty
        case loading(String)
        case loaded(InspectedModel)
        case error(String)
    }

    var state: State = .empty
    var showFilePicker = false
    var selectedTab: InspectorTab = .general

    enum InspectorTab: String, CaseIterable {
        case general   = "General"
        case inputs    = "Inputs"
        case outputs   = "Outputs"
        case structure = "Structure"
        case metadata  = "Metadata"

        var icon: String {
            switch self {
            case .general:   return "info.circle"
            case .inputs:    return "arrow.down.circle"
            case .outputs:   return "arrow.up.circle"
            case .structure: return "square.3.layers.3d"
            case .metadata:  return "tag"
            }
        }
    }

    func loadModel(at url: URL) {
        state = .loading("Compiling \(url.lastPathComponent)…")
        Task {
            do {
                let model = try await ModelParser.parse(url: url)
                await MainActor.run {
                    withAnimation(.spring(duration: 0.4)) {
                        state = .loaded(model)
                        selectedTab = .general
                    }
                }
            } catch {
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    // Convenience for demo / simulator where file picker may be restricted
    func loadSampleModel() {
        // Build a synthetic model for preview
        state = .loading("Loading sample…")
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                withAnimation(.spring(duration: 0.4)) {
                    state = .loaded(SampleData.diceDetectorModel)
                }
            }
        }
    }
}

// MARK: - Sample data for previews / demo

enum SampleData {
    static var diceDetectorModel: InspectedModel {
        InspectedModel(
            name: "DiceDetector",
            fileURL: URL(fileURLWithPath: "/Models/DiceDetector.mlpackage"),
            fileSize: 47_235_000,
            fileSizeString: "47.2 MB",
            fileFormat: .mlpackage,
            specVersion: 8,
            metadata: ModelMetadata(
                author: "Apple Inc.",
                shortDescription: "Detects dice and returns bounding box predictions with confidence scores.",
                license: "Apple Sample Code License",
                versionString: "1.0",
                userDefined: ["task": "object_detection", "nmsThreshold": "0.45"],
                isUpdatable: false,
                computeUnitsLabel: "All (CPU + GPU + ANE)"
            ),
            inputs: [
                FeatureInfo(id: .init(), name: "image", featureDescription: "Input image for dice detection", type: .image, isOptional: false, typeDetail: "Image", shapeDetail: "736 × 736", dataTypeDetail: nil, colorDetail: "BGRA 8-bit"),
                FeatureInfo(id: .init(), name: "iouThreshold", featureDescription: "IOU threshold for NMS", type: .double_, isOptional: true, typeDetail: "Double", shapeDetail: nil, dataTypeDetail: nil, colorDetail: nil),
                FeatureInfo(id: .init(), name: "confidenceThreshold", featureDescription: "Minimum confidence score", type: .double_, isOptional: true, typeDetail: "Double", shapeDetail: nil, dataTypeDetail: nil, colorDetail: nil),
            ],
            outputs: [
                FeatureInfo(id: .init(), name: "confidence", featureDescription: "Confidence scores per detection", type: .multiArray, isOptional: false, typeDetail: "MultiArray", shapeDetail: "1 × 16 × 6", dataTypeDetail: "Float32", colorDetail: nil),
                FeatureInfo(id: .init(), name: "coordinates", featureDescription: "Bounding box coordinates", type: .multiArray, isOptional: false, typeDetail: "MultiArray", shapeDetail: "1 × 16 × 4", dataTypeDetail: "Float32", colorDetail: nil),
            ],
            structure: ModelStructureInfo(
                kind: .program,
                layerCount: 0,
                operationCount: 52,
                layers: [],
                operations: [
                    OperationInfo(id: .init(), index: 0,  operatorName: "const",         inputs: [],                      outputs: ["var_0"],                 computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 1,  operatorName: "conv",           inputs: ["image", "var_0"],       outputs: ["conv_1_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 2,  operatorName: "batch_norm",     inputs: ["conv_1_out"],           outputs: ["bn_1_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 3,  operatorName: "leaky_relu",     inputs: ["bn_1_out"],             outputs: ["act_1_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 4,  operatorName: "conv",           inputs: ["act_1_out"],            outputs: ["conv_2_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 5,  operatorName: "batch_norm",     inputs: ["conv_2_out"],           outputs: ["bn_2_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 6,  operatorName: "leaky_relu",     inputs: ["bn_2_out"],             outputs: ["act_2_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 7,  operatorName: "max_pool",       inputs: ["act_2_out"],            outputs: ["pool_1_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 8,  operatorName: "conv",           inputs: ["pool_1_out"],           outputs: ["conv_3_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 9,  operatorName: "batch_norm",     inputs: ["conv_3_out"],           outputs: ["bn_3_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 10, operatorName: "leaky_relu",     inputs: ["bn_3_out"],             outputs: ["act_3_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 11, operatorName: "conv",           inputs: ["act_3_out"],            outputs: ["conv_4_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 12, operatorName: "batch_norm",     inputs: ["conv_4_out"],           outputs: ["bn_4_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 13, operatorName: "leaky_relu",     inputs: ["bn_4_out"],             outputs: ["act_4_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 14, operatorName: "max_pool",       inputs: ["act_4_out"],            outputs: ["pool_2_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 15, operatorName: "conv",           inputs: ["pool_2_out"],           outputs: ["conv_5_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 16, operatorName: "batch_norm",     inputs: ["conv_5_out"],           outputs: ["bn_5_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 17, operatorName: "leaky_relu",     inputs: ["bn_5_out"],             outputs: ["act_5_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 18, operatorName: "concat",         inputs: ["act_5_out", "act_4_out"], outputs: ["concat_out"],          computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 19, operatorName: "conv",           inputs: ["concat_out"],           outputs: ["conv_6_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 20, operatorName: "batch_norm",     inputs: ["conv_6_out"],           outputs: ["bn_6_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 21, operatorName: "leaky_relu",     inputs: ["bn_6_out"],             outputs: ["act_6_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 22, operatorName: "upsample",       inputs: ["act_6_out"],            outputs: ["up_1_out"],              computeDevice: ComputeDeviceInfo(preferred: .cpu, supported: [.cpu])),
                    OperationInfo(id: .init(), index: 23, operatorName: "conv",           inputs: ["up_1_out"],             outputs: ["conv_7_out"],            computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 24, operatorName: "batch_norm",     inputs: ["conv_7_out"],           outputs: ["bn_7_out"],              computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 25, operatorName: "leaky_relu",     inputs: ["bn_7_out"],             outputs: ["act_7_out"],             computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 26, operatorName: "softmax",        inputs: ["act_7_out"],            outputs: ["softmax_out"],           computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 27, operatorName: "sigmoid",        inputs: ["softmax_out"],          outputs: ["sigmoid_out"],           computeDevice: ComputeDeviceInfo(preferred: .neuralEngine, supported: [.cpu, .gpu, .neuralEngine])),
                    OperationInfo(id: .init(), index: 28, operatorName: "reshape",        inputs: ["sigmoid_out"],          outputs: ["reshape_out"],           computeDevice: ComputeDeviceInfo(preferred: .cpu, supported: [.cpu])),
                    OperationInfo(id: .init(), index: 29, operatorName: "transpose",      inputs: ["reshape_out"],          outputs: ["transpose_out"],         computeDevice: ComputeDeviceInfo(preferred: .cpu, supported: [.cpu])),
                    OperationInfo(id: .init(), index: 30, operatorName: "split",          inputs: ["transpose_out"],        outputs: ["conf_raw", "coords_raw"], computeDevice: ComputeDeviceInfo(preferred: .cpu, supported: [.cpu])),
                    OperationInfo(id: .init(), index: 31, operatorName: "nms",            inputs: ["conf_raw", "coords_raw"], outputs: ["confidence", "coordinates"], computeDevice: ComputeDeviceInfo(preferred: .cpu, supported: [.cpu])),
                ],
                pipelineStages: []
            )
        )
    }
}

// Make FeatureInfo manually initializable with explicit id for SampleData
extension FeatureInfo {
    init(id: UUID, name: String, featureDescription: String, type: FeatureKind, isOptional: Bool, typeDetail: String, shapeDetail: String?, dataTypeDetail: String?, colorDetail: String?) {
        self.name = name
        self.featureDescription = featureDescription
        self.type = type
        self.isOptional = isOptional
        self.typeDetail = typeDetail
        self.shapeDetail = shapeDetail
        self.dataTypeDetail = dataTypeDetail
        self.colorDetail = colorDetail
    }
}

extension OperationInfo {
    init(id: UUID, index: Int, operatorName: String, inputs: [String], outputs: [String], computeDevice: ComputeDeviceInfo?) {
        self.index = index
        self.operatorName = operatorName
        self.inputs = inputs
        self.outputs = outputs
        self.computeDevice = computeDevice
    }
}
