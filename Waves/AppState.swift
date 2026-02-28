import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let audioPlayer: AudioPlayer
    let lyriaService: LyriaService
    let speechRecognizer = SpeechRecognizer()
    let waveSession = WaveSession()
    private let pingPlayer = PingPlayer()

    @Published var prompt: String
    @Published var bpm: Double = 120
    @Published var isStreaming = false
    @Published var connectionState: LyriaConnectionState = .disconnected
    @Published var steeringStatus: SteeringStatus = .idle

    #if os(macOS)
    weak var focusGuard: FocusGuard?
    #endif

    private var userSteeringPrompt: String?
    private var cancellables = Set<AnyCancellable>()
    private var steeringStatusTask: Task<Void, Never>?

    private(set) var calmPrompt: String
    private(set) var intensePrompt: String

    var apiKey: String {
        UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    }

    init() {
        let player = AudioPlayer()
        self.audioPlayer = player
        self.lyriaService = LyriaService(audioPlayer: player)

        let prefs = MusicPreferences.load() ?? .default
        self.calmPrompt = prefs.calmPrompt
        self.intensePrompt = prefs.intensePrompt
        self._prompt = Published(initialValue: prefs.defaultPrompt)

        lyriaService.$connectionState
            .assign(to: &$connectionState)

        waveSession.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        setupWaveCallbacks()
    }

    private func setupWaveCallbacks() {
        waveSession.onParametersChanged = { [weak self] params, bpmChanged in
            Task { @MainActor in
                guard let self else { return }
                await self.lyriaService.setPrompts(self.wavePrompts(for: params))
                await self.lyriaService.setMusicConfig(
                    bpm: bpmChanged ? params.bpm : nil,
                    density: params.density,
                    brightness: params.brightness
                )
                if bpmChanged {
                    await self.lyriaService.resetContext()
                }
            }
        }

        waveSession.onWaveCompleted = { [weak self] in
            Task { @MainActor in
                await self?.stopWaveMusic()
            }
        }
    }

    // MARK: - Free Play

    func startMusic() async {
        guard !apiKey.isEmpty else { return }

        if connectionState != .connected {
            await lyriaService.connect(apiKey: apiKey)
            guard lyriaService.connectionState == .connected else { return }
        }

        await lyriaService.setPrompts([(text: prompt, weight: 1.0)])
        await lyriaService.setMusicConfig(bpm: Int(bpm))
        audioPlayer.start()
        await lyriaService.play()
        isStreaming = true
    }

    func pauseMusic() async {
        await lyriaService.pause()
        audioPlayer.pause()
        isStreaming = false
    }

    func stopMusic() async {
        await lyriaService.stop()
        audioPlayer.stop()
        isStreaming = false
        lyriaService.disconnect()
    }

    // MARK: - Wave

    func startWave() async {
        guard !apiKey.isEmpty else { return }
        userSteeringPrompt = nil

        if connectionState != .connected {
            await lyriaService.connect(apiKey: apiKey)
            guard lyriaService.connectionState == .connected else { return }
        }

        let initial = waveSession.currentParameters
        await lyriaService.setPrompts(wavePrompts(for: initial))
        await lyriaService.setMusicConfig(
            bpm: initial.bpm,
            density: initial.density,
            brightness: initial.brightness
        )
        audioPlayer.start()
        audioPlayer.fadeIn(over: 5)
        await lyriaService.play()
        isStreaming = true
        waveSession.start()
    }

    func pauseWave() async {
        waveSession.pause()
        await lyriaService.pause()
        audioPlayer.pause()
        isStreaming = false
    }

    func resumeWave() async {
        audioPlayer.resume()
        await lyriaService.play()
        isStreaming = true
        waveSession.resume()
    }

    func cancelWave() async {
        userSteeringPrompt = nil
        pingPlayer.stop()
        waveSession.cancel()
        await stopWaveMusic()
    }

    func suspendWave() async {
        waveSession.pause()
        await lyriaService.pause()
        audioPlayer.pause()
        isStreaming = false
        pingPlayer.start()
    }

    func resumeSuspendedWave() async {
        userSteeringPrompt = nil
        pingPlayer.stop()
        audioPlayer.cancelFade()
        waveSession.restart()
        let initial = waveSession.currentParameters
        await lyriaService.setPrompts(wavePrompts(for: initial))
        await lyriaService.setMusicConfig(
            bpm: initial.bpm,
            density: initial.density,
            brightness: initial.brightness
        )
        await lyriaService.resetContext()
        audioPlayer.resume()
        audioPlayer.fadeIn(over: 5)
        await lyriaService.play()
        isStreaming = true
    }

    private func stopWaveMusic() async {
        await lyriaService.stop()
        audioPlayer.stop()
        isStreaming = false
        lyriaService.disconnect()
    }

    // MARK: - Steering

    func steerMusic(_ text: String) async {
        guard connectionState == .connected, isStreaming else { return }
        prompt = text
        userSteeringPrompt = text
        await lyriaService.setPrompts(wavePrompts(for: waveSession.currentParameters))
    }

    private func wavePrompts(for params: WaveParameters) -> [(text: String, weight: Double)] {
        var prompts: [(text: String, weight: Double)] = [
            (text: calmPrompt, weight: params.calmWeight),
            (text: intensePrompt, weight: params.intenseWeight),
        ]
        if let steering = userSteeringPrompt {
            prompts.append((text: steering, weight: 2.0))
        }
        return prompts
    }

    func handleSteeringInput(_ text: String) async {
        guard !apiKey.isEmpty else { return }

        steeringStatus = .classifying

        #if os(macOS)
        let domains = focusGuard?.blockedDomains ?? []
        let apps = focusGuard?.blockedApps ?? []
        #else
        let domains: [String] = []
        let apps: [String] = []
        #endif

        let intent: SteeringIntent
        do {
            intent = try await GeminiService.classifyIntent(
                text,
                apiKey: apiKey,
                blockedDomains: domains,
                blockedApps: apps
            )
        } catch {
            print("[Steering] Classification failed: \(error.localizedDescription)")
            setSteeringStatus(.error(error.localizedDescription))
            return
        }

        switch intent {
        case .steerMusic(let prompt):
            await steerMusic(prompt)
            setSteeringStatus(.success("Music: \(prompt)"))

        #if os(macOS)
        case .block(let domain, let appName):
            guard let guard_ = focusGuard else { break }
            var blocked: [String] = []
            if !domain.isEmpty {
                if !guard_.blockedDomains.contains(where: { $0.caseInsensitiveCompare(domain) == .orderedSame }) {
                    guard_.blockedDomains.append(domain)
                }
                blocked.append(domain)
            }
            if !appName.isEmpty {
                if !guard_.blockedApps.contains(where: { $0.caseInsensitiveCompare(appName) == .orderedSame }) {
                    guard_.blockedApps.append(appName)
                }
                blocked.append(appName)
            }
            guard_.reevaluate()
            setSteeringStatus(.success("Blocked \(blocked.joined(separator: " & "))"))

        case .unblock(let domain, let appName):
            guard let guard_ = focusGuard else { break }
            var unblocked: [String] = []
            if !domain.isEmpty {
                guard_.blockedDomains.removeAll { $0.caseInsensitiveCompare(domain) == .orderedSame }
                unblocked.append(domain)
            }
            if !appName.isEmpty {
                guard_.blockedApps.removeAll { $0.caseInsensitiveCompare(appName) == .orderedSame }
                unblocked.append(appName)
            }
            guard_.reevaluate()
            setSteeringStatus(.success("Unblocked \(unblocked.joined(separator: " & "))"))
        #else
        case .block, .unblock:
            setSteeringStatus(.error("Focus Guard is only available on macOS"))
        #endif
        }
    }

    private func setSteeringStatus(_ status: SteeringStatus) {
        steeringStatus = status
        steeringStatusTask?.cancel()
        steeringStatusTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            steeringStatus = .idle
        }
    }

    func applyPreferences(_ prefs: MusicPreferences) {
        calmPrompt = prefs.calmPrompt
        intensePrompt = prefs.intensePrompt
        prompt = prefs.defaultPrompt
    }
}
