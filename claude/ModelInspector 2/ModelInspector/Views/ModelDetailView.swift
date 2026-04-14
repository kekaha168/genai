import SwiftUI

struct ModelDetailView: View {
    let model: InspectedModel
    let vm: InspectorViewModel
    @State private var headerExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Model header card
            ModelHeaderCard(model: model, isExpanded: $headerExpanded)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Tab bar
            TabScrollView(selectedTab: Binding(
                get: { vm.selectedTab },
                set: { vm.selectedTab = $0 }
            ))
            .padding(.vertical, 8)

            Divider()

            // Tab content
            TabView(selection: Binding(
                get: { vm.selectedTab },
                set: { vm.selectedTab = $0 }
            )) {
                GeneralTabView(model: model)
                    .tag(InspectorViewModel.InspectorTab.general)

                FeaturesTabView(features: model.inputs, label: "Input")
                    .tag(InspectorViewModel.InspectorTab.inputs)

                FeaturesTabView(features: model.outputs, label: "Output")
                    .tag(InspectorViewModel.InspectorTab.outputs)

                StructureTabView(structure: model.structure)
                    .tag(InspectorViewModel.InspectorTab.structure)

                MetadataTabView(model: model)
                    .tag(InspectorViewModel.InspectorTab.metadata)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.spring(duration: 0.3), value: vm.selectedTab)
        }
        .navigationTitle(model.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        vm.state = .empty
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            #endif
        }
    }
}

// MARK: - Header Card

struct ModelHeaderCard: View {
    let model: InspectedModel
    @Binding var isExpanded: Bool

    var accentColor: Color {
        switch model.fileFormat.accentColor {
        case "blue":   return .blue
        case "purple": return .purple
        case "orange": return .orange
        default:       return .blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Format icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: model.fileFormat.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        FormatBadge(text: model.fileFormat.displayName, color: accentColor)
                        Text(model.fileSizeString)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Stats
                HStack(spacing: 16) {
                    StatMini(value: "\(model.inputs.count)", label: "in")
                    StatMini(value: "\(model.outputs.count)", label: "out")
                    let opCount = model.structure.layerCount > 0 ? model.structure.layerCount : model.structure.operationCount
                    if opCount > 0 {
                        StatMini(value: "\(opCount)", label: "ops")
                    }
                }
            }
            .padding(14)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}

struct FormatBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

struct StatMini: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Custom tab bar

struct TabScrollView: View {
    @Binding var selectedTab: InspectorViewModel.InspectorTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(InspectorViewModel.InspectorTab.allCases, id: \.self) { tab in
                    TabChip(tab: tab, isSelected: selectedTab == tab) {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct TabChip: View {
    let tab: InspectorViewModel.InspectorTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? tab.icon + ".fill" : tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
//            .background(isSelected ? .blue : Color(.systemGray6),
//                        in: Capsule())
#if os(iOS)
            .background(isSelected ? .blue.opacity(0.15) : Color(.systemGray6), in: Capsule())
#else
            .background(isSelected ? .blue.opacity(0.15) : Color(
                nsColor: .windowBackgroundColor // Closest equivalent on macOS
            ), in: Capsule())
            
#endif
            .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
