import Combine
import Foundation

enum WaveState: Equatable {
    case idle
    case running
    case paused
    case completed
}

struct WaveParameters: Equatable {
    var bpm: Int
    var density: Double
    var brightness: Double
    var calmWeight: Double
    var intenseWeight: Double
}

@MainActor
final class WaveSession: ObservableObject {
    @Published var state: WaveState = .idle
    @Published var duration: TimeInterval = 25 * 60
    @Published var elapsedTime: TimeInterval = 0
    @Published var intensity: Double = 0

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsedTime / duration, 1.0)
    }

    var remainingTime: TimeInterval {
        max(duration - elapsedTime, 0)
    }

    var currentParameters: WaveParameters {
        WaveParameters(
            bpm: Int(lerp(60, 200, intensity)),
            density: lerp(0.1, 0.9, intensity),
            brightness: lerp(0.2, 0.8, intensity),
            calmWeight: max(1.0 - intensity, 0.1),
            intenseWeight: max(intensity, 0.1)
        )
    }

    var onParametersChanged: ((_ params: WaveParameters, _ bpmChanged: Bool) -> Void)?
    var onWaveCompleted: (() -> Void)?

    private var timerTask: Task<Void, Never>?
    private var lastSentBPM: Int = 60
    private var timeSinceLastUpdate: TimeInterval = 0
    private static let updateInterval: TimeInterval = 5

    func start() {
        elapsedTime = 0
        intensity = 0
        lastSentBPM = 60
        timeSinceLastUpdate = Self.updateInterval // fire immediately on first tick
        state = .running
        startTimer()
    }

    func pause() {
        state = .paused
        timerTask?.cancel()
        timerTask = nil
    }

    func resume() {
        state = .running
        startTimer()
    }

    func cancel() {
        timerTask?.cancel()
        timerTask = nil
        state = .idle
        elapsedTime = 0
        intensity = 0
    }

    // MARK: - Private

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.state == .running else { break }

                self.elapsedTime += 1
                self.recomputeIntensity()
                self.timeSinceLastUpdate += 1

                if self.elapsedTime >= self.duration {
                    self.state = .completed
                    self.onWaveCompleted?()
                    break
                }

                if self.timeSinceLastUpdate >= Self.updateInterval {
                    self.timeSinceLastUpdate = 0
                    let params = self.currentParameters
                    let bpmChanged = abs(params.bpm - self.lastSentBPM) >= 10
                    if bpmChanged { self.lastSentBPM = params.bpm }
                    self.onParametersChanged?(params, bpmChanged)
                }
            }
        }
    }

    private func recomputeIntensity() {
        let p = progress
        if p <= 0.75 {
            let t = p / 0.75
            intensity = easeInOut(t)
        } else {
            let t = (p - 0.75) / 0.25
            intensity = 1.0 - easeOut(t)
        }
    }

    // smoothstep: slow start, fast middle, slow arrival
    private func easeInOut(_ t: Double) -> Double {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }

    // decelerating curve
    private func easeOut(_ t: Double) -> Double {
        let c = max(0, min(1, t))
        return c * (2 - c)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * max(0, min(1, t))
    }
}
