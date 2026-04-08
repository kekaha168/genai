import Foundation

/// MSL shader sources as Swift string literals.
/// These are fed directly to `MetalKernel(shaderSource:kernelName:…)`
/// so the factory can compile any kernel at runtime — no precompiled
/// .metallib required.
enum KernelShaders {

    // ------------------------------------------------------------------
    // Add
    // ------------------------------------------------------------------
    static let addArrays = """
#include <metal_stdlib>
using namespace metal;

kernel void add_arrays(device const float* inA   [[ buffer(0) ]],
                       device const float* inB   [[ buffer(1) ]],
                       device       float* result [[ buffer(2) ]],
                       uint index [[ thread_position_in_grid ]])
{
    result[index] = inA[index] + inB[index];
}
"""

    // ------------------------------------------------------------------
    // Multiply
    // ------------------------------------------------------------------
    static let multiplyArrays = """
#include <metal_stdlib>
using namespace metal;

kernel void multiply_arrays(device const float* inA   [[ buffer(0) ]],
                             device const float* inB   [[ buffer(1) ]],
                             device       float* result [[ buffer(2) ]],
                             uint index [[ thread_position_in_grid ]])
{
    result[index] = inA[index] * inB[index];
}
"""
}
