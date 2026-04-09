//
//  ContentView.swift
//  CoreMLSample
//
//  Created by Dennis Sheu on 4/8/26.
//

import SwiftUI
import CoreML

struct ContentView: View {
    var body: some View {
        TabView {
            FastViTView()
                .tabItem {
                    Label("Classify", systemImage: "photo.on.rectangle")
                }
            BERTView()
                .tabItem {
                    Label("Q&A", systemImage: "text.bubble")
                }
        }
    }
}

#Preview {
    ContentView()
}
