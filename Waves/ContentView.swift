import SwiftUI

struct ContentView: View {
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @StateObject private var audioPlayer = AudioPlayer()
    #if os(macOS)
    @StateObject private var appMonitor = ActiveAppMonitor()
    #endif
    @State private var lyriaService: LyriaService?

    @State private var prompt = "minimal techno with deep bass"
    @State private var bpm: Double = 120
    @State private var isStreaming = false
    @State private var connectionState: LyriaConnectionState = .disconnected

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            controlsView
                .padding(24)
        }
        .frame(minWidth: 480, minHeight: 420)
        .onAppear {
            let service = LyriaService(audioPlayer: audioPlayer)
            lyriaService = service
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

            statusBadge

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

    // MARK: - Actions

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
