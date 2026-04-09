// Views/Components/SharedComponents.swift
import SwiftUI
internal import UniformTypeIdentifiers

// ─── Section Header ───────────────────────────────────────────────
struct LabSectionHeader: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "#A78BFA"))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            Spacer()
        }
    }
}

// ─── Card Container ───────────────────────────────────────────────
struct LabCard<Content: View>: View {
    @ViewBuilder let content: Content
    var padding: CGFloat = 16

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#0E1420"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

// ─── Compute Unit Picker ──────────────────────────────────────────
struct ComputeUnitPicker: View {
    @Binding var selection: ComputeUnit
    var onchange: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ComputeUnit.allCases) { unit in
                ComputeUnitChip(unit: unit, isSelected: selection == unit) {
                    selection = unit
                    onchange?()
                }
            }
        }
    }
}

struct ComputeUnitChip: View {
    let unit: ComputeUnit
    let isSelected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isSelected ? unit.color.swiftUIColor : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
                Text(unit.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? unit.color.swiftUIColor : Color.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? unit.color.swiftUIColor.opacity(0.12) : Color.white.opacity(hover ? 0.04 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? unit.color.swiftUIColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// ─── Metric Tile ──────────────────────────────────────────────────
struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    var accentColor: Color = Color(hex: "#A78BFA")
    var trend: TrendDir? = nil

    enum TrendDir { case up, down, flat }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
                if let t = trend {
                    Image(systemName: t == .up ? "arrow.up.right" : t == .down ? "arrow.down.right" : "minus")
                        .font(.system(size: 9))
                        .foregroundColor(t == .down ? Color(hex: "#34D399") : t == .up ? Color(hex: "#F87171") : Color.white.opacity(0.3))
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(accentColor.opacity(0.8))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#0E1420"))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.15), lineWidth: 1))
        )
    }
}

// ─── Status Pill ──────────────────────────────────────────────────
struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
                .overlay(Circle().fill(color.opacity(0.4)).frame(width: 10, height: 10).scaleEffect(1.2))
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.1)).overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1)))
    }
}

// ─── Model Picker Section (sidebar) ──────────────────────────────
struct ModelPickerSection: View {
    @EnvironmentObject var store: AppStore
    @State private var showingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MODELS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                    .kerning(1.5)
                Spacer()
                Button {
                    showingImporter = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#A78BFA"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if store.importedModels.isEmpty {
                Button {
                    showingImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12))
                        Text("Import .mlpackage")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: "#A78BFA").opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#A78BFA").opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.importedModels) { model in
                            ModelRowItem(model: model, isSelected: store.selectedModel?.id == model.id) {
                                store.selectModel(model)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(maxHeight: 120)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.init(filenameExtension: "mlpackage")!, .init(filenameExtension: "mlmodel")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.importModel(url: url)
            }
        }
    }
}

struct ModelRowItem: View {
    let model: ImportedModel
    let isSelected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: model.format == .mlpackage ? "shippingbox.fill" : "cube.fill")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Color(hex: "#A78BFA") : Color.white.opacity(0.4))
                Text(model.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(hex: "#A78BFA").opacity(0.1) : (hover ? Color.white.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// ─── Thermal Badge ────────────────────────────────────────────────
struct ThermalBadge: View {
    @EnvironmentObject var store: AppStore

    var info: (label: String, color: Color) {
        switch store.thermalState {
        case .nominal:  return ("NOMINAL",  Color(hex: "#34D399"))
        case .fair:     return ("FAIR",     Color(hex: "#A3E635"))
        case .serious:  return ("SERIOUS",  Color(hex: "#F59E0B"))
        case .critical: return ("CRITICAL", Color(hex: "#F87171"))
        @unknown default: return ("UNKNOWN", Color.white.opacity(0.4))
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 11))
                .foregroundColor(info.color)
            Text("THERMAL · \(info.label)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(info.color)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(info.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(info.color.opacity(0.2), lineWidth: 1))
        )
    }
}

// ─── Primary Action Button ─────────────────────────────────────────
struct LabButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    var color: Color = Color(hex: "#A78BFA")
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.7)
                } else {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                }
                Text(title).font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20).padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(hover ? 0.9 : 0.75))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 1))
            )
            .shadow(color: color.opacity(0.3), radius: 8, y: 3)
            .scaleEffect(hover ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        /*
         Explain xcode error "Contextual closure type '() throws -> Void' expects 0 arguments, but 1 was used in closure body" at "hover = $0" in

        What this error means
        This error is happening because you have two nested closures, and you are using the $0 shorthand in the wrong one.
        Let's look at the line causing the issue:
            .onHover { _ in withAnimation(.spring(duration: 0.2)) { hover = $0 } }
        The outer closure (onHover) gives you 1 argument: a Bool telling you whether the mouse is hovering or not. However, by typing _ in, you are explicitly throwing that argument away.
        The inner closure (withAnimation) takes 0 arguments (() throws -> Void).
        Inside withAnimation, you wrote hover = $0. The Swift compiler thinks $0 belongs to withAnimation. Because withAnimation expects 0 arguments, the compiler throws an error saying: "Contextual closure type '() throws -> Void' expects 0 arguments, but 1 ($0) was used."
         */
        // .onHover { _ in withAnimation(.spring(duration: 0.2)) { hover = $0 } }
        .onHover { isHovering in
            withAnimation(.spring(duration: 0.2)) {
                hover = isHovering
            }
        }
        .disabled(isLoading)
    }
}

// ─── No-model placeholder ─────────────────────────────────────────
struct NoModelPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 40))
                .foregroundColor(Color.white.opacity(0.15))
            Text("No model loaded")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
            Text("Import a .mlpackage or .mlmodel\nfrom the sidebar to begin.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.2))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─── Tab scaffold ─────────────────────────────────────────────────
struct TabScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#A78BFA").opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(Color(hex: "#0A0F1A"))
            .overlay(alignment: .bottom) {
                Divider().background(Color.white.opacity(0.06))
            }

            ScrollView {
                content
                    .padding(24)
            }
        }
    }
}
