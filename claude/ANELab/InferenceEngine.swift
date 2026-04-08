// Engine/InferenceEngine.swift
import CoreML
import Foundation

final class InferenceEngine {

    /// Builds a zero-filled MLFeatureProvider that satisfies a model's input requirements.
    /// Returns nil if the model needs inputs we can't auto-generate (e.g. sequences).
    func makeSyntheticInput(for model: MLModel) -> MLFeatureProvider? {
        var features: [String: MLFeatureValue] = [:]

        for (name, desc) in model.modelDescription.inputDescriptionsByName {
            switch desc.type {
            case .multiArray:
                guard let constraint = desc.multiArrayConstraint else { continue }
                let shape: [NSNumber]
                if constraint.shape.allSatisfy({ $0.intValue > 0 }) {
                    shape = constraint.shape
                } else {
                    // Fall back to a small fixed shape for dynamic dims
                    shape = constraint.shape.map { $0.intValue > 0 ? $0 : 1 }
                }
                guard let arr = try? MLMultiArray(shape: shape, dataType: constraint.dataType) else { continue }
                // Fill with small random values
                for i in 0..<arr.count {
                    arr[i] = NSNumber(value: Float.random(in: -0.1...0.1))
                }
                features[name] = MLFeatureValue(multiArray: arr)

            case .image:
                guard let constraint = desc.imageConstraint else { continue }
                let w = constraint.pixelsWide > 0 ? constraint.pixelsWide : 224
                let h = constraint.pixelsHigh > 0 ? constraint.pixelsHigh : 224
                if let img = makeSolidCGImage(width: w, height: h),
                   let fv  = try? MLFeatureValue(cgImage: img, constraint: constraint) {
                    features[name] = fv
                }

            case .int64:
                features[name] = MLFeatureValue(int64: 0)

            case .double:
                features[name] = MLFeatureValue(double: 0)

            case .string:
                features[name] = MLFeatureValue(string: "")

            default:
                break
            }
        }

        guard !features.isEmpty else { return nil }
        return try? MLDictionaryFeatureProvider(dictionary: features)
    }

    private func makeSolidCGImage(width: Int, height: Int) -> CGImage? {
        let bpc = 8, bpp = 32, bpr = width * 4
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: bpc, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
