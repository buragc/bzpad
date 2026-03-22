import Foundation

/// Natural language date parsing.
///
/// Two-pass strategy:
/// 1. Regex pre-pass for relative phrases NSDataDetector misses:
///    "in N days", "in N weeks", "in N months"
/// 2. NSDataDetector for everything else:
///    "tomorrow", "next Friday", "March 15", ISO dates, etc.
///
/// Ported from chrono-node usage in the React prototype.
public enum DateParser {

    // MARK: – Static resources

    private static let detector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    /// Matches "in N days/weeks/months" (case-insensitive).
    /// Group 1: numeric value, Group 2: unit (day/days/week/weeks/month/months)
    private static let relativePattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"\bin\s+(\d+)\s+(days?|weeks?|months?)\b"#,
            options: .caseInsensitive
        )
    }()

    // MARK: – Public API

    /// Extracts the first date reference from `text`. Returns nil if none found.
    public static func parse(_ text: String, now: Date = Date()) -> Date? {
        // Pass 1: relative phrases ("in 2 weeks", "in 3 days")
        if let relative = parseRelative(text, now: now) { return relative }

        // Pass 2: NSDataDetector (absolute & common relative phrases)
        guard let detector else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).first?.date
    }

    /// Returns `text` with recognized date phrases stripped out.
    /// Useful for cleaning the task title after extracting the date.
    public static func strippingDatePhrases(from text: String, now: Date = Date()) -> String {
        var result = stripRelativePhrases(from: text)

        guard let detector else { return result.trimmingCharacters(in: .whitespaces) }
        let range = NSRange(location: 0, length: (result as NSString).length)
        let matches = detector.matches(in: result, options: [], range: range)
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: result) else { continue }
            result.removeSubrange(swiftRange)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: – Private helpers

    private static func parseRelative(_ text: String, now: Date) -> Date? {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = relativePattern.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange  = Range(match.range(at: 2), in: text),
              let value = Int(text[valueRange])
        else { return nil }

        let unit = text[unitRange].lowercased()
        var components = DateComponents()
        if unit.hasPrefix("day") {
            components.day = value
        } else if unit.hasPrefix("week") {
            components.day = value * 7
        } else if unit.hasPrefix("month") {
            components.month = value
        } else {
            return nil
        }
        return Calendar.current.date(byAdding: components, to: now)
    }

    private static func stripRelativePhrases(from text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return relativePattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
    }
}
