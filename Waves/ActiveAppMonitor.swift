#if os(macOS)
import AppKit
import Combine
import SwiftUI

@MainActor
final class ActiveAppMonitor: ObservableObject {
    @Published var appName: String = ""
    @Published var appIcon: NSImage?
    @Published var activeURL: String?

    private var currentBundleID: String?
    private var urlTimer: Timer?

    private static let browserScripts: [String: String] = [
        "com.apple.Safari": """
            tell application "Safari" to return URL of current tab of front window
            """,
        "com.google.Chrome": """
            tell application "Google Chrome" to return URL of active tab of front window
            """,
        "company.thebrowser.Browser": """
            tell application "Arc" to return URL of active tab of front window
            """,
        "com.microsoft.edgemac": """
            tell application "Microsoft Edge" to return URL of active tab of front window
            """,
        "com.brave.Browser": """
            tell application "Brave Browser" to return URL of active tab of front window
            """,
    ]

    init() {
        update(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        update(app)
    }

    private func update(_ app: NSRunningApplication?) {
        appName = app?.localizedName ?? "Unknown"
        appIcon = app?.icon
        currentBundleID = app?.bundleIdentifier

        if let bundleID = currentBundleID, Self.browserScripts[bundleID] != nil {
            fetchBrowserURL()
            startPolling()
        } else {
            activeURL = nil
            stopPolling()
        }
    }

    private func startPolling() {
        stopPolling()
        urlTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchBrowserURL()
            }
        }
    }

    private func stopPolling() {
        urlTimer?.invalidate()
        urlTimer = nil
    }

    private func fetchBrowserURL() {
        guard let bundleID = currentBundleID,
              let script = Self.browserScripts[bundleID] else {
            activeURL = nil
            return
        }

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        if let result = appleScript?.executeAndReturnError(&error).stringValue {
            activeURL = result
        } else {
            activeURL = nil
        }
    }

    deinit {
        urlTimer?.invalidate()
    }
}
#endif
