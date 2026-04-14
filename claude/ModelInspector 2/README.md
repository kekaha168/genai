# CoreML Model Inspector

A SwiftUI app for iOS 26+ that replicates Xcode's model inspector — on device.

## Features

| Tab | What it shows | CoreML API |
|-----|--------------|------------|
| **General** | File size, format, compute units, I/O summary, hardware distribution bar | `MLModelDescription` |
| **Inputs** | Each input with type, shape, pixel format, data type — expandable | `MLFeatureDescription` |
| **Outputs** | Each output with full type detail | `MLFeatureDescription` |
| **Structure** | Every layer/operation with name, type, hardware routing — searchable & filterable | `MLModelStructure`, `MLComputePlan` |
| **Metadata** | Author, version, license, user-defined keys, API code snippets | `MLModelDescription.metadata` |

## Requirements

- Xcode 15+
- iOS 17+ deployment target
- No third-party dependencies

## Setup

1. Open `ModelInspector.xcodeproj` in Xcode
2. Set your Development Team in target settings
3. Build and run on device or simulator

## Loading a Model

**From device:** Tap "Choose Model File" — the document picker accepts `.mlmodel`, `.mlpackage`, and `.mlmodelc`.

**Demo mode:** Tap "Load Sample (DiceDetector)" to explore a synthetic DiceDetector model with 32 realistic operations, showing the full Neural Engine / CPU routing that Xcode's inspector displays.

## CoreML APIs Used

```swift
// Metadata + I/O
model.modelDescription
desc.inputDescriptionsByName   // [String: MLFeatureDescription]
desc.metadata[.author]

// Layer structure (iOS 17+)
MLModelStructure.load(contentsOf: compiledURL)  // async
// → .neuralNetwork / .program / .pipeline

// Hardware routing (iOS 17+)
MLComputePlan(contentsOf: compiledURL, configuration: config)
plan.computeDeviceUsage(for: layer)
// → .cpu / .gpu / .neuralEngine
```

## File Structure

```
ModelInspector/
├── App/
│   └── ModelInspectorApp.swift
├── Models/
│   └── InspectorModels.swift        ← domain types
├── ViewModels/
│   └── InspectorViewModel.swift     ← @Observable VM + sample data
├── Views/
│   ├── ContentView.swift
│   ├── EmptyStateView.swift
│   ├── ModelDetailView.swift        ← header card + tab bar
│   ├── GeneralTabView.swift
│   ├── FeaturesTabView.swift        ← inputs & outputs
│   ├── StructureTabView.swift       ← layer/op list with search + filter
│   └── MetadataTabView.swift        ← metadata + API snippets
└── Utilities/
    └── ModelParser.swift            ← CoreML → domain model conversion
```
