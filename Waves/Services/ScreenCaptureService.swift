#if os(macOS)
import AppKit
import ScreenCaptureKit
import Combine

@Observable
final class ScreenCaptureService {
    var latestScreenshot: NSImage?
    var screenshotTimestamp: Date?
    var frontmostAppName: String?
    var frontmostAppIcon: NSImage?
    var hasPermission: Bool = false
    var isCapturing: Bool = false

    private var captureTask: Task<Void, Never>?
    private var workspaceObserver: AnyCancellable?

    init() {
        hasPermission = CGPreflightScreenCaptureAccess()
        updateFrontmostApplication()
        startObservingFrontmostApp()
    }

    deinit {
        stopCapturing()
    }

    func requestPermission() {
        let granted = CGRequestScreenCaptureAccess()
        hasPermission = granted
    }

    func recheckPermission() {
        hasPermission = CGPreflightScreenCaptureAccess()
    }

    func startCapturing(interval: TimeInterval = 10) {
        guard !isCapturing else { return }
        isCapturing = true

        captureTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.captureScreenshot()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopCapturing() {
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
    }

    func captureScreenshot() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

            latestScreenshot = NSImage(cgImage: image, size: NSSize(
                width: image.width,
                height: image.height
            ))
            screenshotTimestamp = Date()
        } catch {
            print("Screenshot capture failed: \(error.localizedDescription)")
        }
    }

    private func updateFrontmostApplication() {
        let app = NSWorkspace.shared.frontmostApplication
        frontmostAppName = app?.localizedName
        frontmostAppIcon = app?.icon
    }

    private func startObservingFrontmostApp() {
        workspaceObserver = NotificationCenter.default.publisher(
            for: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateFrontmostApplication()
        }
    }
}
#endif
