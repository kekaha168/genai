import SwiftUI

struct FeaturesTabView: View {
    let features: [FeatureInfo]
    let label: String

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if features.isEmpty {
                    EmptyFeaturesView(label: label)
                } else {
                    ForEach(features) { feat in
                        FeatureDetailCard(feat: feat)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct EmptyFeaturesView: View {
    let label: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No \(label) features")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Feature Card

struct FeatureDetailCard: View {
    let feat: FeatureInfo
    @State private var expanded = false

    var typeColor: Color {
        switch feat.type.color {
        case "blue":   return .blue
        case "purple": return .purple
        case "green":  return .green
        case "orange": return .orange
        default:       return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    // Type icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(typeColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: feat.type.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(typeColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(feat.name)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)

                            if feat.isOptional {
                                Text("optional")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                        }

                        HStack(spacing: 6) {
                            TypeBadge(text: feat.typeDetail, color: typeColor)

                            if let shape = feat.shapeDetail {
                                Text(shape)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if expanded {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 0) {
                    if let shape = feat.shapeDetail {
                        DetailRow(key: "Shape", value: shape, monospace: true)
                    }
                    if let dtype = feat.dataTypeDetail {
                        DetailRow(key: "Data Type", value: dtype, monospace: false)
                    }
                    if let color = feat.colorDetail {
                        DetailRow(key: "Pixel Format", value: color, monospace: false)
                    }
                    DetailRow(key: "Required", value: feat.isOptional ? "No" : "Yes", monospace: false)

                    if !feat.featureDescription.isEmpty {
                        HStack(alignment: .top) {
                            Text("Description")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            Text(feat.featureDescription)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        Divider().padding(.leading, 14)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 0.5))
    }
}

struct TypeBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

struct DetailRow: View {
    let key: String
    let value: String
    let monospace: Bool

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            if monospace {
                Text(value)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary)
            } else {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)

        Divider().padding(.leading, 14)
    }
}
