//
//  MetalLabLLMApp.swift
//  MetalLabLLM
//
//  Created by Dennis Sheu on 4/14/26.
//

import SwiftUI

@main
struct MetalLabLLMApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
#if os(macOS)
        .defaultSize(width: 1100, height: 720)
        .commands {
            MetalLabCommands()
        }
#endif
    }
}
