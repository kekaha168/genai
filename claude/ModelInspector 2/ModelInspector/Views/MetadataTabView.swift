import SwiftUI

struct MetadataTabView: View {
    let model: InspectedModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Author / version
                InfoSection(title: "Authorship") {
                    InfoRow(label: "Author", value: model.metadata.author)
                    InfoRow(label: "Version", value: model.metadata.versionString)
                    InfoRow(label: "License", value: model.metadata.license)
                }

                // Description
                if model.metadata.shortDescription != "—" {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("DESCRIPTION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 6)

                        Text(model.metadata.shortDescription)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5))
                    }
                }

                // Model capabilities
                InfoSection(title: "Capabilities") {
                    InfoRow(label: "Updatable", value: model.metadata.isUpdatable ? "Yes" : "No")
                    InfoRow(label: "Compute Units", value: model.metadata.computeUnitsLabel)
                    InfoRow(label: "Format", value: model.fileFormat.displayName)
                    InfoRow(label: "Spec Version", value: "\(model.specVersion)")
                }

                // User-defined metadata
                if !model.metadata.userDefined.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("USER-DEFINED KEYS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 6)

                        VStack(spacing: 0) {
                            ForEach(model.metadata.userDefined.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(key)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.blue)
                                        .frame(width: 130, alignment: .leading)

                                    Text(value)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                Divider().padding(.leading, 14)
                            }
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5))
                    }
                }

                // API access guide
                APIAccessCard()
            }
            .padding(16)
        }
    }
}

// MARK: - API Access guide card

//struct APIAccessCard: View {
//    @State private var selectedSnippet = 0
//
//    let snippets: [(String, String)] = [
//        ("Metadata", """
//let desc = model.modelDescription
//let author = desc.metadata[.author]
//let version = desc.metadata[.versionString]
//let isUpdatable = desc.isUpdatable
//"""),
//        ("Structure", """
//// iOS 17+
//let structure = try await
//  MLModelStructure.load(contentsOf: url)
//if case .program(let prog) = structure {
//  for op in prog.functions["main"]!
//                 .block.operations {
//    print(op.operatorName)
//  }
//}
//"""),
//        ("Compute Plan", """
//// iOS 17+
//let plan = try await MLComputePlan(
//  contentsOf: compiledURL,
//  configuration: config)
//for layer in nn.layers {
//  let usage = plan
//    .computeDeviceUsage(for: layer)
//  // .cpu / .gpu / .neuralEngine
//}
//"""),
//    ]
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            Text("API ACCESS")
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundStyle(.secondary)
//                .padding(.horizontal, 4)
//                .padding(.bottom, 6)
//
//            VStack(spacing: 0) {
//                // Snippet tabs
//                HStack(spacing: 0) {
//                    ForEach(snippets.indices, id: \.self) { i in
//                        Button {
//                            withAnimation(.spring(duration: 0.2)) { selectedSnippet = i }
//                        } label: {
//                            Text(snippets[i].0)
//                                .font(.system(size: 12, weight: .medium))
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 8)
//                                .frame(maxWidth: .infinity)
//                                .background(selectedSnippet == i ? Color(.systemBackground) : .clear)
//                        }
//                        .buttonStyle(.plain)
//                        .foregroundStyle(selectedSnippet == i ? .primary : .secondary)
//                    }
//                }
//                .background(Color(.systemGray6))
//                .clipShape(RoundedRectangle(cornerRadius: 8))
//                .padding(10)
//
//                ScrollView(.horizontal, showsIndicators: false) {
//                    Text(snippets[selectedSnippet].1)
//                        .font(.system(size: 12, design: .monospaced))
//                        .foregroundStyle(.primary)
//                        .padding(14)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                }
//            }
//            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
//            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 0.5))
//        }
//    }
//}

struct APIAccessCard: View {
    @State private var selectedSnippet = 0
    
    let snippets: [(String, String)] = [
        ("Metadata", "let desc = model.modelDescription\nlet author = desc.metadata[.author]\nlet version = desc.metadata[.versionString]\nlet isUpdatable = desc.isUpdatable"),
        ("Structure", "// iOS 17+\nlet structure = try await\n  MLModelStructure.load(contentsOf: url)\nif case .program(let prog) = structure {\n  for op in prog.functions[\"main\"]!\n                 .block.operations {\n    print(op.operatorName)\n  }\n}"),
        ("Compute Plan", "// iOS 17+\nlet plan = try await MLComputePlan(\n  contentsOf: compiledURL,\n  configuration: config)\nfor layer in nn.layers {\n  let usage = plan\n    .computeDeviceUsage(forLayer: layer)\n  // .cpu / .gpu / .neuralEngine\n}")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerLabel
            
            VStack(spacing: 0) {
                snippetPicker
                codeDisplay
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerLabel: some View {
        Text("API ACCESS")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
    }
    
    private var snippetPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<snippets.count, id: \.self) { i in
                Button {
                    withAnimation(.spring(duration: 0.2)) { selectedSnippet = i }
                } label: {
                    Text(snippets[i].0)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    // Use standard SwiftUI semantic backgrounds
                        .background(selectedSnippet == i ? Color.secondary.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedSnippet == i ? .primary : .secondary)
            }
        }
        .padding(6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .padding(10)
    }
    
    private var codeDisplay: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(snippets[selectedSnippet].1)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
