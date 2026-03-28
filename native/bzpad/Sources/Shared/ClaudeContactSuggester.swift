import Foundation
import EisenhowerCore

/// Calls Claude to suggest agenda topics for an upcoming 1:1 meeting.
enum ClaudeContactSuggester {

    static func suggestTopics(
        for contact: Contact,
        sessions: [Session],
        apiKey: String
    ) async throws -> [String] {
        guard !apiKey.isEmpty else { throw ClaudeAPIError.emptyAPIKey }

        var contextParts: [String] = []

        if let role = contact.role { contextParts.append("Role: \(role)") }
        if let area = contact.area { contextParts.append("Area: \(area)") }
        if !contact.notes.isEmpty  { contextParts.append("My current notes: \(contact.notes)") }

        let recentSessions = sessions.prefix(3)
        if !recentSessions.isEmpty {
            let history = recentSessions
                .map { "- \($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.notes)" }
                .joined(separator: "\n")
            contextParts.append("Recent meeting notes:\n\(history)")
        }

        let context = contextParts.isEmpty ? "No prior context." : contextParts.joined(separator: "\n")

        let prompt = """
        I'm preparing for a 1:1 meeting with \(contact.name).
        \(context)

        Suggest 3–5 specific, actionable agenda items for our next 1:1.
        Reply with ONLY a JSON array of strings — no prose, no markdown fences:
        ["topic 1","topic 2","topic 3"]
        """

        let body: [String: Any] = [
            "model":      "claude-sonnet-4-6",
            "max_tokens": 512,
            "messages":   [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey,               forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",         forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json",   forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw ClaudeAPIError.invalidAPIKey
        }

        struct APIResponse: Decodable {
            struct Content: Decodable { let text: String }
            struct APIError: Decodable { let message: String }
            let content: [Content]?
            let error:   APIError?
        }
        let envelope = try JSONDecoder().decode(APIResponse.self, from: data)
        if let err = envelope.error { throw ClaudeAPIError.apiError(err.message) }
        guard let text = envelope.content?.first?.text else { throw ClaudeAPIError.parseError }

        guard let start = text.firstIndex(of: "["),
              let end   = text.lastIndex(of: "]") else {
            throw ClaudeAPIError.parseError
        }
        let json = String(text[start...end])
        return (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }
}
