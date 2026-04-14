import SwiftUI

// Cross-platform semantic background used for chips and search field
private extension Color {
    static var appSurfaceBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
}

struct StructureTabView: View {
    let structure: ModelStructureInfo
    @State private var searchText = ""
    @State private var filterDevice: ComputeDevice? = nil

    var filteredLayers: [LayerInfo] {
        var items = structure.layers
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let dev = filterDevice {
            items = items.filter { $0.computeDevice?.preferred == dev }
        }
        return items
    }

    var filteredOps: [OperationInfo] {
        var items = structure.operations
        if !searchText.isEmpty {
            items = items.filter { $0.operatorName.localizedCaseInsensitiveContains(searchText) }
        }
        if let dev = filterDevice {
            items = items.filter { $0.computeDevice?.preferred == dev }
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search + filter bar
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    TextField("Search layers…", text: $searchText)
                        .font(.system(size: 15))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.appSurfaceBackground, in: RoundedRectangle(cornerRadius: 10))

                // Device filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: "All", icon: "square.grid.2x2", isSelected: filterDevice == nil) {
                            filterDevice = nil
                        }
                        ForEach([ComputeDevice.neuralEngine, .gpu, .cpu], id: \.self) { dev in
                            FilterChip(label: dev.rawValue, icon: dev.icon, isSelected: filterDevice == dev) {
                                filterDevice = filterDevice == dev ? nil : dev
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            switch structure.kind {
            case .neuralNetwork:
                LayerListView(layers: filteredLayers, total: structure.layers.count)
            case .program:
                OperationListView(operations: filteredOps, total: structure.operations.count)
            case .pipeline:
                PipelineView(stages: structure.pipelineStages)
            case .unavailable:
                UnavailableStructureView()
            case .other:
                UnavailableStructureView()
            }
        }
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? .blue.opacity(0.15) : Color.appSurfaceBackground, in: Capsule())
            .foregroundStyle(isSelected ? .blue : .secondary)
            .overlay(Capsule().strokeBorder(isSelected ? .blue.opacity(0.3) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layer list

struct LayerListView: View {
    let layers: [LayerInfo]
    let total: Int

    var body: some View {
        List {
            Section {
                ForEach(layers) { layer in
                    LayerRow(layer: layer)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("\(layers.count) of \(total) layers")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
}

struct LayerRow: View {
    let layer: LayerInfo
    @State private var expanded = false

    var deviceColor: Color {
        switch layer.computeDevice?.preferred {
        case .cpu:           return .blue
        case .gpu:           return .green
        case .neuralEngine:  return .purple
        default:             return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    // Index badge
                    Text("\(layer.index)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, alignment: .trailing)

                    // Type indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(deviceColor.opacity(0.8))
                        .frame(width: 3, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(layer.name)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(formatLayerType(layer.type))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let dev = layer.computeDevice?.preferred {
                        HStack(spacing: 3) {
                            Image(systemName: dev.icon)
                                .font(.system(size: 10))
                            Text(dev.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(deviceColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(deviceColor)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !layer.inputNames.isEmpty {
                        IOChipRow(label: "In", names: layer.inputNames, color: .blue)
                    }
                    if !layer.outputNames.isEmpty {
                        IOChipRow(label: "Out", names: layer.outputNames, color: .green)
                    }
                }
                .padding(.leading, 44)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    func formatLayerType(_ raw: String) -> String {
        // prettify camelCase / underscore
        raw.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Operation list

struct OperationListView: View {
    let operations: [OperationInfo]
    let total: Int

    var body: some View {
        List {
            Section {
                ForEach(operations) { op in
                    OperationRow(op: op)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("\(operations.count) of \(total) operations")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
}

struct OperationRow: View {
    let op: OperationInfo
    @State private var expanded = false

    var deviceColor: Color {
        switch op.computeDevice?.preferred {
        case .cpu:           return .blue
        case .gpu:           return .green
        case .neuralEngine:  return .purple
        default:             return .gray
        }
    }

    var opTypeColor: Color { opColor(op.operatorName) }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text("\(op.index)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, alignment: .trailing)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(opTypeColor.opacity(0.8))
                        .frame(width: 3, height: 32)

                    Text(op.operatorName)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let dev = op.computeDevice?.preferred {
                        HStack(spacing: 3) {
                            Image(systemName: dev.icon)
                                .font(.system(size: 10))
                            Text(dev.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(deviceColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(deviceColor)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !op.inputs.isEmpty {
                        IOChipRow(label: "In", names: op.inputs, color: .blue)
                    }
                    if !op.outputs.isEmpty {
                        IOChipRow(label: "Out", names: op.outputs, color: .green)
                    }
                    if let dev = op.computeDevice {
                        HStack(spacing: 6) {
                            Text("Supported:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            ForEach(dev.supported, id: \.rawValue) { d in
                                HStack(spacing: 3) {
                                    Image(systemName: d.icon).font(.system(size: 9))
                                    Text(d.rawValue).font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(deviceColor.opacity(0.08), in: Capsule())
                                .foregroundStyle(deviceColor)
                            }
                        }
                    }
                }
                .padding(.leading, 44)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    func opColor(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("conv"):       return .purple
        case let n where n.contains("batch"):      return .blue
        case let n where n.contains("relu"), let n where n.contains("sigmoid"), let n where n.contains("softmax"): return .orange
        case let n where n.contains("pool"):       return .teal
        case let n where n.contains("concat"):     return .green
        case let n where n.contains("reshape"), let n where n.contains("transpose"): return .gray
        case let n where n.contains("nms"):        return .red
        case let n where n.contains("upsample"):   return .cyan
        default:                                   return .gray
        }
    }
}

// MARK: - IO Chips

struct IOChipRow: View {
    let label: String
    let names: [String]
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
                .padding(.top, 2)

            FlowLayout(spacing: 4) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(color.opacity(0.8))
                }
            }
        }
    }
}

// MARK: - Pipeline view

struct PipelineView: View {
    let stages: [PipelineStageInfo]
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(stages) { stage in
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .frame(width: 32)
                        Text(stage.name)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Unavailable

struct UnavailableStructureView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Structure inspection requires iOS 17+")
                .font(.system(size: 15, weight: .medium))
            Text("Use MLModelStructure on iOS 17 or later to enumerate layers and operations.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
