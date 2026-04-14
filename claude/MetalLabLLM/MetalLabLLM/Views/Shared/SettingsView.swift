import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Tier & role") {
                Picker("Tier", selection: $appState.tier) {
                    ForEach(Tier.allCases) { t in
                        HStack {
                            Circle().fill(t.accentColor).frame(width: 8, height: 8)
                            Text(t.rawValue)
                        }.tag(t)
                    }
                }
                Picker("Role", selection: $appState.role) {
                    ForEach(UserRole.allCases, id: \.self) { r in
                        Label(r.rawValue, systemImage: r.systemImage).tag(r)
                    }
                }
            }

            Section("Performance HUD") {
                Toggle("Show HUD overlay", isOn: $appState.hudEnabled)
                Toggle("Co-step mode", isOn: $appState.coStepEnabled)
                    .disabled(!appState.allows(.coStepMode))
            }

            Section("Device") {
                LabeledContent("Connected devices") {
                    Text("\(appState.connectedDeviceCount)")
                }
                LabeledContent("Metal version") {
                    Text(appState.allows(.inlineTensorInference) ? "Metal 4 (Lab Pack)" : "Metal 4")
                }
                LabeledContent("Platform") {
                    Text(platformString)
                }
            }

            Section("About") {
                LabeledContent("App version", value: "1.0.0")
                LabeledContent("Build", value: "100")
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
    }

    var platformString: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #else
        return "Unknown"
        #endif
    }
}
