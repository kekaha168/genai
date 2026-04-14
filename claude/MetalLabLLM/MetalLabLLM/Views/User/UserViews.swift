import SwiftUI
import Combine

// MARK: - User Sidebar

struct UserSidebar: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: UserDestination?

    var body: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: UserDestination.browse) {
                    Label("Browse labs", systemImage: "square.grid.2x2")
                }
                NavigationLink(value: UserDestination.installed) {
                    Label("Installed", systemImage: "checkmark.circle")
                }
                if appState.allows(.deviceCompare) {
                    NavigationLink(value: UserDestination.compareDevices) {
                        Label("Compare devices", systemImage: "iphone.and.ipad")
                    }
                }
                if appState.allows(.fleetOrchestration) {
                    NavigationLink(value: UserDestination.fleet) {
                        Label("Fleet devices", systemImage: "server.rack")
                    }
                } else if appState.tier == .professional {
                    lockedRow("Fleet devices", icon: "server.rack", required: .labPack)
                }
            } header: { SidebarSectionHeader(title: "Labs") }

            Section {
                NavigationLink(value: UserDestination.perfHUD) {
                    Label("Perf HUD", systemImage: "gauge.with.needle")
                }
                if appState.allows(.counterCompare) {
                    NavigationLink(value: UserDestination.counterCompare) {
                        Label("Counter compare", systemImage: "chart.bar")
                    }
                    NavigationLink(value: UserDestination.occupancyHeatmap) {
                        Label("Occupancy heatmap", systemImage: "square.grid.3x3.fill")
                    }
                    NavigationLink(value: UserDestination.metalFXMeters) {
                        Label("MetalFX meters", systemImage: "wand.and.stars")
                    }
                } else {
                    lockedRow("Counter compare", icon: "chart.bar", required: .professional)
                }
                if appState.allows(.tensorThroughput) {
                    NavigationLink(value: UserDestination.tensorThroughput) {
                        Label("Tensor throughput", systemImage: "brain.head.profile")
                    }
                    NavigationLink(value: UserDestination.sparseMap) {
                        Label("Sparse resource map", systemImage: "map")
                    }
                }
            } header: { SidebarSectionHeader(title: "Profile") }

            Section {
                NavigationLink(value: UserDestination.frameAnnotations) {
                    Label("Frame annotations", systemImage: "note.text")
                }
                if appState.allows(.astAnnotations) {
                    NavigationLink(value: UserDestination.astAnnotations) {
                        Label("AST annotations", systemImage: "arrow.triangle.branch")
                    }
                    NavigationLink(value: UserDestination.taskCards) {
                        Label("Task cards", systemImage: "rectangle.stack")
                    }
                }
                if appState.allows(.collaborativeAST) {
                    NavigationLink(value: UserDestination.collabSessions) {
                        Label("Collab sessions", systemImage: "person.2")
                    }
                    NavigationLink(value: UserDestination.annotationThreads) {
                        Label("Annotation threads", systemImage: "bubble.left.and.bubble.right")
                    }
                    NavigationLink(value: UserDestination.versionHistory) {
                        Label("Version history", systemImage: "clock.arrow.circlepath")
                    }
                }
            } header: { SidebarSectionHeader(title: "Notes & collaborate") }
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
            UpgradeNudge(message: "Upgrade for multi-device compare", requiredTier: .professional)
        case .professional:
            UpgradeNudge(message: "Upgrade for fleet & collaboration", requiredTier: .labPack)
        case .labPack:
            EmptyView()
        }
    }

    private func lockedRow(_ label: String, icon: String, required: Tier) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.tertiary)
            Spacer()
            LockedFeatureView(requiredTier: required)
        }
    }
}

// MARK: - User Detail Router

struct UserDetailView: View {
    @Binding var selection: UserDestination?

    var body: some View {
        switch selection {
        case .browse, .none:        BrowseLabsView()
        case .installed:            InstalledLabsView()
        case .compareDevices:       CompareDevicesView()
        case .fleet:                FleetView()
        case .perfHUD:              PerfHUDView()
        case .counterCompare:       CounterCompareView()
        case .occupancyHeatmap:     OccupancyHeatmapView()
        case .metalFXMeters:        MetalFXMetersView()
        case .tensorThroughput:     TensorThroughputView()
        case .sparseMap:            SparseResourceMapView()
        case .frameAnnotations:     FrameAnnotationsView()
        case .astAnnotations:       ASTAnnotationsView()
        case .taskCards:            TaskCardsView()
        case .collabSessions:       CollabSessionsView()
        case .annotationThreads:    AnnotationThreadsView()
        case .versionHistory:       VersionHistoryView()
        }
    }
}

// MARK: - User Tab View (iOS)

struct UserTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { BrowseLabsView() }
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }.tag(0)

            if appState.allows(.deviceCompare) {
                NavigationStack { CompareDevicesView() }
                    .tabItem { Label("Compare", systemImage: "iphone.and.ipad") }.tag(1)
            }

            NavigationStack { PerfHUDView() }
                .tabItem { Label("Profile", systemImage: "gauge.with.needle") }.tag(2)

            if appState.allows(.collaborativeAST) {
                NavigationStack { CollabSessionsView() }
                    .tabItem { Label("Collab", systemImage: "person.2") }.tag(3)
            }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }.tag(4)
        }
    }
}

// MARK: - Browse Labs

struct BrowseLabsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 10)]

    var filteredLabs: [MetalLab] {
        appState.labs.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(filteredLabs) { lab in
                    LabCard(lab: lab)
                }
            }
            .padding(16)
        }
        .searchable(text: $searchText, prompt: "Search lab packs…")
        .navigationTitle("Browse labs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("Run lab", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .tint(appState.tier.accentColor)
            }
        }
    }
}

// MARK: - Installed Labs

struct InstalledLabsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            ForEach(appState.labs.prefix(3)) { lab in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lab.name).font(.subheadline.weight(.medium))
                        Text(lab.type.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TierBadgeSmall(tier: lab.tier)
                }
            }
        }
        .navigationTitle("Installed labs")
    }
}

// MARK: - Compare Devices

struct CompareDevicesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .deviceCompare) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(label: "Devices", value: "\(appState.deviceResults.count)", accent: appState.tier.accentColor)
                        StatCard(label: "Best frame", value: "4.1 ms", accent: .green)
                        StatCard(label: "Avg fill rate", value: "89%", accent: appState.tier.accentColor)
                    }

                    Divider()

                    ForEach(appState.deviceResults) { result in
                        DeviceResultRow(result: result, best: appState.deviceResults.min(by: { $0.frameTimeMs < $1.frameTimeMs })?.frameTimeMs ?? 1)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Compare devices")
        .navigationSubtitle(appState.allows(.deviceCompare) ? "\(appState.deviceResults.count) devices" : "")
        .toolbar {
            if appState.allows(.gputraceExport) {
                ToolbarItem(placement: .primaryAction) {
                    Button("Export .gputrace") { }
                        .buttonStyle(.borderedProminent)
                        .tint(appState.tier.accentColor)
                }
            }
            ToolbarItem {
                Button("Run A/B") { }
                    .buttonStyle(.bordered)
            }
        }
    }
}

struct DeviceResultRow: View {
    let result: DeviceResult
    let best: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.deviceName).font(.subheadline.weight(.medium))
                Text(result.chipName).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 180, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(format: "%.1f ms", result.frameTimeMs))
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text("\(Int(result.fillRate))%")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: best / result.frameTimeMs)
                    .tint(result.status.color)
            }

            Text(result.status.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(result.status.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(result.status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fleet View

struct FleetView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .fleetOrchestration) {
            VStack(spacing: 0) {
                HStack {
                    StatCard(label: "Fleet size", value: "\(appState.connectedDeviceCount)", accent: appState.tier.accentColor)
                    StatCard(label: "Running", value: "2", accent: .blue)
                    StatCard(label: "Online", value: "\(appState.connectedDeviceCount)", accent: .green)
                }
                .padding(16)

                Divider()

                List {
                    ForEach(appState.deviceResults) { result in
                        HStack {
                            Image(systemName: result.deviceName.contains("Mac") ? "desktopcomputer" : "ipad")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.deviceName).font(.subheadline.weight(.medium))
                                Text(result.chipName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(result.status.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(result.status.color)
                        }
                    }
                }
            }
        }
        .navigationTitle("Fleet devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Run fleet") { }
                    .buttonStyle(.borderedProminent)
                    .tint(appState.tier.accentColor)
            }
            ToolbarItem {
                Button("Regression harness") { }
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Perf HUD

struct PerfHUDView: View {
    @EnvironmentObject var appState: AppState
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var frameTime: Double = 8.2
    @State private var fillRate: Double = 94
    @State private var gpuUtilisation: Double = 76

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Toggle("HUD overlay", isOn: $appState.hudEnabled)
                    .padding(.horizontal, 16).padding(.top, 4)

                HStack(spacing: 12) {
                    StatCard(label: "Frame time", value: String(format: "%.1f ms", frameTime), accent: frameTime < 10 ? .green : .orange)
                    StatCard(label: "Fill rate", value: "\(Int(fillRate))%", accent: appState.tier.accentColor)
                    StatCard(label: "GPU util.", value: "\(Int(gpuUtilisation))%", accent: appState.tier.accentColor)
                }
                .padding(.horizontal, 16)

                if appState.allows(.occupancyHeatmap) {
                    Divider()
                    Text("GPU counter history")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    SimpleSparkline(values: sparkValues, color: appState.tier.accentColor)
                        .frame(height: 60)
                        .padding(.horizontal, 16)
                }

                if appState.allows(.counterExport) {
                    Button("Export counters (CSV/JSON)") { }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("Performance HUD")
        .onReceive(timer) { _ in
            frameTime = Double.random(in: 7.8...9.1)
            fillRate = Double.random(in: 90...97)
            gpuUtilisation = Double.random(in: 70...85)
        }
    }

    var sparkValues: [Double] {
        (0..<20).map { _ in Double.random(in: 0.4...1.0) }
    }
}

struct SimpleSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = w / Double(values.count - 1)
            Path { path in
                guard let first = values.first else { return }
                path.move(to: CGPoint(x: 0, y: h - first * h))
                for (i, v) in values.enumerated() {
                    path.addLine(to: CGPoint(x: Double(i) * step, y: h - v * h))
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Counter Compare

struct CounterCompareView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .counterCompare) {
            List {
                Section("Cross-device counters") {
                    ForEach(appState.deviceResults.prefix(3)) { result in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.deviceName).font(.subheadline.weight(.medium))
                            HStack {
                                CounterBar(label: "Frame", value: result.frameTimeMs / 20, color: appState.tier.accentColor)
                                CounterBar(label: "Fill", value: result.fillRate / 100, color: .green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Counter compare")
    }
}

struct CounterBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            ProgressView(value: value).tint(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Occupancy Heatmap

struct OccupancyHeatmapView: View {
    @EnvironmentObject var appState: AppState
    private let rows = 8
    private let cols = 16

    var body: some View {
        FeatureGated(feature: .occupancyHeatmap) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shader occupancy per thread group")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: cols), spacing: 2) {
                        ForEach(0..<(rows * cols), id: \.self) { _ in
                            let occ = Double.random(in: 0.2...1.0)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(appState.tier.accentColor.opacity(occ))
                                .frame(height: 20)
                        }
                    }

                    HStack {
                        Text("0%").font(.caption2).foregroundStyle(.secondary)
                        LinearGradient(colors: [appState.tier.accentColor.opacity(0.1), appState.tier.accentColor],
                                       startPoint: .leading, endPoint: .trailing)
                        .frame(height: 8).cornerRadius(4)
                        Text("100%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Occupancy heatmap")
    }
}

// MARK: - MetalFX Meters

struct MetalFXMetersView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .metalFXMeters) {
            List {
                Section("MetalFX Upscaling") {
                    MeterRow(label: "Input resolution", value: "1440p → 4K", icon: "arrow.up.right.and.arrow.down.left")
                    MeterRow(label: "Quality mode", value: "Quality (67%)", icon: "dial.medium")
                    MeterRow(label: "Upscale latency", value: "1.2 ms", icon: "timer")
                }
                Section("Denoising") {
                    MeterRow(label: "Ray tracing denoiser", value: "Enabled", icon: "wand.and.stars")
                    MeterRow(label: "Denoise latency", value: "0.8 ms", icon: "timer")
                }
                Section("Frame Interpolation") {
                    MeterRow(label: "Input FPS", value: "60 fps", icon: "film.stack")
                    MeterRow(label: "Output FPS", value: "120 fps", icon: "film.stack")
                    MeterRow(label: "Interpolation lag", value: "8.3 ms", icon: "clock.badge.exclamationmark")
                }
            }
        }
        .navigationTitle("MetalFX meters")
    }
}

struct MeterRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        LabeledContent {
            Text(value).font(.subheadline)
        } label: {
            Label(label, systemImage: icon)
        }
    }
}

// MARK: - Tensor Throughput

struct TensorThroughputView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .tensorThroughput) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(label: "Throughput", value: "4.2 TFLOPS", accent: appState.tier.accentColor)
                        StatCard(label: "Tensor ops/s", value: "128M", accent: appState.tier.accentColor)
                        StatCard(label: "Bandwidth", value: "92 GB/s", accent: appState.tier.accentColor)
                    }

                    Divider()

                    Text("ML pass execution timeline")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(tensorLayers, id: \.0) { name, duration in
                        HStack {
                            Text(name).font(.caption).frame(width: 140, alignment: .leading)
                            ProgressView(value: duration).tint(appState.tier.accentColor)
                            Text(String(format: "%.1f ms", duration * 10))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Tensor throughput")
    }

    let tensorLayers: [(String, Double)] = [
        ("Embedding layer", 0.12), ("Attention heads ×8", 0.68), ("Feed-forward", 0.45),
        ("Layer norm", 0.08), ("Output projection", 0.21),
    ]
}

// MARK: - Sparse Resource Map

struct SparseResourceMapView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .sparseResourceMap) {
            ContentUnavailableView("Sparse resource map", systemImage: "map",
                description: Text("Visualise placement heap utilisation and sparse texture page residency across your Metal resources."))
        }
        .navigationTitle("Sparse resource map")
    }
}

// MARK: - Frame Annotations

struct FrameAnnotationsView: View {
    @EnvironmentObject var appState: AppState
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            // Mock frame preview
            ZStack {
                Color.black.opacity(0.85)
                Text("GPU Frame Preview")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(height: 200)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Annotation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.top, 12)

                TextEditor(text: $note)
                    .font(.subheadline)
                    .frame(height: 80)
                    .padding(4)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)

                HStack {
                    Spacer()
                    Button("Add annotation") { }
                        .buttonStyle(.borderedProminent)
                        .tint(appState.tier.accentColor)
                        .controlSize(.small)
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }

            List {
                Section("Recent annotations") {
                    AnnotationRow(text: "Fragment stage bottleneck visible here", time: "2m ago")
                    AnnotationRow(text: "Fill rate drops to 72% on this frame", time: "5m ago")
                }
            }
        }
        .navigationTitle("Frame annotations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Share") { }
            }
        }
    }
}

struct AnnotationRow: View {
    let text: String
    let time: String
    var body: some View {
        HStack(alignment: .top) {
            Text(text).font(.subheadline)
            Spacer()
            Text(time).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - AST Annotations (User)

struct ASTAnnotationsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .astAnnotations) {
            VStack(spacing: 0) {
                Text("Drag AST nodes to annotate Metal drawing, compute, and app integration tasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.quaternary.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    Section("Annotated nodes") {
                        ASTAnnotationRow(node: "drawPrimitives(.triangle)", annotation: "Perf bottleneck on A18", tag: "draw")
                        ASTAnnotationRow(node: "dispatchThreadgroups()", annotation: "Optimal threadgroup size: 32×1×1", tag: "compute")
                        ASTAnnotationRow(node: "setFragmentTexture()", annotation: "Consider sparse texture here", tag: "app")
                    }
                }
            }
        }
        .navigationTitle("AST annotations")
    }
}

struct ASTAnnotationRow: View {
    let node: String
    let annotation: String
    let tag: String

    var tagColor: Color {
        switch tag {
        case "draw":    return Color(hex: "#185FA5")
        case "compute": return Color(hex: "#1D9E75")
        default:        return Color(hex: "#534AB7")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(node)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                Text(tag)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tagColor)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(tagColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            }
            Text(annotation).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Task Cards

struct TaskCardsView: View {
    @EnvironmentObject var appState: AppState
    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 10)]

    var body: some View {
        FeatureGated(feature: .taskCards) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(taskCards, id: \.title) { card in
                        TaskCard(card: card, accent: appState.tier.accentColor)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Task cards")
    }

    let taskCards: [TaskCardData] = [
        TaskCardData(title: "Draw: Render triangle", category: "draw", status: "done", description: "Render a coloured triangle with vertex buffer"),
        TaskCardData(title: "Compute: Gaussian blur", category: "compute", status: "in progress", description: "5×5 Gaussian kernel on R8 texture"),
        TaskCardData(title: "App: MetalKit integration", category: "app", status: "todo", description: "MTKView with CAMetalLayer presenter"),
        TaskCardData(title: "Draw: Ray traced scene", category: "draw", status: "todo", description: "Acceleration structure + intersection"),
    ]
}

struct TaskCardData {
    let title: String
    let category: String
    let status: String
    let description: String
}

struct TaskCard: View {
    let card: TaskCardData
    let accent: Color

    var statusColor: Color {
        switch card.status {
        case "done":        return .green
        case "in progress": return .orange
        default:            return .secondary
        }
    }

    var categoryColor: Color {
        switch card.category {
        case "draw":    return Color(hex: "#185FA5")
        case "compute": return Color(hex: "#1D9E75")
        default:        return Color(hex: "#534AB7")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.category)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(categoryColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                Spacer()
                Circle().fill(statusColor).frame(width: 7, height: 7)
            }
            Text(card.title).font(.subheadline.weight(.medium)).lineLimit(2)
            Text(card.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(card.status).font(.caption2).foregroundStyle(statusColor)
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
    }
}

// MARK: - Collab Sessions

struct CollabSessionsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .collaborativeAST) {
            List {
                Section("Active sessions") {
                    CollabRow(name: "Alice Chen", action: "Annotating fragment stage", time: "now", online: true)
                    CollabRow(name: "Ben Nakamura", action: "Reviewing compute pass AST", time: "2m ago", online: true)
                    CollabRow(name: "Sara Kim", action: "Added task card: MetalFX", time: "8m ago", online: false)
                }
            }
        }
        .navigationTitle("Collab sessions")
    }
}

struct CollabRow: View {
    let name: String
    let action: String
    let time: String
    let online: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 32, height: 32)
                    .overlay(Text(String(name.prefix(1))).font(.caption.weight(.semibold)))
                if online {
                    Circle().fill(.green).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.background, lineWidth: 1.5))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.medium))
                Text(action).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(time).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Annotation Threads

struct AnnotationThreadsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .annotationThreads) {
            List {
                Section("GPU trace threads") {
                    ForEach(threads, id: \.0) { title, replies, time in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.subheadline.weight(.medium))
                                Text("\(replies) replies · \(time)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "bubble.left").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Annotation threads")
    }

    let threads = [
        ("Fragment stage occupancy drop at frame 142", 3, "5m ago"),
        ("Tensor throughput regression on A18", 7, "1h ago"),
        ("Sparse texture page fault — blit pass", 2, "2h ago"),
    ]
}

// MARK: - Version History

struct VersionHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .versionHistory) {
            List {
                ForEach(versions, id: \.0) { version, date, author, note in
                    HStack(alignment: .top, spacing: 10) {
                        Text(version)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(appState.tier.accentColor)
                            .frame(width: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note).font(.subheadline)
                            Text("\(author) · \(date)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Version history")
    }

    let versions = [
        ("v3.1.0", "Today", "Alice Chen", "Added MetalFX denoiser node"),
        ("v3.0.2", "Yesterday", "Ben Nakamura", "Fixed tensor stride alignment"),
        ("v3.0.1", "2d ago", "Sara Kim", "Improved barrier graph timing"),
        ("v2.9.0", "5d ago", "Alice Chen", "Added multi-GPU support"),
    ]
}
