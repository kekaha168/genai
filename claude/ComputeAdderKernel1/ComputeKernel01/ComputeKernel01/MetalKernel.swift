import Metal
import Foundation

// MARK: - Verification Rule Protocol

/// A rule that checks expected output given inputs.
protocol VerificationRule {
    /// Return nil if the result is correct, or an error message if not.
    func verify(inA: [Float], inB: [Float], result: [Float]) -> String?
}

// MARK: - Built-in Verification Rules

/// Verifies element-wise addition: result[i] == inA[i] + inB[i]
struct AdditionVerificationRule: VerificationRule {
    var tolerance: Float = 1e-4

    func verify(inA: [Float], inB: [Float], result: [Float]) -> String? {
        for i in 0 ..< result.count {
            let expected = inA[i] + inB[i]
            if abs(result[i] - expected) > tolerance {
                return "Mismatch at [\(i)]: got \(result[i]), expected \(expected)"
            }
        }
        return nil
    }
}

/// Verifies element-wise multiplication: result[i] == inA[i] * inB[i]
struct MultiplicationVerificationRule: VerificationRule {
    var tolerance: Float = 1e-4

    func verify(inA: [Float], inB: [Float], result: [Float]) -> String? {
        for i in 0 ..< result.count {
            let expected = inA[i] * inB[i]
            if abs(result[i] - expected) > tolerance {
                return "Mismatch at [\(i)]: got \(result[i]), expected \(expected)"
            }
        }
        return nil
    }
}

/// Custom closure-based rule for arbitrary verification logic.
struct CustomVerificationRule: VerificationRule {
    let check: ([Float], [Float], [Float]) -> String?

    func verify(inA: [Float], inB: [Float], result: [Float]) -> String? {
        check(inA, inB, result)
    }
}

// MARK: - Data Source Protocol

/// Provides the input arrays loaded into GPU buffers.
protocol KernelDataSource {
    var length: Int { get }
    func generateA() -> [Float]
    func generateB() -> [Float]
}

/// Fills both buffers with random floats in [0, 1).
struct RandomDataSource: KernelDataSource {
    let length: Int

    func generateA() -> [Float] { (0 ..< length).map { _ in Float.random(in: 0 ..< 1) } }
    func generateB() -> [Float] { (0 ..< length).map { _ in Float.random(in: 0 ..< 1) } }
}

/// Uses explicit arrays provided by the caller.
struct StaticDataSource: KernelDataSource {
    let dataA: [Float]
    let dataB: [Float]
    var length: Int { dataA.count }

    func generateA() -> [Float] { dataA }
    func generateB() -> [Float] { dataB }
}

// MARK: - Kernel Result

struct KernelResult {
    let inputA: [Float]
    let inputB: [Float]
    let output: [Float]
    let verificationMessage: String?     // nil means pass
    var passed: Bool { verificationMessage == nil }
}

// MARK: - MetalKernel Factory

/// Encapsulates all Metal boilerplate. The caller supplies:
///  - A Metal Shading Language source string (kernel name must match `kernelName`)
///  - A `KernelDataSource` for input generation
///  - A `VerificationRule` for output validation
final class MetalKernel {

    // ------------------------------------------------------------------
    // MARK: Metal objects
    // ------------------------------------------------------------------

    private let device: MTLDevice
    private var pipeline: MTLComputePipelineState!
    private var commandQueue: MTLCommandQueue!

    private var bufferA: MTLBuffer!
    private var bufferB: MTLBuffer!
    private var bufferResult: MTLBuffer!

    // ------------------------------------------------------------------
    // MARK: Configuration supplied by the caller
    // ------------------------------------------------------------------

    private let shaderSource: String
    private let kernelName: String
    private let dataSource: KernelDataSource
    private let rule: VerificationRule

    // Cached CPU-side copies set during prepareData
    private var hostA: [Float] = []
    private var hostB: [Float] = []

    // ------------------------------------------------------------------
    // MARK: initWithDevice
    // ------------------------------------------------------------------

    /// Designated initialiser — mirrors the ObjC `initWithDevice:` pattern.
    ///
    /// - Parameters:
    ///   - device:       The `MTLDevice` to use.
    ///   - shaderSource: Full MSL source containing the kernel function.
    ///   - kernelName:   The name of the `kernel` function inside the source.
    ///   - dataSource:   Provides the input arrays (random or static).
    ///   - rule:         Validates the output buffer after execution.
    init(device: MTLDevice,
         shaderSource: String,
         kernelName: String,
         dataSource: KernelDataSource,
         rule: VerificationRule) {
        self.device = device
        self.shaderSource = shaderSource
        self.kernelName = kernelName
        self.dataSource = dataSource
        self.rule = rule

        // Build pipeline immediately — crash-fast if the shader is bad.
        initPipeline()
    }

    // ------------------------------------------------------------------
    // MARK: initPipeline  (private helpers for initWithDevice)
    // ------------------------------------------------------------------

    private func initPipeline() {
        // Compile the caller-supplied MSL at runtime.
        let options = MTLCompileOptions()
        guard let library = try? device.makeLibrary(source: shaderSource,
                                                     options: options),
              let function = library.makeFunction(name: kernelName)
        else {
            fatalError("MetalKernel: failed to compile kernel '\(kernelName)'")
        }

        guard let ps = try? device.makeComputePipelineState(function: function) else {
            fatalError("MetalKernel: failed to create pipeline for '\(kernelName)'")
        }
        pipeline = ps

        guard let cq = device.makeCommandQueue() else {
            fatalError("MetalKernel: failed to create command queue")
        }
        commandQueue = cq
    }

    // ------------------------------------------------------------------
    // MARK: prepareData
    // ------------------------------------------------------------------

    /// Asks the data source for arrays, writes them into GPU-accessible buffers.
    func prepareData() {
        hostA = dataSource.generateA()
        hostB = dataSource.generateB()
        let byteCount = dataSource.length * MemoryLayout<Float>.stride

        bufferA      = makeBuffer(from: &hostA, byteCount: byteCount, label: "inA")
        bufferB      = makeBuffer(from: &hostB, byteCount: byteCount, label: "inB")
        bufferResult = device.makeBuffer(length: byteCount, options: .storageModeShared)!
        bufferResult.label = "result"
    }

    private func makeBuffer(from data: inout [Float],
                            byteCount: Int,
                            label: String) -> MTLBuffer {
        guard let buf = device.makeBuffer(bytes: data,
                                          length: byteCount,
                                          options: .storageModeShared)
        else { fatalError("MetalKernel: failed to allocate buffer '\(label)'") }
        buf.label = label
        return buf
    }

    // ------------------------------------------------------------------
    // MARK: loadData
    // ------------------------------------------------------------------

    /// Re-fills the GPU buffers with fresh data from the data source
    /// without rebuilding the pipeline.  Call before each run if the
    /// inputs change between runs.
    func loadData() {
        prepareData()
    }

    // ------------------------------------------------------------------
    // MARK: sendComputeCommand
    // ------------------------------------------------------------------

    /// Creates a command buffer, encodes the compute pass, commits, and
    /// blocks until the GPU finishes — then returns a `KernelResult`.
    @discardableResult
    func sendComputeCommand() -> KernelResult {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("MetalKernel: failed to create command buffer")
        }

        encodeKernelCommand(into: commandBuffer)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return verifyResults()
    }

    // ------------------------------------------------------------------
    // MARK: encodeKernelCommand
    // ------------------------------------------------------------------

    /// Encodes the compute pass (pipeline + buffers + thread groups) into
    /// the supplied command buffer.  Kept separate so callers can compose
    /// multiple passes into one buffer if needed.
    func encodeKernelCommand(into commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("MetalKernel: failed to create compute command encoder")
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(bufferA,      offset: 0, index: 0)
        encoder.setBuffer(bufferB,      offset: 0, index: 1)
        encoder.setBuffer(bufferResult, offset: 0, index: 2)

        let gridSize      = MTLSize(width: dataSource.length, height: 1, depth: 1)
        let threadgroupSize = MTLSize(
            width: min(pipeline.maxTotalThreadsPerThreadgroup, dataSource.length),
            height: 1,
            depth: 1
        )
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
    }

    // ------------------------------------------------------------------
    // MARK: verifyResults
    // ------------------------------------------------------------------

    /// Reads the result buffer back to CPU and runs the caller's verification rule.
    @discardableResult
    func verifyResults() -> KernelResult {
        let count = dataSource.length
        let ptr = bufferResult.contents().bindMemory(to: Float.self, capacity: count)
        let output = Array(UnsafeBufferPointer(start: ptr, count: count))

        let message = rule.verify(inA: hostA, inB: hostB, result: output)
        return KernelResult(inputA: hostA,
                            inputB: hostB,
                            output: output,
                            verificationMessage: message)
    }
}
