import Foundation
import GRDB

/// Persists manual task ordering within each quadrant.
///
/// Positions are stored separately from EventKit task data in GRDB.
/// When tasks are loaded from EventKit, they are sorted by ascending position.
/// Tasks with no position entry are sorted after positioned tasks (insertion order).
@MainActor
public final class TaskPositionStore {

    private let db: AppDatabase

    public init(db: AppDatabase = .shared) {
        self.db = db
    }

    // MARK: – Read

    /// Returns a map of taskId → position for a given quadrant.
    /// Lower position = higher in the list.
    public func positions(for quadrant: Quadrant) -> [String: Int] {
        let rows = (try? db.pool.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, position FROM task_positions WHERE quadrant = ? ORDER BY position",
                arguments: [quadrant.rawValue]
            )
        }) ?? []
        var result: [String: Int] = [:]
        for row in rows {
            result[row["id"]] = row["position"]
        }
        return result
    }

    // MARK: – Write

    /// Saves the ordered list of task IDs for a quadrant.
    /// The index in the array becomes the `position` value.
    public func saveOrder(_ orderedIds: [String], quadrant: Quadrant) {
        try? db.pool.write { db in
            // Delete old positions for this quadrant
            try db.execute(
                sql: "DELETE FROM task_positions WHERE quadrant = ?",
                arguments: [quadrant.rawValue]
            )
            // Insert new positions
            for (index, id) in orderedIds.enumerated() {
                try db.execute(
                    sql: "INSERT INTO task_positions (id, quadrant, position) VALUES (?, ?, ?)",
                    arguments: [id, quadrant.rawValue, index]
                )
            }
        }
    }

    /// Removes position entries for tasks that no longer exist.
    /// Call after loading from EventKit to prune stale entries.
    public func pruneStale(keeping validIds: Set<String>) {
        try? db.pool.write { db in
            let all = try String.fetchAll(
                db,
                sql: "SELECT id FROM task_positions"
            )
            let stale = all.filter { !validIds.contains($0) }
            for id in stale {
                try db.execute(
                    sql: "DELETE FROM task_positions WHERE id = ?",
                    arguments: [id]
                )
            }
        }
    }

    /// Removes position entries for specific task IDs (e.g. on delete).
    public func remove(ids: [String]) {
        guard !ids.isEmpty else { return }
        try? db.pool.write { db in
            for id in ids {
                try db.execute(
                    sql: "DELETE FROM task_positions WHERE id = ?",
                    arguments: [id]
                )
            }
        }
    }
}
