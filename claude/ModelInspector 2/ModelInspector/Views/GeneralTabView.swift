import SwiftUI

struct GeneralTabView: View {
    let model: InspectedModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(value: "\(model.inputs.count)", label: "Inputs", icon: "arrow.down.circle.fill", color: .blue)
                    StatCard(value: "\(model.outputs.count)", label: "Outputs", icon: "arrow.up.circle.fill", color: .green)
                    let ops = model.structure.layerCount > 0 ? model.structure.layerCount : model.structure.operationCount
                    StatCard(value: ops > 0 ? "\(ops)" : "—", label: "Operations", icon: "square.3.layers.3d.fill", color: .purple)
                }

                // File info
                InfoSection(title: "File") {
                    InfoRow(label: "Name", value: model.name + model.fileFormat.rawValue)
                    InfoRow(label: "Format", value: model.fileFormat.displayName)
                    InfoRow(label: "Size", value: model.fileSizeString)
                    InfoRow(label: "Path", value: model.fileURL.path, monospaced: true, truncated: true)
                }

                // Model info
                InfoSection(title: "Model") {
                    InfoRow(label: "Type", value: model.structure.kind.rawValue)
                    InfoRow(label: "Compute Units", value: model.metadata.computeUnitsLabel)
                    InfoRow(label: "On-Device Training", value: model.metadata.isUpdatable ? "Supported" : "Not supported")
                }

                // Description
                if model.metadata.shortDescription != "—" {
                    InfoSection(title: "Description") {
                        Text(model.metadata.shortDescription)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                }

                // Input/output summary
                IOSummaryCard(model: model)

                // Structure summary
                if model.structure.kind != .unavailable && model.structure.kind != .other {
                    StructureSummaryCard(structure: model.structure)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Info Section

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var monospaced = false
    var truncated = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
                .fixedSize()

            if monospaced {
                Text(value)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(truncated ? 2 : nil)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(truncated ? 2 : nil)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.clear)
        Divider()
            .padding(.leading, 14)
    }
}

// MARK: - IO Summary Card

struct IOSummaryCard: View {
    let model: InspectedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INPUTS / OUTPUTS".uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(model.inputs) { feat in
                    MiniFeatureRow(feat: feat, direction: .input)
                }
                if !model.inputs.isEmpty && !model.outputs.isEmpty {
                    Divider().padding(.horizontal, 8)
                }
                ForEach(model.outputs) { feat in
                    MiniFeatureRow(feat: feat, direction: .output)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5))
        }
    }
}

enum IODirection { case input, output }

struct MiniFeatureRow: View {
    let feat: FeatureInfo
    let direction: IODirection

    var dirColor: Color { direction == .input ? .blue : .green }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: feat.type.icon)
                .font(.system(size: 13))
                .foregroundStyle(dirColor)
                .frame(width: 20)

            Text(feat.name)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(feat.typeDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if let shape = feat.shapeDetail {
                    Text(shape)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Structure summary

struct StructureSummaryCard: View {
    let structure: ModelStructureInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STRUCTURE".uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            // Device distribution
            let ops = structure.operations.isEmpty ? structure.layers.map { $0.computeDevice } : structure.operations.map { $0.computeDevice }
            let withDevice = ops.compactMap { $0 }
            if !withDevice.isEmpty {
                DeviceDistributionBar(devices: withDevice)
            }
        }
    }
}

struct DeviceDistributionBar: View {
    let devices: [ComputeDeviceInfo]

    var counts: [ComputeDevice: Int] {
        devices.reduce(into: [:]) { dict, info in
            dict[info.preferred, default: 0] += 1
        }
    }

    var total: Double { Double(devices.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach([ComputeDevice.neuralEngine, .gpu, .cpu, .unknown], id: \.self) { dev in
                        if let count = counts[dev], count > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(deviceColor(dev))
                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(total))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 10)

            // Legend
            HStack(spacing: 16) {
                ForEach([ComputeDevice.neuralEngine, .gpu, .cpu], id: \.self) { dev in
                    if let count = counts[dev] {
                        HStack(spacing: 5) {
                            Circle().fill(deviceColor(dev)).frame(width: 8, height: 8)
                            Text("\(dev.rawValue) \(count)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5))
    }

    func deviceColor(_ device: ComputeDevice) -> Color {
        switch device {
        case .cpu:           return .blue
        case .gpu:           return .green
        case .neuralEngine:  return .purple
        case .unknown:       return .gray
        }
    }
}
