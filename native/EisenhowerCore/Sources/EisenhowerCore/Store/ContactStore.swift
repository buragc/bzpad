import Foundation
import GRDB
import Observation

// MARK: – Protocol

/// Minimal capability used by ContactStore.checkReminders.
/// TaskStore conforms; test mocks also conform.
@MainActor
public protocol ReminderTaskStoring: AnyObject {
    func taskIsActive(id: UUID) -> Bool
    @discardableResult
    func addReminderTask(title: String, notes: String?) throws -> UUID
}

// MARK: – ContactStore

@MainActor
@Observable
public final class ContactStore {

    public private(set) var contacts: [Contact] = []

    private let db: AppDatabase

    public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
        load()
    }

    // MARK: – Load

    private func load() {
        contacts = (try? db.pool.read { db in
            try Contact.order(Column("name")).fetchAll(db)
        }) ?? []
    }

    // MARK: – CRUD

    public func addContact(_ contact: Contact) throws {
        var c = contact
        c.createdAt = Date()
        c.updatedAt = Date()
        try db.pool.write { db in try c.insert(db) }
        contacts.append(c)
        sortContacts()
    }

    public func updateContact(_ contact: Contact) throws {
        var c = contact
        c.updatedAt = Date()
        try db.pool.write { db in try c.update(db) }
        if let idx = contacts.firstIndex(where: { $0.id == c.id }) {
            contacts[idx] = c
        }
        sortContacts()
    }

    public func deleteContact(id: UUID) throws {
        try db.pool.write { db in
            _ = try Contact
                .filter(Column("id") == id.uuidString)
                .deleteAll(db)
        }
        contacts.removeAll { $0.id == id }
    }

    public func contact(id: UUID) throws -> Contact? {
        try db.pool.read { db in
            try Contact
                .filter(Column("id") == id.uuidString)
                .fetchOne(db)
        }
    }

    // MARK: – Sessions

    public func recordSession(_ session: Session) throws {
        try db.pool.write { db in try session.insert(db) }
    }

    public func sessions(for contactId: UUID) throws -> [Session] {
        try db.pool.read { db in
            try Session
                .filter(Column("contactId") == contactId.uuidString)
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }

    // MARK: – Mark meeting done

    /// Records a completed meeting, resets the reminder timer, and clears the active reminder ID.
    public func markMeetingDone(contactId: UUID, date: Date, notes: String) throws {
        let session = Session(contactId: contactId, date: date, notes: notes)
        try recordSession(session)

        guard var c = try contact(id: contactId) else { return }
        c.lastMeetingDate = date
        c.reminderTaskId  = nil
        try updateContact(c)
    }

    // MARK: – Reminder generation

    /// Called on app launch. For each due contact with no active reminder task, creates a
    /// "1:1 with [Name]" task in the Schedule quadrant. If task creation fails for one contact,
    /// logs the error and continues to the next.
    public func checkReminders(using taskStore: any ReminderTaskStoring) {
        for contact in contacts where contact.isDue {
            // Skip if an active reminder task already exists for this contact
            if let existingId = contact.reminderTaskId,
               taskStore.taskIsActive(id: existingId) {
                continue
            }

            // Embed last session notes, truncated to 200 chars
            let rawNotes = (try? sessions(for: contact.id).first?.notes) ?? ""
            let embedded: String? = rawNotes.isEmpty ? nil
                : rawNotes.count > 200 ? String(rawNotes.prefix(200)) + "…"
                : rawNotes

            do {
                let taskId = try taskStore.addReminderTask(
                    title: "1:1 with \(contact.name)",
                    notes: embedded
                )
                var updated = contact
                updated.reminderTaskId = taskId
                try? updateContact(updated)
            } catch {
                print("[ContactStore] checkReminders: failed to create task for \(contact.name): \(error)")
            }
        }
    }

    // MARK: – Private

    private func sortContacts() {
        contacts.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

// MARK: – TaskStore conformance

extension TaskStore: ReminderTaskStoring {}
