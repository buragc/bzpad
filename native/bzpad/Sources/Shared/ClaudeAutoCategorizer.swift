import Foundation
import EisenhowerCore

// MARK: – Errors

public enum ClaudeAPIError: LocalizedError, Sendable {
    case emptyAPIKey
    case invalidAPIKey
    case apiError(String)
    case parseError

    public var errorDescription: String? {
        switch self {
        case .emptyAPIKey:    return "No Claude API key set. Add your key in Settings."
        case .invalidAPIKey:  return "Invalid Claude API key. Check your key in Settings."
        case .apiError(let m): return "Claude API error: \(m)"
        case .parseError:     return "Couldn't parse Claude's response. Try again."
        }
    }
}

// MARK: – Auto-categorizer

/// Sends all active tasks to Claude and returns suggested (id, quadrant) pairs.
/// This is a pure async function with no actor isolation — callers on @MainActor
/// can await it freely; URLSession does its work on its own threads.
enum ClaudeAutoCategorizer {

    static func categorize(
        tasks: [EisenhowerCore.Task],
        apiKey: String
    ) async throws -> [(UUID, Quadrant)] {

        guard !apiKey.isEmpty else { throw ClaudeAPIError.emptyAPIKey }
        guard !tasks.isEmpty  else { return [] }

        let formatter = ISO8601DateFormatter()

        let taskLines = tasks.map { task -> String in
            var parts: [String] = [
                "id: \(task.id.uuidString)",
                "title: \"\(task.title)\""
            ]
            if let due = task.dueDate {
                parts.append("due: \(formatter.string(from: due))")
            }
            if !task.tags.isEmpty {
                parts.append("tags: [\(task.tags.joined(separator: ", "))]")
            }
            return "- " + parts.joined(separator: ", ")
        }.joined(separator: "\n")

        let prompt = """
        You are a task prioritization assistant using the Eisenhower Matrix.

        Categorize each task into exactly one quadrant:
        1 = Urgent & Important (Do First) — hard deadlines, active crises
        2 = Not Urgent & Important (Schedule) — planning, learning, long-term goals
        3 = Urgent & Not Important (Delegate) — interruptions, routine requests from others
        4 = Not Urgent & Not Important (Eliminate) — time-wasters, busywork, trivia

        Reply with ONLY a JSON array — no prose, no markdown fences:
        [{"id":"<uuid>","quadrant":<1|2|3|4>},...]

        Tasks:
        \(taskLines)
        """

        let body: [String: Any] = [
            "model":      "claude-sonnet-4-6",
            "max_tokens": 1024,
            "messages":   [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey,        forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",  forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw ClaudeAPIError.invalidAPIKey
        }

        // Parse Anthropic Messages API response envelope
        struct APIResponse: Decodable, Sendable {
            struct Content: Decodable, Sendable { let text: String }
            struct APIError: Decodable, Sendable { let message: String }
            let content: [Content]?
            let error:   APIError?
        }
        let envelope = try JSONDecoder().decode(APIResponse.self, from: data)

        if let err = envelope.error { throw ClaudeAPIError.apiError(err.message) }
        guard let text = envelope.content?.first?.text else { throw ClaudeAPIError.parseError }

        // Defensively extract the JSON array even if Claude prefixes with prose
        guard let start = text.firstIndex(of: "["),
              let end   = text.lastIndex(of: "]") else {
            throw ClaudeAPIError.parseError
        }
        let json = String(text[start...end])

        struct Suggestion: Decodable, Sendable { let id: String; let quadrant: Int }
        let suggestions = try JSONDecoder().decode([Suggestion].self, from: Data(json.utf8))

        return suggestions.compactMap { s in
            guard let uuid = UUID(uuidString: s.id),
                  let q    = Quadrant(rawValue: s.quadrant) else { return nil }
            return (uuid, q)
        }
    }
}
