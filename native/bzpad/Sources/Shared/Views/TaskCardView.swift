import SwiftUI
import EisenhowerCore

struct TaskCardView: View {

    let task: Task

    @Environment(TaskStore.self) private var store
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Completion button
            Button {
                store.completeTask(id: task.id)
            } label: {
                Image(systemName: "circle")
                    .imageScale(.medium)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                if !task.tags.isEmpty || task.dueDate != nil {
                    HStack(spacing: 6) {
                        if let due = task.dueDate {
                            dueDateBadge(due)
                        }
                        ForEach(task.tags.prefix(3), id: \.self) { tag in
                            tagBadge(tag)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            moveMenu
            Divider()
            Button(role: .destructive) {
                store.deleteTask(id: task.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: – Due date badge

    private func dueDateBadge(_ date: Date) -> some View {
        let level = UrgencyCalculator.level(dueDate: date)
        return Label {
            Text(date, style: .date)
        } icon: {
            Image(systemName: "clock")
        }
        .font(.caption2)
        .foregroundStyle(urgencyColor(level))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(urgencyColor(level).opacity(0.12))
        .clipShape(Capsule())
    }

    private func urgencyColor(_ level: UrgencyLevel) -> Color {
        switch level {
        case .overdue:  return .red
        case .critical: return .red
        case .warning:  return .orange
        case .soon:     return .yellow
        case .normal:   return .secondary
        }
    }

    // MARK: – Tag badge

    private func tagBadge(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }

    // MARK: – Move context menu

    private var moveMenu: some View {
        Menu("Move to…") {
            ForEach(Quadrant.allCases.filter { $0 != task.quadrant }) { q in
                Button {
                    store.moveTask(id: task.id, to: q)
                } label: {
                    Label(q.label, systemImage: q.systemImage)
                }
            }
        }
    }
}
