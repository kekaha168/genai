import Metal
import SwiftUI
import Combine

// MARK: - Kernel configuration the UI can swap between

struct KernelConfig: Identifiable, Hashable {
    let id: String
    let displayName: String
    let shaderSource: String
    let kernelName: String
    let verificationRule: any VerificationRule
    let defaultDataSource: KernelDataSource

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: KernelConfig, rhs: KernelConfig) -> Bool { lhs.id == rhs.id }
}

// MARK: - ViewModel

@MainActor
final class KernelViewModel: ObservableObject {

    // ------------------------------------------------------------------
    // Published state consumed by the view
    // ------------------------------------------------------------------

    @Published var selectedConfigID: String = "add"
    @Published var arrayLength: Int = 16
    @Published var useRandomData: Bool = true
    @Published var manualA: String = "1,2,3,4"
    @Published var manualB: String = "10,20,30,40"
    @Published var isRunning: Bool = false
    @Published var result: KernelResult?
    @Published var log: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        var timeString: String {
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
            return f.string(from: timestamp)
        }
    }

    // ------------------------------------------------------------------
    // Available kernel configurations (the "factory catalogue")
    // ------------------------------------------------------------------

    let configs: [KernelConfig] = [
        KernelConfig(
            id: "add",
            displayName: "add_arrays",
            shaderSource: KernelShaders.addArrays,
            kernelName: "add_arrays",
            verificationRule: AdditionVerificationRule(),
            defaultDataSource: RandomDataSource(length: 16)
        ),
        KernelConfig(
            id: "multiply",
            displayName: "multiply_arrays",
            shaderSource: KernelShaders.multiplyArrays,
            kernelName: "multiply_arrays",
            verificationRule: MultiplicationVerificationRule(),
            defaultDataSource: RandomDataSource(length: 16)
        ),
    ]

    var selectedConfig: KernelConfig {
        configs.first { $0.id == selectedConfigID } ?? configs[0]
    }

    // ------------------------------------------------------------------
    // Metal device (shared)
    // ------------------------------------------------------------------

    private let device: MTLDevice

    init() {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.device = dev
        appendLog("MTLDevice: \(dev.name)")
    }

    // ------------------------------------------------------------------
    // Run pipeline
    // ------------------------------------------------------------------

    func run() {
        guard !isRunning else { return }
        isRunning = true
        result = nil

        let config = selectedConfig
        let length = max(1, arrayLength)

        // Build data source from UI settings
        let dataSource: KernelDataSource
        if useRandomData {
            dataSource = RandomDataSource(length: length)
            appendLog("Data source: random (\(length) elements)")
        } else {
            let a = parseFloats(manualA, length: length)
            let b = parseFloats(manualB, length: length)
            dataSource = StaticDataSource(dataA: a, dataB: b)
            appendLog("Data source: manual (\(length) elements)")
        }

        appendLog("Kernel: \(config.kernelName)")
        appendLog("initWithDevice → \(device.name)")

        Task.detached(priority: .userInitiated) { [weak self, device, config, dataSource] in
            guard let self else { return }

            // Build factory
            let kernel = MetalKernel(
                device: device,
                shaderSource: config.shaderSource,
                kernelName: config.kernelName,
                dataSource: dataSource,
                rule: config.verificationRule
            )

            await self.appendLog("prepareData: allocating \(dataSource.length * 3 * 4) bytes")
            kernel.prepareData()

            await self.appendLog("loadData: buffers written to GPU")
            // (loadData == prepareData in the factory; called separately
            //  to mirror the ObjC API signature)

            await self.appendLog("sendComputeCommand → GPU")
            let kernelResult = kernel.sendComputeCommand()

            await self.appendLog("encodeKernelCommand: dispatched \(dataSource.length) threads")

            if kernelResult.passed {
                await self.appendLog("verifyResults: ✓ PASSED")
            } else {
                await self.appendLog("verifyResults: ✗ FAILED — \(kernelResult.verificationMessage ?? "unknown")")
            }

            await self.appendLog("NSLog: Execution finished")

            await MainActor.run {
                self.result = kernelResult
                self.isRunning = false
            }
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private func parseFloats(_ s: String, length: Int) -> [Float] {
        var vals = s.split(separator: ",").compactMap { Float($0.trimmingCharacters(in: .whitespaces)) }
        while vals.count < length { vals.append(Float(vals.count)) }
        return Array(vals.prefix(length))
    }

    private func appendLog(_ message: String) {
        log.append(LogEntry(timestamp: Date(), message: message))
    }

    @MainActor
    private func appendLog(_ message: String) async {
        log.append(LogEntry(timestamp: Date(), message: message))
    }
}
