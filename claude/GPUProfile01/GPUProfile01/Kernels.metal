// Kernels.metal
// GPU Workload Lab — Naive vs Optimized Metal Kernels
// Demonstrates Apple Silicon UMA and Memory Hierarchy

#include <metal_stdlib>
using namespace metal;

// ─────────────────────────────────────────────────
// NAIVE KERNEL
// Matrix multiplication with no memory optimisations.
// Each thread independently reads from global (main RAM)
// for every multiply-accumulate — no threadgroup caching,
// no coalescing awareness.  On UMA this is still "fast"
// but hammers L2 / main-memory bandwidth needlessly.
// ─────────────────────────────────────────────────
kernel void matmul_naive(
    device const float* A        [[ buffer(0) ]],
    device const float* B        [[ buffer(1) ]],
    device       float* C        [[ buffer(2) ]],
    constant     uint&  N        [[ buffer(3) ]],   // matrix dimension (N×N)
    uint2 gid [[ thread_position_in_grid ]])
{
    if (gid.x >= N || gid.y >= N) return;

    float sum = 0.0f;
    for (uint k = 0; k < N; ++k) {
        sum += A[gid.y * N + k] * B[k * N + gid.x];
    }
    C[gid.y * N + gid.x] = sum;
}


// ─────────────────────────────────────────────────
// OPTIMISED KERNEL  (Tiled / Threadgroup-shared memory)
// Splits the matrices into TILE_SIZE × TILE_SIZE tiles
// and stages each tile into threadgroup (L1-equivalent)
// memory before accumulating.  This dramatically reduces
// redundant global-memory traffic and exploits the
// Registers → Threadgroup Memory → L2 → Main RAM
// hierarchy that still exists inside Apple Silicon.
// ─────────────────────────────────────────────────
constant uint TILE_SIZE = 16;

kernel void matmul_optimized(
    device const float* A        [[ buffer(0) ]],
    device const float* B        [[ buffer(1) ]],
    device       float* C        [[ buffer(2) ]],
    constant     uint&  N        [[ buffer(3) ]],
    uint2 gid  [[ thread_position_in_grid    ]],
    uint2 lid  [[ thread_position_in_threadgroup ]])
{
    // Shared (threadgroup) tiles — live in fast on-chip SRAM
    threadgroup float tileA[TILE_SIZE][TILE_SIZE];
    threadgroup float tileB[TILE_SIZE][TILE_SIZE];

    uint row = gid.y;
    uint col = gid.x;

    float sum = 0.0f;
    uint numTiles = (N + TILE_SIZE - 1) / TILE_SIZE;

    for (uint t = 0; t < numTiles; ++t) {
        // Cooperatively load one tile of A and B into threadgroup memory
        uint aCol = t * TILE_SIZE + lid.x;
        uint bRow = t * TILE_SIZE + lid.y;

        tileA[lid.y][lid.x] = (row  < N && aCol < N) ? A[row  * N + aCol] : 0.0f;
        tileB[lid.y][lid.x] = (bRow < N && col  < N) ? B[bRow * N + col ] : 0.0f;

        // Barrier: all threads must finish loading before any thread computes
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Accumulate from fast threadgroup memory (not global)
        for (uint k = 0; k < TILE_SIZE; ++k) {
            sum += tileA[lid.y][k] * tileB[k][lid.x];
        }

        // Barrier: prevent overwriting tiles before all threads finished reading
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (row < N && col < N) {
        C[row * N + col] = sum;
    }
}
