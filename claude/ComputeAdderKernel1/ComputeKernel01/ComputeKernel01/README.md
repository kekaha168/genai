# MetalAdderApp — Compute Kernel Factory

A SwiftUI app that wraps Metal GPU compute kernels behind a clean factory
interface. Drop in any `.metal` kernel source string, a data source, and a
verification rule — the factory handles all boilerplate.

---

## File map

```
MetalAdderApp/
├── MetalAdderApp.swift       @main app entry point
├── ContentView.swift         SwiftUI views (config, data, run, results, log)
├── KernelViewModel.swift     ObservableObject — bridges UI ↔ MetalKernel
├── MetalKernel.swift         ★ Compute Kernel Factory
├── KernelShaders.swift       MSL source strings as Swift constants
└── Shaders.metal             Same kernels compiled into the default .metallib
```

---

## MetalKernel API

```swift
// 1. Choose a data source
let data = RandomDataSource(length: 1024)
// or
let data = StaticDataSource(dataA: [1,2,3], dataB: [4,5,6])

// 2. Choose a verification rule
let rule = AdditionVerificationRule()           // result[i] == inA[i]+inB[i]
let rule = MultiplicationVerificationRule()     // result[i] == inA[i]*inB[i]
let rule = CustomVerificationRule { a, b, r in // your own logic
    r[0] == 42 ? nil : "Expected 42 at [0]"
}

// 3. Build the factory
let kernel = MetalKernel(
    device: MTLCreateSystemDefaultDevice()!,
    shaderSource: KernelShaders.addArrays,   // any MSL string
    kernelName:   "add_arrays",
    dataSource:   data,
    rule:         rule
)

// 4. Run
kernel.prepareData()                 // allocate + fill GPU buffers
let result = kernel.sendComputeCommand()   // encode → commit → wait → verify
print(result.passed)                 // true / false
print(result.output)                 // [Float]

// Optional: re-run with fresh data without rebuilding the pipeline
kernel.loadData()
kernel.sendComputeCommand()
```

---

## Adding a new kernel

1. Add an MSL string constant to `KernelShaders.swift`:

```swift
static let squareArrays = """
#include <metal_stdlib>
using namespace metal;
kernel void square_arrays(device const float* inA [[ buffer(0) ]],
                           device const float* inB [[ buffer(1) ]],
                           device       float* result [[ buffer(2) ]],
                           uint index [[ thread_position_in_grid ]])
{
    result[index] = inA[index] * inA[index];
}
"""
```

2. Register a `KernelConfig` in `KernelViewModel.configs`:

```swift
KernelConfig(
    id: "square",
    displayName: "square_arrays",
    shaderSource: KernelShaders.squareArrays,
    kernelName: "square_arrays",
    verificationRule: CustomVerificationRule { a, _, r in
        for i in 0..<r.count {
            if abs(r[i] - a[i]*a[i]) > 1e-4 { return "Mismatch at [\(i)]" }
        }
        return nil
    },
    defaultDataSource: RandomDataSource(length: 64)
)
```

That's it — the UI picks it up automatically.

---

## Requirements

- Xcode 15+
- iOS 17+ / macOS 14+  (Metal required, no simulator support for GPU compute)
- Add `Metal.framework` to *Link Binary With Libraries* if not already present.
