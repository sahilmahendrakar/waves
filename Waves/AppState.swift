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

    private var userSteeringPrompt: String?
    private var cancellables = Set<AnyCancellable>()

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
                if self.userSteeringPrompt == nil {
                    await self.lyriaService.setPrompts([
                        (text: self.calmPrompt, weight: params.calmWeight),
                        (text: self.intensePrompt, weight: params.intenseWeight),
                    ])
                }
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
        await lyriaService.setPrompts([
            (text: calmPrompt, weight: initial.calmWeight),
            (text: intensePrompt, weight: initial.intenseWeight),
        ])
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
        await lyriaService.setPrompts([
            (text: calmPrompt, weight: initial.calmWeight),
            (text: intensePrompt, weight: initial.intenseWeight),
        ])
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
        await lyriaService.setPrompts([(text: text, weight: 1.0)])
    }

    func applyPreferences(_ prefs: MusicPreferences) {
        calmPrompt = prefs.calmPrompt
        intensePrompt = prefs.intensePrompt
        prompt = prefs.defaultPrompt
    }
}
