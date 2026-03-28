import EisenhowerCore
import TermKit
import GRDB
import Foundation

// MARK: – Direct GRDB repository (no @MainActor protocol involved)
//
// TaskRepositoryProtocol is @MainActor, which makes calling it from TermKit's
// callback-based event loop cumbersome. Instead we talk to AppDatabase.pool
// directly — DatabasePool is Sendable and has no actor isolation.

struct TUIRepo {
    let pool: DatabasePool

    init() { self.pool = AppDatabase.shared.pool }

    func fetchActive(in q: Quadrant) throws -> [EisenhowerCore.Task] {
        try pool.read { db in
            try EisenhowerCore.Task
                .filter(EisenhowerCore.Task.Columns.quadrant == q.rawValue)
                .filter(EisenhowerCore.Task.Columns.isArchived == false)
                .order(EisenhowerCore.Task.Columns.createdAt)
                .fetchAll(db)
        }
    }

    func insert(_ task: EisenhowerCore.Task) throws {
        var t = task
        try pool.write { db in try t.insert(db) }
    }

    func delete(id: UUID) throws {
        try pool.write { db in
            try EisenhowerCore.Task.deleteOne(db, key: id.uuidString)
        }
    }

    func complete(id: UUID) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE tasks SET isArchived = 1, completedAt = ?, updatedAt = ? WHERE id = ?",
                arguments: [Date(), Date(), id.uuidString]
            )
        }
    }

    func move(id: UUID, to q: Quadrant) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE tasks SET quadrant = ?, updatedAt = ? WHERE id = ?",
                arguments: [q.rawValue, Date(), id.uuidString]
            )
        }
    }
}

// MARK: – Global state (single-threaded: TermKit event loop never leaves the main thread)

var repo = TUIRepo()
var tasksByQuadrant: [Quadrant: [EisenhowerCore.Task]] = Dictionary(
    uniqueKeysWithValues: Quadrant.allCases.map { ($0, []) }
)
var focusedQuadrant: Quadrant = .doFirst
var listViews: [Quadrant: QuadrantListView] = [:]

// MARK: – Data helpers

func reloadTasks() {
    for q in Quadrant.allCases {
        tasksByQuadrant[q] = (try? repo.fetchActive(in: q)) ?? []
    }
}

/// Display strings for a quadrant's ListView.
/// Overdue → "!", critical/warning/soon → "~", normal → two-space indent.
func displayItems(for q: Quadrant) -> [String] {
    let tasks = tasksByQuadrant[q] ?? []
    guard !tasks.isEmpty else { return ["  (empty — ^N to add)"] }
    return tasks.map { task in
        var prefix = "  "
        if let due = task.dueDate {
            switch UrgencyCalculator.level(dueDate: due) {
            case .overdue:          prefix = "! "
            case .critical, .warning, .soon: prefix = "~ "
            default:                break
            }
        }
        let tags = task.tags.isEmpty ? "" : " " + task.tags.map { "#\($0)" }.joined(separator: " ")
        return prefix + task.title + tags
    }
}

func refreshAll() {
    for (q, lv) in listViews {
        lv.items = displayItems(for: q)
        lv.setNeedsDisplay()
    }
}

/// The task currently highlighted in the given quadrant, or nil when the list is empty.
func selectedTask(in q: Quadrant) -> EisenhowerCore.Task? {
    let tasks = tasksByQuadrant[q] ?? []
    guard !tasks.isEmpty else { return nil }
    let idx = listViews[q]?.selectedItem ?? 0
    guard idx < tasks.count else { return nil }
    return tasks[idx]
}

// MARK: – Task actions

func addTask(to q: Quadrant) {
    InputBox.request("New Task", message: "Title (supports #tags and natural-language dates):", text: "") { text in
        guard let raw = text, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let dueDate    = DateParser.parse(raw)
        let cleanTitle = DateParser.strippingDatePhrases(from: TagExtractor.strippingHashtags(from: raw))
        let tags       = TagExtractor.extract(from: raw)
        let task = EisenhowerCore.Task(
            title:    cleanTitle.isEmpty ? raw : cleanTitle,
            quadrant: q,
            dueDate:  dueDate,
            tags:     tags,
            source:   dueDate != nil ? .parsed : .manual
        )
        try? repo.insert(task)
        reloadTasks()
        refreshAll()
    }
}

func deleteSelected() {
    guard let task = selectedTask(in: focusedQuadrant) else {
        MessageBox.error("Delete", message: "No task selected.", buttons: ["OK"])
        return
    }
    let preview = task.title.count > 44 ? String(task.title.prefix(44)) + "…" : task.title
    MessageBox.query("Delete", message: "Delete \"\(preview)\"?", buttons: ["Delete", "Cancel"]) { btn in
        if btn == 0 {
            try? repo.delete(id: task.id)
            reloadTasks()
            refreshAll()
        }
    }
}

func completeSelected() {
    guard let task = selectedTask(in: focusedQuadrant) else {
        MessageBox.error("Complete", message: "No task selected.", buttons: ["OK"])
        return
    }
    try? repo.complete(id: task.id)
    reloadTasks()
    refreshAll()
}

func moveSelected() {
    guard let task = selectedTask(in: focusedQuadrant) else {
        MessageBox.error("Move", message: "No task selected.", buttons: ["OK"])
        return
    }
    let targets = Quadrant.allCases.filter { $0 != focusedQuadrant }
    let buttons = targets.map(\.tuiLabel) + ["Cancel"]
    let preview = task.title.count > 30 ? String(task.title.prefix(30)) + "…" : task.title
    MessageBox.query("Move Task", message: "Move \"\(preview)\" to:", buttons: buttons) { btn in
        guard btn < targets.count else { return }
        try? repo.move(id: task.id, to: targets[btn])
        reloadTasks()
        refreshAll()
    }
}

// MARK: – QuadrantListView

/// ListView subclass that updates `focusedQuadrant` whenever it gains keyboard focus.
final class QuadrantListView: ListView {
    let quadrant: Quadrant

    init(quadrant: Quadrant) {
        self.quadrant = quadrant
        super.init()
    }

    override func becomeFirstResponder() -> Bool {
        focusedQuadrant = quadrant
        return super.becomeFirstResponder()
    }
}

// MARK: – Quadrant TUI labels

extension Quadrant {
    var tuiLabel: String {
        switch self {
        case .doFirst:   return "Do Now"
        case .schedule:  return "Plan"
        case .delegate:  return "Hand Off"
        case .eliminate: return "Drop"
        }
    }
    var tuiFrameTitle: String {
        switch self {
        case .doFirst:   return "Do Now — Urgent & Important"
        case .schedule:  return "Plan — Not Urgent & Important"
        case .delegate:  return "Hand Off — Urgent & Not Important"
        case .eliminate: return "Drop — Not Urgent & Not Important"
        }
    }
}

// MARK: – Build a quadrant panel

func makePanel(for q: Quadrant) -> Frame {
    let frame = Frame(q.tuiFrameTitle)

    let lv = QuadrantListView(quadrant: q)
    lv.x      = Pos.at(0)
    lv.y      = Pos.at(0)
    lv.width  = Dim.fill()
    lv.height = Dim.fill()
    frame.addSubview(lv)
    listViews[q] = lv

    return frame
}

// MARK: – Application setup

Application.prepare()

// ── Menu bar ──────────────────────────────────────────────────────────────────
let menuBar = MenuBar(menus: [
    MenuBarItem(title: "_bzpad", children: [
        MenuItem(title: "_Quit", action: { Application.shutdown() }, shortcut: .controlQ),
    ]),
    MenuBarItem(title: "_Tasks", children: [
        MenuItem(title: "_New task…",     action: { addTask(to: focusedQuadrant) }, shortcut: .controlN),
        MenuItem(title: "_Complete task", action: { completeSelected() },           shortcut: .controlK),
        MenuItem(title: "_Delete task",   action: { deleteSelected() },             shortcut: .controlD),
        MenuItem(title: "_Move task…",    action: { moveSelected() },               shortcut: .controlR),
    ]),
])

// ── 2×2 quadrant grid ─────────────────────────────────────────────────────────
//
//   Row 0        ── menu bar
//   Row 1…~48%   ┌──────────────┬──────────────┐
//                │  Do Now (Q1) │  Plan   (Q2) │
//                ├──────────────┼──────────────┤
//   ~48%…fill-1  │  Hand Off    │  Drop   (Q4) │
//                │  (Q3)        │              │
//                └──────────────┴──────────────┘
//   Last row     ── status bar

let q1 = makePanel(for: .doFirst)
let q2 = makePanel(for: .schedule)
let q3 = makePanel(for: .delegate)
let q4 = makePanel(for: .eliminate)

// Top row
q1.x      = Pos.at(0)
q1.y      = Pos.at(1)
q1.width  = Dim.percent(n: 50)
q1.height = Dim.percent(n: 48)

q2.x      = (try? Pos.percent(n: 50)) ?? Pos.at(0)
q2.y      = Pos.at(1)
q2.width  = Dim.fill()
q2.height = Dim.percent(n: 48)

// Bottom row — anchored to the bottom of the top frames, fills to status bar
q3.x      = Pos.at(0)
q3.y      = Pos.bottom(of: q1)
q3.width  = Dim.percent(n: 50)
q3.height = Dim.fill(1)

q4.x      = (try? Pos.percent(n: 50)) ?? Pos.at(0)
q4.y      = Pos.bottom(of: q2)
q4.width  = Dim.fill()
q4.height = Dim.fill(1)

// ── Status bar ────────────────────────────────────────────────────────────────
let statusBar = StatusBar()
statusBar.addHotkeyPanel(id: "new",      hotkeyText: "^N", labelText: "New",
                         hotkey: .controlN, action: { addTask(to: focusedQuadrant) })
statusBar.addHotkeyPanel(id: "complete", hotkeyText: "^K", labelText: "Done",
                         hotkey: .controlK, action: { completeSelected() })
statusBar.addHotkeyPanel(id: "delete",   hotkeyText: "^D", labelText: "Delete",
                         hotkey: .controlD, action: { deleteSelected() })
statusBar.addHotkeyPanel(id: "move",     hotkeyText: "^R", labelText: "Move",
                         hotkey: .controlR, action: { moveSelected() })
statusBar.addHotkeyPanel(id: "quit",     hotkeyText: "^Q", labelText: "Quit",
                         hotkey: .controlQ, action: { Application.shutdown() })

// ── Assemble ──────────────────────────────────────────────────────────────────
Application.top.addSubview(menuBar)
Application.top.addSubview(q1)
Application.top.addSubview(q2)
Application.top.addSubview(q3)
Application.top.addSubview(q4)
Application.top.addSubview(statusBar)

// Load tasks and give initial keyboard focus to Q1 (Do Now)
reloadTasks()
refreshAll()
Application.top.setFocus(q1)

Application.run()
