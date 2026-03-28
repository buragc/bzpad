import Foundation
import Observation

/// Central state container for the app. Observable so SwiftUI views re-render automatically.
@MainActor
@Observable
public final class TaskStore {

    // MARK: – State

    public private(set) var inboxItems: [InboxItem] = []

    public private(set) var tasksByQuadrant: [Quadrant: [Task]] = [
        .doFirst:   [],
        .schedule:  [],
        .delegate:  [],
        .eliminate: [],
    ]
    public private(set) var archivedTasks: [Task] = []
    public private(set) var permissionDenied: Bool = false

    public var selectedIds: Set<UUID> = []
    public var focusedId: UUID? = nil
    public var editingId: UUID? = nil
    public var searchText: String = ""
    public var filterQuadrants: Set<Quadrant> = []
    public var filterTags: [String] = []
    public var viewMode: ViewMode = .matrix
    public var darkMode: DarkMode = .system
    public var isFocusMode: Bool = false         // Q1 + overdue only

    private var undoStack: [[Quadrant: [Task]]] = []    // max 50 snapshots

    private let repo: any TaskRepositoryProtocol
    private let positionStore: TaskPositionStore

    public init(
        repository: any TaskRepositoryProtocol = EventKitRepository(),
        positionDB: AppDatabase = .shared
    ) {
        self.repo = repository
        self.positionStore = TaskPositionStore(db: positionDB)
        _Concurrency.Task { await self.setup() }
    }

    // MARK: – Setup

    /// Re-runs setup if permission was previously denied. Call when the app regains focus
    /// so returning from System Settings automatically clears the denied state.
    public func retryAccessIfNeeded() {
        guard permissionDenied else { return }
        permissionDenied = false
        _Concurrency.Task { await self.setup() }
    }

    private func loadInbox() async {
        let raw = await repo.fetchOtherReminders()
        inboxItems = raw.map { InboxItem(id: $0.id, title: $0.title) }
    }

    private func setup() async {
        do {
            let granted = try await repo.requestAccess()
            if !granted {
                permissionDenied = true
                return
            }
        } catch {
            permissionDenied = true
            print("[TaskStore] requestAccess failed: \(error)")
            return
        }

        await repo.reload()
        loadFromCache()
        await loadInbox()

        repo.observeChanges { [weak self] in
            guard let self else { return }
            self.loadFromCache()
            _Concurrency.Task { await self.loadInbox() }
        }
    }

    // MARK: – Load from cache

    private func loadFromCache() {
        var byQuadrant: [Quadrant: [Task]] = [:]
        var allIds = Set<String>()
        for q in Quadrant.allCases {
            let tasks = (try? repo.fetchActive(in: q)) ?? []
            let pos   = positionStore.positions(for: q)
            // Sort: tasks with a stored position come first (by position ascending),
            // then unpositioned tasks sorted by createdAt (EventKit insertion order).
            byQuadrant[q] = tasks.sorted { a, b in
                switch (pos[a.id.uuidString], pos[b.id.uuidString]) {
                case let (.some(pa), .some(pb)): return pa < pb
                case (.some, .none):             return true
                case (.none, .some):             return false
                case (.none, .none):             return a.createdAt < b.createdAt
                }
            }
            tasks.forEach { allIds.insert($0.id.uuidString) }
        }
        tasksByQuadrant = byQuadrant
        archivedTasks   = (try? repo.fetchArchived()) ?? []
        positionStore.pruneStale(keeping: allIds)
    }

    // MARK: – CRUD

    public func addTask(title: String, quadrant: Quadrant? = nil) {
        let dueDate    = DateParser.parse(title)
        let cleanTitle = DateParser.strippingDatePhrases(
            from: TagExtractor.strippingHashtags(from: title)
        )
        let tags     = TagExtractor.extract(from: title)
        let detected = quadrant ?? QuadrantDetector.detect(from: title)

        let task = Task(
            title:    cleanTitle.isEmpty ? title : cleanTitle,
            quadrant: detected,
            dueDate:  dueDate,
            tags:     tags,
            source:   dueDate != nil ? .parsed : .manual
        )

        pushUndo()

        do {
            try repo.insert(task)
            tasksByQuadrant[detected, default: []].append(task)
        } catch {
            print("[TaskStore] addTask failed: \(error)")
        }
    }

    public func updateTask(_ task: Task) throws {
        var updated = task
        updated.updatedAt = Date()
        pushUndo()
        do {
            try repo.update(updated)
            replaceInQuadrant(updated)
        } catch {
            undoStack.removeLast()
            throw error
        }
    }

    public func deleteTask(id: UUID) {
        pushUndo()
        do {
            try repo.delete(id: id)
            positionStore.remove(ids: [id.uuidString])
            removeFromAllQuadrants(id: id)
            selectedIds.remove(id)
            if focusedId == id { focusedId = nil }
        } catch {
            print("[TaskStore] deleteTask failed: \(error)")
        }
    }

    public func deleteTasks(ids: Set<UUID>) {
        pushUndo()
        do {
            try repo.deleteAll(ids: Array(ids))
            for id in ids { removeFromAllQuadrants(id: id) }
            selectedIds.subtract(ids)
            if let focused = focusedId, ids.contains(focused) { focusedId = nil }
        } catch {
            print("[TaskStore] deleteTasks failed: \(error)")
        }
    }

    public func completeTask(id: UUID) {
        pushUndo()
        do {
            try repo.complete(id: id)
            if let task = findTask(id: id) {
                var completed = task
                completed.completedAt = Date()
                completed.isArchived  = true
                removeFromAllQuadrants(id: id)
                archivedTasks.insert(completed, at: 0)
            }
            selectedIds.remove(id)
        } catch {
            print("[TaskStore] completeTask failed: \(error)")
        }
    }

    public func moveTask(id: UUID, to quadrant: Quadrant) {
        guard var task = findTask(id: id), task.quadrant != quadrant else { return }
        pushUndo()
        do {
            try repo.move(id: id, to: quadrant)
            // Remove old position (task appends at end of new quadrant)
            positionStore.remove(ids: [id.uuidString])
            removeFromAllQuadrants(id: id)
            task.quadrant  = quadrant
            task.updatedAt = Date()
            tasksByQuadrant[quadrant, default: []].append(task)
        } catch {
            print("[TaskStore] moveTask failed: \(error)")
        }
    }

    /// Moves the focused task to the next/previous quadrant in clockwise order.
    public func moveFocusedTask(clockwise: Bool) {
        guard let id = focusedId, let task = findTask(id: id) else { return }
        moveTask(id: id, to: task.quadrant.next(clockwise: clockwise))
    }

    /// Reorders a task within its quadrant by swapping it with its neighbor.
    /// Direction: true = move toward index 0 (up), false = move toward last (down).
    public func reorderTask(id: UUID, up: Bool) {
        guard let task = findTask(id: id),
              var list = tasksByQuadrant[task.quadrant] else { return }
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        let target = up ? idx - 1 : idx + 1
        guard list.indices.contains(target) else { return }  // already at boundary
        pushUndo()
        list.swapAt(idx, target)
        tasksByQuadrant[task.quadrant] = list
        // Persist the new order
        positionStore.saveOrder(list.map(\.id.uuidString), quadrant: task.quadrant)
    }

    /// Moves keyboard focus to the previous/next task in the given quadrant.
    /// Wraps at boundaries (stops at first/last — no wrap-around).
    public func moveFocus(in quadrant: Quadrant, up: Bool) {
        let tasks = activeTasks(in: quadrant)
        guard !tasks.isEmpty else { return }
        if let current = focusedId, let idx = tasks.firstIndex(where: { $0.id == current }) {
            let next = up ? idx - 1 : idx + 1
            if tasks.indices.contains(next) {
                focusedId = tasks[next].id
            }
        } else {
            // No current focus — select first (up) or last (down)
            focusedId = up ? tasks.first?.id : tasks.last?.id
        }
    }

    /// Deletes the currently focused task.
    public func deleteFocused() {
        guard let id = focusedId else { return }
        deleteTask(id: id)
    }

    /// Moves an inbox item (non-bzpad reminder) into `quadrant`, deleting the original.
    public func categorizeInboxItem(id: String, quadrant: Quadrant) {
        guard let item = inboxItems.first(where: { $0.id == id }) else { return }
        pushUndo()
        do {
            let task = try repo.adoptExternalReminder(ekID: id, title: item.title, quadrant: quadrant)
            tasksByQuadrant[task.quadrant, default: []].append(task)
            inboxItems.removeAll { $0.id == id }
        } catch {
            print("[TaskStore] categorizeInboxItem failed: \(error)")
        }
    }

    public func archiveTasks(ids: Set<UUID>) {
        pushUndo()
        for id in ids { completeTask(id: id) }
    }

    // MARK: – Cluster management

    /// All distinct cluster names across all active quadrants.
    public var allClusters: [String] {
        var seen = Set<String>()
        for tasks in tasksByQuadrant.values {
            for task in tasks {
                if let name = task.clusterName { seen.insert(name) }
            }
        }
        return seen.sorted()
    }

    /// Assign `clusterName` to a task (nil to uncluster).
    public func setCluster(taskId: UUID, name: String?) {
        guard var task = findTask(id: taskId) else { return }
        task.clusterName = name
        try? updateTask(task)
    }

    // MARK: – Undo

    public func undo() {
        guard !undoStack.isEmpty else { return }
        tasksByQuadrant = undoStack.removeLast()
        archivedTasks   = (try? repo.fetchArchived()) ?? []
    }

    private func pushUndo() {
        undoStack.append(tasksByQuadrant)
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    // MARK: – Filtering

    public func activeTasks(in quadrant: Quadrant) -> [Task] {
        var tasks = tasksByQuadrant[quadrant] ?? []
        if isFocusMode && quadrant != .doFirst {
            tasks = tasks.filter {
                UrgencyCalculator.level(dueDate: $0.dueDate) == .overdue
            }
        }
        return filteredTasks(tasks)
    }

    public func filteredTasks(_ tasks: [Task]) -> [Task] {
        tasks.filter { task in
            if !searchText.isEmpty,
               !task.title.lowercased().contains(searchText.lowercased()) { return false }
            if !filterQuadrants.isEmpty,
               !filterQuadrants.contains(task.quadrant) { return false }
            if !filterTags.isEmpty,
               !filterTags.contains(where: { task.tags.contains($0) }) { return false }
            return true
        }
    }

    public var allTags: [String] {
        var seen = Set<String>()
        for tasks in tasksByQuadrant.values {
            for task in tasks { task.tags.forEach { seen.insert($0) } }
        }
        return seen.sorted()
    }

    // MARK: – Selection

    public func clearSelection() { selectedIds = [] }

    // MARK: – Reminder task support (used by ContactStore)

    /// Returns true if a task with the given id exists in any active (non-archived) quadrant.
    public func taskIsActive(id: UUID) -> Bool {
        tasksByQuadrant.values.contains { $0.contains { $0.id == id } }
    }

    /// Creates a task directly in the Schedule quadrant with embedded notes.
    /// Bypasses NLP parsing — title and quadrant are taken as-is.
    /// Returns the new task's UUID, or throws if the repository fails.
    @discardableResult
    public func addReminderTask(title: String, notes: String?) throws -> UUID {
        let task = Task(title: title, quadrant: .schedule, userNotes: notes, source: .manual)
        try repo.insert(task)
        tasksByQuadrant[.schedule, default: []].append(task)
        return task.id
    }

    // MARK: – Helpers

    private func findTask(id: UUID) -> Task? {
        for tasks in tasksByQuadrant.values {
            if let t = tasks.first(where: { $0.id == id }) { return t }
        }
        return nil
    }

    private func replaceInQuadrant(_ task: Task) {
        guard var list = tasksByQuadrant[task.quadrant] else { return }
        if let idx = list.firstIndex(where: { $0.id == task.id }) {
            list[idx] = task
            tasksByQuadrant[task.quadrant] = list
        }
    }

    private func removeFromAllQuadrants(id: UUID) {
        for quadrant in tasksByQuadrant.keys {
            tasksByQuadrant[quadrant]?.removeAll(where: { $0.id == id })
        }
    }
}

// MARK: – Supporting types

public struct InboxItem: Identifiable, Sendable {
    public let id: String    // EK calendarItemIdentifier
    public let title: String
}

public enum ViewMode: String, Codable, Sendable {
    case matrix
    case archive
}

public enum DarkMode: String, Codable, Sendable {
    case system
    case light
    case dark
}
