// Views/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
        } detail: {
            DetailRouter()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// ─── Sidebar ──────────────────────────────────────────────────────
struct SidebarView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            // App header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    NeuralPulseIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ANE Lab")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Neural Engine Explorer")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#A78BFA").opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            // Model selector
            ModelPickerSection()

            Divider().background(Color.white.opacity(0.08)).padding(.vertical, 8)

            // Nav items
            VStack(spacing: 2) {
                ForEach(AppStore.Tab.allCases, id: \.self) { tab in
                    SidebarNavItem(tab: tab, isSelected: store.selectedTab == tab) {
                        store.selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Thermal badge
            ThermalBadge()
                .padding(16)
        }
        .frame(minWidth: 220)
        .background(Color(hex: "#080C14"))
    }
}

struct SidebarNavItem: View {
    let tab: AppStore.Tab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? Color(hex: "#A78BFA") : Color.white.opacity(0.5))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.5))
                Spacer()
                if isSelected {
                    Circle()
                        .fill(Color(hex: "#A78BFA"))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "#A78BFA").opacity(0.15) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: "#A78BFA").opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct NeuralPulseIcon: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#A78BFA").opacity(0.2))
                .frame(width: 36, height: 36)
                .scaleEffect(pulsing ? 1.2 : 1.0)
                .opacity(pulsing ? 0 : 1)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(Color(hex: "#A78BFA").opacity(0.3))
                .frame(width: 36, height: 36)
            Image(systemName: "brain")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#A78BFA"))
        }
        .onAppear { pulsing = true }
    }
}

// ─── Detail Router ────────────────────────────────────────────────
struct DetailRouter: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            switch store.selectedTab {
            case .runner:    RunnerTab()
            case .benchmark: BenchmarkTab()
            case .inspector: InspectorTab()
            case .monitor:   MonitorTab()
            case .device:    DeviceTab()
            }
        }
        .background(Color(hex: "#0A0F1A"))
        .navigationBarHidden(true)
    }
}
