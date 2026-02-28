import SwiftUI

struct WaveView: View {
    @ObservedObject var session: WaveSession

    let apiKeyIsEmpty: Bool
    let isConnecting: Bool
    var isViolating = false
    var violationSeconds = 0

    var onStart: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onCancel: () -> Void

    private static let presets: [(label: String, seconds: TimeInterval)] = [
        ("1m", 60),
        ("5m", 5 * 60),
        ("15m", 15 * 60),
        ("25m", 25 * 60),
        ("45m", 45 * 60),
        ("60m", 60 * 60),
    ]

    var body: some View {
        VStack(spacing: 24) {
            switch session.state {
            case .idle:
                idleView
            case .running, .paused:
                runningView
            case .completed:
                completedView
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Duration")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(Self.presets, id: \.seconds) { preset in
                        Button(preset.label) {
                            session.duration = preset.seconds
                        }
                        .buttonStyle(.bordered)
                        .tint(session.duration == preset.seconds ? .accentColor : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onStart()
            } label: {
                Label("Start Wave", systemImage: "water.waves")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyIsEmpty || isConnecting)
        }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: session.progress)
                    .stroke(
                        intensityGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: session.progress)

                // Center content
                VStack(spacing: 4) {
                    if isViolating {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.red)

                        Text("Refocus in \(10 - violationSeconds)s")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.red)
                            .contentTransition(.numericText())
                    } else {
                        Text(formattedRemaining)
                            .font(.system(size: 36, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("\(Int(session.intensity * 100))% intensity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 180, height: 180)
            .padding(.vertical, 4)
            .overlay {
                if isViolating {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 8)
                        .frame(width: 180, height: 180)
                }
            }

            // BPM indicator
            HStack(spacing: 12) {
                parameterPill(label: "BPM", value: "\(session.currentParameters.bpm)")
                parameterPill(
                    label: "Density",
                    value: String(format: "%.0f%%", session.currentParameters.density * 100)
                )
                parameterPill(
                    label: "Bright",
                    value: String(format: "%.0f%%", session.currentParameters.brightness * 100)
                )
            }

            // Transport
            HStack(spacing: 16) {
                if session.state == .paused {
                    Button {
                        onResume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        onPause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }

                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Wave Complete")
                .font(.title2.bold())

            Text("You focused for \(formattedDuration(session.duration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                session.cancel() // resets to idle
            } label: {
                Label("Start Another", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var intensityColor: Color {
        let t = session.intensity
        let r: Double = 0.2 * (1 - t) + 1.0 * t
        let g: Double = 0.5 * (1 - t) + 0.6 * t
        let b: Double = 1.0 * (1 - t) + 0.2 * t
        return Color(red: r, green: g, blue: b)
    }

    private var intensityGradient: AngularGradient {
        let c = intensityColor
        return AngularGradient(
            colors: [c.opacity(0.6), c],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * session.progress)
        )
    }

    private func parameterPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var formattedRemaining: String {
        formattedDuration(session.remainingTime)
    }

    private func formattedDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
