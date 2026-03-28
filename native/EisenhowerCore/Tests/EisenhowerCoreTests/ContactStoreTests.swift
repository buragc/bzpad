import Testing
import Foundation
@testable import EisenhowerCore

// MARK: – Mock

@MainActor
final class MockTaskStore: ReminderTaskStoring {

    struct AddedTask {
        let id: UUID
        let title: String
        let notes: String?
    }

    var addedTasks: [AddedTask] = []
    var activeTaskIds: Set<UUID>
    var failFirstAdd: Bool
    private var addCount = 0

    init(activeTaskIds: Set<UUID> = [], failFirstAdd: Bool = false) {
        self.activeTaskIds = activeTaskIds
        self.failFirstAdd  = failFirstAdd
    }

    func taskIsActive(id: UUID) -> Bool { activeTaskIds.contains(id) }

    func addReminderTask(title: String, notes: String?) throws -> UUID {
        addCount += 1
        if failFirstAdd && addCount == 1 { throw MockError.intentional }
        let id = UUID()
        addedTasks.append(AddedTask(id: id, title: title, notes: notes))
        return id
    }
}

enum MockError: Error { case intentional }

// MARK: – Fixture

extension Contact {
    static func fixture(
        name: String = "Test Contact",
        cadenceDays: Int = 14,
        lastMeetingDate: Date? = nil
    ) -> Contact {
        Contact(
            id: UUID(),
            name: name,
            cadenceDays: cadenceDays,
            lastMeetingDate: lastMeetingDate
        )
    }
}

// MARK: – Tests

@MainActor
@Suite("ContactStore")
struct ContactStoreTests {

    // [A] Empty contacts — no tasks created
    @Test func checkReminders_emptyContacts_noTasksCreated() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let taskStore = MockTaskStore()
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks.isEmpty)
    }

    // [B] Contact not due — skip
    @Test func checkReminders_notDue_noTaskCreated() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: Date())  // just met
        try contactStore.addContact(contact)
        let taskStore = MockTaskStore()
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks.isEmpty)
    }

    // [C] New contact, never met — generates task
    @Test func checkReminders_newContact_generatesTask() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: nil)
        try contactStore.addContact(contact)
        let taskStore = MockTaskStore()
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks.count == 1)
        #expect(taskStore.addedTasks[0].title == "1:1 with \(contact.name)")
    }

    // [D] Cadence expired — generates task
    @Test func checkReminders_cadenceExpired_generatesTask() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let lastMet = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: lastMet)
        try contactStore.addContact(contact)
        let taskStore = MockTaskStore()
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks.count == 1)
    }

    // [E] Already reminded (active task) — no duplicate
    @Test func checkReminders_activeReminder_noDuplicate() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let lastMet = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let existingTaskId = UUID()
        var contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: lastMet)
        contact.reminderTaskId = existingTaskId
        try contactStore.addContact(contact)
        let taskStore = MockTaskStore(activeTaskIds: [existingTaskId])
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks.isEmpty)
    }

    // [F] Previous reminder completed — generates new task
    @Test func checkReminders_completedReminder_generatesNew() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let lastMet = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let completedTaskId = UUID()
        var contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: lastMet)
        contact.reminderTaskId = completedTaskId
        try contactStore.addContact(contact)
        // taskStore has NO active tasks (the old task was completed)
        let taskStore = MockTaskStore(activeTaskIds: [])
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks.count == 1)
    }

    // [G] Task creation throws — continues for other contacts
    @Test func checkReminders_taskCreationFails_continuesOthers() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let c1 = Contact.fixture(name: "Alice", cadenceDays: 14, lastMeetingDate: nil)
        let c2 = Contact.fixture(name: "Bob",   cadenceDays: 14, lastMeetingDate: nil)
        try contactStore.addContact(c1)
        try contactStore.addContact(c2)
        let taskStore = MockTaskStore(failFirstAdd: true)
        contactStore.checkReminders(using: taskStore)
        // Bob's task should still be created despite Alice failing
        #expect(taskStore.addedTasks.count == 1)
        #expect(taskStore.addedTasks[0].title.contains("Bob"))
    }

    // [H] Session notes embedded and truncated
    @Test func checkReminders_embedsSessionNotes_truncated() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let lastMet = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: lastMet)
        try contactStore.addContact(contact)
        let longNotes = String(repeating: "a", count: 300)
        let session = Session(contactId: contact.id, date: lastMet, notes: longNotes)
        try contactStore.recordSession(session)
        let taskStore = MockTaskStore()
        contactStore.checkReminders(using: taskStore)
        let embedded = taskStore.addedTasks[0].notes ?? ""
        #expect(embedded.count <= 203)  // 200 chars + "…"
        #expect(embedded.hasSuffix("…"))
    }

    // [I, J, K, L] markMeetingDone records session + resets fields
    @Test func markMeetingDone_recordsSessionAndResets() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        var contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: nil)
        contact.reminderTaskId = UUID()
        try contactStore.addContact(contact)
        let meetingDate = Date()
        let notes = "Discussed roadmap, headcount"
        try contactStore.markMeetingDone(contactId: contact.id, date: meetingDate, notes: notes)
        let updated = try contactStore.contact(id: contact.id)!
        #expect(updated.lastMeetingDate != nil)
        #expect(Calendar.current.isDate(updated.lastMeetingDate!, inSameDayAs: meetingDate))
        #expect(updated.reminderTaskId == nil)
        let sessions = try contactStore.sessions(for: contact.id)
        #expect(sessions.count == 1)
        #expect(sessions[0].notes == notes)
    }

    // [M] isDue: nil lastMeetingDate → true
    @Test func isDue_nilLastMeeting_returnsTrue() {
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: nil)
        #expect(contact.isDue)
    }

    // [N] isDue: expired cadence → true
    @Test func isDue_expiredCadence_returnsTrue() {
        let lastMet = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: lastMet)
        #expect(contact.isDue)
    }

    // [O] isDue: recent meeting → false
    @Test func isDue_recentMeeting_returnsFalse() {
        let lastMet = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: lastMet)
        #expect(!contact.isDue)
    }

    // [P, Q] deleteContact cascades sessions
    @Test func deleteContact_cascadesSessions() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let contact = Contact.fixture(cadenceDays: 14, lastMeetingDate: nil)
        try contactStore.addContact(contact)
        let session = Session(contactId: contact.id, date: Date(), notes: "Some notes")
        try contactStore.recordSession(session)
        #expect(try contactStore.sessions(for: contact.id).count == 1)
        try contactStore.deleteContact(id: contact.id)
        #expect(try contactStore.sessions(for: contact.id).count == 0)
        #expect(try contactStore.contact(id: contact.id) == nil)
    }

    // [R, S, T] GRDB v3 migration
    @Test func migration_v3_runsClean() throws {
        let db = try AppDatabase.makeEmpty()
        let hasContacts = try db.pool.read { db in try db.tableExists("contacts") }
        let hasSessions = try db.pool.read { db in try db.tableExists("sessions") }
        #expect(hasContacts)
        #expect(hasSessions)
    }

    // Task title format
    @Test func taskTitle_format() throws {
        let db = try AppDatabase.makeEmpty()
        let contactStore = ContactStore(db: db)
        let contact = Contact.fixture(name: "Director of Engineering")
        try contactStore.addContact(contact)
        let taskStore = MockTaskStore()
        contactStore.checkReminders(using: taskStore)
        #expect(taskStore.addedTasks[0].title == "1:1 with Director of Engineering")
    }
}
