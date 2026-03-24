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

    public init(repository: any TaskRepositoryProtocol = EventKitRepository()) {
        self.repo = repository
        _Concurrency.Task { await self.setup() }
    }

    // MARK: – Setup

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
        for q in Quadrant.allCases {
            byQuadrant[q] = (try? repo.fetchActive(in: q)) ?? []
        }
        tasksByQuadrant = byQuadrant
        archivedTasks   = (try? repo.fetchArchived()) ?? []
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

    public func updateTask(_ task: Task) {
        var updated = task
        updated.updatedAt = Date()
        pushUndo()
        do {
            try repo.update(updated)
            replaceInQuadrant(updated)
        } catch {
            print("[TaskStore] updateTask failed: \(error)")
        }
    }

    public func deleteTask(id: UUID) {
        pushUndo()
        do {
            try repo.delete(id: id)
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
            removeFromAllQuadrants(id: id)
            task.quadrant  = quadrant
            task.updatedAt = Date()
            tasksByQuadrant[quadrant, default: []].append(task)
        } catch {
            print("[TaskStore] moveTask failed: \(error)")
        }
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
        updateTask(task)
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
