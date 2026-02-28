import Foundation

struct AppMusicRule: Codable, Identifiable, Equatable {
    var id: UUID
    var label: String
    var appNames: [String]
    var domains: [String]
    var prompt: String

    static let defaults: [AppMusicRule] = [
        AppMusicRule(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000000")!,
            label: "Writing",
            appNames: ["Obsidian", "Notes", "Pages", "TextEdit"],
            domains: ["docs.google.com", "notion.so"],
            prompt: "chill ambient instrumental music, calm and focused"
        ),
        AppMusicRule(
            id: UUID(uuidString: "00000000-0002-0000-0000-000000000000")!,
            label: "Social Media",
            appNames: ["Instagram", "TikTok"],
            domains: ["instagram.com", "reddit.com", "twitter.com", "x.com", "tiktok.com", "facebook.com"],
            prompt: "upbeat pop music with catchy beats and energy"
        ),
        AppMusicRule(
            id: UUID(uuidString: "00000000-0003-0000-0000-000000000000")!,
            label: "Coding",
            appNames: ["Xcode", "Code", "Cursor", "Terminal", "iTerm2", "Warp"],
            domains: ["github.com"],
            prompt: "edm dubstep electronic high energy bass drops"
        ),
    ]

    func matches(appName: String, activeURL: String?) -> Bool {
        if appNames.contains(where: { appName.localizedCaseInsensitiveCompare($0) == .orderedSame }) {
            return true
        }

        if let host = activeURL.flatMap({ URL(string: $0)?.host?.lowercased() }) {
            return domains.contains { domain in
                host == domain || host.hasSuffix(".\(domain)")
            }
        }

        return false
    }

    private static let storageKey = "appMusicRules"

    static func save(_ rules: [AppMusicRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func load() -> [AppMusicRule]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let rules = try? JSONDecoder().decode([AppMusicRule].self, from: data)
        else { return nil }
        return rules
    }
}
