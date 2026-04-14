# TailslayerMetalTests

SwiftUI + Metal shader test suite inspired by
[Tailslayer](https://github.com/LaurieWired/tailslayer) — a C++ library that
reduces DRAM refresh tail latency through hedged reads across multiple
independent DRAM channels.

---

## What is being tested / visualised?

Tailslayer's core insight is that **DRAM refresh stalls** (tRFC ≈ 350 ns every
tREFI ≈ 7.8 µs) cause unpredictable tail latency. By replicating data across
channels with **uncorrelated refresh schedules** and issuing hedged reads, it
takes the first result that comes back — eliminating most stall events.

This project translates that into four live Metal shaders + an XCTest suite:

| # | Shader / View | What it shows |
|---|---------------|---------------|
| 1 | `LatencyChartView` | GPU-computed histogram of 1 M read latencies: baseline vs hedged×2 vs hedged×4. P99 vertical lines. |
| 2 | `ChannelVizView` | Animated DRAM channels with independent refresh sweep waves (orange = stall). Hedged-read cursor races across channels. |
| 3 | `GaugeView` | Speedometer arc: coral = baseline P99, teal needle = hedged P99. Live reduction %. |
| 4 | `ScramblingHeatmapView` | 2-D logical address space coloured by DRAM channel assignment via Tailslayer's XOR scrambling. Adjustable channel-bit selector. |

---

## File structure

```
TailslayerMetalTests/
├── TailslayerMetalTestsApp.swift       # @main entry, TabView navigator
├── Metal/
│   └── TailslayerRenderer.swift        # GPUContext, compute pass, FSQ renderer, coordinator
├── Shaders/
│   └── TailslayerShaders.metal         # All 5 Metal functions
│       ├── compute_latency_histogram   # Compute: fills 3 histogram buffers
│       ├── chart_vertex / chart_fragment  # Test 1: latency histogram chart
│       ├── channel_viz_fragment        # Test 2: animated channel refresh
│       ├── gauge_fragment              # Test 3: P99 speedometer
│       └── scramble_fragment           # Test 4: channel scrambling heatmap
├── Views/
│   └── MetalTestViews.swift            # SwiftUI MTKView wrapper + 4 test views + VMs
└── Tests/
    └── TailslayerMetalTests.swift      # XCTest suite (10 test cases)
```

---

## How to set up in Xcode

1. Create a new **iOS App** project (SwiftUI, Swift).
2. Replace / add files from this package into the project.
3. In the target's **Build Phases → Compile Sources**, add both `.swift` files.
4. Add `TailslayerShaders.metal` — Xcode will compile it into the default Metal library automatically.
5. Add the test file to the **Unit Test** target.
6. Set deployment target to **iOS 16+** (uses `.toolbarBackground`).

No external dependencies are required.

---

## XCTest suite (10 tests)

| Test | What it validates |
|------|-------------------|
| `testWangHashDeterminism` | PRNG produces identical output for identical seeds |
| `testWangHashDistribution` | Hash covers ≥ 95 % of output space |
| `testSingleReadStallRate` | Observed stall rate matches STALL_PROB = tRFC/tREFI ≈ 4.5 % |
| `testHedgedReadNeverWorseThanBaseline` | `hedged ≤ baseline` for every seed |
| `testHedgedP99LowerThanBaselineP99` | CPU-mirror P99: h4 < h2 < baseline |
| `testStallProbabilityFormula` | P(all N stall) = pⁿ matches observed GPU rate |
| `testChannelScramblingProducesBalancedAssignment` | XOR scrambling gives 50/50 split |
| `testChannelScramblingBitSweep` | All channel-bit values 6-12 still produce valid splits |
| `testGPUHistogramTotalCount` | GPU histogram bins sum to exactly numSamples |
| `testGPUHistogramP99Ordering` | GPU-computed P99: hedged4 < hedged2 < baseline |

---

## Key shader parameters

| Constant | Value | Source |
|----------|-------|--------|
| `TREFI_NS` | 7 800 ns | JEDEC DDR4 spec, 1× refresh rate |
| `TRFC_NS` | 350 ns | 16 Gb DRAM tRFC |
| `STALL_PROB` | ≈ 4.49 % | tRFC / tREFI |
| Channel scramble bit | 8 (adjustable 6-12) | Tailslayer discovery/benchmark |

---

## License

Apache 2.0 — matching Tailslayer's upstream license.
