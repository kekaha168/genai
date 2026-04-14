import SwiftUI

struct CreatorSidebar: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: CreatorDestination?

    var body: some View {
        List(selection: $selection) {
            // MARK: Labs
            Section {
                NavigationLink(value: CreatorDestination.myLabs) {
                    Label("My labs", systemImage: "flask")
                }
                NavigationLink(value: CreatorDestination.shaders) {
                    Label("Shaders", systemImage: "cpu")
                }
                NavigationLink(value: CreatorDestination.passes) {
                    Label("Passes", systemImage: "square.3.layers.3d")
                }
                if appState.allows(.mlPassEncoding) {
                    NavigationLink(value: CreatorDestination.mlPasses) {
                        Label("ML passes · tensors", systemImage: "brain.head.profile")
                    }
                } else {
                    lockedRow("ML passes · tensors", icon: "brain.head.profile", required: .professional)
                }
            } header: { SidebarSectionHeader(title: "Labs") }

            // MARK: Apple Silicon (Lab Pack only)
            if appState.allows(.imageblockEditor) {
                Section {
                    NavigationLink(value: CreatorDestination.appleSilicon) {
                        Label("Imageblock / tile", systemImage: "square.grid.3x3.fill")
                    }
                    NavigationLink(value: CreatorDestination.appleSilicon) {
                        Label("Multi-GPU submit", systemImage: "server.rack")
                    }
                    NavigationLink(value: CreatorDestination.appleSilicon) {
                        Label("Raster order groups", systemImage: "list.number")
                    }
                } header: { SidebarSectionHeader(title: "Apple Silicon") }
            } else if appState.tier == .professional {
                Section {
                    lockedRow("Imageblock / tile", icon: "square.grid.3x3.fill", required: .labPack)
                    lockedRow("Multi-GPU submit", icon: "server.rack", required: .labPack)
                } header: { SidebarSectionHeader(title: "Apple Silicon") }
            }

            // MARK: Analysis
            Section {
                if appState.allows(.coStepMode) {
                    NavigationLink(value: CreatorDestination.coStep) {
                        Label("Co-step mode", systemImage: "arrow.left.arrow.right")
                    }
                } else {
                    lockedRow("Co-step mode", icon: "arrow.left.arrow.right", required: .professional)
                }
                if appState.allows(.astDataFlow) {
                    NavigationLink(value: CreatorDestination.astAnalysis) {
                        Label("AST / data flow", systemImage: "arrow.triangle.branch")
                    }
                    NavigationLink(value: CreatorDestination.barrierGraph) {
                        Label("Barrier graph", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }
                if appState.allows(.timelineScrubber) {
                    NavigationLink(value: CreatorDestination.timelineScrubber) {
                        Label("Timeline scrubber", systemImage: "waveform")
                    }
                }
            } header: { SidebarSectionHeader(title: "Analysis") }

            // MARK: Distribution
            Section {
                NavigationLink(value: CreatorDestination.labPacks) {
                    Label("Lab packs", systemImage: "shippingbox")
                }
                if appState.allows(.signedLabPacks) {
                    NavigationLink(value: CreatorDestination.signedPacks) {
                        Label("Signed packs · CI", systemImage: "lock.shield")
                    }
                }
            } header: { SidebarSectionHeader(title: "Distribution") }
        }
        .navigationTitle("Metal Lab")
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            bottomNudge
        }
    }

    @ViewBuilder
    private var bottomNudge: some View {
        switch appState.tier {
        case .baseline:
            UpgradeNudge(message: "Upgrade for ML passes & co-step", requiredTier: .professional)
        case .professional:
            UpgradeNudge(message: "Upgrade for tensor shaders & fleet", requiredTier: .labPack)
        case .labPack:
            EmptyView()
        }
    }

    private func lockedRow(_ label: String, icon: String, required: Tier) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.tertiary)
            Spacer()
            LockedFeatureView(requiredTier: required)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Could present upgrade sheet
        }
    }
}

// MARK: - Creator Tab View (iOS)

struct CreatorTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MyLabsView()
            }
            .tabItem { Label("Labs", systemImage: "flask") }
            .tag(0)

            NavigationStack {
                ShaderEditorView()
            }
            .tabItem { Label("Shaders", systemImage: "cpu") }
            .tag(1)

            if appState.allows(.astDataFlow) {
                NavigationStack {
                    ASTAnalysisView()
                }
                .tabItem { Label("AST", systemImage: "arrow.triangle.branch") }
                .tag(2)

                NavigationStack {
                    CoStepView()
                }
                .tabItem { Label("Step", systemImage: "arrow.left.arrow.right") }
                .tag(3)
            }

            NavigationStack {
                LabPacksView()
            }
            .tabItem { Label("Packs", systemImage: "shippingbox") }
            .tag(4)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(5)
        }
    }
}
