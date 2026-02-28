#if os(macOS)
import Combine
import Foundation

@MainActor
final class AppMusicRouter: ObservableObject {
    @Published var rules: [AppMusicRule] {
        didSet { AppMusicRule.save(rules) }
    }
    @Published var activeRule: AppMusicRule?
    @Published var autoRoutingEnabled: Bool {
        didSet { UserDefaults.standard.set(autoRoutingEnabled, forKey: "appMusicAutoRouting") }
    }
    @Published var isEnabled = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    var onPromptChanged: ((String) -> Void)?
    var originalPrompt: String = ""

    private static let dwellSeconds = 10
    private weak var appMonitor: ActiveAppMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var pendingRule: AppMusicRule?
    private var pendingIsNil = false
    private var dwellTask: Task<Void, Never>?

    init() {
        rules = AppMusicRule.load() ?? AppMusicRule.defaults
        autoRoutingEnabled = UserDefaults.standard.object(forKey: "appMusicAutoRouting") as? Bool ?? true
    }

    func attach(to monitor: ActiveAppMonitor) {
        appMonitor = monitor
    }

    func resetToDefaults() {
        rules = AppMusicRule.defaults
    }

    private func startMonitoring() {
        stopMonitoring()

        guard let monitor = appMonitor else { return }

        Publishers.CombineLatest(monitor.$appName, monitor.$activeURL)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] appName, url in
                self?.evaluate(appName: appName, activeURL: url)
            }
            .store(in: &cancellables)
    }

    private func stopMonitoring() {
        cancellables.removeAll()
        dwellTask?.cancel()
        dwellTask = nil
        pendingRule = nil
    }

    private func evaluate(appName: String, activeURL: String?) {
        guard isEnabled else { return }

        let matched = rules.first { $0.matches(appName: appName, activeURL: activeURL) }
        let matchedIsNil = matched == nil

        if matched?.id == activeRule?.id && matched?.id == pendingRule?.id && matchedIsNil == pendingIsNil {
            return
        }

        if matched?.id == activeRule?.id {
            dwellTask?.cancel()
            dwellTask = nil
            pendingRule = activeRule
            pendingIsNil = false
            return
        }

        if matched?.id == pendingRule?.id && matchedIsNil == pendingIsNil {
            return
        }

        pendingRule = matched
        pendingIsNil = matchedIsNil
        dwellTask?.cancel()

        if let matched {
            dwellTask = Task { [weak self] in
                for _ in 0..<Self.dwellSeconds {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                }
                guard let self, self.isEnabled else { return }
                self.activeRule = matched
                self.onPromptChanged?(matched.prompt)
            }
        } else if activeRule != nil {
            dwellTask = Task { [weak self] in
                for _ in 0..<Self.dwellSeconds {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                }
                guard let self, self.isEnabled else { return }
                self.activeRule = nil
                self.onPromptChanged?(self.originalPrompt)
            }
        }
    }
}
#endif
