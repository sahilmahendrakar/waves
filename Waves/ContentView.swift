import SwiftUI

private enum AppMode: String, CaseIterable {
    case wave = "Wave"
    case freePlay = "Free Play"
}

struct ContentView: View {
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var waveSession = WaveSession()
    #if os(macOS)
    @StateObject private var appMonitor = ActiveAppMonitor()
    #endif
    @State private var lyriaService: LyriaService?

    @State private var mode: AppMode = .wave
    @State private var prompt = "minimal techno with deep bass"
    @State private var bpm: Double = 120
    @State private var isStreaming = false
    @State private var connectionState: LyriaConnectionState = .disconnected

    private static let calmPrompt = "ambient ethereal spacey synth pads chill"
    private static let intensePrompt = "energetic driving fast-paced intense electronic"

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            controlsView
                .padding(24)
        }
        .frame(minWidth: 480, minHeight: 480)
        .onAppear {
            let service = LyriaService(audioPlayer: audioPlayer)
            lyriaService = service
            setupWaveCallbacks(service: service)
        }
        .onChange(of: lyriaService?.connectionState) { _, newValue in
            if let newValue {
                connectionState = newValue
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: isStreaming)

            Text("Waves")
                .font(.title.bold())
            Text("Lyria RealTime Music")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            #if os(macOS)
            HStack(spacing: 6) {
                if let icon = appMonitor.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                Text(appMonitor.appName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if let url = appMonitor.activeURL,
                   let host = URL(string: url)?.host {
                    Text("\u{2014}")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    Text(host)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 4)
            #endif
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 20) {
            apiKeyField

            Picker("Mode", selection: $mode) {
                ForEach(AppMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .wave:
                waveControls
            case .freePlay:
                freePlayControls
            }

            statusBadge
        }
    }

    // MARK: - Wave mode

    private var waveControls: some View {
        WaveView(
            session: waveSession,
            apiKeyIsEmpty: apiKey.isEmpty,
            isConnecting: connectionState == .connecting,
            onStart: { Task { await startWave() } },
            onPause: { Task { await pauseWave() } },
            onResume: { Task { await resumeWave() } },
            onCancel: { Task { await cancelWave() } }
        )
    }

    // MARK: - Free Play mode

    private var freePlayControls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .font(.headline)
                TextField("Describe the music...", text: $prompt)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BPM")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(bpm))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $bpm, in: 60...200, step: 1)
            }

            transportControls
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("API Key")
                .font(.headline)
            SecureField("Gemini API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transportControls: some View {
        HStack(spacing: 16) {
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
                .disabled(apiKey.isEmpty || prompt.isEmpty || connectionState == .connecting)
            }
        }
    }

    // MARK: - Status helpers

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
        case .connecting: "Connecting..."
        case .connected: isStreaming ? "Streaming" : "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }

    // MARK: - Wave actions

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
    }

    private func pauseWave() async {
        guard let service = lyriaService else { return }
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
    }

    private func cancelWave() async {
        waveSession.cancel()
        await stopWaveMusic()
    }

    private func stopWaveMusic() async {
        guard let service = lyriaService else { return }
        await service.stop()
        audioPlayer.stop()
        isStreaming = false
        service.disconnect()
        connectionState = .disconnected
    }

    // MARK: - Free Play actions

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
