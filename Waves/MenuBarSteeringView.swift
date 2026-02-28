import SwiftUI

struct MenuBarSteeringView: View {
    @EnvironmentObject var appState: AppState
    @State private var steeringText = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if appState.isStreaming {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(appState.prompt)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                TextField("Steer the music...", text: $steeringText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitSteering() }

                VoiceSteeringButton(
                    speechRecognizer: appState.speechRecognizer,
                    steeringText: $steeringText
                ) { spokenText in
                    Task { await appState.steerMusic(spokenText) }
                }

                Button(action: submitSteering) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(!canSteer)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { appState.speechRecognizer.requestAuthorization() }
    }

    private var canSteer: Bool {
        appState.isStreaming && !steeringText.isEmpty
    }

    private func submitSteering() {
        guard canSteer else { return }
        let text = steeringText
        steeringText = ""
        Task {
            await appState.steerMusic(text)
        }
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
        case .disconnected: "Not playing"
        case .connecting: "Connecting..."
        case .connected: appState.isStreaming ? "Streaming" : "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }
}
