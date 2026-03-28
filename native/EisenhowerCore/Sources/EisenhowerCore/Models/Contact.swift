import Foundation
import GRDB

// MARK: – Contact

public struct Contact: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var role: String?
    public var area: String?
    /// How often to check in, in days (e.g. 14 = every two weeks).
    public var cadenceDays: Int
    /// Date of the most recent meeting. nil = never met.
    public var lastMeetingDate: Date?
    /// Running agenda / topics for the next 1:1.
    public var notes: String
    /// UUID of the active Schedule-quadrant reminder task, if one exists.
    public var reminderTaskId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        role: String? = nil,
        area: String? = nil,
        cadenceDays: Int = 14,
        lastMeetingDate: Date? = nil,
        notes: String = "",
        reminderTaskId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.area = area
        self.cadenceDays = cadenceDays
        self.lastMeetingDate = lastMeetingDate
        self.notes = notes
        self.reminderTaskId = reminderTaskId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Next date at which a reminder should be generated.
    /// Returns `createdAt` (immediately due) if the contact has never been met.
    public var nextReminderDate: Date {
        guard let last = lastMeetingDate else { return createdAt }
        return Calendar.current.date(byAdding: .day, value: cadenceDays, to: last) ?? last
    }

    public var isDue: Bool {
        nextReminderDate <= Date()
    }
}

// MARK: – GRDB persistence

extension Contact: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "contacts"

    public func encode(to container: inout PersistenceContainer) throws {
        container["id"]              = id.uuidString
        container["name"]            = name
        container["role"]            = role
        container["area"]            = area
        container["cadenceDays"]     = cadenceDays
        container["lastMeetingDate"] = lastMeetingDate
        container["notes"]           = notes
        container["reminderTaskId"]  = reminderTaskId?.uuidString
        container["createdAt"]       = createdAt
        container["updatedAt"]       = updatedAt
    }

    public init(row: Row) throws {
        id              = UUID(uuidString: row["id"] as String) ?? UUID()
        name            = row["name"]
        role            = row["role"]
        area            = row["area"]
        cadenceDays     = row["cadenceDays"]
        lastMeetingDate = row["lastMeetingDate"]
        notes           = row["notes"] ?? ""
        let rtStr: String? = row["reminderTaskId"]
        reminderTaskId  = rtStr.flatMap { UUID(uuidString: $0) }
        createdAt       = row["createdAt"]
        updatedAt       = row["updatedAt"]
    }
}

// MARK: – Session

/// A completed 1:1 meeting record. ON DELETE CASCADE from Contact.
public struct Session: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var contactId: UUID
    public var date: Date
    public var notes: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        contactId: UUID,
        date: Date,
        notes: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.contactId = contactId
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
    }
}

extension Session: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sessions"

    public func encode(to container: inout PersistenceContainer) throws {
        container["id"]        = id.uuidString
        container["contactId"] = contactId.uuidString
        container["date"]      = date
        container["notes"]     = notes
        container["createdAt"] = createdAt
    }

    public init(row: Row) throws {
        id        = UUID(uuidString: row["id"] as String) ?? UUID()
        contactId = UUID(uuidString: row["contactId"] as String) ?? UUID()
        date      = row["date"]
        notes     = row["notes"] ?? ""
        createdAt = row["createdAt"]
    }
}
