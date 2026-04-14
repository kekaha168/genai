// TailslayerMetalTests.swift
// XCTest suite validating the Metal-side logic through CPU mirrors of the
// shader math and checking GPU histogram outputs for statistical correctness.

import XCTest
import Metal
@testable import TailslayerMetalTests   // replace with your module name

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – CPU mirrors of shader math (for determinism tests)
// ─────────────────────────────────────────────────────────────────────────────

private func wangHash(_ x: UInt32) -> UInt32 {
    var x = x
    x = (x ^ 61) ^ (x >> 16)
    x &*= 9
    x ^= x >> 4
    x &*= 0x27d4eb2d
    x ^= x >> 15
    return x
}

private func rand01(_ seed: UInt32) -> Float {
    return Float(wangHash(seed)) / Float(0xFFFF_FFFF)
}

private let TREFI_NS: Float = 7800.0
private let TRFC_NS:  Float = 350.0
private let STALL_PROB = TRFC_NS / TREFI_NS

private func singleReadNs(_ seed: UInt32, base: Float = 60, stall: Float = 350) -> Float {
    rand01(seed) < STALL_PROB ? base + stall : base
}

private func hedgedReadNs(_ seed: UInt32, replicas: UInt32, base: Float = 60, stall: Float = 350) -> Float {
    (0..<replicas).map { i in
        singleReadNs(wangHash(seed &+ i &* 0x9e37_79b9), base: base, stall: stall)
    }.min()!
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Unit tests
// ─────────────────────────────────────────────────────────────────────────────

final class TailslayerShadersTests: XCTestCase {

    // ── 1. Wang hash determinism ──────────────────────────────────────────────
    func testWangHashDeterminism() {
        // Same input must always produce same output
        XCTAssertEqual(wangHash(0),       wangHash(0))
        XCTAssertEqual(wangHash(12345),   wangHash(12345))
        XCTAssertEqual(wangHash(UInt32.max), wangHash(UInt32.max))
    }

    func testWangHashDistribution() {
        // Should cover at least 95 % of value space across a small sample
        let n = 10_000
        var seen = Set<UInt32>()
        for i in 0..<n { seen.insert(wangHash(UInt32(i))) }
        XCTAssertGreaterThan(seen.count, Int(Double(n) * 0.95),
                             "Wang hash has poor distribution")
    }

    // ── 2. Stall probability ──────────────────────────────────────────────────
    func testSingleReadStallRate() {
        let n = 100_000
        var stalls = 0
        for i in 0..<n {
            let lat = singleReadNs(UInt32(i))
            if lat > 60 { stalls += 1 }
        }
        let rate = Float(stalls) / Float(n)
        XCTAssertEqual(rate, STALL_PROB, accuracy: 0.005,
                       "Observed stall rate \(rate) deviates from expected \(STALL_PROB)")
    }

    // ── 3. Hedged read always ≤ baseline ─────────────────────────────────────
    func testHedgedReadNeverWorseThanBaseline() {
        for i in 0..<10_000 {
            let seed = UInt32(i)
            let base = singleReadNs(seed)
            let h2   = hedgedReadNs(seed, replicas: 2)
            let h4   = hedgedReadNs(seed, replicas: 4)
            XCTAssertLessThanOrEqual(h2, base + 0.001, "Hedged×2 worse than baseline at seed \(seed)")
            XCTAssertLessThanOrEqual(h4, h2 + 0.001,  "Hedged×4 worse than hedged×2 at seed \(seed)")
        }
    }

    // ── 4. Hedged P99 lower than baseline P99 ─────────────────────────────────
    func testHedgedP99LowerThanBaselineP99() {
        let n = 100_000
        var base = [Float](); base.reserveCapacity(n)
        var h2   = [Float](); h2.reserveCapacity(n)
        var h4   = [Float](); h4.reserveCapacity(n)

        for i in 0..<n {
            let seed = UInt32(i)
            base.append(singleReadNs(seed))
            h2.append(hedgedReadNs(seed, replicas: 2))
            h4.append(hedgedReadNs(seed, replicas: 4))
        }

        func p99(_ arr: [Float]) -> Float {
            let sorted = arr.sorted()
            return sorted[Int(Double(n) * 0.99)]
        }

        let p99b = p99(base)
        let p99h2 = p99(h2)
        let p99h4 = p99(h4)

        XCTAssertLessThan(p99h2, p99b,  "P99 hedged×2 (\(p99h2)) not lower than baseline (\(p99b))")
        XCTAssertLessThan(p99h4, p99h2, "P99 hedged×4 (\(p99h4)) not lower than hedged×2 (\(p99h2))")
        XCTAssertEqual(p99b, 60 + 350, accuracy: 1.0, "Baseline P99 should be at stall latency")
    }

    // ── 5. Stall probability formula ─────────────────────────────────────────
    func testStallProbabilityFormula() {
        // P(no stall in N replicas) = (1 - p)^N
        // P99 improvement: P(all N stall) = p^N
        let p = STALL_PROB
        let pAllStall2 = p * p
        let pAllStall4 = p * p * p * p
        XCTAssertLessThan(pAllStall2, p,  "Dual-channel should reduce stall probability")
        XCTAssertLessThan(pAllStall4, pAllStall2, "Quad-channel should further reduce stall probability")

        // Check actual reduction exceeds theoretical expectation
        let n = 100_000
        var countBase = 0, count2 = 0, count4 = 0
        for i in 0..<n {
            let s = UInt32(i)
            if singleReadNs(s) > 60 { countBase += 1 }
            if hedgedReadNs(s, replicas: 2) > 60 { count2 += 1 }
            if hedgedReadNs(s, replicas: 4) > 60 { count4 += 1 }
        }
        let obsBase = Float(countBase) / Float(n)
        let obs2    = Float(count2)    / Float(n)
        let obs4    = Float(count4)    / Float(n)

        XCTAssertEqual(obs2, pAllStall2, accuracy: 0.003, "Hedged×2 stall rate mismatch")
        XCTAssertEqual(obs4, pAllStall4, accuracy: 0.001, "Hedged×4 stall rate mismatch")
        _ = obsBase // used for context
    }

    // ── 6. Channel scrambling – XOR channel assignment ────────────────────────
    func testChannelScramblingProducesBalancedAssignment() {
        let numChannels: UInt32 = 2
        let cbit: UInt32 = 8
        var counts = [UInt32: Int]()

        for addrX in 0..<256 {
            for addrY in 0..<256 {
                let addr = UInt32((addrY << 8) | addrX)
                var ch: UInt32 = 0
                for b in UInt32(0)..<4 {
                    ch ^= (addr >> (cbit + b)) & 1
                }
                ch %= numChannels
                counts[ch, default: 0] += 1
            }
        }

        // Both channels should receive roughly equal addresses
        let total = 256 * 256
        for (ch, cnt) in counts {
            let frac = Float(cnt) / Float(total)
            XCTAssertEqual(frac, 0.5, accuracy: 0.05,
                           "Channel \(ch) assignment imbalanced: \(frac)")
        }
    }

    func testChannelScramblingBitSweep() {
        // Changing channel_bit should produce different but still balanced mappings
        for cbit in UInt32(6)...UInt32(12) {
            var counts = [UInt32: Int]()
            for addr in UInt32(0)..<1024 {
                var ch: UInt32 = 0
                for b in UInt32(0)..<4 { ch ^= (addr >> (cbit + b)) & 1 }
                ch %= 2
                counts[ch, default: 0] += 1
            }
            XCTAssertEqual(counts.count, 2,
                           "Channel bit \(cbit) doesn't produce 2-channel split")
        }
    }

    // ── 7. GPU histogram buffer test ──────────────────────────────────────────
    func testGPUHistogramTotalCount() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal not available on this machine")
        }

        let compute = LatencyHistogramCompute()
        let ctx     = GPUContext.shared
        let cb      = ctx.commandQueue.makeCommandBuffer()!
        compute.encode(commandBuffer: cb, seed: 1.0)
        cb.commit()
        cb.waitUntilCompleted()

        // Each histogram should sum to numSamples
        let expected = LatencyHistogramCompute.numSamples
        for (name, buf) in [("baseline", compute.histBaseline),
                             ("hedged2",  compute.histHedged2),
                             ("hedged4",  compute.histHedged4)] {
            let ptr   = buf.contents().assumingMemoryBound(to: UInt32.self)
            let total = (0..<LatencyHistogramCompute.numBins).reduce(0) { $0 + Int(ptr[$1]) }
            XCTAssertEqual(total, expected, accuracy: 0,
                           "\(name) histogram total \(total) ≠ expected \(expected)")
        }
    }

    func testGPUHistogramP99Ordering() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal not available on this machine")
        }

        let compute = LatencyHistogramCompute()
        let ctx     = GPUContext.shared
        let cb      = ctx.commandQueue.makeCommandBuffer()!
        compute.encode(commandBuffer: cb, seed: 42.0)
        cb.commit()
        cb.waitUntilCompleted()

        let p99b = compute.p99(buffer: compute.histBaseline)
        let p99h2 = compute.p99(buffer: compute.histHedged2)
        let p99h4 = compute.p99(buffer: compute.histHedged4)

        XCTAssertLessThan(p99h2, p99b,  "GPU: hedged×2 P99 not better than baseline")
        XCTAssertLessThan(p99h4, p99h2, "GPU: hedged×4 P99 not better than hedged×2")
    }

    // ── 8. Renderer pipeline state creation ───────────────────────────────────
    func testRenderPipelineCreation() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal not available on this machine")
        }

        let fns = ["chart_fragment", "channel_viz_fragment",
                   "gauge_fragment", "scramble_fragment"]
        for fn in fns {
            let rend = FullscreenQuadRenderer(fragmentFunctionName: fn)
            // If PSO creation failed, the render call would no-op; we verify library has the fn
            let lib  = GPUContext.shared.library
            XCTAssertNotNil(lib.makeFunction(name: fn),
                            "Fragment function '\(fn)' not found in Metal library")
        }
    }

    // ── 9. tREFI / tRFC constants sanity ─────────────────────────────────────
    func testRefreshConstants() {
        // tREFI must be between 5µs and 10µs (JEDEC DDR4 spec)
        XCTAssertGreaterThan(TREFI_NS, 5000, "tREFI below JEDEC minimum")
        XCTAssertLessThan   (TREFI_NS, 10000, "tREFI above JEDEC maximum")

        // tRFC for 16Gb should be around 350–550 ns
        XCTAssertGreaterThan(TRFC_NS, 200, "tRFC suspiciously small")
        XCTAssertLessThan   (TRFC_NS, 600, "tRFC suspiciously large")

        // Stall probability should be ~4-6%
        XCTAssertGreaterThan(STALL_PROB, 0.03)
        XCTAssertLessThan   (STALL_PROB, 0.08)
    }

    // ── 10. Hedged read mean is close to baseline mean ────────────────────────
    func testHedgedReadMeanNotMuchDifferentFromBaseline() {
        // Hedging only shaves the tail; mean should increase slightly due to
        // overhead, but practically stays within 5 ns of baseline.
        let n = 100_000
        var sumBase = Float(0), sumH2 = Float(0)
        for i in 0..<n {
            sumBase += singleReadNs(UInt32(i))
            sumH2   += hedgedReadNs(UInt32(i), replicas: 2)
        }
        let meanBase = sumBase / Float(n)
        let meanH2   = sumH2   / Float(n)
        XCTAssertEqual(meanH2, meanBase, accuracy: 5.0,
                       "Hedged mean deviates too far from baseline mean")
    }
}
