// Models/ANEModels.swift
import Foundation
import CoreML

// ─── Compute Unit ────────────────────────────────────────────────
enum ComputeUnit: String, CaseIterable, Identifiable {
    case all             = "ALL"
    case cpuAndNeuralEngine = "CPU + ANE"
    case cpuAndGPU       = "CPU + GPU"
    case cpuOnly         = "CPU Only"

    var id: String { rawValue }

    var mlComputeUnits: MLComputeUnits {
        switch self {
        case .all:                return .all
        case .cpuAndNeuralEngine: return .cpuAndNeuralEngine
        case .cpuAndGPU:          return .cpuAndGPU
        case .cpuOnly:            return .cpuOnly
        }
    }

    var color: ANEColor {
        switch self {
        case .all:                return .ane
        case .cpuAndNeuralEngine: return .ane
        case .cpuAndGPU:          return .gpu
        case .cpuOnly:            return .cpu
        }
    }

    var icon: String {
        switch self {
        case .all:                return "square.3.layers.3d"
        case .cpuAndNeuralEngine: return "brain"
        case .cpuAndGPU:          return "gpu"
        case .cpuOnly:            return "cpu"
        }
    }
}

// ─── Color tokens ─────────────────────────────────────────────────
enum ANEColor {
    case ane, gpu, cpu, neutral

    var swiftUIColor: SwiftUI.Color {
        switch self {
        case .ane:     return .init(hex: "#A78BFA")   // violet
        case .gpu:     return .init(hex: "#34D399")   // emerald
        case .cpu:     return .init(hex: "#F59E0B")   // amber
        case .neutral: return .init(hex: "#64748B")   // slate
        }
    }
}

// ─── Imported Model ────────────────────────────────────────────────
struct ImportedModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let url: URL
    let format: ModelFormat
    let sizeBytes: Int64
    let inputNames: [String]
    let outputNames: [String]
    let importedAt: Date

    enum ModelFormat: String {
        case mlpackage = "ML Package"
        case mlmodel   = "Neural Network"
        case unknown   = "Unknown"
    }
}

// ─── Benchmark Run ─────────────────────────────────────────────────
struct BenchmarkRun: Identifiable {
    let id: UUID
    let modelName: String
    let computeUnit: ComputeUnit
    let warmupCount: Int
    let iterationCount: Int
    let loadTimeMs: Double
    let predictions: [Double]          // ms per inference
    let thermalState: ProcessInfo.ThermalState
    let timestamp: Date

    var meanMs: Double    { predictions.isEmpty ? 0 : predictions.reduce(0,+) / Double(predictions.count) }
    var minMs: Double     { predictions.min() ?? 0 }
    var maxMs: Double     { predictions.max() ?? 0 }
    var p95Ms: Double {
        guard !predictions.isEmpty else { return 0 }
        let s = predictions.sorted()
        return s[Int(Double(s.count) * 0.95)]
    }
    var throughput: Double { meanMs > 0 ? 1000.0 / meanMs : 0 }
}

// ─── Layer Dispatch Info ───────────────────────────────────────────
struct LayerDispatch: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let computeUnit: ComputeUnit
    let estimatedFlops: Int?
}

// ─── Compatibility Report ──────────────────────────────────────────
struct CompatibilityReport {
    let modelName: String
    let format: ImportedModel.ModelFormat
    let estimatedANEScore: Int          // 0–100
    let flags: [CompatibilityFlag]
    let inputShapes: [String: String]
    let outputShapes: [String: String]

    struct CompatibilityFlag: Identifiable {
        let id = UUID()
        let severity: Severity
        let message: String
        enum Severity { case info, warning, error }
    }
}

// ─── Device Info ──────────────────────────────────────────────────
struct DeviceInfo {
    let chipName: String
    let aneCores: Int?
    let aneTopsTF: Double?
    let totalRAMGB: Double
    let osVersion: String
    let hasANE: Bool

    static func current() -> DeviceInfo {
        var sysInfo = utsname()
        uname(&sysInfo)
        let machine = withUnsafeBytes(of: &sysInfo.machine) { ptr in
            String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
        }
        return DeviceInfo(
            chipName:   chipNameForMachine(machine),
            aneCores:   aneCountForMachine(machine),
            aneTopsTF:  aneTOPSForMachine(machine),
            totalRAMGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            osVersion:  ProcessInfo.processInfo.operatingSystemVersionString,
            hasANE:     hasANEForMachine(machine)
        )
    }

    static private func chipNameForMachine(_ m: String) -> String {
        switch true {
        case m.hasPrefix("iPhone17"): return "A18 Pro"
        case m.hasPrefix("iPhone16"): return "A17 Pro"
        case m.hasPrefix("iPhone15"): return "A16 Bionic"
        case m.hasPrefix("iPhone14"): return "A15 Bionic"
        case m.hasPrefix("iPad14"):   return "M2"
        case m.hasPrefix("iPad13"):   return "M1 / A14"
        case m.hasPrefix("arm64"):    return "Apple Silicon (Mac)"
        default:                      return m
        }
    }

    static private func aneCountForMachine(_ m: String) -> Int? {
        switch true {
        case m.hasPrefix("iPhone17"): return 16
        case m.hasPrefix("iPhone16"): return 16
        case m.hasPrefix("iPhone15"): return 16
        case m.hasPrefix("iPhone14"): return 16
        default: return nil
        }
    }

    static private func aneTOPSForMachine(_ m: String) -> Double? {
        switch true {
        case m.hasPrefix("iPhone17"): return 35
        case m.hasPrefix("iPhone16"): return 35
        case m.hasPrefix("iPhone15"): return 17
        case m.hasPrefix("iPhone14"): return 15.8
        default: return nil
        }
    }

    static private func hasANEForMachine(_ m: String) -> Bool {
        // A10 and later have ANE; simulator does not
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
}

// Color hex init
extension SwiftUI.Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
