// TailslayerShaders.metal
// SwiftUI Metal shader tests inspired by Tailslayer's DRAM hedged-read architecture.
// Tests model: refresh stall simulation, hedged-read latency reduction,
// channel replication, and latency distribution visualization.

#include <metal_stdlib>
using namespace metal;

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Shared constants
// ─────────────────────────────────────────────────────────────────────────────

constant float TREFI_NS     = 7800.0;   // typical tREFI: 7.8 µs
constant float TRFC_NS      = 350.0;    // typical tRFC: 350 ns for 16Gb
constant float STALL_PROB   = TRFC_NS / TREFI_NS;  // ~4.5 % chance of a stall

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – 1.  Latency Distribution Heatmap (compute)
//
//  Fills a 1-D histogram buffer with simulated read latencies for:
//   - baseline (single channel)
//   - hedged-2  (two replicas, take fastest)
//   - hedged-4  (four replicas)
//  Each thread simulates one memory access using a deterministic PRNG.
// ─────────────────────────────────────────────────────────────────────────────

struct LatencyParams {
    uint  num_samples;      // total accesses to simulate
    uint  num_bins;         // histogram buckets
    float base_lat_ns;      // baseline CAS latency (ns)
    float stall_lat_ns;     // extra latency when refresh stall hits
    float seed;             // per-frame seed for variation
};

// Cheap but decorrelating hash (Wang hash variant)
inline uint wang_hash(uint x) {
    x = (x ^ 61u) ^ (x >> 16u);
    x *= 9u;
    x ^= x >> 4u;
    x *= 0x27d4eb2du;
    x ^= x >> 15u;
    return x;
}

inline float rand01(uint seed) {
    return float(wang_hash(seed)) / float(0xFFFFFFFFu);
}

// One simulated memory read; returns latency in ns.
inline float single_read_ns(uint seed, float base_lat, float stall_lat) {
    float r = rand01(seed);
    return (r < STALL_PROB) ? base_lat + stall_lat : base_lat;
}

// N-way hedged read: min of N independent reads (uncorrelated refresh schedules)
inline float hedged_read_ns(uint base_seed, uint n_replicas,
                             float base_lat, float stall_lat) {
    float best = 1e9;
    for (uint i = 0; i < n_replicas; i++) {
        float lat = single_read_ns(wang_hash(base_seed + i * 0x9e3779b9u),
                                   base_lat, stall_lat);
        best = min(best, lat);
    }
    return best;
}

kernel void compute_latency_histogram(
    device atomic_uint*         histogram_baseline [[buffer(0)]],
    device atomic_uint*         histogram_hedged2  [[buffer(1)]],
    device atomic_uint*         histogram_hedged4  [[buffer(2)]],
    constant LatencyParams&     params             [[buffer(3)]],
    uint                        gid                [[thread_position_in_grid]])
{
    if (gid >= params.num_samples) return;

    uint seed = wang_hash(gid + uint(params.seed * 1000.0));

    float lat_base  = single_read_ns(seed,                   params.base_lat_ns, params.stall_lat_ns);
    float lat_h2    = hedged_read_ns(seed, 2u,               params.base_lat_ns, params.stall_lat_ns);
    float lat_h4    = hedged_read_ns(seed, 4u,               params.base_lat_ns, params.stall_lat_ns);

    float max_lat = params.base_lat_ns + params.stall_lat_ns + 10.0;

    auto to_bin = [&](float lat) -> uint {
        return clamp(uint(lat / max_lat * float(params.num_bins)), 0u, params.num_bins - 1u);
    };

    atomic_fetch_add_explicit(&histogram_baseline[to_bin(lat_base)], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&histogram_hedged2 [to_bin(lat_h2)],   1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&histogram_hedged4 [to_bin(lat_h4)],   1u, memory_order_relaxed);
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: – 2.  Render: Animated Latency Chart (fragment / vertex)
//
//  Draws the histogram as a smooth density chart in a full-screen quad.
//  Color-codes baseline vs hedged, highlights the tail region.
// ─────────────────────────────────────────────────────────────────────────────

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut chart_vertex(uint vid [[vertex_id]]) {
    const float2 positions[6] = {
        {-1, -1}, {1, -1}, {-1, 1},
        {-1,  1}, {1, -1}, { 1, 1}
    };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

struct ChartUniforms {
    uint  num_bins;
    uint  max_count;
    float time;
    float p99_baseline;   // normalised 0-1 x position of p99 (baseline)
    float p99_hedged;     // normalised x position of p99 (hedged-2)
};

fragment float4 chart_fragment(
    VertexOut                       in       [[stage_in]],
    constant uint*                  base_hist[[buffer(0)]],
    constant uint*                  h2_hist  [[buffer(1)]],
    constant uint*                  h4_hist  [[buffer(2)]],
    constant ChartUniforms&         uni      [[buffer(3)]])
{
    float2 uv = in.uv;
    float x = uv.x;
    float y = uv.y;                      // 0 = bottom, 1 = top

    uint bin = uint(x * float(uni.num_bins));
    bin = clamp(bin, 0u, uni.num_bins - 1u);

    float norm = float(uni.max_count);

    float h_base = float(base_hist[bin]) / norm;
    float h_h2   = float(h2_hist[bin])   / norm;
    float h_h4   = float(h4_hist[bin])   / norm;

    // Smooth the bars slightly
    float smooth = 0.003;

    // Palette
    float3 col_base  = float3(0.95, 0.35, 0.25);   // coral – baseline
    float3 col_h2    = float3(0.25, 0.75, 0.55);   // teal  – hedged-2
    float3 col_h4    = float3(0.30, 0.55, 0.95);   // blue  – hedged-4
    float3 col_tail  = float3(1.0,  0.85, 0.20);   // gold  – tail highlight
    float3 bg        = float3(0.07, 0.08, 0.11);

    float3 color = bg;

    // Layered bars (back to front)
    color = mix(color, col_base, smoothstep(h_base - smooth, h_base + smooth, y) < 0.5 ? smoothstep(0.0, smooth, h_base - y) : 0.0);

    // Simpler approach: additive blending per layer
    float bar_base = step(y, h_base);
    float bar_h2   = step(y, h_h2);
    float bar_h4   = step(y, h_h4);

    color = bg;
    color = mix(color, col_base * 0.6, bar_base * 0.7);
    color = mix(color, col_h2   * 0.8, bar_h2   * 0.8);
    color = mix(color, col_h4,          bar_h4   * 0.9);

    // Tail region overlay (x > p99_hedged)
    float tail_fade = smoothstep(uni.p99_hedged - 0.02, uni.p99_hedged + 0.02, x);
    float3 tail_tint = mix(float3(0.0), col_tail * 0.18, tail_fade);
    color += tail_tint;

    // P99 vertical lines
    float lw = 0.0015;
    if (abs(x - uni.p99_baseline) < lw) color = mix(color, col_base, 0.9);
    if (abs(x - uni.p99_hedged)   < lw) color = mix(color, col_h2,   0.9);

    // Grid lines
    float grid = float(fmod(x * 10.0, 1.0) < 0.01 || fmod(y * 10.0, 1.0) < 0.01) * 0.04;
    color += grid;

    // Subtle scanline
    float scan = sin(y * 800.0 + uni.time * 2.0) * 0.01;
    color += scan;

    return float4(saturate(color), 1.0);
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: – 3.  Channel Replication Visualizer (fragment)
//
//  Renders an animated diagram of N DRAM channels with refresh waves.
//  Each channel pulses independently; a hedged-read "races" across them.
// ─────────────────────────────────────────────────────────────────────────────

struct ChannelUniforms {
    float time;
    uint  num_channels;
    float channel_offsets[8];   // per-channel refresh phase offset (0-1)
};

// Signed distance to a rounded rectangle
float sdRoundRect(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

fragment float4 channel_viz_fragment(
    VertexOut             in  [[stage_in]],
    constant ChannelUniforms& uni [[buffer(0)]])
{
    float2 uv  = in.uv;
    float  t   = uni.time;
    uint   N   = min(uni.num_channels, 8u);
    float3 bg  = float3(0.05, 0.06, 0.10);
    float3 col = bg;

    float lane_h = 1.0 / float(N);

    for (uint ch = 0; ch < N; ch++) {
        float fy = (float(ch) + 0.5) * lane_h;
        float dy = abs(uv.y - fy);
        float half_h = lane_h * 0.35;

        if (dy > half_h) continue;

        // Refresh wave: a pulse that sweeps left-to-right periodically
        float phase  = uni.channel_offsets[ch];
        float cycle  = fmod(t * 0.12 + phase, 1.0);   // 0-1 within refresh cycle
        float wave_x = cycle;                           // leading edge x position

        // Background of channel bar
        float bar = sdRoundRect(float2(uv.x - 0.5, uv.y - fy), float2(0.48, half_h * 0.85), 0.01);
        float bar_mask = smoothstep(0.002, -0.002, bar);

        // Channel hue based on index
        float hue = float(ch) / float(N);
        float3 chan_col = float3(
            0.5 + 0.5 * cos(hue * 6.28 + 0.0),
            0.5 + 0.5 * cos(hue * 6.28 + 2.1),
            0.5 + 0.5 * cos(hue * 6.28 + 4.2)
        ) * 0.4;

        col = mix(col, chan_col, bar_mask * 0.6);

        // Refresh stall pulse (narrow bright band sweeping)
        float stall_w  = TRFC_NS / TREFI_NS;             // width in normalised units
        float in_stall = step(wave_x - stall_w, uv.x) * step(uv.x, wave_x);
        float3 stall_col = float3(1.0, 0.4, 0.1);
        col = mix(col, stall_col, bar_mask * in_stall * 0.85);

        // Trailing "ready" glow
        float ready_fade = smoothstep(0.0, 0.3, wave_x - uv.x) * step(uv.x, wave_x);
        col = mix(col, chan_col * 1.8, bar_mask * ready_fade * 0.3);
    }

    // Hedged read cursor: animated vertical line racing toward first ready channel
    float cursor_x = fmod(t * 0.08, 1.0);
    float cursor_w = 0.003;
    float cursor   = smoothstep(cursor_w, 0.0, abs(uv.x - cursor_x));
    col = mix(col, float3(1.0, 0.95, 0.5), cursor * 0.9);

    // Vignette
    float2 vig = uv - 0.5;
    float  v   = 1.0 - dot(vig, vig) * 2.0;
    col *= saturate(v);

    return float4(saturate(col), 1.0);
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: – 4.  Tail-Latency Reduction Meter (fragment)
//
//  Renders a stylised "speedometer" gauge comparing baseline P99 vs hedged P99.
//  Driven by two scalar uniforms: p99_base, p99_hedged (normalised 0-1 of max).
// ─────────────────────────────────────────────────────────────────────────────

struct GaugeUniforms {
    float p99_base;     // 0-1
    float p99_hedged;   // 0-1
    float time;
    float reduction;    // 1 - p99_hedged/p99_base
};

fragment float4 gauge_fragment(
    VertexOut            in  [[stage_in]],
    constant GaugeUniforms& uni [[buffer(0)]])
{
    float2 uv = in.uv * 2.0 - 1.0;   // -1..1

    float3 bg  = float3(0.06, 0.07, 0.10);
    float3 col = bg;

    // Circular arc parameters
    float r     = length(uv);
    float angle = atan2(uv.y, uv.x);   // -π .. π
    // Remap to 0-1 over 240° arc (bottom-left to bottom-right, opening upward)
    float arc_min = -M_PI_F * 0.85;
    float arc_max =  M_PI_F * 0.15;
    float arc_t   = (angle - arc_min) / (arc_max - arc_min);   // 0=left, 1=right
    arc_t = clamp(arc_t, 0.0, 1.0);

    float ring_outer = 0.85;
    float ring_inner = 0.60;
    float in_ring    = step(ring_inner, r) * (1.0 - step(ring_outer, r));

    // Track background
    col = mix(col, float3(0.15, 0.16, 0.20), in_ring);

    // Baseline fill (coral)
    float base_fill  = step(arc_t, uni.p99_base);
    float3 base_col  = float3(0.90, 0.30, 0.20);
    col = mix(col, base_col * 0.7, in_ring * base_fill);

    // Hedged fill (teal), overlaid
    float hedge_fill = step(arc_t, uni.p99_hedged);
    float3 hedge_col = float3(0.20, 0.80, 0.55);
    col = mix(col, hedge_col, in_ring * hedge_fill);

    // Animated needle for hedged value
    float needle_angle = mix(arc_min, arc_max, uni.p99_hedged);
    float2 needle_dir  = float2(cos(needle_angle), sin(needle_angle));
    float  needle_dist = abs(dot(float2(-needle_dir.y, needle_dir.x), uv));
    float  needle_mask = smoothstep(0.012, 0.0, needle_dist) *
                         step(r, ring_outer + 0.05) *
                         step(ring_inner - 0.15, r);
    col = mix(col, float3(1.0, 0.95, 0.4), needle_mask);

    // Center hub
    float hub = 1.0 - smoothstep(0.07, 0.10, r);
    col = mix(col, float3(0.8, 0.8, 0.85), hub);

    // Outer ring glow
    float glow = exp(-20.0 * pow(r - ring_outer, 2.0)) * 0.4;
    col += hedge_col * glow * hedge_fill;

    // Tick marks
    for (int i = 0; i <= 10; i++) {
        float t_tick = float(i) / 10.0;
        float a_tick = mix(arc_min, arc_max, t_tick);
        float2 tick_dir = float2(cos(a_tick), sin(a_tick));
        float  tick_d   = abs(dot(float2(-tick_dir.y, tick_dir.x), uv));
        float  tick_r   = dot(tick_dir, uv);
        float  major = (i % 5 == 0) ? 1.0 : 0.0;
        float  tick_len = major > 0.5 ? 0.10 : 0.06;
        float  in_tick  = step(ring_outer - tick_len, tick_r) * step(tick_r, ring_outer + 0.01)
                        * smoothstep(0.008, 0.0, tick_d);
        col = mix(col, float3(0.7, 0.75, 0.85), in_tick * 0.8);
    }

    return float4(saturate(col), 1.0);
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: – 5.  Memory Channel Scrambling Visualizer (fragment)
//
//  Visualizes how Tailslayer's undocumented channel scrambling offsets
//  map logical addresses to physical DRAM channels.
//  Renders a 2-D grid of memory addresses; colors encode the channel assignment.
// ─────────────────────────────────────────────────────────────────────────────

struct ScramblingUniforms {
    float  time;
    uint   channel_bit;     // bit position used for channel selection (default 8)
    uint   num_channels;
    float  zoom;            // address space zoom
};

fragment float4 scramble_fragment(
    VertexOut                   in  [[stage_in]],
    constant ScramblingUniforms& uni [[buffer(0)]])
{
    float2 uv = in.uv;
    float3 bg = float3(0.05, 0.06, 0.09);

    // Map UV to a logical address space (visualised as 64-bit address grid)
    float zoom   = max(uni.zoom, 1.0);
    uint  addr_x = uint(uv.x * 256.0 * zoom);
    uint  addr_y = uint(uv.y * 256.0 * zoom);
    uint  addr   = (addr_y << 8u) | addr_x;   // simple 2-D to 1-D mapping

    // Channel selection: XOR-based scrambling (mimics actual hardware behaviour)
    uint cbit = clamp(uni.channel_bit, 6u, 12u);
    uint ch   = 0u;
    // Tailslayer uses channel bit XOR fold across row/column bits
    for (uint b = 0u; b < 4u; b++) {
        ch ^= (addr >> (cbit + b)) & 1u;
    }
    ch = ch % max(uni.num_channels, 1u);

    float hue = float(ch) / float(max(uni.num_channels, 1u));
    float3 chan_col = float3(
        0.5 + 0.5 * cos(hue * 6.28 + 0.0),
        0.5 + 0.5 * cos(hue * 6.28 + 2.1),
        0.5 + 0.5 * cos(hue * 6.28 + 4.2)
    );

    // Brightness encodes access recency (animated refresh wave)
    float refresh_phase = fmod(float(addr) / 65536.0 + uni.time * 0.05, 1.0);
    float stall_bright  = step(1.0 - STALL_PROB, refresh_phase);   // is this address in stall?
    float brightness    = stall_bright > 0.5 ? 0.2 : 0.7;

    float3 col = chan_col * brightness;

    // Grid overlay
    float gx = fmod(uv.x * 256.0, 1.0);
    float gy = fmod(uv.y * 256.0, 1.0);
    float grid = (step(0.95, gx) + step(0.95, gy)) * 0.3;
    col -= grid;

    return float4(saturate(col), 1.0);
}
