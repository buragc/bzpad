import Foundation
import GRDB

// Eisenhower quadrant (1–4).
// 1 = Urgent + Important    (Do First)
// 2 = Not Urgent + Important (Schedule)
// 3 = Urgent + Not Important (Delegate)
// 4 = Not Urgent + Not Important (Eliminate)
public enum Quadrant: Int, Codable, Sendable, DatabaseValueConvertible, CaseIterable, Identifiable {
    case doFirst = 1
    case schedule = 2
    case delegate = 3
    case eliminate = 4

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .doFirst:   return "Urgent & Important"
        case .schedule:  return "Not Urgent & Important"
        case .delegate:  return "Urgent & Not Important"
        case .eliminate: return "Not Urgent & Not Important"
        }
    }

    public var subtitle: String {
        switch self {
        case .doFirst:   return "Do First"
        case .schedule:  return "Schedule"
        case .delegate:  return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }
}

public enum TaskSource: String, Codable, Sendable, DatabaseValueConvertible {
    case manual
    case parsed
}

public enum UrgencyLevel: String, Sendable {
    case overdue
    case critical   // < 24h
    case warning    // 1–2 days
    case soon       // 3–7 days
    case normal     // > 7 days
}

public struct Task: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var quadrant: Quadrant
    public var dueDate: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var isArchived: Bool
    public var tags: [String]
    /// Cluster membership — encoded as `@clusterName` in EventKit notes.
    /// nil means the task is not in a cluster.
    public var clusterName: String?
    /// Free-form notes visible in Reminders.app. Stored before the metadata line.
    public var userNotes: String?
    public var source: TaskSource
    public var parsedUrgency: Double?
    public var parsedImportance: Double?

    public init(
        id: UUID = UUID(),
        title: String,
        quadrant: Quadrant,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        isArchived: Bool = false,
        tags: [String] = [],
        clusterName: String? = nil,
        userNotes: String? = nil,
        source: TaskSource = .manual,
        parsedUrgency: Double? = nil,
        parsedImportance: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.quadrant = quadrant
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.isArchived = isArchived
        self.tags = tags
        self.clusterName = clusterName
        self.userNotes = userNotes
        self.source = source
        self.parsedUrgency = parsedUrgency
        self.parsedImportance = parsedImportance
    }
}

// MARK: – GRDB persistence
extension Task: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseTableName = "tasks"

    public enum Columns {
        public static let id               = Column(CodingKeys.id)
        public static let title            = Column(CodingKeys.title)
        public static let quadrant         = Column(CodingKeys.quadrant)
        public static let dueDate          = Column(CodingKeys.dueDate)
        public static let createdAt        = Column(CodingKeys.createdAt)
        public static let updatedAt        = Column(CodingKeys.updatedAt)
        public static let completedAt      = Column(CodingKeys.completedAt)
        public static let isArchived       = Column(CodingKeys.isArchived)
        public static let tagsJSON         = Column("tagsJSON")
        public static let clusterName      = Column(CodingKeys.clusterName)
        public static let userNotes        = Column(CodingKeys.userNotes)
        public static let source           = Column(CodingKeys.source)
        public static let parsedUrgency    = Column(CodingKeys.parsedUrgency)
        public static let parsedImportance = Column(CodingKeys.parsedImportance)
    }

    public func encode(to container: inout PersistenceContainer) throws {
        container["id"]               = id.uuidString
        container["title"]            = title
        container["quadrant"]         = quadrant.rawValue
        container["dueDate"]          = dueDate
        container["createdAt"]        = createdAt
        container["updatedAt"]        = updatedAt
        container["completedAt"]      = completedAt
        container["isArchived"]       = isArchived
        container["tagsJSON"]         = try String(data: JSONEncoder().encode(tags), encoding: .utf8)
        container["clusterName"]      = clusterName
        container["userNotes"]        = userNotes
        container["source"]           = source.rawValue
        container["parsedUrgency"]    = parsedUrgency
        container["parsedImportance"] = parsedImportance
    }

    public init(row: Row) throws {
        id               = UUID(uuidString: row["id"] as String) ?? UUID()
        title            = row["title"]
        quadrant         = Quadrant(rawValue: row["quadrant"] as Int) ?? .eliminate
        dueDate          = row["dueDate"]
        createdAt        = row["createdAt"]
        updatedAt        = row["updatedAt"]
        completedAt      = row["completedAt"]
        isArchived       = row["isArchived"]
        tags             = (try? JSONDecoder().decode([String].self, from: Data((row["tagsJSON"] as String? ?? "[]").utf8))) ?? []
        clusterName      = row["clusterName"]
        userNotes        = row["userNotes"]
        source           = TaskSource(rawValue: row["source"] as String? ?? "manual") ?? .manual
        parsedUrgency    = row["parsedUrgency"]
        parsedImportance = row["parsedImportance"]
    }
}
