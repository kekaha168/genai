//
//  ModelHelper.swift
//  CoreMLSample
//
//  Created by Dennis Sheu on 4/8/26.
//

import CoreML

//func printModelInfo(_ model: MLModel, name: String) {
//    print("\n====== \(name) ======")
//    print("── Inputs ──")
//    for (key, desc) in model.modelDescription.inputDescriptionsByName {
//        print("• \(key): type=\(desc.type.rawValue)", terminator: "")
//        if let ma = desc.multiArrayConstraint {
//            print(" shape=\(ma.shape) dtype=\(ma.dataType.rawValue)", terminator: "")
//        }
//        print()
//    }
//    print("── Outputs ──")
//    for (key, desc) in model.modelDescription.outputDescriptionsByName {
//        print("• \(key): type=\(desc.type.rawValue)", terminator: "")
//        if let ma = desc.multiArrayConstraint {
//            print(" shape=\(ma.shape) dtype=\(ma.dataType.rawValue)", terminator: "")
//        }
//        print()
//    }
//}

// MARK: - Public Entry Point

func printModelInfo(_ model: MLModel, name: String) {
    let desc = model.modelDescription
    
    print("\n╔══════════════════════════════════════╗")
    print("║  Model: \(name)")
    print("╚══════════════════════════════════════╝")
    
    print("\nInput")
    print(String(repeating: "─", count: 40))
    for (key, featureDesc) in desc.inputDescriptionsByName {
        printFeature(key: key, featureDesc: featureDesc)
    }
    
    print("\nOutput")
    print(String(repeating: "─", count: 40))
    for (key, featureDesc) in desc.outputDescriptionsByName {
        printFeature(key: key, featureDesc: featureDesc)
    }
}

// MARK: - Feature Printer

private func printFeature(key: String, featureDesc: MLFeatureDescription) {
    print("\n  \(key)")
    
    switch featureDesc.type {
            
        case .image:
            if let imageConstraint = featureDesc.imageConstraint {
                //let colorStr = colorSpaceString(imageConstraint.colorSpaceModel)
                //print("  image (\(colorStr) \(imageConstraint.pixelsWide) x \(imageConstraint.pixelsHigh))")
                // ✅ Fix 1 — MLImageConstraint exposes pixelsWide/pixelsHigh only
                // Color space is not directly exposed at runtime; default to "Color"
                print("  image (Color \(imageConstraint.pixelsWide) x \(imageConstraint.pixelsHigh))")
            } else {
                print("  image")
            }
            
        case .multiArray:
            if let ma = featureDesc.multiArrayConstraint {
                let typeStr  = multiArrayDataTypeString(ma.dataType)
                let shapeStr = ma.shape.map { "\($0)" }.joined(separator: " x ")
                print("  MultiArray (\(typeStr) \(shapeStr))")
            } else {
                print("  MultiArray")
            }
            
        case .dictionary:
            if let dict = featureDesc.dictionaryConstraint {
                let keyType = dict.keyType == .string ? "String" : "Int64"
                print("  Dictionary (\(keyType) → Double)")
            } else {
                print("  Dictionary")
            }
            
        case .string:
            print("  string")
            
        case .double:
            print("  double")
            
        case .int64:
            print("  int64")
            
        case .sequence:
//            if let seq = featureDesc.sequenceConstraint {
//                //print("  sequence (\(seq.dataType))")
//                let seqType = seq.valueDescription.type
//                print("  sequence (\(featureTypeString(seqType)))")
//            } else {
//                print("  sequence")
//            }
            if let seq = featureDesc.sequenceConstraint {
                // ✅ Fix 1 — inline the type conversion directly, no separate function needed
                let seqTypeStr: String
                switch seq.valueDescription.type {
                    case .int64:      seqTypeStr = "Int64"
                    case .double:     seqTypeStr = "Double"
                    case .string:     seqTypeStr = "String"
                    case .image:      seqTypeStr = "Image"
                    case .multiArray: seqTypeStr = "MultiArray"
                    case .dictionary: seqTypeStr = "Dictionary"
                    case .sequence:   seqTypeStr = "Sequence"
                    case .invalid:    seqTypeStr = "Invalid"
                    @unknown default: seqTypeStr = "Unknown"
                }
                print("  sequence (\(seqTypeStr))")
            } else {
                print("  sequence")
            }
            
        case .invalid:
            print("  (invalid type)")
            
        @unknown default:
            print("  (unknown type: \(featureDesc.type.rawValue))")
    }
    
    // Short description if the model provides one
//    if let doc = featureDesc.shortDescription, !doc.isEmpty {
//        print("  Description")
//        print("  \(doc)")
//    }
    // ✅ Fix 2 — MLFeatureDescription has no shortDescription;
    // use name as fallback label only
    print("  \(featureDesc.name)")

}

// MARK: - Data Type Helpers

private func multiArrayDataTypeString(_ dataType: MLMultiArrayDataType) -> String {
    switch dataType {
        case .float16:          return "Float16"
        case .float32:          return "Float"
        case .float64:          return "Double"
        case .int32:            return "Int32"
        case .double:           return "Double"
        @unknown default:       return "Unknown(\(dataType.rawValue))"
    }
}
