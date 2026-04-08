// ContentView.swift
// GPU Workload Lab — SwiftUI Interface

import SwiftUI
import Charts
internal import Combine

// ═══════════════════════════════════════════════════
//  MARK: – Top-level entry / error gate
// ═══════════════════════════════════════════════════
struct ContentView: View {
    @StateObject private var vm: LabViewModel

    init() {
        // Initialise the view-model; surface Metal init errors in UI
        _vm = StateObject(wrappedValue: LabViewModel())
    }

    var body: some View {
        if let err = vm.fatalError {
            FatalErrorView(message: err)
        } else {
            LabView(vm: vm)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – ViewModel
// ═══════════════════════════════════════════════════
@MainActor
final class LabViewModel: ObservableObject {
    var objectWillChange: ObservableObjectPublisher?

    @Published var benchmark:   MetalBenchmark?
    @Published var fatalError:  String?

    // Controls
    @Published var matrixSizeIndex: Int = 2          // index into presets
    @Published var iterations:      Int = 3

    let matrixPresets: [(label: String, size: Int)] = [
        ("128 × 128",   128),
        ("256 × 256",   256),
        ("512 × 512",   512),
        ("1024 × 1024", 1024),
    ]

    var selectedSize: Int { matrixPresets[matrixSizeIndex].size }

    var results: [BenchmarkResult] { benchmark?.results ?? [] }
    var isRunning: Bool            { benchmark?.isRunning ?? false }
    var progress: Double           { benchmark?.progress ?? 0 }
    var statusText: String         { benchmark?.statusText ?? "" }
    var errorMsg: String?          { benchmark?.errorMsg }

    // Speedup ratio (Optimized vs Naive)
    var speedup: Double? {
        guard
            let naive = results.first(where: { $0.kernelName == "Naive"     })?.elapsedMs,
            let optim = results.first(where: { $0.kernelName == "Optimized" })?.elapsedMs,
            optim > 0
        else { return nil }
        return naive / optim
    }

    init() {
        do {
            benchmark = try MetalBenchmark()
        } catch {
            fatalError = error.localizedDescription
        }
    }

    func run() {
        guard let bm = benchmark else { return }
        Task {
            await bm.runBenchmarks(matrixSize: selectedSize, iterations: iterations)
            objectWillChange.send()
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Main Lab View
// ═══════════════════════════════════════════════════
struct LabView: View {
    @ObservedObject var vm: LabViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HeaderBanner()
                    MemoryHierarchyDiagram()
                    ConfigPanel(vm: vm)
                    RunButton(vm: vm)
                    if vm.isRunning { ProgressSection(vm: vm) }
                    if !vm.results.isEmpty { ResultsSection(vm: vm) }
                    ExplainerSection()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            #if os(iOS)
            .background(
                Color(uiColor: .systemGroupedBackground)
            )
            #elseif os(macOS)
            .background(
                Color(nsColor: .windowBackgroundColor)
                )
            #endif
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Header
// ═══════════════════════════════════════════════════
struct HeaderBanner: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0A0E1A"), Color(hex: "#0D2137")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Grid decoration
                    Canvas { ctx, size in
                        let step: CGFloat = 28
                        var path = Path()
                        var x: CGFloat = 0
                        while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                        var y: CGFloat = 0
                        while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                        ctx.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                )
                .frame(height: 160)

            VStack(alignment: .leading, spacing: 6) {
                Label("GPU Workload Lab", systemImage: "cpu.fill")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Apple Silicon · Metal · Memory Hierarchy")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#4FC3F7"))
            }
            .padding(20)
        }
        .padding(.top, 16)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Memory Hierarchy Diagram
// ═══════════════════════════════════════════════════
struct MemoryHierarchyDiagram: View {
    let levels: [(name: String, subtitle: String, color: Color, width: CGFloat)] = [
        ("Registers",          "Per-thread · ~ns",    Color(hex: "#FF6B6B"), 0.30),
        ("Threadgroup Memory", "Shared · ~10ns",      Color(hex: "#FFD93D"), 0.50),
        ("L2 Cache",           "Shared · ~50ns",      Color(hex: "#6BCB77"), 0.70),
        ("Main RAM (UMA)",     "CPU+GPU · ~100ns",    Color(hex: "#4D96FF"), 1.00),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "pyramid.fill", title: "Memory Hierarchy")
            VStack(spacing: 6) {
                ForEach(levels, id: \.name) { level in
                    GeometryReader { geo in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(level.color.opacity(0.85))
                                .frame(width: geo.size.width * level.width * 0.6, height: 40)
                                .overlay(
                                    Text(level.name)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black.opacity(0.85))
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                )
                            Text(level.subtitle)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .frame(height: 40)
                }
            }
        }
        .padding(16)
        #if os(iOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        #elseif os(macOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.controlBackgroundColor)))
        #endif
    }
}

//// ═══════════════════════════════════════════════════
////  MARK: – Config Panel
//// ═══════════════════════════════════════════════════
//struct ConfigPanel: View {
//    @ObservedObject var vm: LabViewModel
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 14) {
//            SectionHeader(icon: "slider.horizontal.3", title: "Configuration")
//
//            VStack(alignment: .leading, spacing: 6) {
//                Label("Matrix Dimension", systemImage: "square.grid.3x3.fill")
//                    .font(.system(size: 13, weight: .semibold))
//                    .foregroundColor(.primary)
//
//                Picker("Matrix Size", selection: $vm.matrixSizeIndex) {
//                    ForEach(vm.matrixPresets.indices, id: \.self) { i in
//                        Text(vm.matrixPresets[i].label).tag(i)
//                    }
//                }
//                .pickerStyle(.segmented)
//            }
//
//            VStack(alignment: .leading, spacing: 6) {
//                Label("Iterations (averaged)", systemImage: "repeat")
//                    .font(.system(size: 13, weight: .semibold))
//                    .foregroundColor(.primary)
//
//                HStack(spacing: 16) {
//                    ForEach([1, 3, 5], id: \.self) { n in
//                        Button {
//                            vm.iterations = n
//                        } label: {
//                            Text("\(n)×")
//                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
//                                .frame(maxWidth: .infinity)
//                                .padding(.vertical, 8)
//                                .background(vm.iterations == n ? Color.accentColor : Color(.tertiaryGroupedBackground))
//                                .foregroundColor(vm.iterations == n ? .white : .primary)
//                                .cornerRadius(10)
//                        }
//                    }
//                }
//            }
//        }
//        .padding(16)
//        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondaryGroupedBackground)))
//    }
//}

//  MARK: – Config Panel
// ═══════════════════════════════════════════════════
struct ConfigPanel: View {
    @ObservedObject var vm: LabViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(icon: "slider.horizontal.3", title: "Configuration")
            
            matrixSizeSection
            
            iterationsSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondaryGroupedBackground)
        )
    }
    
    // MARK: - Sub-Expressions
    
    private var matrixSizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Matrix Dimension", systemImage: "square.grid.3x3.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Picker("Matrix Size", selection: $vm.matrixSizeIndex) {
                ForEach(vm.matrixPresets.indices, id: \.self) { i in
                    Text(vm.matrixPresets[i].label).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var iterationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Iterations (averaged)", systemImage: "repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                let options: [Int] = [1, 3, 5]
                ForEach(options, id: \.self) { n in
                    iterationButton(for: n)
                }
            }
        }
    }
    
    private func iterationButton(for n: Int) -> some View {
        Button {
            vm.iterations = n
        } label: {
            Text("\(n)×")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(vm.iterations == n ? Color.accentColor : Color.tertiaryGroupedBackground)
                .foregroundColor(vm.iterations == n ? .white : .primary)
                .cornerRadius(10)
        }
        // Essential for cross-platform: macOS buttons wrap Text in a gray pill
        // by default. .plain removes this so your custom background works.
        .buttonStyle(.plain)
    }
}


extension Color {
    static var secondaryGroupedBackground: Color {
#if os(iOS) || os(tvOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
#elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor) // macOS equivalent
#else
        return Color.clear
#endif
    }
    
    static var tertiaryGroupedBackground: Color {
#if os(iOS) || os(tvOS)
        return Color(uiColor: .tertiarySystemGroupedBackground)
#elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor) // macOS equivalent
#else
        return Color.clear
#endif
    }
}

//extension Color {
//    static var secondaryGroupedBackground: Color {
//#if os(iOS)
//        return Color(uiColor: .secondarySystemGroupedBackground)
//#elseif os(macOS)
//        return Color(nsColor: .windowBackgroundColor) // macOS equivalent
//#else
//        return Color.clear
//#endif
//    }
//    
//    static var tertiaryGroupedBackground: Color {
//#if os(iOS)
//        return Color(uiColor: .tertiarySystemGroupedBackground)
//#elseif os(macOS)
//        return Color(nsColor: .controlBackgroundColor) // macOS equivalent
//#else
//        return Color.clear
//#endif
//    }
//}

// ═══════════════════════════════════════════════════
//  MARK: – Run Button
// ═══════════════════════════════════════════════════
struct RunButton: View {
    @ObservedObject var vm: LabViewModel

    var body: some View {
        Button(action: vm.run) {
            HStack(spacing: 10) {
                if vm.isRunning {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(vm.isRunning ? "Running…" : "Run Benchmark")
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                vm.isRunning
                    ? AnyShapeStyle(Color.gray)
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(hex: "#0066FF"), Color(hex: "#0044BB")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(vm.isRunning)
        .shadow(color: .blue.opacity(0.35), radius: 8, y: 4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Progress Section
// ═══════════════════════════════════════════════════
struct ProgressSection: View {
    @ObservedObject var vm: LabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vm.statusText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            ProgressView(value: vm.progress)
                .tint(.blue)
        }
        .padding(16)
        //.background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondaryGroupedBackground)))
#if os(iOS) || os(tvOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
#elseif os(macOS)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.windowBackgroundColor)))
#endif
        return Color.clear
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Results Section
// ═══════════════════════════════════════════════════
struct ResultsSection: View {
    @ObservedObject var vm: LabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "chart.bar.fill", title: "Results")

            // Metric cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(vm.results, id: \.kernelName) { r in
                    ResultCard(result: r)
                }
            }

            // Speedup pill
            if let s = vm.speedup {
                SpeedupBadge(speedup: s)
            }

            // Chart
            BarChartView(results: vm.results)
        }
        .padding(16)
//        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondaryGroupedBackground)))
#if os(iOS) || os(tvOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
#elseif os(macOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.windowBackgroundColor)))
#endif
    }
}

struct ResultCard: View {
    let result: BenchmarkResult
    private var accentColor: Color { result.kernelName == "Naive" ? Color(hex: "#FF6B6B") : Color(hex: "#6BCB77") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(accentColor).frame(width: 8, height: 8)
                Text(result.kernelName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                Spacer()
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isCorrect ? .green : .red)
                    .font(.caption)
            }

            Text(String(format: "%.2f ms", result.elapsedMs))
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundColor(.primary)

            Text(String(format: "%.2f GFLOP/s", result.gflops))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            Text("\(result.matrixSize)×\(result.matrixSize)")
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(accentColor.opacity(0.15)))
                .foregroundColor(accentColor)
        }
        .padding(14)
//        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondaryGroupedBackground)))
#if os(iOS) || os(tvOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
#elseif os(macOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.windowBackgroundColor)))
#endif
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.3), lineWidth: 1))
    }
}

struct SpeedupBadge: View {
    let speedup: Double

    var body: some View {
        HStack {
            Image(systemName: "bolt.fill").foregroundColor(.yellow)
            Text(String(format: "Optimized is %.2f× faster", speedup))
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        )
    }
}

// ─── Bar Chart using Swift Charts ───────────────────
struct BarChartView: View {
    let results: [BenchmarkResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Execution Time (ms)  —  lower is better")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)

            Chart(results, id: \.kernelName) { r in
                BarMark(
                    x: .value("Kernel", r.kernelName),
                    y: .value("ms",     r.elapsedMs)
                )
                .foregroundStyle(r.kernelName == "Naive" ? Color(hex: "#FF6B6B") : Color(hex: "#6BCB77"))
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text(String(format: "%.1f", r.elapsedMs))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .chartYAxis { AxisMarks(preset: .aligned) }
            .frame(height: 180)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Explainer
// ═══════════════════════════════════════════════════
struct ExplainerSection: View {
    let items: [(icon: String, title: String, body: String)] = [
        ("bolt.slash",   "Naive Kernel",
         "Each GPU thread independently reads A and B from main RAM (UMA) on every multiply-accumulate step. High bandwidth pressure, no data reuse."),
        ("memorychip",   "Optimised Kernel (Tiled)",
         "Loads 16×16 tiles cooperatively into fast threadgroup memory. Each value is read from main RAM only once — subsequent MACs hit on-chip SRAM."),
        ("cpu",          "Apple Silicon UMA",
         "CPU and GPU share the same physical DRAM. Zero-copy buffers eliminate CPU↔GPU transfer overhead, but the Registers→Threadgroup→L2→RAM hierarchy still governs performance."),
        ("arrow.triangle.2.circlepath", "SIMT Execution",
         "64 threads execute in lockstep per SIMD-group. threadgroup_barrier() synchronises all threads before a tile is consumed or overwritten — essential for correctness."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "info.circle.fill", title: "How It Works")
            ForEach(items, id: \.title) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                        Text(item.body)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if item.title != items.last!.title { Divider() }
            }
        }
        .padding(16)
        #if os(iOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(
            //Color(.secondarySystemGroupedBackground))
            Color(uiColor: .systemGroupedBackground)
            ))
        #elseif os(macOS)
        .background(RoundedRectangle(cornerRadius: 16).fill(
            //Color(.secondarySystemGroupedBackground))
            Color(nsColor: .windowBackgroundColor)
        ))
        #endif
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Fatal Error View
// ═══════════════════════════════════════════════════
struct FatalErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle).foregroundColor(.red)
            Text("Metal Unavailable").font(.headline)
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Shared sub-components
// ═══════════════════════════════════════════════════
struct SectionHeader: View {
    let icon: String
    let title: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
    }
}

// Hex colour convenience
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >>  8) & 0xFF) / 255
        let b = Double( val        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: – Preview
// ═══════════════════════════════════════════════════
#Preview {
    ContentView()
}
