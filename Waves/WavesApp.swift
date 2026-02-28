import SwiftUI
import UserNotifications

@main
struct WavesApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appState)
                    .onAppear {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                    }
            } else {
                OnboardingView()
                    .environmentObject(appState)
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
