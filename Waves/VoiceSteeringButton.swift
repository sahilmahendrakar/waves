import SwiftUI

struct VoiceSteeringButton: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @Binding var steeringText: String
    var onSubmit: (String) -> Void

    var body: some View {
        Button(action: toggleRecording) {
            Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundStyle(speechRecognizer.isRecording ? .red : .primary)
                .symbolEffect(.pulse, isActive: speechRecognizer.isRecording)
        }
        .buttonStyle(.borderless)
        .disabled(!speechRecognizer.isAuthorized)
        .onChange(of: speechRecognizer.transcribedText) { _, newValue in
            if speechRecognizer.isRecording {
                steeringText = newValue
            }
        }
        .onChange(of: speechRecognizer.isRecording) { wasRecording, isNowRecording in
            if wasRecording && !isNowRecording && !speechRecognizer.transcribedText.isEmpty {
                onSubmit(speechRecognizer.transcribedText)
                steeringText = ""
            }
        }
    }

    private func toggleRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            steeringText = ""
            try? speechRecognizer.startRecording()
        }
    }
}
