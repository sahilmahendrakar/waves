import AVFoundation
import Combine
import Foundation

final class PingPlayer {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private let interval: TimeInterval = 3
    private let volume: Float = 1

    func start() {
        stop()
        guard let url = Bundle.main.url(forResource: "ping", withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = volume
        playOnce()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playOnce()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
    }

    private func playOnce() {
        player?.currentTime = 0
        player?.play()
    }
}

@MainActor
final class AudioPlayer: ObservableObject {
    @Published var isPlaying = false

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let outputFormat: AVAudioFormat
    private var fadeTask: Task<Void, Never>?

    private static let sampleRate: Double = 48_000
    private static let channels: AVAudioChannelCount = 2

    init() {
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.sampleRate,
            channels: Self.channels,
            interleaved: true
        )!

        engine.attach(playerNode)

        let mixerFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: Self.channels,
            interleaved: false
        )!
        engine.connect(playerNode, to: engine.mainMixerNode, format: mixerFormat)
    }

    func start() {
        guard !isPlaying else { return }
        cancelFade()
        do {
            try engine.start()
            playerNode.play()
            isPlaying = true
        } catch {
            print("AudioPlayer: failed to start engine – \(error)")
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func resume() {
        cancelFade()
        playerNode.play()
        isPlaying = true
    }

    func fadeOut(over duration: TimeInterval) {
        fadeTask?.cancel()
        let steps = 50
        let interval = duration / Double(steps)
        let startVolume = playerNode.volume

        fadeTask = Task {
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                playerNode.volume = startVolume * Float(steps - step) / Float(steps)
            }
        }
    }

    func cancelFade() {
        fadeTask?.cancel()
        fadeTask = nil
        playerNode.volume = 1.0
    }

    /// Enqueue raw interleaved 16-bit PCM data (48 kHz, stereo) for playback.
    nonisolated func scheduleAudioData(_ data: Data) {
        let bytesPerSample = 2
        let frameCount = data.count / (bytesPerSample * Int(Self.channels))
        guard frameCount > 0 else { return }

        let float32Format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: Self.channels,
            interleaved: false
        )!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: float32Format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        data.withUnsafeBytes { rawPtr in
            guard let int16Ptr = rawPtr.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            let leftChannel = buffer.floatChannelData![0]
            let rightChannel = buffer.floatChannelData![1]
            let scale: Float = 1.0 / Float(Int16.max)

            for frame in 0..<frameCount {
                let left = Int(int16Ptr[frame * 2])
                let right = Int(int16Ptr[frame * 2 + 1])
                leftChannel[frame] = Float(left) * scale
                rightChannel[frame] = Float(right) * scale
            }
        }

        playerNode.scheduleBuffer(buffer)
    }
}
