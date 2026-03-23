import Foundation
import GRDB

/// CRUD operations for tasks backed by SQLite/GRDB. All methods run on the GRDB writer/reader queue.
public struct TaskRepository: TaskRepositoryProtocol {

    private let db: AppDatabase

    public init(database: AppDatabase = .shared) {
        self.db = database
    }

    // MARK: – Reads

    public func fetchAll() throws -> [Task] {
        try db.pool.read { db in
            try Task.order(Task.Columns.createdAt).fetchAll(db)
        }
    }

    public func fetchActive(in quadrant: Quadrant) throws -> [Task] {
        try db.pool.read { db in
            try Task
                .filter(Task.Columns.quadrant == quadrant.rawValue)
                .filter(Task.Columns.isArchived == false)
                .order(Task.Columns.createdAt)
                .fetchAll(db)
        }
    }

    public func fetchArchived() throws -> [Task] {
        try db.pool.read { db in
            try Task
                .filter(Task.Columns.isArchived == true)
                .order(Task.Columns.completedAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetches tasks modified after `date` — used by CloudKit sync to find dirty records.
    public func fetchModified(after date: Date) throws -> [Task] {
        try db.pool.read { db in
            try Task
                .filter(Task.Columns.updatedAt > date)
                .fetchAll(db)
        }
    }

    // MARK: – Writes

    @discardableResult
    public func insert(_ task: Task) throws -> Task {
        let task = task
        try db.pool.write { db in
            try task.insert(db)
        }
        return task
    }

    public func update(_ task: Task) throws {
        let task = task
        try db.pool.write { db in
            try task.update(db)
        }
    }

    public func delete(id: UUID) throws {
        try db.pool.write { db in
            try Task.deleteOne(db, key: id.uuidString)
        }
    }

    public func deleteAll(ids: [UUID]) throws {
        let keys = ids.map(\.uuidString)
        try db.pool.write { db in
            try Task.deleteAll(db, keys: keys)
        }
    }

    public func complete(id: UUID) throws {
        try db.pool.write { db in
            try db.execute(
                sql: """
                    UPDATE tasks
                       SET isArchived = 1, completedAt = ?, updatedAt = ?
                     WHERE id = ?
                """,
                arguments: [Date(), Date(), id.uuidString]
            )
        }
    }

    public func move(id: UUID, to quadrant: Quadrant) throws {
        try db.pool.write { db in
            try db.execute(
                sql: "UPDATE tasks SET quadrant = ?, updatedAt = ? WHERE id = ?",
                arguments: [quadrant.rawValue, Date(), id.uuidString]
            )
        }
    }

    // MARK: – Observation (for SwiftUI)

    /// Returns a ValueObservation that emits all active tasks whenever the table changes.
    public func observeActive(in quadrant: Quadrant) -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        ValueObservation.tracking { db in
            try Task
                .filter(Task.Columns.quadrant == quadrant.rawValue)
                .filter(Task.Columns.isArchived == false)
                .order(Task.Columns.createdAt)
                .fetchAll(db)
        }
    }
}
