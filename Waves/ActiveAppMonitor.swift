#if os(macOS)
import AppKit
import Combine
import SwiftUI

@MainActor
final class ActiveAppMonitor: ObservableObject {
    @Published var appName: String = ""
    @Published var appIcon: NSImage?

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
    }
}
#endif
