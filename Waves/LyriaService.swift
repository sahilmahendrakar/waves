import Combine
import Foundation

enum LyriaConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

@MainActor
final class LyriaService: ObservableObject {
    @Published var connectionState: LyriaConnectionState = .disconnected

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let audioPlayer: AudioPlayer

    private static let apiVersion = "v1alpha"
    private static let model = "models/lyria-realtime-exp"
    private static let baseURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage"

    init(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    // MARK: - Connection

    func connect(apiKey: String) async {
        disconnect()
        connectionState = .connecting

        let urlString = "\(Self.baseURL).\(Self.apiVersion).GenerativeService.BidiGenerateMusic?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            connectionState = .error("Invalid URL")
            return
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        let setupMessage: [String: Any] = [
            "setup": ["model": Self.model]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: setupMessage)
            try await task.send(.string(String(data: data, encoding: .utf8)!))

            // Wait for setup response
            let setupResponse = try await task.receive()
            if case .string(let text) = setupResponse {
                print("Lyria setup response: \(text)")
            }

            connectionState = .connected
            startReceiving()
        } catch {
            connectionState = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        audioPlayer.stop()
    }

    // MARK: - Commands

    func setPrompts(_ prompts: [(text: String, weight: Double)]) async {
        let weightedPrompts = prompts.map { ["text": $0.text, "weight": $0.weight] as [String: Any] }
        let message: [String: Any] = [
            "clientContent": ["weightedPrompts": weightedPrompts]
        ]
        await sendJSON(message)
    }

    func setMusicConfig(bpm: Int? = nil, temperature: Double = 1.0) async {
        var config: [String: Any] = ["temperature": temperature]
        if let bpm { config["bpm"] = bpm }
        let message: [String: Any] = ["musicGenerationConfig": config]
        await sendJSON(message)
    }

    func play() async {
        await sendJSON(["playbackControl": "PLAY"])
    }

    func pause() async {
        await sendJSON(["playbackControl": "PAUSE"])
    }

    func stop() async {
        await sendJSON(["playbackControl": "STOP"])
    }

    // MARK: - Private

    private func sendJSON(_ object: [String: Any]) async {
        guard let task = webSocketTask else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            let string = String(data: data, encoding: .utf8)!
            try await task.send(.string(string))
        } catch {
            print("Lyria send error: \(error)")
        }
    }

    private func startReceiving() {
        receiveTask = Task {
            while !Task.isCancelled {
                guard let task = self.webSocketTask else { break }
                do {
                    let message = try await task.receive()
                    self.handleMessage(message)
                } catch {
                    if !Task.isCancelled {
                        self.connectionState = .error(error.localizedDescription)
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            processServerJSON(json)
        case .data(let data):
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            processServerJSON(json)
        @unknown default:
            break
        }
    }

    private func processServerJSON(_ json: [String: Any]) {
        guard let serverContent = json["serverContent"] as? [String: Any],
              let audioChunks = serverContent["audioChunks"] as? [[String: Any]] else {
            if let error = json["error"] as? [String: Any] {
                let msg = error["message"] as? String ?? "Unknown API error"
                Task { @MainActor in
                    self.connectionState = .error(msg)
                }
            }
            return
        }

        for chunk in audioChunks {
            guard let base64String = chunk["data"] as? String,
                  let audioData = Data(base64Encoded: base64String) else {
                continue
            }
            audioPlayer.scheduleAudioData(audioData)
        }
    }
}
