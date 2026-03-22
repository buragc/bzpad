import Foundation

/// Extracts tags from task text.
/// Ported from tagUtils.ts extractTags() in the React prototype.
public enum TagExtractor {

    // NSRegularExpression avoids the Swift regex literal /#/ parsing ambiguity.
    private static let hashtagRegex: NSRegularExpression = {
        // Matches a literal '#' followed by one-or-more word characters.
        try! NSRegularExpression(pattern: "#(\\w+)", options: [])
    }()

    /// Extracts `#tag` style tags AND urgency/importance keywords as implicit tags.
    /// Deduplicates the result. Returns lowercase tags.
    public static func extract(from text: String) -> [String] {
        var tags: [String] = []

        // #hashtag extraction
        let lower = text.lowercased()
        let nsText = text as NSString
        let range  = NSRange(location: 0, length: nsText.length)
        for match in hashtagRegex.matches(in: text, options: [], range: range) {
            let tagRange = match.range(at: 1)
            if tagRange.location != NSNotFound, let r = Range(tagRange, in: text) {
                let tag = text[r].lowercased()
                if !tags.contains(tag) { tags.append(tag) }
            }
        }

        // Keyword tags (urgency + importance) — consistent with web prototype
        let keywords = QuadrantDetector.urgentKeywords.union(QuadrantDetector.importantKeywords)
        for kw in keywords.sorted() {
            if lower.contains(kw), !tags.contains(kw) {
                tags.append(kw)
            }
        }

        return tags
    }

    /// Returns `text` with `#tag` patterns removed (for display cleanup).
    public static func strippingHashtags(from text: String) -> String {
        let nsText = text as NSString
        let range  = NSRange(location: 0, length: nsText.length)
        return hashtagRegex
            .stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
