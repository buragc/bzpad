import Foundation
import EventKit

/// EventKit-backed task repository. Uses Apple Reminders as the persistence layer,
/// giving us iCloud sync for free.
///
/// Architecture:
/// - 4 EKCalendar lists, one per Eisenhower quadrant ("bzpad – Do First", etc.)
/// - Each EKReminder ↔ one Task; UUID embedded in notes as `[bzpad:UUID]`
/// - Metadata line in notes encodes tags, cluster, and UUID via `NotesEncoder`
/// - A local cache (`activeCache`, `archivedCache`) is kept in sync so reads are synchronous
/// - `reload()` is the only truly async operation (wraps EK's callback API)
/// - `observeChanges` listens to `.EKEventStoreChanged` for Reminders.app edits
@MainActor
public final class EventKitRepository: TaskRepositoryProtocol {

    // MARK: – State

    private let ekStore = EKEventStore()

    private var activeCache:   [Quadrant: [Task]] = [:]
    private var archivedCache: [Task] = []
    private var ekIDMap: [UUID: String] = [:]
    private var observer: NSObjectProtocol?

    public init() {}

    // MARK: – Calendar names (dynamic prefix from user settings)

    private var listPrefix: String {
        UserDefaults.standard.string(forKey: "reminderListPrefix") ?? "bzpad"
    }

    private func calendarName(for quadrant: Quadrant) -> String {
        let suffix: String
        switch quadrant {
        case .doFirst:   suffix = "Do First"
        case .schedule:  suffix = "Schedule"
        case .delegate:  suffix = "Delegate"
        case .eliminate: suffix = "Eliminate"
        }
        return "\(listPrefix) – \(suffix)"
    }

    /// All calendar names currently managed by this repository.
    private var allManagedCalendarNames: Set<String> {
        Set(Quadrant.allCases.map { calendarName(for: $0) })
    }

    // MARK: – TaskRepositoryProtocol: Lifecycle

    public func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await ekStore.requestFullAccessToReminders()
        } else {
            return try await withCheckedThrowingContinuation { cont in
                ekStore.requestAccess(to: .reminder) { granted, error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume(returning: granted) }
                }
            }
        }
    }

    public func reload() async {
        await loadAll()
    }

    public func observeChanges(handler: @MainActor @Sendable @escaping () -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: ekStore,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }
                await self.reload()
                handler()
            }
        }
    }

    // MARK: – TaskRepositoryProtocol: Reads

    public func fetchActive(in quadrant: Quadrant) throws -> [Task] {
        activeCache[quadrant] ?? []
    }

    public func fetchArchived() throws -> [Task] {
        archivedCache
    }

    public func fetchModified(after date: Date) throws -> [Task] {
        let all = activeCache.values.flatMap { $0 } + archivedCache
        return all.filter { $0.updatedAt > date }
    }

    // MARK: – TaskRepositoryProtocol: Writes

    @discardableResult
    public func insert(_ task: Task) throws -> Task {
        let reminder = EKReminder(eventStore: ekStore)
        reminder.calendar = try calendarForWriting(quadrant: task.quadrant)
        apply(task: task, to: reminder)
        try ekStore.save(reminder, commit: true)

        ekIDMap[task.id] = reminder.calendarItemIdentifier
        activeCache[task.quadrant, default: []].append(task)
        return task
    }

    public func update(_ task: Task) throws {
        guard let reminder = ekReminder(for: task.id) else { return }
        reminder.calendar = try calendarForWriting(quadrant: task.quadrant)
        apply(task: task, to: reminder)
        try ekStore.save(reminder, commit: true)
        updateCache(task)
    }

    public func delete(id: UUID) throws {
        if let reminder = ekReminder(for: id) {
            try ekStore.remove(reminder, commit: true)
        }
        ekIDMap.removeValue(forKey: id)
        for q in activeCache.keys { activeCache[q]?.removeAll { $0.id == id } }
        archivedCache.removeAll { $0.id == id }
    }

    public func deleteAll(ids: [UUID]) throws {
        for id in ids { try delete(id: id) }
    }

    public func complete(id: UUID) throws {
        guard let reminder = ekReminder(for: id) else { return }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try ekStore.save(reminder, commit: true)

        for q in activeCache.keys {
            if let idx = activeCache[q]?.firstIndex(where: { $0.id == id }) {
                var t = activeCache[q]![idx]
                t.completedAt = reminder.completionDate
                t.isArchived  = true
                activeCache[q]!.remove(at: idx)
                archivedCache.insert(t, at: 0)
                break
            }
        }
    }

    public func move(id: UUID, to quadrant: Quadrant) throws {
        // Changing `reminder.calendar` on an existing EKReminder triggers
        // REMAccountStorage -isEqual:, which decodes heavy lazy JSON and logs
        // performance warnings. Avoid by deleting the old reminder and creating
        // a fresh one in the target calendar instead.

        // Find cached task data before we touch anything
        var sourceTask: Task?
        for q in activeCache.keys {
            if let t = activeCache[q]?.first(where: { $0.id == id }) {
                sourceTask = t; break
            }
        }
        guard var task = sourceTask else { return }

        // Delete old EK reminder (separate commit so EK doesn't compare accounts)
        if let old = ekReminder(for: id) {
            try ekStore.remove(old, commit: true)
        }

        // Create replacement in the target calendar
        task.quadrant  = quadrant
        task.updatedAt = Date()
        let newReminder = EKReminder(eventStore: ekStore)
        newReminder.calendar = try calendarForWriting(quadrant: quadrant)
        apply(task: task, to: newReminder)
        try ekStore.save(newReminder, commit: true)

        ekIDMap[id] = newReminder.calendarItemIdentifier

        // Update cache
        for q in activeCache.keys {
            if let idx = activeCache[q]?.firstIndex(where: { $0.id == id }) {
                activeCache[q]!.remove(at: idx)
                break
            }
        }
        activeCache[quadrant, default: []].append(task)
    }

    // MARK: – TaskRepositoryProtocol: Inbox adoption

    /// Moves an existing non-bzpad reminder into the target bzpad quadrant list.
    /// Deletes the original EK reminder and creates a replacement with bzpad metadata.
    @discardableResult
    public func adoptExternalReminder(ekID: String, title: String, quadrant: Quadrant) throws -> Task {
        // Look up the original reminder — may or may not be fetchable at this point
        let original = ekStore.calendarItem(withIdentifier: ekID) as? EKReminder

        // Preserve due date from the original if available
        var dueDate: Date?
        if let comps = original?.dueDateComponents {
            dueDate = Calendar.current.date(from: comps)
        }

        // Apply the same smart parsing addTask uses
        let tags       = TagExtractor.extract(from: title)
        let cleanTitle = DateParser.strippingDatePhrases(
            from: TagExtractor.strippingHashtags(from: title)
        )
        if dueDate == nil { dueDate = DateParser.parse(title) }

        let task = Task(
            id:        UUID(),
            title:     cleanTitle.isEmpty ? title : cleanTitle,
            quadrant:  quadrant,
            dueDate:   dueDate,
            createdAt: original?.creationDate ?? Date(),
            updatedAt: Date(),
            tags:      tags,
            source:    .manual
        )

        // Delete from original list (same delete-then-recreate pattern as move())
        if let original {
            try ekStore.remove(original, commit: true)
        }

        // Create in the target bzpad list
        let newReminder = EKReminder(eventStore: ekStore)
        newReminder.calendar = try calendarForWriting(quadrant: quadrant)
        apply(task: task, to: newReminder)
        try ekStore.save(newReminder, commit: true)

        ekIDMap[task.id] = newReminder.calendarItemIdentifier
        activeCache[quadrant, default: []].append(task)
        return task
    }

    public func fetchOtherReminders() async -> [(id: String, title: String)] {
        let managed = allManagedCalendarNames
        let otherCals = ekStore.calendars(for: .reminder)
            .filter { !managed.contains($0.title) }
        guard !otherCals.isEmpty else { return [] }

        let predicate = ekStore.predicateForReminders(in: otherCals)
        return await withCheckedContinuation { cont in
            ekStore.fetchReminders(matching: predicate) { results in
                DispatchQueue.main.async {
                    let items = (results ?? [])
                        .filter { !$0.isCompleted }
                        .compactMap { r -> (id: String, title: String)? in
                            guard let title = r.title, !title.isEmpty else { return nil }
                            return (id: r.calendarItemIdentifier, title: title)
                        }
                    cont.resume(returning: items)
                }
            }
        }
    }

    // MARK: – Private: Load

    /// Sendable snapshot of EKReminder — read on whatever thread EK delivers,
    /// then safely transferred across the actor boundary.
    private struct ReminderSnapshot: Sendable {
        let ekID: String
        let title: String?
        let notes: String?
        let dueDateComponents: DateComponents?
        let creationDate: Date?
        let lastModifiedDate: Date?
        let completionDate: Date?
        let isCompleted: Bool

        init(_ r: EKReminder) {
            ekID               = r.calendarItemIdentifier
            title              = r.title
            notes              = r.notes
            dueDateComponents  = r.dueDateComponents
            creationDate       = r.creationDate
            lastModifiedDate   = r.lastModifiedDate
            completionDate     = r.completionDate
            isCompleted        = r.isCompleted
        }
    }

    private func loadAll() async {
        var newActive:   [Quadrant: [Task]] = Dictionary(
            uniqueKeysWithValues: Quadrant.allCases.map { ($0, []) }
        )
        var newArchived: [Task] = []
        var newEKIDMap:  [UUID: String] = [:]

        for quadrant in Quadrant.allCases {
            // Only fetch from calendars that already exist — don't create them during load.
            // They're created on first insert for a given quadrant.
            guard let cal = existingCalendar(for: quadrant) else { continue }

            let predicate = ekStore.predicateForReminders(in: [cal])

            // EKReminder is not thread-safe. fetchReminders calls its callback on an
            // arbitrary queue, so we bounce back to main before reading any properties.
            let snapshots: [ReminderSnapshot] = await withCheckedContinuation { cont in
                ekStore.fetchReminders(matching: predicate) { results in
                    DispatchQueue.main.async {
                        cont.resume(returning: (results ?? []).map { ReminderSnapshot($0) })
                    }
                }
            }

            for snap in snapshots {
                let task = makeTask(from: snap, quadrant: quadrant)
                newEKIDMap[task.id] = snap.ekID
                if task.isArchived { newArchived.append(task) }
                else               { newActive[quadrant, default: []].append(task) }
            }
        }

        newArchived.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        activeCache   = newActive
        archivedCache = newArchived
        ekIDMap       = newEKIDMap
    }

    // MARK: – Private: Calendar management

    /// Returns an existing managed calendar for `quadrant`, or `nil` if not yet created.
    private func existingCalendar(for quadrant: Quadrant) -> EKCalendar? {
        let name = calendarName(for: quadrant)
        return ekStore.calendars(for: .reminder).first { $0.title == name }
    }

    /// Returns an existing calendar or creates a new one. Throws if unable to save.
    private func calendarForWriting(quadrant: Quadrant) throws -> EKCalendar {
        if let existing = existingCalendar(for: quadrant) { return existing }

        let cal = EKCalendar(for: .reminder, eventStore: ekStore)
        cal.title  = calendarName(for: quadrant)
        cal.source = preferredSource() ?? ekStore.defaultCalendarForNewReminders()?.source

        guard cal.source != nil else {
            throw EventKitError.noSourceAvailable
        }

        try ekStore.saveCalendar(cal, commit: true)
        return cal
    }

    private func preferredSource() -> EKSource? {
        if let s = ekStore.sources.first(where: { $0.sourceType == .calDAV }) { return s }
        if let s = ekStore.sources.first(where: { $0.sourceType == .local })  { return s }
        return nil
    }

    // MARK: – Private: EKReminder ↔ Task

    private func apply(task: Task, to reminder: EKReminder) {
        reminder.title = task.title

        if let due = task.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
        } else {
            reminder.dueDateComponents = nil
        }

        reminder.notes = NotesEncoder.encode(
            NotesEncoder.Metadata(
                userNotes:   task.userNotes,
                tags:        task.tags,
                clusterName: task.clusterName,
                taskID:      task.id
            )
        )

        reminder.isCompleted    = task.isArchived
        reminder.completionDate = task.completedAt
    }

    private func makeTask(from snap: ReminderSnapshot, quadrant: Quadrant) -> Task {
        let meta = NotesEncoder.decode(snap.notes)
        let id   = meta.taskID ?? deterministicUUID(ekID: snap.ekID)

        var dueDate: Date?
        if let comps = snap.dueDateComponents {
            dueDate = Calendar.current.date(from: comps)
        }

        return Task(
            id:          id,
            title:       snap.title ?? "",
            quadrant:    quadrant,
            dueDate:     dueDate,
            createdAt:   snap.creationDate ?? Date(),
            updatedAt:   snap.lastModifiedDate ?? Date(),
            completedAt: snap.completionDate,
            isArchived:  snap.isCompleted,
            tags:        meta.tags,
            clusterName: meta.clusterName,
            userNotes:   meta.userNotes,
            source:      .manual
        )
    }

    private func deterministicUUID(ekID: String) -> UUID {
        var bytes = Array(ekID.utf8.prefix(16))
        while bytes.count < 16 { bytes.append(0) }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0],  bytes[1],  bytes[2],  bytes[3],
            bytes[4],  bytes[5],  bytes[6],  bytes[7],
            bytes[8],  bytes[9],  bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: – Private: Cache helpers

    private func ekReminder(for id: UUID) -> EKReminder? {
        guard let ekID = ekIDMap[id] else { return nil }
        return ekStore.calendarItem(withIdentifier: ekID) as? EKReminder
    }

    private func updateCache(_ task: Task) {
        for q in activeCache.keys {
            if let idx = activeCache[q]?.firstIndex(where: { $0.id == task.id }) {
                if q == task.quadrant {
                    activeCache[q]![idx] = task
                } else {
                    activeCache[q]!.remove(at: idx)
                    activeCache[task.quadrant, default: []].append(task)
                }
                return
            }
        }
        if let idx = archivedCache.firstIndex(where: { $0.id == task.id }) {
            archivedCache[idx] = task
        }
    }
}

// MARK: – Errors

enum EventKitError: Error {
    case noSourceAvailable
}
