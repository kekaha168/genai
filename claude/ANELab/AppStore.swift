// Models/AppStore.swift
import Foundation
import CoreML
import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {

    // ── Navigation ───────────────────────────────
    @Published var selectedTab: Tab = .runner

    enum Tab: String, CaseIterable {
        case runner      = "Runner"
        case benchmark   = "Benchmark"
        case inspector   = "Inspector"
        case monitor     = "Monitor"
        case device      = "Device"

        var icon: String {
            switch self {
            case .runner:    return "play.rectangle.fill"
            case .benchmark: return "chart.bar.fill"
            case .inspector: return "magnifyingglass"
            case .monitor:   return "waveform.path.ecg"
            case .device:    return "cpu"
            }
        }
    }

    // ── Imported models ───────────────────────────
    @Published var importedModels: [ImportedModel] = []
    @Published var selectedModel: ImportedModel?

    // ── Compute unit selection ─────────────────────
    @Published var selectedComputeUnit: ComputeUnit = .cpuAndNeuralEngine

    // ── Loaded ML model ───────────────────────────
    @Published var loadedModel: MLModel?
    @Published var loadState: LoadState = .idle

    enum LoadState { case idle, loading, loaded, failed(String) }

    // ── Benchmark ─────────────────────────────────
    @Published var benchmarkRuns: [BenchmarkRun] = []
    @Published var currentRun: BenchmarkRun?
    @Published var benchmarkState: BenchmarkState = .idle
    @Published var benchmarkProgress: Double = 0
    @Published var warmupCount: Int = 3
    @Published var iterationCount: Int = 10
    @Published var liveLatencies: [Double] = []

    enum BenchmarkState { case idle, warmup, running, done }

    // ── Inspector ─────────────────────────────────
    @Published var compatibilityReport: CompatibilityReport?

    // ── Monitor ───────────────────────────────────
    @Published var rollingLatencies: [Double] = []   // last 60 values
    @Published var isMonitoring: Bool = false
    @Published var monitorComputeUnit: ComputeUnit = .cpuAndNeuralEngine

    // ── Device ────────────────────────────────────
    @Published var deviceInfo: DeviceInfo = DeviceInfo.current()
    @Published var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState

    // ── Internal ──────────────────────────────────
    private var monitorTask: Task<Void, Never>?
    private let engine = InferenceEngine()

    // ─────────────────────────────────────────────
    //  MARK: Model Loading
    // ─────────────────────────────────────────────
    func importModel(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let name   = url.deletingPathExtension().lastPathComponent
        let ext    = url.pathExtension.lowercased()
        let format: ImportedModel.ModelFormat = ext == "mlpackage" ? .mlpackage : ext == "mlmodel" ? .mlmodel : .unknown
        let size   = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        // Copy to app sandbox
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)

        let model = ImportedModel(
            id: UUID(), name: name, url: dest, format: format,
            sizeBytes: size, inputNames: [], outputNames: [],
            importedAt: Date()
        )
        importedModels.append(model)
        selectModel(model)
    }

    func selectModel(_ model: ImportedModel) {
        selectedModel = model
        loadedModel   = nil
        loadState     = .loading
        compatibilityReport = buildCompatibilityReport(for: model)
        Task { await loadModel(model) }
    }

    private func loadModel(_ model: ImportedModel) async {
        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = selectedComputeUnit.mlComputeUnits
            let start = Date()
            let ml = try await MLModel.load(contentsOf: model.url, configuration: cfg)
            let ms = Date().timeIntervalSince(start) * 1000
            loadedModel = ml
            loadState   = .loaded
            print("[ANELab] Model loaded in \(String(format: "%.1f", ms)) ms")
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func reloadWithCurrentComputeUnit() {
        guard let m = selectedModel else { return }
        loadedModel = nil
        loadState   = .loading
        Task { await loadModel(m) }
    }

    // ─────────────────────────────────────────────
    //  MARK: Benchmark
    // ─────────────────────────────────────────────
    func runBenchmark() async {
        guard let model = loadedModel, let imp = selectedModel else { return }
        benchmarkState    = .warmup
        benchmarkProgress = 0
        liveLatencies     = []
        thermalState      = ProcessInfo.processInfo.thermalState

        let loadStart = Date()
        let cfg = MLModelConfiguration()
        cfg.computeUnits = selectedComputeUnit.mlComputeUnits
        guard let freshModel = try? await MLModel.load(contentsOf: imp.url, configuration: cfg) else { return }
        let loadMs = Date().timeIntervalSince(loadStart) * 1000

        // Synthetic input (zeros) for benchmarking
        guard let input = engine.makeSyntheticInput(for: freshModel) else {
            benchmarkState = .idle; return
        }

        // Warm-up
        for _ in 0..<warmupCount {
            _ = try? freshModel.prediction(from: input)
        }

        benchmarkState = .running
        var timings: [Double] = []

        for i in 0..<iterationCount {
            let t0 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            _ = try? freshModel.prediction(from: input)
            let t1 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            let ms = Double(t1 - t0) / 1_000_000
            timings.append(ms)
            liveLatencies.append(ms)
            benchmarkProgress = Double(i + 1) / Double(iterationCount)
            try? await Task.sleep(nanoseconds: 1_000_000)   // yield to UI
        }

        let run = BenchmarkRun(
            id: UUID(), modelName: imp.name,
            computeUnit: selectedComputeUnit,
            warmupCount: warmupCount, iterationCount: iterationCount,
            loadTimeMs: loadMs, predictions: timings,
            thermalState: ProcessInfo.processInfo.thermalState,
            timestamp: Date()
        )
        benchmarkRuns.append(run)
        currentRun     = run
        benchmarkState = .done
        benchmarkProgress = 1
    }

    // ─────────────────────────────────────────────
    //  MARK: Live Monitor
    // ─────────────────────────────────────────────
    func startMonitor() {
        guard let imp = selectedModel, !isMonitoring else { return }
        isMonitoring = true
        rollingLatencies = []
        monitorTask = Task {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = monitorComputeUnit.mlComputeUnits
            guard let m = try? await MLModel.load(contentsOf: imp.url, configuration: cfg),
                  let inp = engine.makeSyntheticInput(for: m) else {
                isMonitoring = false; return
            }
            while !Task.isCancelled {
                let t0 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                _ = try? m.prediction(from: inp)
                let t1 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                let ms = Double(t1 - t0) / 1_000_000
                rollingLatencies.append(ms)
                if rollingLatencies.count > 60 { rollingLatencies.removeFirst() }
                thermalState = ProcessInfo.processInfo.thermalState
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func stopMonitor() {
        monitorTask?.cancel()
        monitorTask  = nil
        isMonitoring = false
    }

    // ─────────────────────────────────────────────
    //  MARK: Compatibility Report
    // ─────────────────────────────────────────────
    private func buildCompatibilityReport(for model: ImportedModel) -> CompatibilityReport {
        var flags: [CompatibilityReport.CompatibilityFlag] = []
        var score = 80

        if model.format == .mlmodel {
            flags.append(.init(severity: .warning, message: "NeuralNetwork (.mlmodel) format has limited ANE coverage. Consider converting to ML Program (.mlpackage)."))
            score -= 20
        } else {
            flags.append(.init(severity: .info, message: "ML Program format (.mlpackage) — best ANE compatibility."))
        }

        #if targetEnvironment(simulator)
        flags.append(.init(severity: .error, message: "Simulator detected: ANE is not available. All compute routes to CPU."))
        score = 0
        #else
        flags.append(.init(severity: .info, message: "Physical device detected — ANE dispatch is available."))
        #endif

        flags.append(.init(severity: .info, message: "Compute unit is set at model load time via MLModelConfiguration. Reload required when switching units."))
        flags.append(.init(severity: .warning, message: "Dynamic input shapes may cause ANE fallback to GPU. Use fixed shapes where possible."))
        flags.append(.init(severity: .info, message: "Thermal throttling can reduce ANE clock speed. Check thermal state before benchmarking."))

        return CompatibilityReport(
            modelName: model.name, format: model.format,
            estimatedANEScore: max(0, min(100, score)),
            flags: flags,
            inputShapes: [:], outputShapes: [:]
        )
    }
}
