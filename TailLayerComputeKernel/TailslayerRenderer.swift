// TailslayerRenderer.swift
// Coordinates Metal compute + render pipelines for all Tailslayer shader tests.

import Metal
import MetalKit
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Shared GPU device
// ─────────────────────────────────────────────────────────────────────────────

final class GPUContext {
    static let shared = GPUContext()
    let device:       MTLDevice
    let commandQueue: MTLCommandQueue
    let library:      MTLLibrary

    private init() {
        guard
            let dev = MTLCreateSystemDefaultDevice(),
            let queue = dev.makeCommandQueue(),
            let lib = dev.makeDefaultLibrary()
        else { fatalError("Metal not available") }
        device       = dev
        commandQueue = queue
        library      = lib
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Latency histogram compute pass
// ─────────────────────────────────────────────────────────────────────────────

struct LatencyParams {
    var numSamples:  UInt32
    var numBins:     UInt32
    var baseLatNs:   Float
    var stallLatNs:  Float
    var seed:        Float
}

struct ChartUniforms {
    var numBins:      UInt32
    var maxCount:     UInt32
    var time:         Float
    var p99Baseline:  Float
    var p99Hedged:    Float
}

final class LatencyHistogramCompute {
    static let numBins    = 256
    static let numSamples = 1_000_000

    private let pso:     MTLComputePipelineState
    private let ctx = GPUContext.shared

    let histBaseline: MTLBuffer
    let histHedged2:  MTLBuffer
    let histHedged4:  MTLBuffer

    init() {
        let fn = ctx.library.makeFunction(name: "compute_latency_histogram")!
        pso = try! ctx.device.makeComputePipelineState(function: fn)

        let size = MemoryLayout<UInt32>.size * LatencyHistogramCompute.numBins
        histBaseline = ctx.device.makeBuffer(length: size, options: .storageModeShared)!
        histHedged2  = ctx.device.makeBuffer(length: size, options: .storageModeShared)!
        histHedged4  = ctx.device.makeBuffer(length: size, options: .storageModeShared)!
    }

    func encode(commandBuffer: MTLCommandBuffer, seed: Float) {
        // Clear
        let size = LatencyHistogramCompute.numBins * MemoryLayout<UInt32>.size
        histBaseline.contents().initializeMemory(as: UInt32.self,
                                                  repeating: 0,
                                                  count: LatencyHistogramCompute.numBins)
        histHedged2.contents().initializeMemory(as: UInt32.self,
                                                 repeating: 0,
                                                 count: LatencyHistogramCompute.numBins)
        histHedged4.contents().initializeMemory(as: UInt32.self,
                                                 repeating: 0,
                                                 count: LatencyHistogramCompute.numBins)

        var params = LatencyParams(
            numSamples:  UInt32(LatencyHistogramCompute.numSamples),
            numBins:     UInt32(LatencyHistogramCompute.numBins),
            baseLatNs:   60.0,
            stallLatNs:  350.0,
            seed:        seed
        )

        let enc = commandBuffer.makeComputeCommandEncoder()!
        enc.setComputePipelineState(pso)
        enc.setBuffer(histBaseline, offset: 0, index: 0)
        enc.setBuffer(histHedged2,  offset: 0, index: 1)
        enc.setBuffer(histHedged4,  offset: 0, index: 2)
        enc.setBytes(&params, length: MemoryLayout<LatencyParams>.size, index: 3)

        let tpg = MTLSize(width: pso.threadExecutionWidth, height: 1, depth: 1)
        let tg  = MTLSize(width: (LatencyHistogramCompute.numSamples + tpg.width - 1) / tpg.width,
                          height: 1, depth: 1)
        enc.dispatchThreadgroups(tg, threadsPerThreadgroup: tpg)
        enc.endEncoding()
        _ = size // silence warning
    }

    /// Returns P99 normalised x position (0-1) for a given histogram buffer.
    func p99(buffer: MTLBuffer) -> Float {
        let ptr  = buffer.contents().assumingMemoryBound(to: UInt32.self)
        let bins = LatencyHistogramCompute.numBins
        var total: UInt64 = 0
        for i in 0..<bins { total += UInt64(ptr[i]) }
        let threshold = UInt64(Double(total) * 0.99)
        var acc: UInt64 = 0
        for i in 0..<bins {
            acc += UInt64(ptr[i])
            if acc >= threshold { return Float(i) / Float(bins) }
        }
        return 1.0
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Full-screen quad render helper
// ─────────────────────────────────────────────────────────────────────────────

final class FullscreenQuadRenderer {
    private let vertexFn:   MTLFunction
    private var pso:        MTLRenderPipelineState?
    let ctx = GPUContext.shared

    init(vertexFunctionName: String = "chart_vertex",
         fragmentFunctionName: String) {
        vertexFn = ctx.library.makeFunction(name: vertexFunctionName)!
        let fragFn = ctx.library.makeFunction(name: fragmentFunctionName)!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vertexFn
        desc.fragmentFunction = fragFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pso = try? ctx.device.makeRenderPipelineState(descriptor: desc)
    }

    func encode(renderEncoder: MTLRenderCommandEncoder,
                buffers: [(MTLBuffer, Int)],
                bytesBuffers: [(UnsafeRawPointer, Int, Int)] = []) {
        guard let pso else { return }
        renderEncoder.setRenderPipelineState(pso)
        for (buf, idx) in buffers {
            renderEncoder.setFragmentBuffer(buf, offset: 0, index: idx)
        }
        for (ptr, len, idx) in bytesBuffers {
            renderEncoder.setFragmentBytes(ptr, length: len, index: idx)
        }
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – MTKView coordinator (generic, reusable)
// ─────────────────────────────────────────────────────────────────────────────

typealias DrawBlock = (_ commandBuffer: MTLCommandBuffer,
                       _ drawable: CAMetalDrawable,
                       _ time: Double) -> Void

final class MetalViewCoordinator: NSObject, MTKViewDelegate {
    var drawBlock: DrawBlock?
    private var startTime = Date()
    private(set) var elapsedTime: Double = 0

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let block    = drawBlock,
            let drawable = view.currentDrawable,
            let cb       = GPUContext.shared.commandQueue.makeCommandBuffer()
        else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
        block(cb, drawable, elapsedTime)
        cb.present(drawable)
        cb.commit()
    }
}
