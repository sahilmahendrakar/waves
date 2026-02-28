import SwiftUI
import UserNotifications

@main
struct WavesApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
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
