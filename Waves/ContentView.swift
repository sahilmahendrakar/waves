import SwiftUI
import UserNotifications

enum AppMode: String, CaseIterable {
    case wave = "Wave"
    case freePlay = "Free Play"
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("geminiAPIKey") private var apiKey = ""
    #if os(macOS)
    @StateObject private var appMonitor = ActiveAppMonitor()
    @StateObject private var focusGuard = FocusGuard()
    @StateObject private var appMusicRouter = AppMusicRouter()
    #endif
    @State private var showingSettings = false

    @AppStorage("appMode") private var mode: AppMode = .wave

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
            appState.focusGuard = focusGuard
            focusGuard.attach(to: appMonitor)
            focusGuard.onViolationTriggered = {
                Task { await appState.suspendWave() }
            }
            focusGuard.onRefocused = {
                Task { await appState.resumeSuspendedWave() }
            }
            appMusicRouter.attach(to: appMonitor)
            appMusicRouter.onPromptChanged = { prompt in
                Task { await appState.applyRoutedPrompt(prompt) }
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
                sendRefocusNotification()
            } else if !violating {
                appState.audioPlayer.cancelFade()
            }
        }
        #endif
        .sheet(isPresented: $showingSettings) {
            #if os(macOS)
            SettingsView(apiKey: $apiKey, focusGuard: focusGuard)
                .environmentObject(appState)
            #else
            SettingsView(apiKey: $apiKey)
                .environmentObject(appState)
            #endif
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            if apiKey.isEmpty {
                apiKeyMissingView
            } else {
                switch mode {
                case .wave:
                    waveControls
                case .freePlay:
                    freePlayControls
                }
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
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

    private var freePlayControls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Prompt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    #if os(macOS)
                    if let rule = appMusicRouter.activeRule, appMusicRouter.isEnabled {
                        Text(rule.label)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    #endif
                }
                TextField("Describe the music...", text: $appState.prompt)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(appState.bpm))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $appState.bpm, in: 60...200, step: 1)
            }

            transportControls

            #if os(macOS)
            appRulesSection
            #endif
        }
    }

    #if os(macOS)
    @State private var showingAdvanced = false

    private var appRulesSection: some View {
        DisclosureGroup("Advanced", isExpanded: $showingAdvanced) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Auto-adapt music to active app", isOn: $appMusicRouter.autoRoutingEnabled)
                    .font(.subheadline)

                if appMusicRouter.autoRoutingEnabled {
                    ForEach($appMusicRouter.rules) { $rule in
                        AppMusicRuleRow(rule: $rule, onDelete: {
                            appMusicRouter.rules.removeAll { $0.id == rule.id }
                        })
                    }

                    HStack {
                        Button {
                            let newRule = AppMusicRule(
                                id: UUID(),
                                label: "New Rule",
                                appNames: [],
                                domains: [],
                                prompt: ""
                            )
                            appMusicRouter.rules.append(newRule)
                        } label: {
                            Label("Add Rule", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Button("Reset to Defaults") {
                            appMusicRouter.resetToDefaults()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    #endif

    private var transportControls: some View {
        HStack(spacing: 12) {
            if appState.isStreaming {
                Button {
                    Task {
                        await appState.pauseMusic()
                        #if os(macOS)
                        appMusicRouter.isEnabled = false
                        #endif
                    }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await appState.stopMusic()
                        #if os(macOS)
                        appMusicRouter.isEnabled = false
                        #endif
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    Task {
                        await appState.startMusic()
                        #if os(macOS)
                        if appMusicRouter.autoRoutingEnabled {
                            appMusicRouter.originalPrompt = appState.prompt
                            appMusicRouter.isEnabled = true
                        }
                        #endif
                    }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(appState.prompt.isEmpty || appState.connectionState == .connecting)
            }
        }
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
        case .connecting: "Connecting\u{2026}"
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

    #if os(macOS)
    private func sendRefocusNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Waves"
        content.body = "Take a deep breath, listen in, and refocus."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "refocus-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
    #endif
}

#if os(macOS)
struct AppMusicRuleRow: View {
    @Binding var rule: AppMusicRule
    var onDelete: () -> Void

    @State private var isExpanded = false
    @State private var newApp = ""
    @State private var newDomain = ""

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Label")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextField("Rule name", text: $rule.label)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextField("Music prompt...", text: $rule.prompt)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(rule.appNames, id: \.self) { app in
                            chipView(app) {
                                rule.appNames.removeAll { $0 == app }
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        TextField("App name...", text: $newApp)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit { addApp() }
                        Button("Add") { addApp() }
                            .font(.caption)
                            .disabled(newApp.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Websites")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(rule.domains, id: \.self) { domain in
                            chipView(domain) {
                                rule.domains.removeAll { $0 == domain }
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        TextField("domain.com...", text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit { addDomain() }
                        Button("Add") { addDomain() }
                            .font(.caption)
                            .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Rule", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 8) {
                Text(rule.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(rule.prompt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private func chipView(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption2)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }

    private func addApp() {
        let name = newApp.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !rule.appNames.contains(name) else { return }
        rule.appNames.append(name)
        newApp = ""
    }

    private func addDomain() {
        var domain = newDomain
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        if domain.hasPrefix("www.") { domain = String(domain.dropFirst(4)) }
        if domain.hasSuffix("/") { domain = String(domain.dropLast()) }
        guard !domain.isEmpty, !rule.domains.contains(domain) else { return }
        rule.domains.append(domain)
        newDomain = ""
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(AppState())
}
