// Views/Tabs/DeviceTab.swift
import SwiftUI

struct DeviceTab: View {
    @EnvironmentObject var store: AppStore

    var info: DeviceInfo { store.deviceInfo }

    var body: some View {
        TabScaffold(title: "Device", subtitle: "Silicon · ANE · Memory") {
            VStack(spacing: 20) {
                ChipCard(info: info)
                MemoryCard(info: info)
                ANECapabilityCard(info: info)
                ThermalDetailCard()
                CoreMLNotesCard()
            }
        }
    }
}

// ─── Chip Card ────────────────────────────────────────────────────
struct ChipCard: View {
    let info: DeviceInfo

    var body: some View {
        LabCard {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#A78BFA").opacity(0.12))
                        .frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1)
                        .frame(width: 72, height: 72)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "#A78BFA"))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(info.chipName)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(info.osVersion)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                    HStack(spacing: 8) {
                        StatusPill(
                            label: info.hasANE ? "ANE AVAILABLE" : "NO ANE",
                            color: info.hasANE ? Color(hex: "#34D399") : Color(hex: "#F87171")
                        )
                    }
                }
                Spacer()
            }
        }
    }
}

// ─── Memory Card ──────────────────────────────────────────────────
struct MemoryCard: View {
    let info: DeviceInfo

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "memorychip.fill", title: "Unified Memory Architecture")

                HStack(spacing: 12) {
                    MetricTile(
                        label: "TOTAL RAM",
                        value: String(format: "%.0f", info.totalRAMGB),
                        unit: "GB",
                        accentColor: Color(hex: "#38BDF8")
                    )
                    MetricTile(
                        label: "ARCHITECTURE",
                        value: "UMA",
                        unit: "",
                        accentColor: Color(hex: "#A78BFA")
                    )
                }

                Text("CPU and GPU share the same physical DRAM pool. Core ML buffers use .storageModeShared — zero-copy handoff between processor domains with no explicit DMA transfer.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// ─── ANE Capability Card ──────────────────────────────────────────
struct ANECapabilityCard: View {
    let info: DeviceInfo

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "brain.head.profile", title: "Neural Engine")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    MetricTile(
                        label: "ANE CORES",
                        value: info.aneCores.map { "\($0)" } ?? "N/A",
                        unit: "cores",
                        accentColor: Color(hex: "#A78BFA")
                    )
                    MetricTile(
                        label: "PEAK TOPS",
                        value: info.aneTopsTF.map { String(format: "%.0f", $0) } ?? "N/A",
                        unit: "TOPS",
                        accentColor: Color(hex: "#34D399")
                    )
                    MetricTile(
                        label: "PRECISION",
                        value: "FP16",
                        unit: "",
                        accentColor: Color(hex: "#F59E0B")
                    )
                }

                if !info.hasANE {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: "#F59E0B"))
                        Text("ANE not available on this device or in Simulator. All inference routes to CPU.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#F59E0B").opacity(0.8))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#F59E0B").opacity(0.08)))
                }
            }
        }
    }
}

// ─── Thermal Detail ───────────────────────────────────────────────
struct ThermalDetailCard: View {
    @EnvironmentObject var store: AppStore

    let levels: [(label: String, description: String, color: Color)] = [
        ("NOMINAL",  "Full ANE clock speed. Ideal for benchmarking.",                                Color(hex: "#34D399")),
        ("FAIR",     "Minor throttling may begin. Results still representative.",                   Color(hex: "#A3E635")),
        ("SERIOUS",  "Significant throttling. ANE clock reduced. Tag all results at this state.",   Color(hex: "#F59E0B")),
        ("CRITICAL", "Aggressive throttling across all cores. Benchmark results unreliable.",       Color(hex: "#F87171")),
    ]

    var currentLabel: String {
        switch store.thermalState {
        case .nominal: return "NOMINAL"
        case .fair: return "FAIR"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        @unknown default: return "UNKNOWN"
        }
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "thermometer.sun.fill", title: "Thermal States")

                VStack(spacing: 8) {
                    ForEach(levels, id: \.label) { level in
                        HStack(spacing: 12) {
                            HStack(spacing: 5) {
                                if level.label == currentLabel {
                                    Circle().fill(level.color).frame(width: 6, height: 6)
                                } else {
                                    Circle().stroke(level.color.opacity(0.4), lineWidth: 1).frame(width: 6, height: 6)
                                }
                                Text(level.label)
                                    .font(.system(size: 10, weight: level.label == currentLabel ? .black : .regular, design: .monospaced))
                                    .foregroundColor(level.label == currentLabel ? level.color : level.color.opacity(0.5))
                            }
                            .frame(width: 88, alignment: .leading)
                            Text(level.description)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(level.label == currentLabel ? Color.white.opacity(0.7) : Color.white.opacity(0.3))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        if level.label != "CRITICAL" { Divider().background(Color.white.opacity(0.04)) }
                    }
                }
            }
        }
    }
}

// ─── Core ML Notes ────────────────────────────────────────────────
struct CoreMLNotesCard: View {
    let notes: [(icon: String, text: String)] = [
        ("lock.fill",         "Compute unit is set at MLModel load time via MLModelConfiguration.computeUnits — not changeable per-inference."),
        ("arrow.triangle.2.circlepath", "Core ML may override your compute unit choice if a layer is unsupported on the requested hardware."),
        ("chart.line.uptrend.xyaxis", "ML Program (.mlpackage) format has materially better ANE coverage than the legacy NeuralNetwork format."),
        ("square.resize",     "Fixed input shapes are required for reliable ANE dispatch. Dynamic shapes trigger GPU or CPU fallback."),
        ("eye.slash",         "No public API exposes per-layer compute unit assignment at runtime. Use Xcode Instruments → Core ML for ground truth."),
    ]

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabSectionHeader(icon: "doc.text.fill", title: "Core ML Notes")
                VStack(spacing: 10) {
                    ForEach(notes, id: \.text) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.icon)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#A78BFA").opacity(0.7))
                                .frame(width: 16)
                            Text(note.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        if note.text != notes.last!.text {
                            Divider().background(Color.white.opacity(0.04))
                        }
                    }
                }
            }
        }
    }
}
