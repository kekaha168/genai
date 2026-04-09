//
//  ANEEngine02App.swift
//  ANEEngine02
//
//  Created by Dennis Sheu on 4/6/26.
//

import SwiftUI

@main
struct ANEEngine02App: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
