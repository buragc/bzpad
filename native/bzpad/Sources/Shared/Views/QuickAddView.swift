import SwiftUI
import EisenhowerCore

/// Floating input bar for quick task entry.
/// Appears pinned to the bottom of the matrix; also presented by the toolbar button.
struct QuickAddView: View {

    /// When non-nil, new tasks are placed in this quadrant;
    /// otherwise QuadrantDetector picks automatically.
    let defaultQuadrant: Quadrant?

    @Environment(TaskStore.self) private var store
    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .imageScale(.large)

            TextField("Add a task…", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { submit() }

            if !text.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .animation(.spring(duration: 0.25), value: text.isEmpty)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addTask(title: trimmed, quadrant: defaultQuadrant)
        text = ""
    }
}
