import Foundation

struct GeminiService {
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    static func classifyIntent(
        _ text: String,
        apiKey: String,
        blockedDomains: [String] = [],
        blockedApps: [String] = []
    ) async throws -> SteeringIntent {
        let systemPrompt = buildSystemPrompt(
            blockedDomains: blockedDomains,
            blockedApps: blockedApps
        )

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": text]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": responseSchema,
                "temperature": 0.0,
            ],
        ]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "non-utf8"
            print("[GeminiService] API error \(statusCode): \(bodyPreview)")
            throw GeminiError.apiError(statusCode: statusCode)
        }

        return try parseResponse(data)
    }

    private static func buildSystemPrompt(blockedDomains: [String], blockedApps: [String]) -> String {
        let domainsContext = blockedDomains.isEmpty
            ? "none"
            : blockedDomains.joined(separator: ", ")
        let appsContext = blockedApps.isEmpty
            ? "none"
            : blockedApps.joined(separator: ", ")

        return """
        You are an intent classifier for a music + focus app called Waves. \
        The user can either steer the music style OR block/unblock services in the focus guard.

        Currently blocked domains: \(domainsContext)
        Currently blocked apps: \(appsContext)

        Classify the user's input into exactly one intent:

        - "steer_music": The input describes a music style, genre, mood, or sound. \
        Set "value" to the music prompt. Leave "domain" and "app_name" as empty strings. \
        Examples: "rock", "chill vibes", "more bass", "upbeat electronic", "jazz piano".

        - "block": The user wants to block a service. Fill in BOTH "domain" and "app_name" \
        when the service has both a website and a native app. Use empty string for whichever \
        does not apply. \
        Examples: "block instagram" -> domain="instagram.com", app_name="Instagram". \
        "block gmail" -> domain="mail.google.com", app_name="". \
        "block slack" -> domain="", app_name="Slack".

        - "unblock": The user wants to unblock/remove a service. Same rules as "block" \
        for filling in "domain" and "app_name".

        When in doubt, default to "steer_music". Music-related words should always be steer_music.

        Domain resolution rules:
        - "gmail" / "google mail" -> "mail.google.com"
        - "youtube" / "yt" -> "youtube.com" (app_name: "YouTube")
        - "reddit" -> "reddit.com" (app_name: "Reddit")
        - "twitter" / "x" -> "x.com" (app_name: "X")
        - "instagram" / "ig" / "insta" -> "instagram.com" (app_name: "Instagram")
        - "facebook" / "fb" -> "facebook.com" (app_name: "Facebook")
        - "tiktok" -> "tiktok.com" (app_name: "TikTok")
        - "linkedin" -> "linkedin.com" (app_name: "LinkedIn")
        - "slack" -> "slack.com" (app_name: "Slack")
        - "discord" -> "discord.com" (app_name: "Discord")
        - For other sites, use your best judgment to determine the domain.
        - Only set app_name if the service is commonly used as a native macOS/iOS app.
        """
    }

    private static var responseSchema: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "intent": [
                    "type": "STRING",
                    "enum": ["steer_music", "block", "unblock"],
                ],
                "value": [
                    "type": "STRING",
                    "description": "The music prompt for steer_music. Empty string for block/unblock.",
                ],
                "domain": [
                    "type": "STRING",
                    "description": "The website domain to block/unblock. Empty string if not applicable.",
                ],
                "app_name": [
                    "type": "STRING",
                    "description": "The native app display name to block/unblock. Empty string if not applicable.",
                ],
            ],
            "required": ["intent", "value", "domain", "app_name"],
        ]
    }

    private static func parseResponse(_ data: Data) throws -> SteeringIntent {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let resultData = text.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any],
              let intent = result["intent"] as? String
        else {
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "non-utf8"
            print("[GeminiService] Failed to parse response: \(bodyPreview)")
            throw GeminiError.parseError
        }

        let value = result["value"] as? String ?? ""
        let domain = (result["domain"] as? String ?? "").lowercased()
        let appName = result["app_name"] as? String ?? ""

        switch intent {
        case "steer_music":
            return .steerMusic(prompt: value)
        case "block":
            return .block(domain: domain, appName: appName)
        case "unblock":
            return .unblock(domain: domain, appName: appName)
        default:
            return .steerMusic(prompt: value)
        }
    }
}

enum GeminiError: LocalizedError {
    case invalidURL
    case apiError(statusCode: Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Gemini API URL"
        case .apiError(let code):
            "Gemini API error (HTTP \(code))"
        case .parseError:
            "Failed to parse Gemini response"
        }
    }
}
