import SwiftUI
import EisenhowerCore

struct QuadrantView: View {

    let quadrant: Quadrant
    @Binding var quickAddTarget: Quadrant?

    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            taskList
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(minHeight: 220)
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(quadrant.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(quadrant.color)
                Text(quadrant.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                quickAddTarget = quadrant
            } label: {
                Image(systemName: "plus")
                    .imageScale(.medium)
                    .foregroundStyle(quadrant.color)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: – Task list

    private var taskList: some View {
        let tasks = store.activeTasks(in: quadrant)
        return Group {
            if tasks.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskCardView(task: task)
                        if task.id != tasks.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No tasks")
            .font(.caption)
            .foregroundStyle(.quaternary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}

// MARK: – Quadrant appearance

extension Quadrant {

    var label: String {
        switch self {
        case .doFirst:   return "Do First"
        case .schedule:  return "Schedule"
        case .delegate:  return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }

    var subtitle: String {
        switch self {
        case .doFirst:   return "Urgent & Important"
        case .schedule:  return "Not Urgent & Important"
        case .delegate:  return "Urgent & Not Important"
        case .eliminate: return "Not Urgent & Not Important"
        }
    }

    var color: Color {
        switch self {
        case .doFirst:   return .red
        case .schedule:  return .blue
        case .delegate:  return .orange
        case .eliminate: return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .doFirst:   return "flame.fill"
        case .schedule:  return "calendar"
        case .delegate:  return "person.2.fill"
        case .eliminate: return "trash"
        }
    }
}
