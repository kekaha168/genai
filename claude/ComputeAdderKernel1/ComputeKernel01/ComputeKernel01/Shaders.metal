// Shaders.metal
// This file is compiled by Xcode into the default Metal library.
// The shader source is ALSO exposed as a Swift constant (see KernelShaders.swift)
// so that MetalKernel can compile it at runtime from source — enabling
// the "factory" pattern where any kernel string can be swapped in.

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------
// add_arrays  — element-wise addition
//   inA[i] + inB[i] → result[i]
// ---------------------------------------------------------------------
kernel void add_arrays(device const float* inA   [[ buffer(0) ]],
                       device const float* inB   [[ buffer(1) ]],
                       device       float* result [[ buffer(2) ]],
                       uint index [[ thread_position_in_grid ]])
{
    result[index] = inA[index] + inB[index];
}

// ---------------------------------------------------------------------
// multiply_arrays  — element-wise multiplication
//   inA[i] * inB[i] → result[i]
// ---------------------------------------------------------------------
kernel void multiply_arrays(device const float* inA   [[ buffer(0) ]],
                             device const float* inB   [[ buffer(1) ]],
                             device       float* result [[ buffer(2) ]],
                             uint index [[ thread_position_in_grid ]])
{
    result[index] = inA[index] * inB[index];
}
