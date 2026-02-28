import SwiftUI

struct WaveView: View {
    @ObservedObject var session: WaveSession

    let isConnecting: Bool
    var isViolating = false
    var violationSeconds = 0
    var isSuspended = false

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

    private let circleSize: CGFloat = 280
    private let strokeWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: 20) {
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
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.08), lineWidth: strokeWidth)

                Text(formattedDuration(session.duration))
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(width: circleSize, height: circleSize)

            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.seconds) { preset in
                    presetButton(preset: preset)
                }
            }

            Button {
                onStart()
            } label: {
                Text("Start Wave")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isConnecting)
        }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(intensityColor.opacity(0.1), lineWidth: strokeWidth)

                Circle()
                    .trim(from: 0, to: session.progress)
                    .stroke(
                        intensityGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: session.progress)

                centerContent
            }
            .frame(width: circleSize, height: circleSize)
            .shadow(color: intensityColor.opacity(0.3), radius: 24)
            .animation(.easeInOut(duration: 2), value: session.intensity)
            .overlay {
                if isSuspended {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: strokeWidth)
                        .frame(width: circleSize, height: circleSize)
                } else if isViolating {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: strokeWidth)
                        .frame(width: circleSize, height: circleSize)
                }
            }

            HStack(spacing: 10) {
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

            HStack(spacing: 12) {
                if session.state == .paused {
                    Button {
                        onResume()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        onPause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        if let countdown = session.countdownSeconds {
            VStack(spacing: 6) {
                Text("Starting wave in")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("\(countdown)")
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        } else if isSuspended {
            VStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Wave Reset")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)

                Text("Return to focus\nto continue")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if isViolating {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)

                Text("Refocus in \(10 - violationSeconds)s")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .contentTransition(.numericText())
            }
        } else {
            Text(formattedRemaining)
                .font(.system(size: 42, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.12), lineWidth: strokeWidth)

                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.green)
            }
            .frame(width: circleSize, height: circleSize)
            .shadow(color: .green.opacity(0.2), radius: 20)

            Text("Wave Complete")
                .font(.title3.weight(.semibold))

            Text("You focused for \(formattedDuration(session.duration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                session.cancel()
            } label: {
                Text("Start Another")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var intensityColor: Color {
        let t = session.intensity
        let hue: Double
        let saturation: Double
        let brightness: Double

        if t <= 0.5 {
            let p = t / 0.5
            hue = 0.55 + p * (0.75 - 0.55)
            saturation = 0.6 + p * (0.7 - 0.6)
            brightness = 0.9 + p * (0.85 - 0.9)
        } else {
            let p = (t - 0.5) / 0.5
            hue = 0.75 + p * (1.05 - 0.75)
            saturation = 0.7 + p * (0.8 - 0.7)
            brightness = 0.85 + p * (1.0 - 0.85)
        }

        return Color(hue: hue.truncatingRemainder(dividingBy: 1.0), saturation: saturation, brightness: brightness)
    }

    private var intensityGradient: AngularGradient {
        let c = intensityColor
        return AngularGradient(
            colors: [c.opacity(0.4), c.opacity(0.7), c],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * session.progress)
        )
    }

    @ViewBuilder
    private func presetButton(preset: (label: String, seconds: TimeInterval)) -> some View {
        if session.duration == preset.seconds {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    session.duration = preset.seconds
                }
            } label: {
                Text(preset.label)
                    .font(.subheadline.weight(.medium))
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    session.duration = preset.seconds
                }
            } label: {
                Text(preset.label)
                    .font(.subheadline.weight(.medium))
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private func parameterPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
