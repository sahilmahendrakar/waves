//
//  WavesApp.swift
//  Waves
//
//  Created by Sahil Mahendrakar on 2/28/26.
//

import SwiftUI
import UserNotifications

@main
struct WavesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
        }
    }
}
