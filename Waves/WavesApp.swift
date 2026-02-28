//
//  WavesApp.swift
//  Waves
//
//  Created by Sahil Mahendrakar on 2/28/26.
//

import SwiftUI

@main
struct WavesApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }

        #if os(macOS)
        MenuBarExtra("Waves", systemImage: "waveform.circle.fill") {
            MenuBarSteeringView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
