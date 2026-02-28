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

            waveProgressSection

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
                TextField("Steer music or give a command...", text: $steeringText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitSteering() }

                VoiceSteeringButton(
                    speechRecognizer: appState.speechRecognizer,
                    steeringText: $steeringText
                ) { spokenText in
                    Task { await appState.handleSteeringInput(spokenText) }
                }

                Button(action: submitSteering) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(!canSteer)
            }

            steeringStatusView
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { appState.speechRecognizer.requestAuthorization() }
    }

    private var canSteer: Bool {
        !steeringText.isEmpty
    }

    private func submitSteering() {
        guard canSteer else { return }
        let text = steeringText
        steeringText = ""
        Task {
            await appState.handleSteeringInput(text)
        }
    }

    @ViewBuilder
    private var steeringStatusView: some View {
        switch appState.steeringStatus {
        case .idle:
            EmptyView()
        case .classifying:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Thinking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .transition(.opacity)
        case .success(let message):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .transition(.opacity)
        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var waveProgressSection: some View {
        let session = appState.waveSession
        if session.state == .running || session.state == .paused {
            HStack(spacing: 8) {
                Text(formattedTime(session.remainingTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: session.progress)
                    .tint(.accentColor)
                if session.state == .paused {
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formattedTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
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
