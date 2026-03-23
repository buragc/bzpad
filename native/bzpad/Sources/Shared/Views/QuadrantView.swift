import SwiftUI
import EisenhowerCore

struct QuadrantView: View {

    let quadrant: Quadrant
    @Binding var quickAddTarget: Quadrant?

    @Environment(TaskStore.self) private var store
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header is always pinned here — it never moves regardless of task count
            header
            Divider()
            // Tasks scroll independently within their quadrant panel
            ScrollView {
                taskList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Drop destination covers the full quadrant panel
        .dropDestination(for: String.self) { items, _ in
            guard let uuidString = items.first,
                  let id = UUID(uuidString: uuidString) else { return false }
            store.moveTask(id: id, to: quadrant)
            return true
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
        .overlay {
            Rectangle()
                .fill(quadrant.color.opacity(isDropTarget ? 0.07 : 0))
                .allowsHitTesting(false)
        }
        .overlay {
            Rectangle()
                .strokeBorder(quadrant.color.opacity(isDropTarget ? 0.6 : 0), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: – Task list

    private var taskList: some View {
        let tasks = store.activeTasks(in: quadrant)
        return LazyVStack(spacing: 0) {
            if tasks.isEmpty {
                emptyState
            } else {
                ForEach(tasks) { task in
                    TaskCardView(task: task)
                    if task.id != tasks.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .padding(.bottom, 60) // clearance for QuickAddView overlay
    }

    private var emptyState: some View {
        Text(isDropTarget ? "Drop here" : "No tasks")
            .font(.caption)
            .foregroundStyle(isDropTarget ? quadrant.color : Color.secondary.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .animation(.easeInOut(duration: 0.15), value: isDropTarget)
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
