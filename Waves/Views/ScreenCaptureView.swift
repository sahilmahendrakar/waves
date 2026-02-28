#if os(macOS)
import SwiftUI

struct ScreenCaptureView: View {
    @State private var service = ScreenCaptureService()

    var body: some View {
        VStack(spacing: 16) {
            if service.hasPermission {
                captureControls
                frontmostAppInfo
                screenshotDisplay
            } else {
                permissionPrompt
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 400)
        .onAppear {
            service.recheckPermission()
        }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Screen Recording Permission Required")
                .font(.headline)

            Text("Waves needs screen recording access to capture screenshots of your workspace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button("Grant Permission") {
                service.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("You may need to enable it in System Settings → Privacy & Security → Screen Recording")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button("Recheck Permission") {
                service.recheckPermission()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var captureControls: some View {
        HStack {
            Button {
                if service.isCapturing {
                    service.stopCapturing()
                } else {
                    service.startCapturing()
                }
            } label: {
                Label(
                    service.isCapturing ? "Stop Capturing" : "Start Capturing",
                    systemImage: service.isCapturing ? "stop.circle.fill" : "play.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(service.isCapturing ? .red : .green)

            Spacer()

            if let timestamp = service.screenshotTimestamp {
                Text(timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var frontmostAppInfo: some View {
        Group {
            if let appName = service.frontmostAppName {
                HStack(spacing: 8) {
                    if let icon = service.frontmostAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }

                    Text(appName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
    }

    private var screenshotDisplay: some View {
        Group {
            if let screenshot = service.latestScreenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
            } else {
                ContentUnavailableView(
                    "No Screenshot Yet",
                    systemImage: "photo",
                    description: Text("Press Start Capturing to begin taking periodic screenshots.")
                )
            }
        }
    }
}

#Preview {
    ScreenCaptureView()
}
#endif
