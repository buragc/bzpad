import Foundation

/// Common interface satisfied by both the GRDB-backed repository (tests / future)
/// and the EventKit-backed repository (production).
///
/// `@MainActor` because `TaskStore` (the sole caller) is `@MainActor`, and
/// EventKitRepository maintains a mutable main-actor cache.
@MainActor
public protocol TaskRepositoryProtocol {

    // MARK: – Reads

    func fetchActive(in quadrant: Quadrant) throws -> [Task]
    func fetchArchived() throws -> [Task]
    func fetchModified(after date: Date) throws -> [Task]

    // MARK: – Writes

    @discardableResult
    func insert(_ task: Task) throws -> Task
    func update(_ task: Task) throws
    func delete(id: UUID) throws
    func deleteAll(ids: [UUID]) throws
    func complete(id: UUID) throws
    func move(id: UUID, to quadrant: Quadrant) throws

    // MARK: – Lifecycle (optional — default no-ops for GRDB)

    /// Request access to the backing store (EventKit permissions).
    /// Returns `true` if access was granted.
    func requestAccess() async throws -> Bool

    /// Force-reload data from the backing store into the local cache.
    func reload() async

    /// Subscribe to external changes (e.g. user edits in Reminders.app).
    /// `handler` is called on the main actor.
    func observeChanges(handler: @MainActor @Sendable @escaping () -> Void)
}

// MARK: – Default no-ops (GRDB doesn't need these)

public extension TaskRepositoryProtocol {
    func requestAccess() async throws -> Bool { true }
    func reload() async {}
    func observeChanges(handler: @MainActor @Sendable @escaping () -> Void) {}
}
