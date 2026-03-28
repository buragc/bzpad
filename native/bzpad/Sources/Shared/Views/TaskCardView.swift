import SwiftUI
import EisenhowerCore

struct TaskCardView: View {

    let task: Task
    var isKeyboardFocused: Bool = false

    @Environment(TaskStore.self) private var store
    @AppStorage("textSizeStep") private var textSizeStep: Int = 0
    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovering = false
    @State private var saveError = false
    @FocusState private var focused: Bool

    /// Each step adjusts the base size by ±15 %.
    private var titleFont: Font {
        let base = 14.0
        let scale = 1.0 + Double(textSizeStep) * 0.15
        return .system(size: base * scale)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Keyboard focus accent bar
            if isKeyboardFocused {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }

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
                if isEditing {
                    TextField("", text: $editText, axis: .vertical)
                        .font(titleFont)
                        .lineLimit(1...3)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { save() }
                        .onChange(of: isEditing) { _, on in if on { focused = true } }
                } else {
                    HStack(alignment: .center, spacing: 4) {
                        Text(task.title)
                            .font(titleFont)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                        if isHovering {
                            Image(systemName: "pencil")
                                .imageScale(.small)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
                }

                if saveError {
                    Text("Could not save")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

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
        .background(isKeyboardFocused ? Color.accentColor.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.1), value: isKeyboardFocused)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { store.focusedId = task.id }
        .highPriorityGesture(TapGesture(count: 2).onEnded { beginEditing() })
        .onChange(of: store.editingId) { _, newId in
            if newId == task.id {
                beginEditing()
            } else if isEditing {
                endEditing()
            }
        }
        .background {
            // Hidden Escape button — captures Escape key while editing
            if isEditing {
                Button("", role: .cancel) { endEditing() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
                    .frame(width: 0, height: 0)
            }
        }
        .draggable(task.id.uuidString) {
            // Drag preview: compact title label
            Text(task.title)
                .font(.subheadline)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 240)
        }
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

    // MARK: – Edit helpers

    private func beginEditing() {
        editText = task.title
        isEditing = true
        store.editingId = task.id
    }

    private func endEditing() {
        isEditing = false
        focused = false
        if store.editingId == task.id {
            store.editingId = nil
        }
    }

    private func save() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { endEditing(); return }
        var updated = task
        updated.title = trimmed
        do {
            try store.updateTask(updated)
        } catch {
            saveError = true
            editText = task.title
            _Concurrency.Task {
                try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000)
                saveError = false
            }
        }
        endEditing()
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
            .background(Color.tertiaryFill)
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
