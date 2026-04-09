// Views/Tabs/InspectorTab.swift
import SwiftUI

struct InspectorTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabScaffold(title: "ANE Inspector", subtitle: "Compatibility · Schema · Dispatch hints") {
            if store.selectedModel == nil {
                NoModelPlaceholder().frame(height: 400)
            } else {
                VStack(spacing: 20) {
                    if let report = store.compatibilityReport {
                        ANEScoreCard(report: report)
                        CompatibilityFlagsCard(report: report)
                    }
                    ModelSchemaCard()
                    DispatchHintsCard()
                }
            }
        }
    }
}

// ─── ANE Score Card ───────────────────────────────────────────────
struct ANEScoreCard: View {
    let report: CompatibilityReport

    var scoreColor: Color {
        switch report.estimatedANEScore {
        case 80...100: return Color(hex: "#34D399")
        case 50...79:  return Color(hex: "#F59E0B")
        default:       return Color(hex: "#F87171")
        }
    }
    var scoreLabel: String {
        switch report.estimatedANEScore {
        case 80...100: return "ANE-READY"
        case 50...79:  return "PARTIAL"
        default:       return "CPU FALLBACK LIKELY"
        }
    }

    var body: some View {
        LabCard {
            HStack(spacing: 20) {
                // Circular score gauge
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.estimatedANEScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 1.0, bounce: 0.3), value: report.estimatedANEScore)
                    VStack(spacing: 2) {
                        Text("\(report.estimatedANEScore)")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("/ 100")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(label: scoreLabel, color: scoreColor)
                    Text(report.modelName)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(report.format.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                    Text("Note: ANE dispatch cannot be confirmed at runtime via public API. Score is heuristic.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.25))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }
}

// ─── Flags ────────────────────────────────────────────────────────
struct CompatibilityFlagsCard: View {
    let report: CompatibilityReport

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "flag.fill", title: "Compatibility Flags")
                VStack(spacing: 10) {
                    ForEach(report.flags) { flag in
                        FlagRow(flag: flag)
                    }
                }
            }
        }
    }
}

struct FlagRow: View {
    let flag: CompatibilityReport.CompatibilityFlag

    var color: Color {
        switch flag.severity {
        case .info:    return Color(hex: "#38BDF8")
        case .warning: return Color(hex: "#F59E0B")
        case .error:   return Color(hex: "#F87171")
        }
    }
    var icon: String {
        switch flag.severity {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(minWidth: 16)
            Text(flag.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.07)).overlay(
            RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.15), lineWidth: 1)
        ))
    }
}

// ─── Model Schema ─────────────────────────────────────────────────
struct ModelSchemaCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "list.bullet.rectangle", title: "I/O Schema")

                if let model = store.loadedModel {
                    VStack(alignment: .leading, spacing: 12) {
                        SchemaSection(title: "INPUTS", color: Color(hex: "#34D399"),
                                      descriptors: model.modelDescription.inputDescriptionsByName)
                        Divider().background(Color.white.opacity(0.06))
                        SchemaSection(title: "OUTPUTS", color: Color(hex: "#38BDF8"),
                                      descriptors: model.modelDescription.outputDescriptionsByName)
                    }
                } else {
                    Text("Model not loaded.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
        }
    }
}

struct SchemaSection: View {
    let title: String
    let color: Color
    let descriptors: [String: MLFeatureDescription]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
                .kerning(1.5)

            ForEach(Array(descriptors), id: \.key) { name, desc in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.8))
                        .frame(width: 3, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(typeDetail(desc))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                }
            }
        }
    }

    func typeDetail(_ d: MLFeatureDescription) -> String {
        switch d.type {
        case .multiArray:
            guard let c = d.multiArrayConstraint else { return "MultiArray" }
            let shape = c.shape.map { "\($0)" }.joined(separator: " × ")
            return "MultiArray [\(shape)] · \(dataTypeName(c.dataType))"
        case .image:
            guard let c = d.imageConstraint else { return "Image" }
            return "Image · \(c.pixelsWide)×\(c.pixelsHigh) · \(pixelFormatName(c.pixelFormatType))"
        case .int64:    return "Int64"
        case .double:   return "Double"
        case .string:   return "String"
        case .sequence: return "Sequence"
        default:        return "Unknown"
        }
    }

    func dataTypeName(_ t: MLMultiArrayDataType) -> String {
        switch t {
        case .float16: return "Float16"
        case .float32: return "Float32"
        case .double:  return "Float64"
        case .int32:   return "Int32"
        default:       return "Unknown"
        }
    }

    func pixelFormatName(_ t: OSType) -> String {
        switch t {
        case kCVPixelFormatType_32BGRA: return "BGRA32"
        case kCVPixelFormatType_32ARGB: return "ARGB32"
        case kCVPixelFormatType_OneComponent8: return "Grayscale8"
        default: return String(format: "0x%08X", t)
        }
    }
}

import CoreML
import CoreVideo

// ─── Dispatch Hints ───────────────────────────────────────────────
struct DispatchHintsCard: View {
    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "map.fill", title: "Compute Dispatch Hints",
                                subtitle: "How Core ML routes layers to hardware")

                VStack(spacing: 10) {
                    DispatchHintRow(
                        unit: "ANE",
                        color: Color(hex: "#A78BFA"),
                        description: "Best for: Conv2D, BatchNorm, ReLU, LayerNorm, Attention in FP16. Requires fixed input shapes and ML Program format."
                    )
                    DispatchHintRow(
                        unit: "GPU",
                        color: Color(hex: "#34D399"),
                        description: "Best for: Custom ops, dynamic shapes, FP32, large matrix ops. Falls back from ANE when shapes are dynamic."
                    )
                    DispatchHintRow(
                        unit: "CPU",
                        color: Color(hex: "#F59E0B"),
                        description: "Last resort: String ops, unsupported activations, sequence models. Lowest throughput for ML workloads."
                    )
                }

                Divider().background(Color.white.opacity(0.06))

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("Core ML selects compute units at model load time. No public API confirms per-layer ANE dispatch at runtime — use Xcode Instruments for ground-truth profiling.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.3))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct DispatchHintRow: View {
    let unit: String
    let color: Color
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(unit)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(color.opacity(0.12)).overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1)))
                .frame(width: 50)
            Text(description)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
