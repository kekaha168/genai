import Foundation
import CoreML

// MARK: - Top-level model info

struct InspectedModel: Identifiable {
    let id = UUID()
    let name: String
    let fileURL: URL
    let fileSize: Int64
    let fileSizeString: String
    let fileFormat: ModelFileFormat

    let specVersion: Int
    let metadata: ModelMetadata

    let inputs: [FeatureInfo]
    let outputs: [FeatureInfo]

    let structure: ModelStructureInfo
}

enum ModelFileFormat: String {
    case mlmodel = ".mlmodel"
    case mlpackage = ".mlpackage"
    case mlmodelc = ".mlmodelc"

    var displayName: String {
        switch self {
        case .mlmodel:    return "Neural Network"
        case .mlpackage:  return "ML Program"
        case .mlmodelc:   return "Compiled Model"
        }
    }

    var icon: String {
        switch self {
        case .mlmodel:    return "cpu"
        case .mlpackage:  return "square.stack.3d.up"
        case .mlmodelc:   return "bolt.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .mlmodel:    return "blue"
        case .mlpackage:  return "purple"
        case .mlmodelc:   return "orange"
        }
    }
}

// MARK: - Metadata

struct ModelMetadata {
    let author: String
    let shortDescription: String
    let license: String
    let versionString: String
    let userDefined: [String: String]
    let isUpdatable: Bool
    let computeUnitsLabel: String
}

// MARK: - Feature / I-O

struct FeatureInfo: Identifiable {
    let id = UUID()
    let name: String
    let featureDescription: String
    let type: FeatureKind
    let isOptional: Bool
    let typeDetail: String
    let shapeDetail: String?
    let dataTypeDetail: String?
    let colorDetail: String?
}

enum FeatureKind: String {
    case image = "Image"
    case multiArray = "MultiArray"
    case dictionary = "Dictionary"
    case sequence = "Sequence"
    case double_ = "Double"
    case int64 = "Int64"
    case string = "String"
    case invalid = "Unknown"

    var icon: String {
        switch self {
        case .image:       return "photo"
        case .multiArray:  return "tablecells"
        case .dictionary:  return "list.bullet.rectangle"
        case .sequence:    return "list.number"
        case .double_:     return "number"
        case .int64:       return "number.square"
        case .string:      return "textformat"
        case .invalid:     return "questionmark"
        }
    }

    var color: String {
        switch self {
        case .image:       return "blue"
        case .multiArray:  return "purple"
        case .dictionary:  return "green"
        case .sequence:    return "orange"
        default:           return "gray"
        }
    }
}

// MARK: - Structure

struct ModelStructureInfo {
    let kind: StructureKind
    let layerCount: Int
    let operationCount: Int
    let layers: [LayerInfo]
    let operations: [OperationInfo]
    let pipelineStages: [PipelineStageInfo]
}

enum StructureKind: String {
    case neuralNetwork = "Neural Network"
    case program = "ML Program"
    case pipeline = "Pipeline"
    case other = "Other"
    case unavailable = "Unavailable"
}

struct LayerInfo: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
    let type: String
    let inputNames: [String]
    let outputNames: [String]
    let computeDevice: ComputeDeviceInfo?
    let attributes: [String: String]
}

struct OperationInfo: Identifiable {
    let id = UUID()
    let index: Int
    let operatorName: String
    let inputs: [String]
    let outputs: [String]
    let computeDevice: ComputeDeviceInfo?
}

struct PipelineStageInfo: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
}

struct ComputeDeviceInfo {
    let preferred: ComputeDevice
    let supported: [ComputeDevice]
}

enum ComputeDevice: String {
    case cpu = "CPU"
    case gpu = "GPU"
    case neuralEngine = "Neural Engine"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .cpu:           return "cpu"
        case .gpu:           return "rectangle.3.group"
        case .neuralEngine:  return "brain.head.profile"
        case .unknown:       return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .cpu:           return "blue"
        case .gpu:           return "green"
        case .neuralEngine:  return "purple"
        case .unknown:       return "gray"
        }
    }
}
