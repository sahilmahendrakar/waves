import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("geminiAPIKey") private var apiKey = ""
    #if os(macOS)
    @StateObject private var appMonitor = ActiveAppMonitor()
    @StateObject private var focusGuard = FocusGuard()
    #endif
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                footerBar
            }
        }
        .frame(minWidth: 480, minHeight: 540)
        .onAppear {
            #if os(macOS)
            focusGuard.attach(to: appMonitor)
            focusGuard.onViolationTriggered = {
                Task { await appState.suspendWave() }
            }
            focusGuard.onRefocused = {
                Task { await appState.resumeSuspendedWave() }
            }
            #endif
        }
        #if os(macOS)
        .onChange(of: appState.waveSession.state) { _, newState in
            if newState == .completed {
                focusGuard.isEnabled = false
            }
        }
        .onChange(of: focusGuard.isViolating) { _, violating in
            if violating && appState.waveSession.state == .running {
                appState.audioPlayer.fadeOut(over: 10)
            } else if !violating {
                appState.audioPlayer.cancelFade()
            }
        }
        #endif
        .sheet(isPresented: $showingSettings) {
            #if os(macOS)
            SettingsView(apiKey: $apiKey, focusGuard: focusGuard)
            #else
            SettingsView(apiKey: $apiKey)
            #endif
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            headerView

            if apiKey.isEmpty {
                apiKeyMissingView
            } else {
                waveControls
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: appState.isStreaming)
        }
    }

    private var apiKeyMissingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("API Key Required")
                .font(.headline)

            Text("Add your Gemini API key in Settings to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingSettings = true
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 4)
        }
    }

    private var waveControls: some View {
        WaveView(
            session: appState.waveSession,
            isConnecting: appState.connectionState == .connecting,
            isViolating: isFocusViolating,
            violationSeconds: focusViolationSeconds,
            isSuspended: isFocusSuspended,
            onStart: { Task { await startWave() } },
            onPause: { Task { await pauseWave() } },
            onResume: { Task { await resumeWave() } },
            onCancel: { Task { await cancelWave() } }
        )
    }

    private var isFocusViolating: Bool {
        #if os(macOS)
        focusGuard.isViolating
        #else
        false
        #endif
    }

    private var focusViolationSeconds: Int {
        #if os(macOS)
        focusGuard.violationSeconds
        #else
        0
        #endif
    }

    private var isFocusSuspended: Bool {
        #if os(macOS)
        focusGuard.isSuspended
        #else
        false
        #endif
    }

    private var footerBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            #if os(macOS)
            if !appMonitor.appName.isEmpty {
                HStack(spacing: 4) {
                    if let icon = appMonitor.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    Text(appMonitor.appName)
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var statusColor: Color {
        switch appState.connectionState {
        case .disconnected: .gray
        case .connecting: .orange
        case .connected: .green
        case .error: .red
        }
    }

    private var statusText: String {
        switch appState.connectionState {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .connected: appState.isStreaming ? "Streaming" : "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }

    private func startWave() async {
        await appState.startWave()
        #if os(macOS)
        focusGuard.isEnabled = true
        #endif
    }

    private func pauseWave() async {
        #if os(macOS)
        focusGuard.isEnabled = false
        #endif
        await appState.pauseWave()
    }

    private func resumeWave() async {
        await appState.resumeWave()
        #if os(macOS)
        focusGuard.isEnabled = true
        #endif
    }

    private func cancelWave() async {
        #if os(macOS)
        focusGuard.isEnabled = false
        #endif
        await appState.cancelWave()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
