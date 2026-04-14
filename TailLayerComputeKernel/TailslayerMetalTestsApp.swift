// TailslayerMetalTestsApp.swift
// Root entry point for the Tailslayer Metal/SwiftUI test harness.

import SwiftUI

@main
struct TailslayerMetalTestsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Content View (Tab Navigator)
// ─────────────────────────────────────────────────────────────────────────────

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                LatencyChartView()
                    .navigationTitle("Latency Distribution")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbarBackground(Color(white: 0.09), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Histogram", systemImage: "chart.bar.fill")
            }
            .tag(0)

            NavigationView {
                ChannelVizView()
                    .navigationTitle("DRAM Channel Refresh")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbarBackground(Color(white: 0.09), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Channels", systemImage: "memorychip")
            }
            .tag(1)

            NavigationView {
                GaugeView()
                    .navigationTitle("P99 Gauge")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbarBackground(Color(white: 0.09), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Gauge", systemImage: "gauge.with.needle")
            }
            .tag(2)

            NavigationView {
                ScramblingHeatmapView()
                    .navigationTitle("Channel Scrambling")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbarBackground(Color(white: 0.09), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Scramble Map", systemImage: "grid.circle.fill")
            }
            .tag(3)
        }
        .accentColor(Color(red: 0.2, green: 0.8, blue: 0.55))
        .preferredColorScheme(.dark)
    }
}
