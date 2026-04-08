import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @StateObject private var vm = KernelViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    KernelConfigSection(vm: vm)
                    DataSourceSection(vm: vm)
                    RunSection(vm: vm)

                    if let result = vm.result {
                        ResultSection(result: result, vm: vm)
                    }

                    LogSection(entries: vm.log)
                }
                .padding()
            }
            .navigationTitle("Metal Kernel Factory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .foregroundStyle(.green)
                        Text("Metal Kernel Factory")
                            .font(.headline)
                    }
                }
            }
        }
    }
}

// MARK: - Section: Kernel Config

struct KernelConfigSection: View {
    @ObservedObject var vm: KernelViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Compute Kernel", systemImage: "function")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Kernel", selection: $vm.selectedConfigID) {
                    ForEach(vm.configs) { config in
                        Text(config.displayName).tag(config.id)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(kernelDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var kernelDescription: String {
        switch vm.selectedConfigID {
        case "add":      return "result[i] = inA[i] + inB[i]"
        case "multiply": return "result[i] = inA[i] × inB[i]"
        default:         return ""
        }
    }
}

// MARK: - Section: Data Source

struct DataSourceSection: View {
    @ObservedObject var vm: KernelViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label("Data Source", systemImage: "memorychip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Toggle("Random data", isOn: $vm.useRandomData)

                if vm.useRandomData {
                    HStack {
                        Text("Array length")
                            .font(.subheadline)
                        Spacer()
                        Stepper("\(vm.arrayLength)",
                                value: $vm.arrayLength,
                                in: 4...1024,
                                step: 4)
                        .fixedSize()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual arrays (comma-separated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LabeledTextField(label: "inA", text: $vm.manualA)
                        LabeledTextField(label: "inB", text: $vm.manualB)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
            TextField("values…", text: $text)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }
}

// MARK: - Section: Run

struct RunSection: View {
    @ObservedObject var vm: KernelViewModel

    var body: some View {
        Button {
            vm.run()
        } label: {
            HStack(spacing: 8) {
                if vm.isRunning {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(vm.isRunning ? "Running…" : "Send Compute Command")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(vm.isRunning)
    }
}

// MARK: - Section: Result

struct ResultSection: View {
    let result: KernelResult
    @ObservedObject var vm: KernelViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                // Status badge
                HStack {
                    Label("Result", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    StatusBadge(passed: result.passed)
                }

                // Stats
                HStack(spacing: 12) {
                    StatCard(title: "Elements", value: "\(result.output.count)")
                    StatCard(title: "inA[0]",   value: String(format: "%.4f", result.inputA.first ?? 0))
                    StatCard(title: "inB[0]",   value: String(format: "%.4f", result.inputB.first ?? 0))
                    StatCard(title: "out[0]",   value: String(format: "%.4f", result.output.first ?? 0))
                }

                // Failure message
                if let msg = result.verificationMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                // Scrollable buffer preview
                BufferPreview(label: "inA",    values: result.inputA)
                BufferPreview(label: "inB",    values: result.inputB)
                BufferPreview(label: "result", values: result.output, highlight: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatusBadge: View {
    let passed: Bool
    var body: some View {
        Label(passed ? "Passed" : "Failed",
              systemImage: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(passed ? .green : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((passed ? Color.green : Color.red).opacity(0.12),
                        in: Capsule())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BufferPreview: View {
    let label: String
    let values: [Float]
    var highlight: Bool = false

    private let previewCount = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(values.prefix(previewCount).enumerated()), id: \.offset) { idx, v in
                        VStack(spacing: 2) {
                            Text("[\(idx)]")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.2f", v))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(highlight ? Color.green : .primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(
                            highlight
                                ? Color.green.opacity(0.08)
                                : Color(.systemGray6),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(highlight ? Color.green.opacity(0.3) : .clear,
                                              lineWidth: 0.5)
                        )
                    }
                    if values.count > previewCount {
                        Text("+\(values.count - previewCount) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .padding(2)
            }
        }
    }
}

// MARK: - Section: Log

struct LogSection: View {
    let entries: [KernelViewModel.LogEntry]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                Label("Execution Log", systemImage: "terminal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                if entries.isEmpty {
                    Text("No output yet.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timeString)
                                    .foregroundStyle(.tertiary)
                                Text(entry.message)
                                    .foregroundStyle(logColor(entry.message))
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func logColor(_ message: String) -> Color {
        if message.contains("✓") || message.contains("Execution finished") { return .green }
        if message.contains("✗") || message.contains("FAILED")            { return .red   }
        if message.contains("sendComputeCommand") || message.contains("GPU") { return .orange }
        return .primary
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
