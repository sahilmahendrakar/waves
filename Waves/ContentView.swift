import SwiftUI
import UserNotifications

enum AppMode: String, CaseIterable {
    case wave = "Wave"
    case vibe = "Vibe"
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @StateObject private var appMonitor = ActiveAppMonitor()
    @StateObject private var focusGuard = FocusGuard()
    @StateObject private var appMusicRouter = AppMusicRouter()
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
        }
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(apiKey: $apiKey, focusGuard: focusGuard)
                .environmentObject(appState)
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
                case .vibe:
                    vibeControls
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
            isViolating: focusGuard.isViolating,
            violationSeconds: focusGuard.violationSeconds,
            isSuspended: focusGuard.isSuspended,
            onStart: { Task { await startWave() } },
            onPause: { Task { await pauseWave() } },
            onResume: { Task { await resumeWave() } },
            onCancel: { Task { await cancelWave() } }
        )
    }

    private var vibeControls: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Vibe")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text("Play. Create. Flow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("What do you want to listen to?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let rule = appMusicRouter.activeRule, appMusicRouter.isEnabled {
                        Text(rule.label)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    TextField("Describe the music...", text: $appState.prompt)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 4) {
                        Stepper(value: $appState.bpm, in: 60...200, step: 1) {
                            TextField("", value: $appState.bpm, format: .number.precision(.fractionLength(0)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 48)
                                .multilineTextAlignment(.center)
                                .monospacedDigit()
                        }
                        Text("BPM")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            autoAdaptSection

            transportControls
        }
    }

    @State private var showingRules = false

    private var autoAdaptSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Toggle("Auto-adapt music to what you're doing", isOn: $appMusicRouter.autoRoutingEnabled)
                    .font(.subheadline)

                if appMusicRouter.autoRoutingEnabled, let rule = appMusicRouter.activeRule, appMusicRouter.isEnabled {
                    Text(rule.label)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)

            if appMusicRouter.autoRoutingEnabled {
                Divider()
                    .padding(.horizontal, 14)

                DisclosureGroup("Rules", isExpanded: $showingRules) {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(.top, 8)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var transportControls: some View {
        HStack(spacing: 12) {
            if appState.isStreaming {
                Button {
                    Task {
                        await appState.pauseMusic()
                        appMusicRouter.isEnabled = false
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
                        appMusicRouter.isEnabled = false
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
                        if appMusicRouter.autoRoutingEnabled {
                            appMusicRouter.originalPrompt = appState.prompt
                            appMusicRouter.isEnabled = true
                        }
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
        focusGuard.isEnabled = true
    }

    private func pauseWave() async {
        focusGuard.isEnabled = false
        await appState.pauseWave()
    }

    private func resumeWave() async {
        await appState.resumeWave()
        focusGuard.isEnabled = true
    }

    private func cancelWave() async {
        focusGuard.isEnabled = false
        await appState.cancelWave()
    }

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
}

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

#Preview {
    ContentView()
        .environmentObject(AppState())
}
