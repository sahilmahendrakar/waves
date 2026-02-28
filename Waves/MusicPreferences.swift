import Foundation

struct MusicPreferences: Codable, Equatable {
    var selectedGenres: [String]
    var selectedMood: String

    static let availableGenres = [
        "Ambient", "Techno", "Lo-fi", "Classical",
        "Jazz", "Indie", "Electronic", "Hip-Hop",
        "Rock", "R&B", "Acoustic", "Cinematic",
    ]

    static let availableMoods = [
        "Chill & Spacey",
        "Warm & Melodic",
        "Dark & Driving",
        "Bright & Uplifting",
    ]

    static let `default` = MusicPreferences(
        selectedGenres: ["Electronic"],
        selectedMood: "Chill & Spacey"
    )

    private static let moodCalmAdjectives: [String: String] = [
        "Chill & Spacey": "ambient ethereal spacey floating dreamy",
        "Warm & Melodic": "warm soft melodic gentle soothing",
        "Dark & Driving": "dark moody atmospheric brooding minimal",
        "Bright & Uplifting": "gentle light airy peaceful calm",
    ]

    private static let moodIntenseAdjectives: [String: String] = [
        "Chill & Spacey": "deep immersive expansive layered swirling",
        "Warm & Melodic": "energetic rich lush harmonic soaring",
        "Dark & Driving": "aggressive driving intense pounding heavy",
        "Bright & Uplifting": "energetic euphoric uplifting powerful bright",
    ]

    var calmPrompt: String {
        let adjectives = Self.moodCalmAdjectives[selectedMood] ?? "ambient chill"
        let genres = selectedGenres.joined(separator: " ")
        return "\(adjectives) \(genres)"
    }

    var intensePrompt: String {
        let adjectives = Self.moodIntenseAdjectives[selectedMood] ?? "energetic driving"
        let genres = selectedGenres.joined(separator: " ")
        return "\(adjectives) \(genres)"
    }

    var defaultPrompt: String {
        let genre = selectedGenres.first ?? "electronic"
        let moodWord: String
        switch selectedMood {
        case "Chill & Spacey": moodWord = "chill spacey"
        case "Warm & Melodic": moodWord = "warm melodic"
        case "Dark & Driving": moodWord = "dark driving"
        case "Bright & Uplifting": moodWord = "bright uplifting"
        default: moodWord = "chill"
        }
        return "\(moodWord) \(genre.lowercased()) with deep bass"
    }

    private static let storageKey = "musicPreferences"

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func load() -> MusicPreferences? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(MusicPreferences.self, from: data)
        else { return nil }
        return prefs
    }
}
