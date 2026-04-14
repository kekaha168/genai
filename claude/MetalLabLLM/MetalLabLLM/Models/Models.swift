import SwiftUI
import Combine

// MARK: - Tier

enum Tier: String, CaseIterable, Identifiable {
    case baseline     = "Baseline"
    case professional = "Professional"
    case labPack      = "Lab Pack"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .baseline:     return Color(hex: "#1D9E75")
        case .professional: return Color(hex: "#185FA5")
        case .labPack:      return Color(hex: "#534AB7")
        }
    }

    var badgeBackground: Color {
        switch self {
        case .baseline:     return Color(hex: "#E1F5EE")
        case .professional: return Color(hex: "#E6F1FB")
        case .labPack:      return Color(hex: "#EEEDFE")
        }
    }

    var badgeForeground: Color {
        switch self {
        case .baseline:     return Color(hex: "#0F6E56")
        case .professional: return Color(hex: "#185FA5")
        case .labPack:      return Color(hex: "#534AB7")
        }
    }

    func allows(_ feature: Feature) -> Bool {
        feature.minimumTier.tierIndex <= self.tierIndex
    }

    var tierIndex: Int {
        switch self { case .baseline: return 0; case .professional: return 1; case .labPack: return 2 }
    }
}

// MARK: - Feature Gates

enum Feature: String {
    // Creator
    case mslEditor, renderPass, computePass, blitPass, argumentTable, residencySet
    case functionSpecialisation, commonMetalIR, compilationQoS, pipelineHarvesting, hlslConverter
    case mlPassEncoding, indirectCommandBuffer, rayTracingAccel, placementSparse
    case inlineTensorInference, metalFXNodes, imageblockEditor, multiGPUSubmit, rasterOrderGroup
    case astDataFlow, coStepMode, barrierGraph
    case timelineScrubber, crossGPUSync, fullASTPanel, captureScopeExport
    case singleLabExport, multiLabPack, signedLabPacks, ciHooks, vsCodeBridge

    // User
    case deviceCompare, abPlayback, counterCompare, occupancyHeatmap, metalFXMeters, frameInterpolationMetrics
    case astAnnotations, gputraceExport, taskCards
    case fleetOrchestration, regressionHarness, tensorThroughput, sparseResourceMap, counterExport
    case collaborativeAST, versionHistory, annotationThreads

    var minimumTier: Tier {
        switch self {
        case .mslEditor, .renderPass, .computePass, .blitPass, .argumentTable, .residencySet,
             .singleLabExport, .deviceCompare:
            return .baseline
        case .functionSpecialisation, .commonMetalIR, .compilationQoS, .pipelineHarvesting,
             .hlslConverter, .mlPassEncoding, .indirectCommandBuffer, .rayTracingAccel, .placementSparse,
             .astDataFlow, .coStepMode, .barrierGraph, .multiLabPack,
             .abPlayback, .counterCompare, .occupancyHeatmap, .metalFXMeters, .frameInterpolationMetrics,
             .astAnnotations, .gputraceExport, .taskCards:
            return .professional
        case .inlineTensorInference, .metalFXNodes, .imageblockEditor, .multiGPUSubmit, .rasterOrderGroup,
             .timelineScrubber, .crossGPUSync, .fullASTPanel, .captureScopeExport,
             .signedLabPacks, .ciHooks, .vsCodeBridge,
             .fleetOrchestration, .regressionHarness, .tensorThroughput, .sparseResourceMap,
             .counterExport, .collaborativeAST, .versionHistory, .annotationThreads:
            return .labPack
        }
    }
}

// MARK: - Role

enum UserRole: String, CaseIterable {
    case creator = "Lab Creator"
    case user    = "Lab User"

    var systemImage: String {
        switch self {
        case .creator: return "hammer"
        case .user:    return "play.circle"
        }
    }
}

// MARK: - Navigation Destinations

enum CreatorDestination: Hashable {
    case myLabs, shaders, passes, mlPasses, appleSilicon, astAnalysis, coStep, barrierGraph
    case timelineScrubber, labPacks, signedPacks
}

enum UserDestination: Hashable {
    case browse, installed, compareDevices, fleet
    case perfHUD, counterCompare, occupancyHeatmap, metalFXMeters, tensorThroughput, sparseMap
    case frameAnnotations, astAnnotations, taskCards, collabSessions, annotationThreads, versionHistory
}

// MARK: - Data Models

struct MetalLab: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var type: LabType
    var tier: Tier
    var lastModified: Date = .now
    var lineCount: Int = 0

    enum LabType: String, CaseIterable {
        case render   = "Render pass"
        case compute  = "Compute pass"
        case blit     = "Blit pass"
        case mlPass   = "ML pass"
        case rayTrace = "Ray tracing"
    }

    static let samples: [MetalLab] = [
        MetalLab(name: "Triangle demo",      type: .render,   tier: .baseline,     lineCount: 42),
        MetalLab(name: "Compute blur",        type: .compute,  tier: .baseline,     lineCount: 67),
        MetalLab(name: "Blit copy",           type: .blit,     tier: .baseline,     lineCount: 28),
        MetalLab(name: "Ray tracing scene",   type: .rayTrace, tier: .professional, lineCount: 184),
        MetalLab(name: "Tensor inference",    type: .mlPass,   tier: .labPack,      lineCount: 231),
        MetalLab(name: "MetalFX upscale",     type: .mlPass,   tier: .labPack,      lineCount: 156),
    ]
}

struct DeviceResult: Identifiable {
    let id = UUID()
    var deviceName: String
    var chipName: String
    var frameTimeMs: Double
    var fillRate: Double
    var status: DeviceStatus

    enum DeviceStatus: String {
        case ready   = "Ready"
        case running = "Running"
        case done    = "Done"
        var color: Color {
            switch self {
            case .ready:   return Color(hex: "#1D9E75")
            case .running: return Color(hex: "#185FA5")
            case .done:    return .secondary
            }
        }
    }

    static let samples: [DeviceResult] = [
        DeviceResult(deviceName: "Mac Studio M4 Ultra",  chipName: "M4 Ultra",  frameTimeMs: 4.1,  fillRate: 98, status: .ready),
        DeviceResult(deviceName: "MacBook Pro M4 Pro",   chipName: "M4 Pro",    frameTimeMs: 8.2,  fillRate: 94, status: .running),
        DeviceResult(deviceName: "iPad Pro M4",          chipName: "M4",        frameTimeMs: 9.7,  fillRate: 91, status: .ready),
        DeviceResult(deviceName: "iPhone 16 Pro",        chipName: "A18 Pro",   frameTimeMs: 11.4, fillRate: 87, status: .done),
        DeviceResult(deviceName: "iPhone 16",            chipName: "A18",       frameTimeMs: 14.3, fillRate: 82, status: .ready),
        DeviceResult(deviceName: "iPad mini A17 Pro",    chipName: "A17 Pro",   frameTimeMs: 13.1, fillRate: 84, status: .done),
    ]
}

// MARK: - App State

final class AppState: ObservableObject {
    @Published var tier: Tier = .baseline
    @Published var role: UserRole = .creator
    @Published var labs: [MetalLab] = MetalLab.samples
    @Published var deviceResults: [DeviceResult] = DeviceResult.samples
    @Published var selectedLab: MetalLab? = MetalLab.samples.first
    @Published var hudEnabled: Bool = true
    @Published var coStepEnabled: Bool = false
    @Published var connectedDeviceCount: Int = 6

    func allows(_ feature: Feature) -> Bool {
        tier.allows(feature)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
