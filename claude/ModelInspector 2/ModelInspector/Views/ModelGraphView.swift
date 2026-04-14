import SwiftUI

// MARK: - Graph Node model

struct GraphNode: Identifiable {
    let id: Int           // matches LayerInfo.index or OperationInfo.index
    let label: String     // short display name
    let subtitle: String  // type / opName
    let inputs: [String]  // output-tensor names that feed into this node
    let outputs: [String] // output-tensor names this node produces
    let device: ComputeDevice
    var column: Int = 0   // assigned during layout
    var row: Int = 0
    var center: CGPoint = .zero
}

struct GraphEdge: Identifiable {
    let id: UUID = .init()
    let from: Int  // node id
    let to: Int    // node id
}

// MARK: - Layout engine

struct GraphLayout {
    static let nodeW: CGFloat  = 130
    static let nodeH: CGFloat  = 48
    static let colGap: CGFloat = 72
    static let rowGap: CGFloat = 16

    /// Build nodes + edges + assign (column, row, center) to every node.
    static func layout(layers: [LayerInfo]) -> ([GraphNode], [GraphEdge]) {
        guard !layers.isEmpty else { return ([], []) }

        var nodes = layers.map { l in
            GraphNode(
                id: l.index,
                label: shortName(l.name),
                subtitle: formatType(l.type),
                inputs: l.inputNames,
                outputs: l.outputNames,
                device: l.computeDevice?.preferred ?? .unknown
            )
        }
        let edges = buildEdges(nodes: nodes)
        nodes = assignColumns(nodes: nodes, edges: edges)
        nodes = assignRows(nodes: &nodes)
        nodes = assignCenters(nodes: nodes)
        return (nodes, edges)
    }

    static func layout(operations: [OperationInfo]) -> ([GraphNode], [GraphEdge]) {
        guard !operations.isEmpty else { return ([], []) }

        var nodes = operations.map { op in
            GraphNode(
                id: op.index,
                label: shortName(op.operatorName),
                subtitle: op.operatorName,
                inputs: op.inputs,
                outputs: op.outputs,
                device: op.computeDevice?.preferred ?? .unknown
            )
        }
        let edges = buildEdges(nodes: nodes)
        nodes = assignColumns(nodes: nodes, edges: edges)
        nodes = assignRows(nodes: &nodes)
        nodes = assignCenters(nodes: nodes)
        return (nodes, edges)
    }

    // MARK: Private

    private static func buildEdges(nodes: [GraphNode]) -> [GraphEdge] {
        // Map each output-tensor name → node id that produces it
        var producerOf: [String: Int] = [:]
        for n in nodes {
            for out in n.outputs { producerOf[out] = n.id }
        }
        var edges: [GraphEdge] = []
        for n in nodes {
            for inp in n.inputs {
                if let src = producerOf[inp] {
                    edges.append(GraphEdge(from: src, to: n.id))
                }
            }
        }
        return edges
    }

    /// Kahn's topological column assignment
    private static func assignColumns(nodes: [GraphNode], edges: [GraphEdge]) -> [GraphNode] {
        var inDegree = [Int: Int]()
        var successors = [Int: [Int]]()
        for n in nodes { inDegree[n.id] = 0; successors[n.id] = [] }
        for e in edges {
            inDegree[e.to, default: 0] += 1
            successors[e.from, default: []].append(e.to)
        }

        var col = [Int: Int]()
        var queue = nodes.filter { inDegree[$0.id] == 0 }.map { $0.id }
        queue.forEach { col[$0] = 0 }

        while !queue.isEmpty {
            let curr = queue.removeFirst()
            for succ in successors[curr, default: []] {
                col[succ] = max(col[succ] ?? 0, (col[curr] ?? 0) + 1)
                inDegree[succ]! -= 1
                if inDegree[succ]! == 0 { queue.append(succ) }
            }
        }

        return nodes.map { n in
            var m = n; m.column = col[n.id] ?? 0; return m
        }
    }

    /// Pack nodes into rows per column
    private static func assignRows(nodes: inout [GraphNode]) -> [GraphNode] {
        var rowCount = [Int: Int]()
        for i in nodes.indices {
            let c = nodes[i].column
            nodes[i].row = rowCount[c, default: 0]
            rowCount[c, default: 0] += 1
        }
        return nodes
    }

    /// Convert (column, row) → canvas center point
    private static func assignCenters(nodes: [GraphNode]) -> [GraphNode] {
        // We lay the graph left-to-right: column → x, row → y
        let xBase: CGFloat = nodeW / 2 + 20
        let yBase: CGFloat = nodeH / 2 + 20
        return nodes.map { n in
            var m = n
            m.center = CGPoint(
                x: xBase + CGFloat(n.column) * (nodeW + colGap),
                y: yBase + CGFloat(n.row)    * (nodeH + rowGap)
            )
            return m
        }
    }

    // MARK: Helpers

    static func canvasSize(nodes: [GraphNode]) -> CGSize {
        guard !nodes.isEmpty else { return CGSize(width: 300, height: 200) }
        let maxX = nodes.map { $0.center.x + nodeW / 2 }.max()! + 20
        let maxY = nodes.map { $0.center.y + nodeH / 2 }.max()! + 20
        return CGSize(width: maxX, height: maxY)
    }

    private static func shortName(_ s: String) -> String {
        let clean = s.replacingOccurrences(of: "_", with: " ")
        if clean.count <= 16 { return clean }
        return String(clean.prefix(14)) + "…"
    }

    private static func formatType(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Graph Canvas View

struct ModelGraphView: View {
    let structure: ModelStructureInfo
    let searchText: String
    let filterDevice: ComputeDevice?

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var selectedID: Int? = nil

    // Build nodes/edges once
    private var builtGraph: ([GraphNode], [GraphEdge]) {
        switch structure.kind {
        case .neuralNetwork:
            return GraphLayout.layout(layers: structure.layers)
        case .program:
            return GraphLayout.layout(operations: structure.operations)
        default:
            return ([], [])
        }
    }

    private var allNodes: [GraphNode] { builtGraph.0 }
    private var allEdges: [GraphEdge] { builtGraph.1 }

    private var visibleIDs: Set<Int> {
        var ids = Set(allNodes.map { $0.id })
        if !searchText.isEmpty {
            ids = ids.filter { id in
                guard let n = allNodes.first(where: { $0.id == id }) else { return false }
                return n.label.localizedCaseInsensitiveContains(searchText)
                    || n.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let dev = filterDevice {
            ids = ids.filter { id in
                allNodes.first(where: { $0.id == id })?.device == dev
            }
        }
        return ids
    }

    private var nodeByID: [Int: GraphNode] {
        Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, $0) })
    }

    var body: some View {
        GeometryReader { geo in
            if allNodes.isEmpty {
                emptyGraph
            } else {
                ZStack(alignment: .topLeading) {
                    graphCanvas(geo: geo)
                    controlOverlay(geo: geo)
                }
                .clipped()
            }
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #elseif os(macOS)
        .background(.quaternary)
        #endif
    }

    // MARK: Canvas

    @ViewBuilder
    private func graphCanvas(geo: GeometryProxy) -> some View {
        let canvasSize = GraphLayout.canvasSize(nodes: allNodes)

        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Background dot grid
                Canvas { ctx, size in
                    let spacing: CGFloat = 28
                    var x: CGFloat = 0
                    while x < size.width {
                        var y: CGFloat = 0
                        while y < size.height {
                            ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                                     with: .color(.secondary.opacity(0.15)))
                            y += spacing
                        }
                        x += spacing
                    }
                }
                .frame(width: canvasSize.width * scale,
                       height: canvasSize.height * scale)

                // Edges layer
                Canvas { ctx, _ in
                    drawEdges(ctx: &ctx)
                }
                .frame(width: canvasSize.width * scale,
                       height: canvasSize.height * scale)
                .allowsHitTesting(false)

                // Nodes layer
                ForEach(allNodes) { node in
                    NodeView(
                        node: node,
                        isSelected: selectedID == node.id,
                        isDimmed: !visibleIDs.contains(node.id)
                    )
                    .frame(width: GraphLayout.nodeW * scale,
                           height: GraphLayout.nodeH * scale)
                    .position(
                        x: node.center.x * scale,
                        y: node.center.y * scale
                    )
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedID = selectedID == node.id ? nil : node.id
                        }
                    }
                }

                // Selected node detail tooltip
                if let selID = selectedID, let node = nodeByID[selID] {
                    NodeTooltip(node: node)
                        .position(
                            x: min(max(node.center.x * scale, 110),
                                   canvasSize.width * scale - 110),
                            y: node.center.y * scale - GraphLayout.nodeH * scale * 0.5 - 56
                        )
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .frame(width: canvasSize.width * scale,
                   height: canvasSize.height * scale)
        }
        .gesture(
            MagnificationGesture()
                .onChanged { v in
                    scale = max(0.25, min(3.0, lastScale * v))
                }
                .onEnded { _ in lastScale = scale }
        )
    }

    private func drawEdges(ctx: inout GraphicsContext) {
        for edge in allEdges {
            guard let src = nodeByID[edge.from],
                  let dst = nodeByID[edge.to] else { continue }

            let fromPt = CGPoint(
                x: (src.center.x + GraphLayout.nodeW / 2) * scale,
                y:  src.center.y * scale
            )
            let toPt = CGPoint(
                x: (dst.center.x - GraphLayout.nodeW / 2) * scale,
                y:  dst.center.y * scale
            )

            let isDimmed = !visibleIDs.contains(src.id) || !visibleIDs.contains(dst.id)
            let alpha: Double = isDimmed ? 0.06 : 0.22
            let color: Color = visibleIDs.contains(src.id) ? edgeColor(src.device) : .gray

            let cpX = (fromPt.x + toPt.x) / 2
            var path = Path()
            path.move(to: fromPt)
            path.addCurve(
                to: toPt,
                control1: CGPoint(x: cpX, y: fromPt.y),
                control2: CGPoint(x: cpX, y: toPt.y)
            )

            ctx.stroke(path,
                       with: .color(color.opacity(alpha)),
                       style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
        }
    }

    // MARK: Controls overlay

    @ViewBuilder
    private func controlOverlay(geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    // Legend
                    legendPill
                    // Zoom controls
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                scale = min(3.0, scale * 1.3)
                                lastScale = scale
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 36, height: 36)
                        }
                        Divider().frame(height: 20)
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                scale = max(0.25, scale / 1.3)
                                lastScale = scale
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 36, height: 36)
                        }
                        Divider().frame(height: 20)
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 36, height: 36)
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 0.5))
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var legendPill: some View {
        HStack(spacing: 10) {
            ForEach([ComputeDevice.neuralEngine, .gpu, .cpu], id: \.self) { dev in
                HStack(spacing: 4) {
                    Circle()
                        .fill(nodeAccentColor(dev))
                        .frame(width: 7, height: 7)
                    Text(dev.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }

    private var emptyGraph: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No graph data available")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Colors

    func nodeAccentColor(_ device: ComputeDevice) -> Color {
        switch device {
        case .cpu:           return .blue
        case .gpu:           return .green
        case .neuralEngine:  return .purple
        case .unknown:
#if os(iOS)
                return Color(.systemGray3)
#elseif os(macOS)
                return Color(NSColor.windowBackgroundColor)
#endif
        }
    }

    func edgeColor(_ device: ComputeDevice) -> Color { nodeAccentColor(device) }
}

// MARK: - Node View

struct NodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isDimmed: Bool

    var accentColor: Color {
        switch node.device {
            case .cpu:           return .blue
            case .gpu:           return .green
            case .neuralEngine:  return .purple
            case .unknown:
#if os(iOS)
                return Color(.systemGray3)
#elseif os(macOS)
                return Color(NSColor.windowBackgroundColor)
#endif
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? accentColor : accentColor.opacity(0.35),
                    lineWidth: isSelected ? 2 : 1
                )

            // Left accent strip
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor)
                    .frame(width: 4)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 8, bottomLeadingRadius: 8,
                            bottomTrailingRadius: 0, topTrailingRadius: 0
                        )
                    )
                Spacer()
            }

            VStack(spacing: 1) {
                Text(node.label)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(node.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
        }
        .opacity(isDimmed ? 0.2 : 1.0)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .shadow(color: isSelected ? accentColor.opacity(0.25) : .clear, radius: 6)
        .animation(.spring(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isDimmed)
    }
}

// MARK: - Node Tooltip

struct NodeTooltip: View {
    let node: GraphNode

    var accentColor: Color {
        switch node.device {
        case .cpu:           return .blue
        case .gpu:           return .green
        case .neuralEngine:  return .purple
        case .unknown:       return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: node.device.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(accentColor)
                Text(node.device.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            Text(node.subtitle)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
            if !node.inputs.isEmpty {
                Text("In: " + node.inputs.prefix(3).joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !node.outputs.isEmpty {
                Text("Out: " + node.outputs.prefix(3).joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accentColor.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8)
        .frame(width: 200)
    }
}
