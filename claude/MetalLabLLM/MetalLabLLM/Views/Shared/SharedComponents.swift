import SwiftUI

// MARK: - Tier Picker

struct TierPicker: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Picker("Tier", selection: $appState.tier) {
            ForEach(Tier.allCases) { tier in
                Text(tier.rawValue).tag(tier)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
    }
}

// MARK: - Role Picker

struct RolePicker: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Picker("Role", selection: $appState.role) {
            ForEach(UserRole.allCases, id: \.self) { role in
                Label(role.rawValue, systemImage: role.systemImage).tag(role)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
    }
}

// MARK: - Tier Badge

struct TierBadge: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(appState.tier.accentColor)
                .frame(width: 8, height: 8)
            Text(appState.tier.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(appState.tier.badgeForeground)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(appState.tier.badgeBackground, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Locked Feature Overlay

struct LockedFeatureView: View {
    let requiredTier: Tier
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Requires \(requiredTier.rawValue)")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(requiredTier.badgeForeground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(requiredTier.badgeBackground, in: RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Upgrade Nudge Banner

struct UpgradeNudge: View {
    let message: String
    let requiredTier: Tier
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle")
                    .font(.caption)
                Text(message)
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .foregroundStyle(requiredTier.badgeForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(requiredTier.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .sheet(isPresented: $showSheet) {
            UpgradeSheet(targetTier: requiredTier)
        }
    }
}

// MARK: - Upgrade Sheet

struct UpgradeSheet: View {
    let targetTier: Tier
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(targetTier.accentColor)
                Text("Upgrade to \(targetTier.rawValue)")
                    .font(.title2).fontWeight(.semibold)
                Text("Unlock advanced Metal 4 features for your lab workflow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(upgradePoints, id: \.self) { point in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(targetTier.accentColor)
                            .font(.subheadline)
                        Text(point)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Not now") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Upgrade") {
                    appState.tier = targetTier
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(targetTier.accentColor)
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
    }

    var upgradePoints: [String] {
        switch targetTier {
        case .professional:
            return ["ML pass encoding with MTLTensor", "Function specialisation builder",
                    "AST & data-flow CLI integration", "Metal/shader engine co-step mode",
                    "Multi-lab packs with version manifests"]
        case .labPack:
            return ["Inline tensor inference in shaders", "MetalFX upscaling & denoising nodes",
                    "Imageblock & tile shader pass editor", "Multi-GPU work submission",
                    "Signed lab pack collections + CI hooks"]
        default:
            return []
        }
    }
}

// MARK: - Feature-Gated Container

struct FeatureGated<Content: View>: View {
    @EnvironmentObject var appState: AppState
    let feature: Feature
    @ViewBuilder let content: () -> Content

    var body: some View {
        if appState.allows(feature) {
            content()
        } else {
            lockedPlaceholder
        }
    }

    private var lockedPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                LockedFeatureView(requiredTier: feature.minimumTier)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// MARK: - Section Header

struct SidebarSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    var accent: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Lab Card

struct LabCard: View {
    let lab: MetalLab
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lab.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(lab.type.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(lab.tier.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(lab.tier.badgeForeground)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(lab.tier.badgeBackground, in: RoundedRectangle(cornerRadius: 4))
                Spacer()
                Text("\(lab.lineCount) lines")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
    }
}

// MARK: - MSL Code Preview

struct MSLCodePreview: View {
    let code: String

    var body: some View {
        ScrollView {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
#if os(iOS)
        .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
#else
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
#endif
    }

    static let sampleRenderKernel = """
kernel void vertexShader(
    uint vertexID [[vertex_id]],
    constant Vertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    float4 pos = float4(vertices[vertexID].position, 1.0);
    return uniforms.projectionMatrix * pos;
}
"""

    static let sampleComputeKernel = """
kernel void gaussianBlur(
    texture2d<float, access::read>  inTex  [[texture(0)]],
    texture2d<float, access::write> outTex [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    float4 color = float4(0.0);
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            color += inTex.read(gid + uint2(dx, dy));
        }
    }
    outTex.write(color / 25.0, gid);
}
"""

    static let sampleTensorKernel = """
// Metal 4 — inline tensor inference
[[kernel]]
void tensorPass(
    MTLTensor *inputTensor  [[tensor(0)]],
    MTLTensor *outputTensor [[tensor(1)]],
    uint3 gid [[thread_position_in_grid]])
{
    // Inline ML inference alongside shader code
    float val = inputTensor->read(gid);
    outputTensor->write(activate(val), gid);
}
"""
}
