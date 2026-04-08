// MetalBenchmark.swift
// Manages Metal device, pipeline states, buffers, and benchmark execution.

import Metal
import Foundation
internal import Combine

// ─── Result model ────────────────────────────────
struct BenchmarkResult {
    let kernelName:   String
    let matrixSize:   Int          // N (N×N matrix)
    let elapsedMs:    Double
    let gflops:       Double       // (2·N³) FLOPs / elapsed
    let isCorrect:    Bool         // spot-checked vs CPU reference
}

// ─── Errors ──────────────────────────────────────
enum MetalError: LocalizedError {
    case noDevice
    case libraryFailed(String)
    case pipelineFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDevice:              return "No Metal-capable GPU found."
        case .libraryFailed(let m):  return "Shader library error: \(m)"
        case .pipelineFailed(let m): return "Pipeline error: \(m)"
        }
    }
}

// ─── Engine ──────────────────────────────────────
@MainActor
final class MetalBenchmark: ObservableObject {

    // Published state consumed by the SwiftUI view
    @Published var results:    [BenchmarkResult] = []
    @Published var isRunning:  Bool              = false
    @Published var errorMsg:   String?           = nil
    @Published var progress:   Double            = 0      // 0…1
    @Published var statusText: String            = "Ready"

    // Metal objects
    private let device:       MTLDevice
    private let commandQueue: MTLCommandQueue
    private var naivePSO:     MTLComputePipelineState?
    private var optimPSO:     MTLComputePipelineState?

    // ── Init ─────────────────────────────────────
    init() throws {
        guard let dev = MTLCreateSystemDefaultDevice() else { throw MetalError.noDevice }
        guard let cq  = dev.makeCommandQueue()         else { throw MetalError.noDevice }
        device       = dev
        commandQueue = cq
        try buildPipelines()
    }

    // ── Pipeline compilation ──────────────────────
    private func buildPipelines() throws {
        let lib: MTLLibrary
        do {
            lib = try device.makeDefaultLibrary(bundle: .main)
        } catch {
            throw MetalError.libraryFailed(error.localizedDescription)
        }

        func makePSO(_ name: String) throws -> MTLComputePipelineState {
            guard let fn = lib.makeFunction(name: name) else {
                throw MetalError.libraryFailed("Function '\(name)' not found.")
            }
            do {
                return try device.makeComputePipelineState(function: fn)
            } catch {
                throw MetalError.pipelineFailed("\(name): \(error.localizedDescription)")
            }
        }

        naivePSO = try makePSO("matmul_naive")
        optimPSO = try makePSO("matmul_optimized")
    }

    // ── Public entry point ────────────────────────
    func runBenchmarks(matrixSize N: Int, iterations: Int) async {
        isRunning  = true
        results    = []
        errorMsg   = nil
        progress   = 0

        do {
            let total = iterations * 2
            var done  = 0

            var naiveResults: [BenchmarkResult] = []
            var optimResults: [BenchmarkResult] = []

            // Warm-up (not recorded)
            statusText = "Warming up GPU…"
            _ = try await runKernel(pso: naivePSO!, name: "Naive",     N: N)
            _ = try await runKernel(pso: optimPSO!, name: "Optimized", N: N)

            for i in 1...iterations {
                statusText = "Naive kernel — iteration \(i)/\(iterations)"
                let r = try await runKernel(pso: naivePSO!, name: "Naive", N: N)
                naiveResults.append(r)
                done += 1; progress = Double(done) / Double(total)

                statusText = "Optimized kernel — iteration \(i)/\(iterations)"
                let o = try await runKernel(pso: optimPSO!, name: "Optimized", N: N)
                optimResults.append(o)
                done += 1; progress = Double(done) / Double(total)
            }

            // Average across iterations
            results = [average(naiveResults), average(optimResults)]
            statusText = "Done ✓"

        } catch {
            errorMsg   = error.localizedDescription
            statusText = "Error"
        }

        isRunning = false
        progress  = 1
    }

    // ── Single kernel run ─────────────────────────
    private func runKernel(
        pso:  MTLComputePipelineState,
        name: String,
        N:    Int
    ) async throws -> BenchmarkResult {

        let floatCount = N * N
        let byteCount  = floatCount * MemoryLayout<Float>.stride

        // Generate random input matrices on CPU
        var hostA = [Float](repeating: 0, count: floatCount)
        var hostB = [Float](repeating: 0, count: floatCount)
        for i in 0..<floatCount {
            hostA[i] = Float.random(in: -1...1)
            hostB[i] = Float.random(in: -1...1)
        }

        // Allocate shared (UMA) buffers — zero-copy on Apple Silicon
        guard
            let bufA = device.makeBuffer(bytes: hostA, length: byteCount, options: .storageModeShared),
            let bufB = device.makeBuffer(bytes: hostB, length: byteCount, options: .storageModeShared),
            let bufC = device.makeBuffer(length: byteCount,              options: .storageModeShared)
        else { throw MetalError.noDevice }

        var dim = UInt32(N)

        // Encode & commit
        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let enc    = cmdBuf.makeComputeCommandEncoder()
        else { throw MetalError.noDevice }

        enc.setComputePipelineState(pso)
        enc.setBuffer(bufA, offset: 0, index: 0)
        enc.setBuffer(bufB, offset: 0, index: 1)
        enc.setBuffer(bufC, offset: 0, index: 2)
        enc.setBytes(&dim, length: MemoryLayout<UInt32>.size, index: 3)

        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups    = MTLSize(
            width:  (N + 15) / 16,
            height: (N + 15) / 16,
            depth:  1
        )
        enc.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        enc.endEncoding()

        let start = Date()
        cmdBuf.commit()
        await cmdBuf.completed()
        let elapsedMs = Date().timeIntervalSince(start) * 1_000

        // Verify a random cell against CPU reference
        let correct = verify(bufA: bufA, bufB: bufB, bufC: bufC, N: N)

        // GFLOPs = (2·N³) / (elapsed_s * 1e9)
        let flops  = 2.0 * Double(N) * Double(N) * Double(N)
        let gflops = flops / (elapsedMs / 1_000) / 1e9

        return BenchmarkResult(
            kernelName: name,
            matrixSize: N,
            elapsedMs:  elapsedMs,
            gflops:     gflops,
            isCorrect:  correct
        )
    }

    // ── Spot-check correctness ────────────────────
    private func verify(
        bufA: MTLBuffer,
        bufB: MTLBuffer,
        bufC: MTLBuffer,
        N:    Int
    ) -> Bool {
        let pA = bufA.contents().assumingMemoryBound(to: Float.self)
        let pB = bufB.contents().assumingMemoryBound(to: Float.self)
        let pC = bufC.contents().assumingMemoryBound(to: Float.self)

        // Check 4 random cells
        for _ in 0..<4 {
            let row = Int.random(in: 0..<N)
            let col = Int.random(in: 0..<N)
            var ref: Float = 0
            for k in 0..<N { ref += pA[row * N + k] * pB[k * N + col] }
            let gpu = pC[row * N + col]
            if abs(ref - gpu) > 0.5 { return false }   // generous epsilon for FP32
        }
        return true
    }

    // ── Average helper ────────────────────────────
    private func average(_ rs: [BenchmarkResult]) -> BenchmarkResult {
        guard !rs.isEmpty else { return rs[0] }
        let ms = rs.map(\.elapsedMs).reduce(0, +) / Double(rs.count)
        let gf = rs.map(\.gflops).reduce(0, +)    / Double(rs.count)
        return BenchmarkResult(
            kernelName: rs[0].kernelName,
            matrixSize: rs[0].matrixSize,
            elapsedMs:  ms,
            gflops:     gf,
            isCorrect:  rs.allSatisfy(\.isCorrect)
        )
    }
}
