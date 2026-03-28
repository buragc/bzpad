import SwiftUI
import EisenhowerCore

struct QuadrantView: View {

    let quadrant: Quadrant
    @Binding var quickAddTarget: Quadrant?
    var isFocused: Bool = false
    var onRequestFocus: (() -> Void)? = nil
    var onRequestQuickAdd: (() -> Void)? = nil
    /// Bound to MatrixView's @FocusState — setting this from the parent transfers
    /// AppKit first-responder status to this quadrant's ScrollView.
    var quadrantFocus: FocusState<Quadrant?>.Binding

    @Environment(TaskStore.self) private var store
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header is always pinned here — it never moves regardless of task count
            header
            Divider()
            // ScrollViewReader lets us scroll a task into view when keyboard focus moves.
            // .focusable() puts the ScrollView in the macOS responder chain.
            // .focused() lets MatrixView transfer first-responder here via @FocusState.
            ScrollViewReader { proxy in
                ScrollView {
                    taskList
                }
                .focusable()
                .focused(quadrantFocus, equals: quadrant)
                .onKeyPress(phases: .down) { press in
                    handleKeyPress(press)
                }
                .onChange(of: store.focusedId) { _, newId in
                    guard let id = newId,
                          store.activeTasks(in: quadrant).contains(where: { $0.id == id })
                    else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onRequestFocus?() }
        // Drop destination covers the full quadrant panel.
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first else { return false }
            if let id = UUID(uuidString: payload) {
                store.moveTask(id: id, to: quadrant)
                return true
            }
            if payload.hasPrefix("inbox:") {
                let inboxID = String(payload.dropFirst("inbox:".count))
                store.categorizeInboxItem(id: inboxID, quadrant: quadrant)
                return true
            }
            return false
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
        // Drop color tint
        .overlay {
            Rectangle()
                .fill(quadrant.color.opacity(isDropTarget ? 0.07 : 0))
                .allowsHitTesting(false)
        }
        // Drop border
        .overlay {
            Rectangle()
                .strokeBorder(quadrant.color.opacity(isDropTarget ? 0.6 : 0), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        // Keyboard focus ring — visible when this quadrant has cursor focus
        .overlay {
            if isFocused {
                Rectangle()
                    .strokeBorder(quadrant.color.opacity(0.7), lineWidth: 2.5)
                    .allowsHitTesting(false)
            }
        }
        .background(isFocused ? quadrant.color.opacity(0.03) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    // MARK: – Keyboard handler

    @discardableResult
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard isFocused else { return .ignored }

        // Return — edit focused task if one is selected, otherwise jump to quick-add
        if press.key == .return && press.modifiers.isEmpty {
            if store.focusedId != nil {
                store.editingId = store.focusedId
            } else {
                onRequestQuickAdd?()
            }
            return .handled
        }

        // Arrow navigation within quadrant
        if press.key == .upArrow && press.modifiers.isEmpty {
            store.moveFocus(in: quadrant, up: true)
            return .handled
        }
        if press.key == .downArrow && press.modifiers.isEmpty {
            store.moveFocus(in: quadrant, up: false)
            return .handled
        }

        // Backspace/Delete — delete focused task
        if (press.key == .delete || press.key == .deleteForward) && press.modifiers.isEmpty {
            if store.focusedId != nil {
                store.deleteFocused()
                return .handled
            }
        }

        // D — vim-style delete
        if press.characters == "d" && press.modifiers.isEmpty && store.focusedId != nil {
            store.deleteFocused()
            return .handled
        }

        // Cmd+↑ / Cmd+↓ — reorder within quadrant
        if press.key == .upArrow && press.modifiers == .command {
            if let id = store.focusedId { store.reorderTask(id: id, up: true) }
            return .handled
        }
        if press.key == .downArrow && press.modifiers == .command {
            if let id = store.focusedId { store.reorderTask(id: id, up: false) }
            return .handled
        }

        // Cmd+← / Cmd+→ — move focused task to adjacent quadrant (clockwise)
        if press.key == .leftArrow && press.modifiers == .command {
            store.moveFocusedTask(clockwise: false)
            return .handled
        }
        if press.key == .rightArrow && press.modifiers == .command {
            store.moveFocusedTask(clockwise: true)
            return .handled
        }

        return .ignored
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
                    TaskCardView(task: task, isKeyboardFocused: store.focusedId == task.id)
                        .id(task.id)
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
        case .doFirst:   return "Do Now"
        case .schedule:  return "Plan"
        case .delegate:  return "Hand Off"
        case .eliminate: return "Drop"
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
