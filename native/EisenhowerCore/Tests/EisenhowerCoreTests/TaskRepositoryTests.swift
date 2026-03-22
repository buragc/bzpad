import Testing
import Foundation
@testable import EisenhowerCore

@Suite("TaskRepository")
struct TaskRepositoryTests {

    // Each test gets a fresh isolated database (unique temp file)
    private func makeRepo() throws -> TaskRepository {
        let db = try AppDatabase.makeEmpty()
        return TaskRepository(database: db)
    }

    private func makeTask(
        title: String = "Test task",
        quadrant: Quadrant = .doFirst
    ) -> Task {
        Task(title: title, quadrant: quadrant)
    }

    // MARK: – Insert & Fetch

    @Test("insert then fetchAll returns inserted task")
    func insertAndFetchAll() throws {
        let repo = try makeRepo()
        let task = makeTask(title: "Buy oat milk")
        try repo.insert(task)

        let all = try repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Buy oat milk")
    }

    @Test("fetchActive filters by quadrant and isArchived=false")
    func fetchActiveByQuadrant() throws {
        let repo = try makeRepo()
        try repo.insert(makeTask(title: "Q1 task", quadrant: .doFirst))
        try repo.insert(makeTask(title: "Q2 task", quadrant: .schedule))

        let q1Tasks = try repo.fetchActive(in: .doFirst)
        #expect(q1Tasks.count == 1)
        #expect(q1Tasks[0].title == "Q1 task")

        let q2Tasks = try repo.fetchActive(in: .schedule)
        #expect(q2Tasks.count == 1)
    }

    @Test("fetchActive excludes archived tasks")
    func fetchActiveExcludesArchived() throws {
        let repo = try makeRepo()
        var task = makeTask(title: "Done task")
        try repo.insert(task)
        try repo.complete(id: task.id)

        let active = try repo.fetchActive(in: .doFirst)
        #expect(active.isEmpty)
    }

    @Test("fetchArchived returns completed tasks")
    func fetchArchived() throws {
        let repo = try makeRepo()
        let task = makeTask(title: "Finished item")
        try repo.insert(task)
        try repo.complete(id: task.id)

        let archived = try repo.fetchArchived()
        #expect(archived.count == 1)
        #expect(archived[0].title == "Finished item")
        #expect(archived[0].isArchived == true)
        #expect(archived[0].completedAt != nil)
    }

    // MARK: – Update

    @Test("update persists title change")
    func updateTitle() throws {
        let repo = try makeRepo()
        var task = makeTask(title: "Original")
        try repo.insert(task)

        task.title = "Updated"
        try repo.update(task)

        let all = try repo.fetchAll()
        #expect(all[0].title == "Updated")
    }

    // MARK: – Delete

    @Test("delete removes task")
    func deleteTask() throws {
        let repo = try makeRepo()
        let task = makeTask()
        try repo.insert(task)
        try repo.delete(id: task.id)

        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test("deleteAll removes multiple tasks")
    func deleteAll() throws {
        let repo = try makeRepo()
        let t1 = makeTask(title: "T1")
        let t2 = makeTask(title: "T2")
        let t3 = makeTask(title: "T3")
        try repo.insert(t1)
        try repo.insert(t2)
        try repo.insert(t3)

        try repo.deleteAll(ids: [t1.id, t2.id])
        let remaining = try repo.fetchAll()
        #expect(remaining.count == 1)
        #expect(remaining[0].title == "T3")
    }

    // MARK: – Move

    @Test("move changes quadrant")
    func move() throws {
        let repo = try makeRepo()
        let task = makeTask(title: "Move me", quadrant: .doFirst)
        try repo.insert(task)

        try repo.move(id: task.id, to: .schedule)

        let q1 = try repo.fetchActive(in: .doFirst)
        let q2 = try repo.fetchActive(in: .schedule)
        #expect(q1.isEmpty)
        #expect(q2.count == 1)
    }

    // MARK: – fetchModified

    @Test("fetchModified returns tasks updated after cutoff")
    func fetchModified() throws {
        let repo = try makeRepo()
        let cutoff = Date()

        // Insert a task, then manually update to set updatedAt > cutoff
        var task = makeTask(title: "Modified later")
        task.updatedAt = cutoff.addingTimeInterval(60) // 1 minute after cutoff
        try repo.insert(task)

        let modified = try repo.fetchModified(after: cutoff)
        #expect(modified.count == 1)
    }

    @Test("fetchModified excludes tasks updated before cutoff")
    func fetchModifiedExcludes() throws {
        let repo = try makeRepo()
        let cutoff = Date().addingTimeInterval(3600) // far future cutoff

        var task = makeTask(title: "Old task")
        try repo.insert(task)

        let modified = try repo.fetchModified(after: cutoff)
        #expect(modified.isEmpty)
    }
}
