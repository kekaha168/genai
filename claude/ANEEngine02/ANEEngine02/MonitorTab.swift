// Views/Tabs/MonitorTab.swift
import SwiftUI
import Charts

struct MonitorTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabScaffold(title: "Live Monitor", subtitle: "Continuous inference · rolling latency") {
            if store.selectedModel == nil {
                NoModelPlaceholder().frame(height: 400)
            } else {
                VStack(spacing: 20) {
                    MonitorControlCard()
                    if store.isMonitoring || !store.rollingLatencies.isEmpty {
                        LiveLatencyChartCard()
                        LiveStatsRow()
                    }
                    MonitorExplainerCard()
                }
            }
        }
    }
}

// ─── Control ──────────────────────────────────────────────────────
struct MonitorControlCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "waveform.path.ecg", title: "Monitor Control")

                ComputeUnitPicker(selection: $store.monitorComputeUnit)
                    .disabled(store.isMonitoring)

                HStack(spacing: 12) {
                    if !store.isMonitoring {
                        LabButton(title: "Start Monitor", icon: "play.fill", color: Color(hex: "#34D399")) {
                            store.startMonitor()
                        }
                    } else {
                        LabButton(title: "Stop Monitor", icon: "stop.fill", color: Color(hex: "#F87171")) {
                            store.stopMonitor()
                        }
                        PulsingDot(color: Color(hex: "#34D399"))
                        Text("LIVE — inference every 200ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "#34D399"))
                    }
                }
            }
        }
    }
}

struct PulsingDot: View {
    let color: Color
    @State private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(2 - scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    scale = 2
                }
            }
    }
}

// ─── Chart ────────────────────────────────────────────────────────
struct LiveLatencyChartCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LabSectionHeader(icon: "waveform", title: "Rolling Latency",
                                    subtitle: "Last \(store.rollingLatencies.count) samples")
                    Spacer()
                    if let last = store.rollingLatencies.last {
                        Text(String(format: "%.1f ms", last))
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }

                // Main chart
                Chart {
                    ForEach(Array(store.rollingLatencies.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("sample", i), y: .value("ms", v))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("sample", i), y: .value("ms", v))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#A78BFA").opacity(0.25), Color.clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                    }

                    // Mean rule line
                    if !store.rollingLatencies.isEmpty {
                        let mean = store.rollingLatencies.reduce(0,+) / Double(store.rollingLatencies.count)
                        RuleMark(y: .value("mean", mean))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color(hex: "#F59E0B").opacity(0.6))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(String(format: "avg %.1f", mean))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(Color(hex: "#F59E0B").opacity(0.8))
                            }
                    }
                }
                .frame(height: 160)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel()
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .animation(.linear(duration: 0.15), value: store.rollingLatencies.count)
            }
        }
    }
}

// ─── Live Stats ───────────────────────────────────────────────────
struct LiveStatsRow: View {
    @EnvironmentObject var store: AppStore

    var latencies: [Double] { store.rollingLatencies }
    var mean: Double { latencies.isEmpty ? 0 : latencies.reduce(0,+)/Double(latencies.count) }
    var minV: Double { latencies.min() ?? 0 }
    var maxV: Double { latencies.max() ?? 0 }
    var throughput: Double { mean > 0 ? 1000.0/mean : 0 }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            MetricTile(label: "MEAN",  value: String(format: "%.1f", mean),       unit: "ms",    accentColor: Color(hex: "#A78BFA"))
            MetricTile(label: "MIN",   value: String(format: "%.1f", minV),       unit: "ms",    accentColor: Color(hex: "#34D399"), trend: .down)
            MetricTile(label: "MAX",   value: String(format: "%.1f", maxV),       unit: "ms",    accentColor: Color(hex: "#F87171"), trend: .up)
            MetricTile(label: "THRU",  value: String(format: "%.1f", throughput), unit: "inf/s", accentColor: Color(hex: "#38BDF8"))
        }
    }
}

// ─── Explainer ────────────────────────────────────────────────────
struct MonitorExplainerCard: View {
    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabSectionHeader(icon: "info.circle.fill", title: "About Live Monitor")
                Text("The monitor runs continuous inference on synthetic inputs every 200ms, allowing you to observe latency variance and the effect of thermal throttling over time. Compare the same model under different compute units to observe routing differences.\n\nNote: CoreML selects its compute route at load time — switch the unit above and tap Start to reload with a different configuration.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
