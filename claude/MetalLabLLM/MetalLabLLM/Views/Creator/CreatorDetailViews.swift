import SwiftUI

// MARK: - Creator Detail Router

struct CreatorDetailView: View {
    @Binding var selection: CreatorDestination?

    var body: some View {
        switch selection {
        case .myLabs, .none:     MyLabsView()
        case .shaders:           ShaderEditorView()
        case .passes:            PassesView()
        case .mlPasses:          MLPassesView()
        case .appleSilicon:      AppleSiliconView()
        case .astAnalysis:       ASTAnalysisView()
        case .coStep:            CoStepView()
        case .barrierGraph:      BarrierGraphView()
        case .timelineScrubber:  TimelineScrubberView()
        case .labPacks:          LabPacksView()
        case .signedPacks:       SignedPacksView()
        }
    }
}

// MARK: - My Labs

struct MyLabsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewLab = false
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(appState.labs) { lab in
                    LabCard(lab: lab)
                }
            }
            .padding(16)
        }
        .navigationTitle("My labs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewLab = true } label: {
                    Label("New lab", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button { } label: {
                    Label("Export .metalab", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showNewLab) {
            NewLabSheet()
        }
    }
}

struct NewLabSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var name = ""
    @State private var type = MetalLab.LabType.render

    var body: some View {
        NavigationStack {
            Form {
                TextField("Lab name", text: $name)
                Picker("Pass type", selection: $type) {
                    ForEach(MetalLab.LabType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
            }
            .navigationTitle("New lab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        appState.labs.append(MetalLab(name: name.isEmpty ? "Untitled" : name, type: type, tier: appState.tier))
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 200)
    }
}

// MARK: - Shader Editor

struct ShaderEditorView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedKernel = 0
    @State private var showFunctionSpec = false

    private let kernelOptions = ["Vertex", "Compute (blur)", "Tensor (ML)"]

    var body: some View {
        VStack(spacing: 0) {
            // Picker bar
            HStack {
                Picker("Kernel", selection: $selectedKernel) {
                    ForEach(kernelOptions.indices, id: \.self) { i in
                        Text(kernelOptions[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)

                Spacer()

                if appState.allows(.compilationQoS) {
                    Button("QoS context") { }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                if appState.allows(.pipelineHarvesting) {
                    Button("Harvest pipelines") { }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                if appState.allows(.functionSpecialisation) {
                    Button("Specialise…") { showFunctionSpec = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(appState.tier.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            HStack(spacing: 0) {
                // Code area
                MSLCodePreview(code: codeForKernel(selectedKernel))
                    .padding(12)

                // Right panel — Analysis
                if appState.allows(.astDataFlow) {
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)

                        AnalysisPanelEntry(label: "AST nodes", value: "47", icon: "arrow.triangle.branch")
                        AnalysisPanelEntry(label: "Data flow edges", value: "23", icon: "arrow.left.arrow.right")
                        AnalysisPanelEntry(label: "IR size", value: "2.1 KB", icon: "doc.text")

                        if appState.allows(.fullASTPanel) {
                            AnalysisPanelEntry(label: "CFG blocks", value: "8", icon: "rectangle.connected.to.line.below")
                            AnalysisPanelEntry(label: "DFG depth", value: "5", icon: "list.number")
                        }

                        Spacer()

                        if appState.allows(.coStepMode) {
                            Toggle("Co-step mode", isOn: $appState.coStepEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 170)
                }
            }
        }
        .navigationTitle("Shaders")
        .navigationSubtitle(appState.allows(.commonMetalIR) ? "Common Metal IR · shared" : "Static compilation")
        .sheet(isPresented: $showFunctionSpec) {
            FunctionSpecSheet()
        }
    }

    func codeForKernel(_ index: Int) -> String {
        switch index {
        case 1:  return MSLCodePreview.sampleComputeKernel
        case 2:  return appState.allows(.inlineTensorInference) ? MSLCodePreview.sampleTensorKernel : "// Requires Lab Pack tier\n// to use inline tensor inference"
        default: return MSLCodePreview.sampleRenderKernel
        }
    }
}

struct AnalysisPanelEntry: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary).frame(width: 14)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.medium)
        }
    }
}

struct FunctionSpecSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enableHDR = true
    @State private var qualityLevel = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Pipeline variants") {
                    Toggle("HDR output", isOn: $enableHDR)
                    Stepper("Quality level: \(qualityLevel)", value: $qualityLevel, in: 1...4)
                }
                Section("Common Metal IR") {
                    Text("Compilation results are shared across pipeline variants to reduce redundant compile work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Function specialisation")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .frame(minWidth: 360, minHeight: 260)
    }
}

// MARK: - Passes

struct PassesView: View {
    @EnvironmentObject var appState: AppState
    private let passTypes: [(String, String, Feature)] = [
        ("Render pass", "Encode draw commands for GPU rasterisation", .renderPass),
        ("Compute pass", "Parallel thread grid execution", .computePass),
        ("Blit pass", "Buffer & texture copy / clear operations", .blitPass),
        ("ML pass", "MTLTensor-backed inference execution", .mlPassEncoding),
        ("Indirect commands", "GPU-driven draw stored in MTLBuffer", .indirectCommandBuffer),
        ("Ray tracing", "Acceleration structure + intersection", .rayTracingAccel),
    ]

    var body: some View {
        List {
            ForEach(passTypes, id: \.0) { name, description, feature in
                PassRow(name: name, description: description, feature: feature)
            }
        }
        .navigationTitle("Passes")
        .navigationSubtitle("MTL4ArgumentTable · residency sets")
    }
}

struct PassRow: View {
    @EnvironmentObject var appState: AppState
    let name: String
    let description: String
    let feature: Feature

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline).fontWeight(.medium)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if appState.allows(feature) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                LockedFeatureView(requiredTier: feature.minimumTier)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ML Passes

struct MLPassesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .mlPassEncoding) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(label: "Tensor ops", value: "128", accent: appState.tier.accentColor)
                        StatCard(label: "Network depth", value: "24 layers", accent: appState.tier.accentColor)
                        StatCard(label: "Throughput", value: "4.2 TFLOPS", accent: appState.tier.accentColor)
                    }

                    Divider()

                    Text("Tensor configuration")
                        .font(.headline)

                    MSLCodePreview(code: MSLCodePreview.sampleTensorKernel)
                        .frame(height: 200)

                    if appState.allows(.inlineTensorInference) {
                        Text("Inline inference")
                            .font(.headline)
                        Text("ML inference is available directly within shader code. Use MTLTensor as a first-class citizen in your Metal Shading Language kernels.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("ML passes · tensors")
        .navigationSubtitle(appState.allows(.inlineTensorInference) ? "Inline inference enabled" : "Command-line execution")
        .toolbar {
            if appState.allows(.mlPassEncoding) {
                ToolbarItem(placement: .primaryAction) {
                    Button("Execute network") { }
                        .buttonStyle(.borderedProminent)
                        .tint(appState.tier.accentColor)
                }
            }
        }
    }
}

// MARK: - Apple Silicon

struct AppleSiliconView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .imageblockEditor) {
            List {
                Section("Tile-based deferred rendering") {
                    NavigationLink("Imageblock editor") {
                        PlaceholderDetailView(title: "Imageblock editor", systemImage: "square.grid.3x3.fill")
                    }
                    NavigationLink("Tile shader pass") {
                        PlaceholderDetailView(title: "Tile shader pass", systemImage: "rectangle.split.3x1")
                    }
                    NavigationLink("Raster order groups") {
                        PlaceholderDetailView(title: "Raster order groups", systemImage: "list.number")
                    }
                }
                Section("Multi-GPU") {
                    NavigationLink("Work submission orchestrator") {
                        PlaceholderDetailView(title: "Multi-GPU orchestrator", systemImage: "server.rack")
                    }
                    NavigationLink("Cross-GPU fence sync") {
                        PlaceholderDetailView(title: "Cross-GPU fence sync", systemImage: "bolt.horizontal")
                    }
                }
            }
        }
        .navigationTitle("Apple Silicon")
    }
}

// MARK: - AST Analysis

struct ASTAnalysisView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .astDataFlow) {
            VStack(spacing: 0) {
                HStack {
                    ForEach(["AST", "CFG", "DFG"], id: \.self) { tab in
                        Button(tab) { }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Spacer()
                    if appState.allows(.fullASTPanel) {
                        Button("Run CLI analysis") { }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(appState.tier.accentColor)
                    }
                }
                .padding(12)
                .background(.bar)
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ASTNodeRow(depth: 0, name: "TranslationUnit", kind: "root")
                        ASTNodeRow(depth: 1, name: "FunctionDecl: computePass", kind: "function")
                        ASTNodeRow(depth: 2, name: "ParmVarDecl: in [[buffer(0)]]", kind: "param")
                        ASTNodeRow(depth: 2, name: "ParmVarDecl: out [[buffer(1)]]", kind: "param")
                        ASTNodeRow(depth: 2, name: "CompoundStmt", kind: "stmt")
                        ASTNodeRow(depth: 3, name: "BinaryOperator: =", kind: "expr")
                        ASTNodeRow(depth: 4, name: "ArraySubscriptExpr: out[gid]", kind: "expr")
                        ASTNodeRow(depth: 4, name: "BinaryOperator: * 2.0", kind: "expr")
                        if appState.allows(.fullASTPanel) {
                            ASTNodeRow(depth: 5, name: "ImplicitCastExpr: float", kind: "cast")
                            ASTNodeRow(depth: 5, name: "FloatingLiteral: 2.0", kind: "literal")
                        }
                    }
                    .padding(12)
                }
            }
        }
        .navigationTitle("AST / data flow")
    }
}

struct ASTNodeRow: View {
    let depth: Int
    let name: String
    let kind: String

    var kindColor: Color {
        switch kind {
        case "function": return Color(hex: "#185FA5")
        case "param":    return Color(hex: "#1D9E75")
        case "expr":     return Color(hex: "#534AB7")
        default:         return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<depth, id: \.self) { _ in
                Spacer().frame(width: 16)
                Rectangle().fill(.separator).frame(width: 1)
                Spacer().frame(width: 8)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .padding(.leading, 4)
            Spacer()
            Text(kind)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(kindColor)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(kindColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - Co-Step

struct CoStepView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 2
    private let stepCount = 6

    var body: some View {
        FeatureGated(feature: .coStepMode) {
            VStack(spacing: 0) {
                // Step control bar
                HStack(spacing: 12) {
                    Button { if currentStep > 0 { currentStep -= 1 } } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    ForEach(0..<stepCount, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? appState.tier.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: i == currentStep ? 10 : 7, height: i == currentStep ? 10 : 7)
                    }

                    Button { if currentStep < stepCount - 1 { currentStep += 1 } } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("Step \(currentStep + 1) / \(stepCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Live", isOn: $appState.coStepEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    Text("Live sync").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.bar)
                Divider()

                HStack(spacing: 0) {
                    // Metal engine state
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Metal engine")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(metalSteps[currentStep], id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.3))

                    Divider()

                    // Shader state
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shader state")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(shaderSteps[currentStep], id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Co-step mode")
    }

    let metalSteps: [[String]] = [
        ["encoder.beginRenderPass()", "descriptor.colorAttachments[0]"],
        ["encoder.setRenderPipelineState()", "pipeline bound → vertex stage"],
        ["encoder.setVertexBuffer(vertices)", "buffer(0) → 3 vertices"],
        ["encoder.drawPrimitives(.triangle)", "thread dispatch: 3 vertices"],
        ["encoder.endEncoding()", "commands serialised"],
        ["commandBuffer.commit()", "submitted to GPU"],
    ]
    let shaderSteps: [[String]] = [
        ["// RenderPass initialised", "colorAttachment format: bgra8"],
        ["vertexShader() loaded", "fragmentShader() loaded"],
        ["in[0] = {0,-0.5,0}", "in[1] = {-0.5,0.5,0}", "in[2] = {0.5,0.5,0}"],
        ["gid = 0 → pos = float4(0,-0.5,0,1)", "gid = 1 → pos = float4(-0.5,0.5,0,1)"],
        ["fragment stage: rasterise 3 tris", "out: rgba(1,0,0,1)"],
        ["// GPU execution complete"],
    ]
}

// MARK: - Barrier Graph

struct BarrierGraphView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .barrierGraph) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stage-to-stage synchronisation")
                        .font(.headline)

                    ForEach(barriers, id: \.0) { from, to, timing in
                        BarrierRow(from: from, to: to, timingMs: timing, accent: appState.tier.accentColor)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Barrier graph")
    }

    let barriers: [(String, String, Double)] = [
        ("Vertex stage", "Fragment stage", 0.12),
        ("Fragment stage", "Compute pass", 0.34),
        ("Compute pass", "Blit pass", 0.08),
        ("Blit pass", "Present", 0.05),
    ]
}

struct BarrierRow: View {
    let from: String
    let to: String
    let timingMs: Double
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(from).font(.caption.weight(.medium))
                Text("→ \(to)").font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 180, alignment: .leading)

            RoundedRectangle(cornerRadius: 3)
                .fill(accent.opacity(0.25))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(accent)
                        .frame(width: timingMs * 300)
                }
                .frame(height: 12)

            Text(String(format: "%.2f ms", timingMs))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Timeline Scrubber

struct TimelineScrubberView: View {
    @EnvironmentObject var appState: AppState
    @State private var playhead: Double = 0.32

    var body: some View {
        FeatureGated(feature: .timelineScrubber) {
            VStack(spacing: 0) {
                HStack {
                    Text("Multi-encoder timeline")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.0f ms", playhead * 100))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.top, 12)

                Slider(value: $playhead, in: 0...1)
                    .padding(.horizontal, 16)
                    .tint(appState.tier.accentColor)

                Divider().padding(.top, 8)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(encoders, id: \.0) { name, start, duration, color in
                            TimelineTrack(name: name, start: start, duration: duration,
                                          playhead: playhead, color: color)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Timeline scrubber")
    }

    let encoders: [(String, Double, Double, Color)] = [
        ("Render encoder",   0.00, 0.45, Color(hex: "#185FA5")),
        ("Compute encoder",  0.40, 0.30, Color(hex: "#1D9E75")),
        ("Blit encoder",     0.65, 0.15, Color(hex: "#534AB7")),
        ("ML pass encoder",  0.75, 0.20, Color(hex: "#BA7517")),
    ]
}

struct TimelineTrack: View {
    let name: String
    let start: Double
    let duration: Double
    let playhead: Double
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.caption)
                .frame(width: 130, alignment: .trailing)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(width: geo.size.width)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * duration,
                               height: geo.size.height)
                        .offset(x: geo.size.width * start)

                    Rectangle()
                        .fill(.red.opacity(0.7))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * playhead)
                }
            }
            .frame(height: 20)
        }
    }
}

// MARK: - Lab Packs

struct LabPacksView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("Installed packs") {
                LabPackRow(name: "Metal fundamentals", labCount: 6, version: "1.2.0", tier: .baseline)
                if appState.allows(.multiLabPack) {
                    LabPackRow(name: "Compute pipeline suite", labCount: 12, version: "2.0.1", tier: .professional)
                    LabPackRow(name: "Ray tracing essentials", labCount: 8, version: "1.0.3", tier: .professional)
                }
                if appState.allows(.signedLabPacks) {
                    LabPackRow(name: "ML inference labs (signed)", labCount: 18, version: "3.1.0", tier: .labPack)
                }
            }
        }
        .navigationTitle("Lab packs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export .metalab") { }
                    .buttonStyle(.borderedProminent)
                    .tint(appState.tier.accentColor)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !appState.allows(.multiLabPack) {
                UpgradeNudge(message: "Upgrade for multi-lab packs", requiredTier: .professional)
            }
        }
    }
}

struct LabPackRow: View {
    let name: String
    let labCount: Int
    let version: String
    let tier: Tier

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.weight(.medium))
                Text("\(labCount) labs · v\(version)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            TierBadgeSmall(tier: tier)
        }
    }
}

// MARK: - Signed Packs

struct SignedPacksView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeatureGated(feature: .signedLabPacks) {
            List {
                Section("Signing & distribution") {
                    NavigationLink("Code signing identity") {
                        PlaceholderDetailView(title: "Code signing identity", systemImage: "lock.shield")
                    }
                    NavigationLink("CI pipeline hooks") {
                        PlaceholderDetailView(title: "CI pipeline hooks", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink("Remote VS Code bridge") {
                        PlaceholderDetailView(title: "VS Code bridge", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    NavigationLink("JetBrains bridge") {
                        PlaceholderDetailView(title: "JetBrains bridge", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
        }
        .navigationTitle("Signed packs · CI")
    }
}

// MARK: - Helpers

struct TierBadgeSmall: View {
    let tier: Tier
    var body: some View {
        Text(tier.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(tier.badgeForeground)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tier.badgeBackground, in: RoundedRectangle(cornerRadius: 4))
    }
}

struct PlaceholderDetailView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage,
            description: Text("Configure \(title) settings here."))
        .navigationTitle(title)
    }
}
