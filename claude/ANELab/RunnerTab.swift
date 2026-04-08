// Views/Tabs/RunnerTab.swift
import SwiftUI
import CoreML

struct RunnerTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabScaffold(title: "Model Runner", subtitle: "Load · Configure · Infer") {
            if store.selectedModel == nil {
                NoModelPlaceholder()
                    .frame(height: 400)
            } else {
                VStack(spacing: 20) {
                    // Model info card
                    ModelInfoCard()

                    // Compute unit selection
                    LabCard {
                        VStack(alignment: .leading, spacing: 14) {
                            LabSectionHeader(icon: "cpu", title: "Compute Unit",
                                            subtitle: "Reload required when switching")
                            ComputeUnitPicker(selection: $store.selectedComputeUnit) {
                                store.reloadWithCurrentComputeUnit()
                            }

                            // Load state indicator
                            LoadStateRow()
                        }
                    }

                    // Run single inference
                    SingleInferenceCard()

                    // Input scaffold info
                    InputSchemaCard()
                }
            }
        }
    }
}

struct ModelInfoCard: View {
    @EnvironmentObject var store: AppStore

    var model: ImportedModel? { store.selectedModel }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "shippingbox.fill", title: "Model")

                if let m = model {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.name)
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            HStack(spacing: 8) {
                                StatusPill(label: m.format.rawValue,
                                           color: m.format == .mlpackage ? Color(hex: "#A78BFA") : Color(hex: "#F59E0B"))
                                Text(formatBytes(m.sizeBytes))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(m.importedAt, style: .date)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.3))
                        }
                    }
                }
            }
        }
    }

    func formatBytes(_ b: Int64) -> String {
        let mb = Double(b) / 1_048_576
        return mb >= 1 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", Double(b)/1024)
    }
}

struct LoadStateRow: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 10) {
            switch store.loadState {
            case .idle:
                StatusPill(label: "IDLE", color: Color.white.opacity(0.3))
            case .loading:
                StatusPill(label: "LOADING", color: Color(hex: "#F59E0B"))
                ProgressView().tint(Color(hex: "#F59E0B")).scaleEffect(0.7)
            case .loaded:
                StatusPill(label: "LOADED", color: Color(hex: "#34D399"))
                Text("Model ready on \(store.selectedComputeUnit.rawValue)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
            case .failed(let e):
                StatusPill(label: "ERROR", color: Color(hex: "#F87171"))
                Text(e)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#F87171").opacity(0.8))
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}

struct SingleInferenceCard: View {
    @EnvironmentObject var store: AppStore
    @State private var lastResult: String? = nil
    @State private var lastLatencyMs: Double? = nil
    @State private var isRunning = false

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "play.fill", title: "Single Inference",
                                subtitle: "Synthetic input · spot timing")

                HStack(spacing: 16) {
                    LabButton(title: "Run Inference", icon: "play.fill", isLoading: isRunning) {
                        runOnce()
                    }
                    .disabled(store.loadedModel == nil)

                    if let ms = lastLatencyMs {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#A78BFA"))
                            Text(String(format: "%.2f ms", ms))
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#A78BFA").opacity(0.1)))
                    }
                }

                if let r = lastResult {
                    Text(r)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                        .lineLimit(3)
                }
            }
        }
    }

    func runOnce() {
        guard let model = store.loadedModel else { return }
        isRunning = true
        Task {
            let engine = InferenceEngine()
            guard let input = engine.makeSyntheticInput(for: model) else {
                lastResult = "Could not generate synthetic input."
                isRunning = false
                return
            }
            let t0 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            let output = try? model.prediction(from: input)
            let t1 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            lastLatencyMs = Double(t1 - t0) / 1_000_000
            if let out = output {
                let names = out.featureNames.prefix(3).joined(separator: ", ")
                lastResult = "Output features: \(names)…"
            } else {
                lastResult = "Inference returned no output."
            }
            isRunning = false
        }
    }
}

struct InputSchemaCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "square.grid.2x2.fill", title: "Input Schema",
                                subtitle: "Auto-detected from modelDescription")

                if let model = store.loadedModel {
                    VStack(spacing: 8) {
                        ForEach(Array(model.modelDescription.inputDescriptionsByName), id: \.key) { name, desc in
                            HStack(spacing: 10) {
                                Text("IN")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundColor(Color(hex: "#34D399"))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: "#34D399").opacity(0.1)))
                                Text(name)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(typeLabel(desc))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(.vertical, 4)
                            if name != model.modelDescription.inputDescriptionsByName.keys.sorted().last {
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                } else {
                    Text("Load a model to see its input schema.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
        }
    }

    func typeLabel(_ d: MLFeatureDescription) -> String {
        switch d.type {
        case .multiArray:
            let shape = d.multiArrayConstraint?.shape.map { "\($0)" }.joined(separator: "×") ?? "?"
            return "MultiArray [\(shape)]"
        case .image:
            let c = d.imageConstraint
            return "Image \(c?.pixelsWide ?? 0)×\(c?.pixelsHigh ?? 0)"
        case .int64:    return "Int64"
        case .double:   return "Double"
        case .string:   return "String"
        case .sequence: return "Sequence"
        default:        return "Unknown"
        }
    }
}
