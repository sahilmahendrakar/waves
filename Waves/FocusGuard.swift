#if os(macOS)
import Combine
import Foundation

enum FocusGuardMode: String, CaseIterable, Codable {
    case blocklist = "Blocklist"
    case allowlist = "Allowlist"
}

@MainActor
final class FocusGuard: ObservableObject {
    @Published var mode: FocusGuardMode {
        didSet { persist() }
    }
    @Published var blockedApps: [String] {
        didSet { persist() }
    }
    @Published var blockedDomains: [String] {
        didSet { persist() }
    }
    @Published var allowedApps: [String] {
        didSet { persist() }
    }
    @Published var allowedDomains: [String] {
        didSet { persist() }
    }
    @Published var isViolating = false
    @Published var violationSeconds = 0
    @Published var isSuspended = false

    var isEnabled = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    var onViolationTriggered: (() -> Void)?
    var onRefocused: (() -> Void)?

    static let defaultBlockedApps = ["Instagram", "Reddit", "TikTok"]
    static let defaultBlockedDomains = [
        "instagram.com",
        "reddit.com",
        "youtube.com",
        "twitter.com",
        "x.com",
        "tiktok.com",
    ]

    static let defaultAllowedApps = ["Notes", "Google Chrome", "Safari", "Spotify", "Finder", "Calendar"]
    static let defaultAllowedDomains = [
        "mail.google.com",
        "docs.google.com",
        "notion.so",
        "github.com",
    ]

    private static let wavesAppName = "Waves"
    private static let graceSeconds = 10

    private weak var appMonitor: ActiveAppMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var timerTask: Task<Void, Never>?

    init() {
        mode = .blocklist
        blockedApps = Self.defaultBlockedApps
        blockedDomains = Self.defaultBlockedDomains
        allowedApps = Self.defaultAllowedApps
        allowedDomains = Self.defaultAllowedDomains
        load()
    }

    func attach(to monitor: ActiveAppMonitor) {
        appMonitor = monitor
    }

    func resetToDefaults() {
        blockedApps = Self.defaultBlockedApps
        blockedDomains = Self.defaultBlockedDomains
        allowedApps = Self.defaultAllowedApps
        allowedDomains = Self.defaultAllowedDomains
        mode = .blocklist
    }

    // MARK: - Violation check

    func isContextBlocked(appName: String, activeURL: String?) -> Bool {
        if appName == Self.wavesAppName { return false }

        let host = activeURL
            .flatMap { URL(string: $0)?.host?.lowercased() }

        switch mode {
        case .blocklist:
            if blockedApps.contains(where: { appName.localizedCaseInsensitiveCompare($0) == .orderedSame }) {
                return true
            }
            if let host {
                return blockedDomains.contains { domain in
                    host == domain || host.hasSuffix(".\(domain)")
                }
            }
            return false

        case .allowlist:
            if allowedApps.contains(where: { appName.localizedCaseInsensitiveCompare($0) == .orderedSame }) {
                return false
            }
            if let host {
                let allowed = allowedDomains.contains { domain in
                    host == domain || host.hasSuffix(".\(domain)")
                }
                return !allowed
            }
            return true
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        stopMonitoring()
        isViolating = false
        violationSeconds = 0

        guard let monitor = appMonitor else { return }

        Publishers.CombineLatest(monitor.$appName, monitor.$activeURL)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] appName, url in
                self?.evaluate(appName: appName, activeURL: url)
            }
            .store(in: &cancellables)

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.isEnabled else { break }
                if self.isViolating && !self.isSuspended {
                    self.violationSeconds += 1
                    if self.violationSeconds >= Self.graceSeconds {
                        self.isSuspended = true
                        self.onViolationTriggered?()
                    }
                }
            }
        }
    }

    private func stopMonitoring() {
        cancellables.removeAll()
        timerTask?.cancel()
        timerTask = nil
        isViolating = false
        violationSeconds = 0
        isSuspended = false
    }

    private func evaluate(appName: String, activeURL: String?) {
        guard isEnabled else { return }
        let blocked = isContextBlocked(appName: appName, activeURL: activeURL)
        if blocked && !isViolating {
            isViolating = true
            violationSeconds = 0
        } else if !blocked && isViolating {
            let wasSuspended = isSuspended
            isViolating = false
            violationSeconds = 0
            isSuspended = false
            if wasSuspended {
                onRefocused?()
            }
        }
    }

    // MARK: - Persistence

    private static let storageKey = "focusGuardConfig"

    private struct StoredConfig: Codable {
        var mode: FocusGuardMode
        var apps: [String]
        var domains: [String]
        var allowedApps: [String]?
        var allowedDomains: [String]?
    }

    private func persist() {
        let config = StoredConfig(
            mode: mode,
            apps: blockedApps,
            domains: blockedDomains,
            allowedApps: allowedApps,
            allowedDomains: allowedDomains
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let config = try? JSONDecoder().decode(StoredConfig.self, from: data) else {
            return
        }
        mode = config.mode
        blockedApps = config.apps
        blockedDomains = config.domains
        allowedApps = config.allowedApps ?? Self.defaultAllowedApps
        allowedDomains = config.allowedDomains ?? Self.defaultAllowedDomains
    }
}
#endif
