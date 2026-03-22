import Foundation

/// Detects the Eisenhower quadrant from task text using keyword matching.
/// Ported from the React prototype's taskUtils.ts detectQuadrant().
public enum QuadrantDetector {

    // "critical" intentionally appears in BOTH lists — a critical task is
    // both urgent AND important, mapping it to Q1 (Do First).
    static let urgentKeywords: Set<String> = [
        "asap", "urgent", "today", "deadline", "due", "now", "immediately", "critical"
    ]

    static let importantKeywords: Set<String> = [
        "critical", "important", "goal", "milestone", "review", "key", "priority", "strategic"
    ]

    /// Detects the quadrant from `text` using keyword matching.
    /// Case-insensitive; whole-word matching is not enforced (consistent with web prototype).
    public static func detect(from text: String) -> Quadrant {
        let lower = text.lowercased()
        let isUrgent    = urgentKeywords.contains(where: { lower.contains($0) })
        let isImportant = importantKeywords.contains(where: { lower.contains($0) })

        switch (isUrgent, isImportant) {
        case (true,  true):  return .doFirst
        case (false, true):  return .schedule
        case (true,  false): return .delegate
        case (false, false): return .eliminate
        }
    }
}
