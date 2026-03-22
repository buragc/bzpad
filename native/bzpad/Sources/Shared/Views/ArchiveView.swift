import SwiftUI
import EisenhowerCore

struct ArchiveView: View {

    @Environment(TaskStore.self) private var store

    var body: some View {
        Group {
            if store.archivedTasks.isEmpty {
                ContentUnavailableView(
                    "No Archived Tasks",
                    systemImage: "archivebox",
                    description: Text("Completed tasks will appear here.")
                )
            } else {
                List {
                    ForEach(store.archivedTasks) { task in
                        archivedRow(task)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Archive")
    }

    private func archivedRow(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.subheadline)
                .strikethrough(true, color: .secondary)
                .foregroundStyle(.secondary)

            if let completedAt = task.completedAt {
                Text("Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
