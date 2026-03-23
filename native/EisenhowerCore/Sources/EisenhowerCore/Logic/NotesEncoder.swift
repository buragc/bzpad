import Foundation

/// Encodes and decodes task metadata in the notes field of an EKReminder.
///
/// Format — last line of the notes string:
///   `#tag1 #tag2 @cluster-name [bzpad:UUID]`
///
/// - Tags are bare words prefixed with `#`.
/// - Cluster name is a single `@word` (spaces in cluster names are joined with `-`).
/// - The bzpad UUID is bracketed: `[bzpad:<uuid>]`.
/// - User-visible notes live on all lines *before* the metadata line.
///
/// Rules:
/// - If there are no tags, no cluster, and no UUID, the metadata line is omitted.
/// - The encoder never touches lines other than the last one.
/// - Round-tripping through Reminders.app is safe: the metadata line is
///   human-readable and survives iCloud sync unchanged.
public enum NotesEncoder {

    // MARK: – Public types

    public struct Metadata: Equatable {
        public var userNotes: String?
        public var tags: [String]
        public var clusterName: String?
        public var taskID: UUID?

        public init(
            userNotes: String? = nil,
            tags: [String] = [],
            clusterName: String? = nil,
            taskID: UUID? = nil
        ) {
            self.userNotes   = userNotes
            self.tags        = tags
            self.clusterName = clusterName
            self.taskID      = taskID
        }
    }

    // MARK: – Regex fragments

    private static let tagPattern     = #"#([\w-]+)"#
    private static let clusterPattern = #"@([\w-]+)"#
    private static let uuidPattern    = #"\[bzpad:([0-9A-Fa-f-]{36})\]"#

    // MARK: – Encode

    /// Returns the full notes string (userNotes + metadata line), or `nil` if everything is empty.
    public static func encode(_ meta: Metadata) -> String? {
        var parts: [String] = []

        for tag in meta.tags         { parts.append("#\(tag)") }
        if let cluster = meta.clusterName, !cluster.isEmpty {
            parts.append("@\(cluster.replacingOccurrences(of: " ", with: "-"))")
        }
        if let id = meta.taskID      { parts.append("[bzpad:\(id.uuidString)]") }

        let metaLine = parts.joined(separator: " ")

        var lines: [String] = []
        if let notes = meta.userNotes, !notes.isEmpty { lines.append(notes) }
        if !metaLine.isEmpty { lines.append(metaLine) }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: – Decode

    /// Parses `notes` (EKReminder.notes) back into structured metadata.
    public static func decode(_ notes: String?) -> Metadata {
        guard let notes, !notes.isEmpty else { return Metadata() }

        let lines = notes.components(separatedBy: "\n")

        // Check if the last line looks like our metadata (contains #, @, or [bzpad:…])
        let lastLine = lines.last ?? ""
        let isMetaLine = lastLine.contains("#") || lastLine.contains("@") || lastLine.contains("[bzpad:")

        let metaLine  = isMetaLine ? lastLine : nil
        let bodyLines = isMetaLine ? lines.dropLast() : lines[...]
        let userNotes = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard let meta = metaLine else {
            return Metadata(userNotes: userNotes.isEmpty ? nil : userNotes)
        }

        // Extract tags
        let tags = matches(of: tagPattern, in: meta, group: 1)

        // Extract cluster name (first @word only)
        let cluster = matches(of: clusterPattern, in: meta, group: 1)
            .first
            .map { $0.replacingOccurrences(of: "-", with: " ") }

        // Extract UUID
        let taskID = matches(of: uuidPattern, in: meta, group: 1)
            .first
            .flatMap { UUID(uuidString: $0) }

        return Metadata(
            userNotes:   userNotes.isEmpty ? nil : userNotes,
            tags:        tags,
            clusterName: cluster,
            taskID:      taskID
        )
    }

    // MARK: – Helpers

    private static func matches(of pattern: String, in string: String, group: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range   = NSRange(string.startIndex..., in: string)
        let results = regex.matches(in: string, range: range)
        return results.compactMap { result -> String? in
            guard result.numberOfRanges > group,
                  let r = Range(result.range(at: group), in: string) else { return nil }
            return String(string[r])
        }
    }
}
