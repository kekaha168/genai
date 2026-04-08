// Views/Tabs/BenchmarkTab.swift
import SwiftUI
import Charts

struct BenchmarkTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabScaffold(title: "Benchmark", subtitle: "Latency · Throughput · Cross-unit comparison") {
            if store.selectedModel == nil {
                NoModelPlaceholder().frame(height: 400)
            } else {
                VStack(spacing: 20) {
                    BenchmarkConfigCard()
                    if store.benchmarkState != .idle || !store.benchmarkRuns.isEmpty {
                        BenchmarkProgressCard()
                    }
                    if let run = store.currentRun {
                        BenchmarkResultsCard(run: run)
                    }
                    if store.benchmarkRuns.count > 1 {
                        CrossUnitComparisonCard()
                    }
                    if !store.benchmarkRuns.isEmpty {
                        RunHistoryCard()
                    }
                }
            }
        }
    }
}

// ─── Config ───────────────────────────────────────────────────────
struct BenchmarkConfigCard: View {
    @EnvironmentObject var store: AppStore

    var isRunning: Bool { store.benchmarkState == .warmup || store.benchmarkState == .running }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 16) {
                LabSectionHeader(icon: "gearshape.fill", title: "Configuration")

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WARMUP").font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.3)).kerning(1)
                        HStack(spacing: 6) {
                            ForEach([1, 3, 5, 10], id: \.self) { n in
                                CounterChip(value: n, selected: store.warmupCount == n) {
                                    store.warmupCount = n
                                }
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ITERATIONS").font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.3)).kerning(1)
                        HStack(spacing: 6) {
                            ForEach([5, 10, 20, 50], id: \.self) { n in
                                CounterChip(value: n, selected: store.iterationCount == n) {
                                    store.iterationCount = n
                                }
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.06))

                ComputeUnitPicker(selection: $store.selectedComputeUnit)

                LabButton(
                    title: isRunning ? "Running…" : "Run Benchmark",
                    icon: isRunning ? "hourglass" : "bolt.fill",
                    isLoading: isRunning,
                    color: Color(hex: "#A78BFA")
                ) {
                    Task { await store.runBenchmark() }
                }
                .disabled(store.loadedModel == nil || isRunning)
            }
        }
    }
}

struct CounterChip: View {
    let value: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 11, weight: selected ? .black : .regular, design: .monospaced))
                .foregroundColor(selected ? Color(hex: "#A78BFA") : Color.white.opacity(0.4))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color(hex: "#A78BFA").opacity(0.15) : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color(hex: "#A78BFA").opacity(0.4) : Color.clear, lineWidth: 1))
                )
        }.buttonStyle(.plain)
    }
}

// ─── Progress ─────────────────────────────────────────────────────
struct BenchmarkProgressCard: View {
    @EnvironmentObject var store: AppStore

    var statusLabel: String {
        switch store.benchmarkState {
        case .idle:    return "IDLE"
        case .warmup:  return "WARMING UP"
        case .running: return "PROFILING"
        case .done:    return "COMPLETE"
        }
    }
    var statusColor: Color {
        switch store.benchmarkState {
        case .idle:    return Color.white.opacity(0.3)
        case .warmup:  return Color(hex: "#F59E0B")
        case .running: return Color(hex: "#A78BFA")
        case .done:    return Color(hex: "#34D399")
        }
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(label: statusLabel, color: statusColor)
                    Spacer()
                    if store.benchmarkState == .running {
                        Text("\(Int(store.benchmarkProgress * 100))%")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#A78BFA"))
                    }
                }

                if store.benchmarkState == .running || store.benchmarkState == .warmup {
                    ProgressView(value: store.benchmarkProgress)
                        .tint(Color(hex: "#A78BFA"))
                        .animation(.linear(duration: 0.1), value: store.benchmarkProgress)
                }

                // Live latency sparkline
                if !store.liveLatencies.isEmpty {
                    LatencySparkline(values: store.liveLatencies)
                        .frame(height: 50)
                }
            }
        }
    }
}

struct LatencySparkline: View {
    let values: [Double]

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                LineMark(x: .value("i", i), y: .value("ms", v))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("i", i), y: .value("ms", v))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA").opacity(0.3), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisValueLabel()
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }
}

// ─── Results ──────────────────────────────────────────────────────
struct BenchmarkResultsCard: View {
    let run: BenchmarkRun

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 16) {
                LabSectionHeader(icon: "chart.bar.fill", title: "Results",
                                subtitle: "\(run.modelName) · \(run.computeUnit.rawValue)")

                // Metric grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    MetricTile(label: "MEAN", value: String(format: "%.2f", run.meanMs), unit: "ms",
                               accentColor: run.computeUnit.color.swiftUIColor)
                    MetricTile(label: "MIN",  value: String(format: "%.2f", run.minMs),  unit: "ms",
                               accentColor: Color(hex: "#34D399"))
                    MetricTile(label: "P95",  value: String(format: "%.2f", run.p95Ms),  unit: "ms",
                               accentColor: Color(hex: "#F59E0B"))
                    MetricTile(label: "THRU", value: String(format: "%.1f", run.throughput), unit: "inf/s",
                               accentColor: Color(hex: "#38BDF8"))
                }

                // Distribution histogram
                DistributionChart(predictions: run.predictions, color: run.computeUnit.color.swiftUIColor)
                    .frame(height: 130)
                    .padding(.top, 4)

                // Thermal tag
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium").font(.system(size: 10))
                    Text("Captured at thermal state: \(thermalLabel(run.thermalState))")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(Color.white.opacity(0.3))
            }
        }
    }

    func thermalLabel(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

struct DistributionChart: View {
    let predictions: [Double]
    let color: Color

    // Bucket into 10 bins
    var bins: [(range: String, count: Int)] {
        guard !predictions.isEmpty else { return [] }
        let mn = predictions.min()!
        let mx = predictions.max()!
        let span = mx - mn
        guard span > 0 else { return [("", predictions.count)] }
        let binCount = 10
        let binWidth = span / Double(binCount)
        return (0..<binCount).map { i in
            let lo = mn + Double(i) * binWidth
            let hi = lo + binWidth
            let count = predictions.filter { $0 >= lo && ($0 < hi || i == binCount - 1) }.count
            return (String(format: "%.1f", lo), count)
        }
    }

    var body: some View {
        Chart(bins, id: \.range) { bin in
            BarMark(x: .value("ms", bin.range), y: .value("count", bin.count))
                .foregroundStyle(color.opacity(0.7))
                .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) {
                AxisValueLabel().font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel().font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
            }
        }
    }
}

// ─── Cross-unit comparison ────────────────────────────────────────
struct CrossUnitComparisonCard: View {
    @EnvironmentObject var store: AppStore

    // Latest run per compute unit
    var latestPerUnit: [BenchmarkRun] {
        var seen = Set<ComputeUnit.RawValue>()
        return store.benchmarkRuns.reversed().filter { seen.insert($0.computeUnit.rawValue).inserted }
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "arrow.left.arrow.right", title: "Cross-Unit Comparison",
                                subtitle: "Most recent run per compute path")

                Chart(latestPerUnit, id: \.id) { run in
                    BarMark(
                        x: .value("Unit", run.computeUnit.rawValue),
                        y: .value("ms",   run.meanMs)
                    )
                    .foregroundStyle(run.computeUnit.color.swiftUIColor)
                    .cornerRadius(5)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", run.meanMs))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel().font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.white.opacity(0.3))
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    }
                }
                .chartXAxis {
                    AxisMarks { AxisValueLabel().font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.white.opacity(0.5)) }
                }
            }
        }
    }
}

// ─── Run History ──────────────────────────────────────────────────
struct RunHistoryCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabSectionHeader(icon: "clock.arrow.circlepath", title: "Run History")
                ForEach(store.benchmarkRuns.reversed().prefix(8)) { run in
                    HStack(spacing: 12) {
                        Circle().fill(run.computeUnit.color.swiftUIColor).frame(width: 7, height: 7)
                        Text(run.computeUnit.rawValue)
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(Color.white.opacity(0.6))
                        Spacer()
                        Text(String(format: "%.2f ms", run.meanMs))
                            .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        Text(run.timestamp, style: .time)
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(Color.white.opacity(0.3))
                    }
                    .padding(.vertical, 3)
                    Divider().background(Color.white.opacity(0.04))
                }
            }
        }
    }
}
