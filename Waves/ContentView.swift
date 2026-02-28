import SwiftUI

enum AppMode: String, CaseIterable {
    case wave = "Wave"
    case freePlay = "Free Play"
}

struct ContentView: View {
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var waveSession = WaveSession()
    #if os(macOS)
    @StateObject private var appMonitor = ActiveAppMonitor()
    @StateObject private var focusGuard = FocusGuard()
    #endif
    @State private var lyriaService: LyriaService?
    @State private var showingSettings = false

    @AppStorage("appMode") private var mode: AppMode = .wave
    @State private var prompt = "minimal techno with deep bass"
    @State private var bpm: Double = 120
    @State private var isStreaming = false
    @State private var connectionState: LyriaConnectionState = .disconnected

    private static let calmPrompt = "ambient ethereal spacey synth pads chill"
    private static let intensePrompt = "energetic driving fast-paced intense electronic"

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
            let service = LyriaService(audioPlayer: audioPlayer)
            lyriaService = service
            setupWaveCallbacks(service: service)
            #if os(macOS)
            focusGuard.attach(to: appMonitor)
            focusGuard.onViolationTriggered = {
                Task { await suspendWave() }
            }
            focusGuard.onRefocused = {
                Task { await resumeSuspendedWave() }
            }
            #endif
        }
        .onChange(of: lyriaService?.connectionState) { _, newValue in
            if let newValue {
                connectionState = newValue
            }
        }
        #if os(macOS)
        .onChange(of: focusGuard.isViolating) { _, violating in
            if violating && waveSession.state == .running {
                audioPlayer.fadeOut(over: 10)
            } else if !violating {
                audioPlayer.cancelFade()
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

    // MARK: - Main Content

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

    // MARK: - API Key Missing

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

    // MARK: - Wave Mode

    private var waveControls: some View {
        WaveView(
            session: waveSession,
            isConnecting: connectionState == .connecting,
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

    // MARK: - Free Play Mode

    private var freePlayControls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Describe the music...", text: $prompt)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(bpm))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $bpm, in: 60...200, step: 1)
            }

            transportControls
        }
    }

    private var transportControls: some View {
        HStack(spacing: 12) {
            if isStreaming {
                Button {
                    Task { await pauseMusic() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)

                Button {
                    Task { await stopMusic() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    Task { await startMusic() }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(prompt.isEmpty || connectionState == .connecting)
            }
        }
    }

    // MARK: - Footer Bar

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

    // MARK: - Status Helpers

    private var statusColor: Color {
        switch connectionState {
        case .disconnected: .gray
        case .connecting: .orange
        case .connected: .green
        case .error: .red
        }
    }

    private var statusText: String {
        switch connectionState {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting\u{2026}"
        case .connected: isStreaming ? "Streaming" : "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }

    // MARK: - Wave Actions

    private func setupWaveCallbacks(service: LyriaService) {
        waveSession.onParametersChanged = { params, bpmChanged in
            Task {
                await service.setPrompts([
                    (text: Self.calmPrompt, weight: params.calmWeight),
                    (text: Self.intensePrompt, weight: params.intenseWeight),
                ])
                await service.setMusicConfig(
                    bpm: bpmChanged ? params.bpm : nil,
                    density: params.density,
                    brightness: params.brightness
                )
                if bpmChanged {
                    await service.resetContext()
                }
            }
        }

        waveSession.onWaveCompleted = {
            Task { await stopWaveMusic() }
        }
    }

    private func startWave() async {
        guard let service = lyriaService else { return }

        if connectionState != .connected {
            await service.connect(apiKey: apiKey)
            connectionState = service.connectionState
            guard connectionState == .connected else { return }
        }

        let initial = waveSession.currentParameters
        await service.setPrompts([
            (text: Self.calmPrompt, weight: initial.calmWeight),
            (text: Self.intensePrompt, weight: initial.intenseWeight),
        ])
        await service.setMusicConfig(
            bpm: initial.bpm,
            density: initial.density,
            brightness: initial.brightness
        )
        audioPlayer.start()
        await service.play()
        isStreaming = true
        waveSession.start()
        #if os(macOS)
        focusGuard.isEnabled = true
        #endif
    }

    private func pauseWave() async {
        guard let service = lyriaService else { return }
        #if os(macOS)
        focusGuard.isEnabled = false
        #endif
        waveSession.pause()
        await service.pause()
        audioPlayer.pause()
        isStreaming = false
    }

    private func resumeWave() async {
        guard let service = lyriaService else { return }
        audioPlayer.resume()
        await service.play()
        isStreaming = true
        waveSession.resume()
        #if os(macOS)
        focusGuard.isEnabled = true
        #endif
    }

    private func cancelWave() async {
        #if os(macOS)
        focusGuard.isEnabled = false
        #endif
        waveSession.cancel()
        await stopWaveMusic()
    }

    private func suspendWave() async {
        guard let service = lyriaService else { return }
        waveSession.pause()
        await service.pause()
        audioPlayer.pause()
        isStreaming = false
    }

    private func resumeSuspendedWave() async {
        guard let service = lyriaService else { return }
        audioPlayer.cancelFade()
        waveSession.restart()
        let initial = waveSession.currentParameters
        await service.setPrompts([
            (text: Self.calmPrompt, weight: initial.calmWeight),
            (text: Self.intensePrompt, weight: initial.intenseWeight),
        ])
        await service.setMusicConfig(
            bpm: initial.bpm,
            density: initial.density,
            brightness: initial.brightness
        )
        await service.resetContext()
        audioPlayer.resume()
        await service.play()
        isStreaming = true
    }

    private func stopWaveMusic() async {
        guard let service = lyriaService else { return }
        #if os(macOS)
        focusGuard.isEnabled = false
        #endif
        await service.stop()
        audioPlayer.stop()
        isStreaming = false
        service.disconnect()
        connectionState = .disconnected
    }

    // MARK: - Free Play Actions

    private func startMusic() async {
        guard let service = lyriaService else { return }

        if connectionState != .connected {
            await service.connect(apiKey: apiKey)
            connectionState = service.connectionState
            guard connectionState == .connected else { return }
        }

        await service.setPrompts([(text: prompt, weight: 1.0)])
        await service.setMusicConfig(bpm: Int(bpm))
        audioPlayer.start()
        await service.play()
        isStreaming = true
    }

    private func pauseMusic() async {
        guard let service = lyriaService else { return }
        await service.pause()
        audioPlayer.pause()
        isStreaming = false
    }

    private func stopMusic() async {
        guard let service = lyriaService else { return }
        await service.stop()
        audioPlayer.stop()
        isStreaming = false
        service.disconnect()
        connectionState = .disconnected
    }
}

#Preview {
    ContentView()
}
