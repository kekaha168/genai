// MetalTestViews.swift
// SwiftUI wrappers for each Metal shader test.

import SwiftUI
import MetalKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Generic SwiftUI MetalView
// ─────────────────────────────────────────────────────────────────────────────

struct MetalView: UIViewRepresentable {
    let drawBlock: DrawBlock

    func makeCoordinator() -> MetalViewCoordinator {
        let c = MetalViewCoordinator()
        c.drawBlock = drawBlock
        return c
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: GPUContext.shared.device)
        view.delegate          = context.coordinator
        view.colorPixelFormat  = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.clearColor        = MTLClearColorMake(0.05, 0.06, 0.10, 1.0)
        view.isPaused          = false
        view.enableSetNeedsDisplay = false
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Test 1: Latency Distribution Chart
// ─────────────────────────────────────────────────────────────────────────────

/// Simulates 1 M memory accesses on-GPU and renders a colour-coded histogram:
/// baseline (coral), hedged-2 (teal), hedged-4 (blue). Vertical lines mark P99.
struct LatencyChartView: View {
    @StateObject private var vm = LatencyChartVM()

    var body: some View {
        VStack(spacing: 0) {
            legend
            MetalView(drawBlock: vm.drawBlock)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            statsBar
        }
        .background(Color(white: 0.07))
    }

    private var legend: some View {
        HStack(spacing: 20) {
            legendItem(color: Color(red: 0.95, green: 0.35, blue: 0.25), label: "Baseline")
            legendItem(color: Color(red: 0.25, green: 0.75, blue: 0.55), label: "Hedged ×2")
            legendItem(color: Color(red: 0.30, green: 0.55, blue: 0.95), label: "Hedged ×4")
        }
        .padding(.vertical, 8)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var statsBar: some View {
        HStack {
            statCell(title: "P99 Baseline",  value: vm.p99Base,   color: .orange)
            Divider().frame(height: 24).background(Color.white.opacity(0.2))
            statCell(title: "P99 Hedged×2",  value: vm.p99Hedged, color: .green)
            Divider().frame(height: 24).background(Color.white.opacity(0.2))
            statCell(title: "Tail Reduction", value: vm.reduction, color: .yellow)
        }
        .padding(10)
        .background(Color(white: 0.10))
    }

    private func statCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
final class LatencyChartVM: ObservableObject {
    @Published var p99Base    = "—"
    @Published var p99Hedged  = "—"
    @Published var reduction  = "—"

    private let compute  = LatencyHistogramCompute()
    private let renderer: FullscreenQuadRenderer

    init() {
        renderer = FullscreenQuadRenderer(fragmentFunctionName: "chart_fragment")
    }

    lazy var drawBlock: DrawBlock = { [weak self] cb, drawable, time in
        guard let self else { return }
        self.compute.encode(commandBuffer: cb, seed: Float(time) * 0.1)

        let p99b = self.compute.p99(buffer: self.compute.histBaseline)
        let p99h = self.compute.p99(buffer: self.compute.histHedged2)
        let red  = 1.0 - p99h / max(p99b, 0.001)

        Task { @MainActor in
            let baseNs  = Int(p99b * (60 + 350 + 10))
            let hedgeNs = Int(p99h * (60 + 350 + 10))
            self.p99Base    = "\(baseNs) ns"
            self.p99Hedged  = "\(hedgeNs) ns"
            self.reduction  = String(format: "%.1f%%", red * 100)
        }

        // Find max bin count for normalisation
        let basePtr = self.compute.histBaseline.contents()
            .assumingMemoryBound(to: UInt32.self)
        var maxCount: UInt32 = 1
        for i in 0..<LatencyHistogramCompute.numBins {
            maxCount = max(maxCount, basePtr[i])
        }

        var uniforms = ChartUniforms(
            numBins:     UInt32(LatencyHistogramCompute.numBins),
            maxCount:    maxCount,
            time:        Float(time),
            p99Baseline: p99b,
            p99Hedged:   p99h
        )

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture    = drawable.texture
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
        self.renderer.encode(
            renderEncoder: enc,
            buffers: [
                (self.compute.histBaseline, 0),
                (self.compute.histHedged2,  1),
                (self.compute.histHedged4,  2)
            ],
            bytesBuffers: [
                (withUnsafePointer(to: &uniforms) { $0 },
                 MemoryLayout<ChartUniforms>.size, 3)
            ]
        )
        enc.endEncoding()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Test 2: Channel Refresh Visualizer
// ─────────────────────────────────────────────────────────────────────────────

/// Animates N DRAM channels with independent refresh sweep waves.
/// Each channel's tREFI stall window is shown in orange; a hedged-read cursor
/// races across channels and takes the first available result.
struct ChannelVizView: View {
    @State private var numChannels: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            channelPicker
            MetalView(drawBlock: makeDrawBlock(n: numChannels))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            legend
        }
        .background(Color(white: 0.05))
    }

    private var channelPicker: some View {
        HStack {
            Text("Channels:")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Picker("", selection: $numChannels) {
                ForEach([1, 2, 4, 8], id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.09))
    }

    private var legend: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 1, green: 0.4, blue: 0.1))
                    .frame(width: 14, height: 14)
                Text("Refresh Stall (tRFC ≈ 350 ns)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 1, green: 0.95, blue: 0.4))
                    .frame(width: 14, height: 14)
                Text("Hedged Read Cursor")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 8)
        .background(Color(white: 0.09))
    }

    private func makeDrawBlock(n: Int) -> DrawBlock {
        let rend = FullscreenQuadRenderer(fragmentFunctionName: "channel_viz_fragment")
        let ctx  = GPUContext.shared

        // Deterministic but decorrelated phase offsets matching Tailslayer's offsets
        let phases: [Float] = (0..<8).map { i in Float(i) / Float(8) + 0.13 }

        return { cb, drawable, time in
            struct ChannelUniforms {
                var time:          Float
                var numChannels:   UInt32
                var channelOffsets: (Float, Float, Float, Float, Float, Float, Float, Float)
            }
            var uni = ChannelUniforms(
                time: Float(time),
                numChannels: UInt32(n),
                channelOffsets: (phases[0], phases[1], phases[2], phases[3],
                                 phases[4], phases[5], phases[6], phases[7])
            )

            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture    = drawable.texture
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

            let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
            rend.encode(
                renderEncoder: enc,
                buffers: [],
                bytesBuffers: [
                    (withUnsafePointer(to: &uni) { $0 },
                     MemoryLayout<ChannelUniforms>.size, 0)
                ]
            )
            enc.endEncoding()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Test 3: Tail-Latency Reduction Gauge
// ─────────────────────────────────────────────────────────────────────────────

/// Animated speedometer gauge: left is fast (P0), right is slow (P100).
/// Coral arc = baseline P99. Teal arc + needle = hedged P99.
struct GaugeView: View {
    @StateObject private var vm = GaugeVM()

    var body: some View {
        VStack(spacing: 0) {
            header
            MetalView(drawBlock: vm.drawBlock)
                .aspectRatio(1.0, contentMode: .fit)
                .frame(maxWidth: 360)
            reductionLabel
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.06))
    }

    private var header: some View {
        Text("P99 Tail Latency Reduction")
            .font(.system(.headline, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            .padding(.top, 16)
    }

    private var reductionLabel: some View {
        HStack(spacing: 32) {
            VStack {
                Text("BASELINE P99")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text(vm.baseLabel)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
            }
            VStack {
                Text("HEDGED×2 P99")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text(vm.hedgedLabel)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.55))
            }
            VStack {
                Text("REDUCTION")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text(vm.reductionLabel)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.top, 12)
    }
}

@MainActor
final class GaugeVM: ObservableObject {
    @Published var baseLabel      = "— ns"
    @Published var hedgedLabel    = "— ns"
    @Published var reductionLabel = "—"

    private let compute = LatencyHistogramCompute()
    private let renderer: FullscreenQuadRenderer

    init() {
        renderer = FullscreenQuadRenderer(fragmentFunctionName: "gauge_fragment")
    }

    lazy var drawBlock: DrawBlock = { [weak self] cb, drawable, time in
        guard let self else { return }
        self.compute.encode(commandBuffer: cb, seed: 42.0)

        let p99b = self.compute.p99(buffer: self.compute.histBaseline)
        let p99h = self.compute.p99(buffer: self.compute.histHedged2)
        let red  = 1.0 - p99h / max(p99b, 0.001)

        Task { @MainActor in
            let maxNs: Int = 60 + 350 + 10
            self.baseLabel      = "\(Int(p99b * Float(maxNs))) ns"
            self.hedgedLabel    = "\(Int(p99h * Float(maxNs))) ns"
            self.reductionLabel = String(format: "%.1f%%", red * 100)
        }

        struct GaugeUniforms {
            var p99Base: Float; var p99Hedged: Float
            var time: Float; var reduction: Float
        }
        var uni = GaugeUniforms(
            p99Base:   p99b,
            p99Hedged: p99h,
            time:      Float(time),
            reduction: Float(red)
        )

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture    = drawable.texture
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.06, 0.07, 0.10, 1)

        let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
        self.renderer.encode(
            renderEncoder: enc,
            buffers: [],
            bytesBuffers: [(withUnsafePointer(to: &uni) { $0 },
                            MemoryLayout<GaugeUniforms>.size, 0)]
        )
        enc.endEncoding()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Test 4: Channel Scrambling Heatmap
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a 2-D logical address space; colour encodes which DRAM channel
/// each address maps to after XOR-based channel scrambling.
/// Adjustable channel-bit selector reproduces Tailslayer's discovery work.
struct ScramblingHeatmapView: View {
    @State private var channelBit:   Int   = 8
    @State private var numChannels:  Int   = 2
    @State private var zoom:         Float = 1.0

    var body: some View {
        VStack(spacing: 0) {
            controls
            MetalView(drawBlock: makeDrawBlock())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            caption
        }
        .background(Color(white: 0.05))
    }

    @ViewBuilder private var controls: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Channel bit:")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Slider(value: Binding(
                    get: { Double(channelBit) },
                    set: { channelBit = Int($0) }
                ), in: 6...12, step: 1)
                Text("\(channelBit)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.yellow)
                    .frame(width: 24)
            }
            HStack {
                Text("Channels:")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Picker("", selection: $numChannels) {
                    ForEach([1, 2, 4, 8], id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Spacer()
                Text("Zoom:")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Slider(value: $zoom, in: 1...8, step: 1)
                    .frame(width: 80)
                Text("×\(Int(zoom))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(width: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.09))
    }

    private var caption: some View {
        Text("Each color = a DRAM channel  |  Orange cells = in-refresh stall  |  Bit \(channelBit) controls channel selection")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.white.opacity(0.45))
            .padding(6)
            .background(Color(white: 0.09))
    }

    private func makeDrawBlock() -> DrawBlock {
        let rend = FullscreenQuadRenderer(fragmentFunctionName: "scramble_fragment")
        let cBit = channelBit
        let nCh  = numChannels
        let zm   = zoom

        return { cb, drawable, time in
            struct ScramblingUniforms {
                var time: Float; var channelBit: UInt32
                var numChannels: UInt32; var zoom: Float
            }
            var uni = ScramblingUniforms(
                time: Float(time), channelBit: UInt32(cBit),
                numChannels: UInt32(nCh), zoom: zm
            )

            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture    = drawable.texture
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

            let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
            rend.encode(
                renderEncoder: enc,
                buffers: [],
                bytesBuffers: [(withUnsafePointer(to: &uni) { $0 },
                                MemoryLayout<ScramblingUniforms>.size, 0)]
            )
            enc.endEncoding()
        }
    }
}
