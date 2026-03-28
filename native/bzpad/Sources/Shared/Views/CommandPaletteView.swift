import SwiftUI
import EisenhowerCore

// MARK: – Command model

struct AppCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let systemImage: String
    let action: () -> Void
    var isAvailable: Bool = true
}

// MARK: – Command palette view

struct CommandPaletteView: View {

    let commands: [AppCommand]
    /// Called when the palette should close (Escape, command executed, or tap outside).
    var onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    private var filtered: [AppCommand] {
        let available = commands.filter(\.isAvailable)
        guard !searchText.isEmpty else { return available }
        let q = searchText.lowercased()
        return available.filter {
            $0.title.lowercased().contains(q) ||
            ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Search field ──────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search commands…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($searchFocused)
                    .onSubmit { executeSelected() }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Command list ──────────────────────────────────
            if filtered.isEmpty {
                Text("No commands")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, cmd in
                                CommandRow(command: cmd, isSelected: idx == selectedIndex)
                                    .id(idx)
                                    .onTapGesture {
                                        selectedIndex = idx
                                        executeSelected()
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: selectedIndex) { _, new in
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 32, y: 16)
        .preferredColorScheme(.dark)
        .onAppear { selectedIndex = 0 }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
        // onKeyPress fires before the focused TextField handles the key —
        // arrow keys and Escape are intercepted here so the text field never sees them.
        .onKeyPress(.upArrow)   { moveCursor(up: true);  return .handled }
        .onKeyPress(.downArrow) { moveCursor(up: false); return .handled }
        .onKeyPress(.escape)    { onDismiss();            return .handled }
    }

    private func moveCursor(up: Bool) {
        guard !filtered.isEmpty else { return }
        selectedIndex = up
            ? max(0, selectedIndex - 1)
            : min(filtered.count - 1, selectedIndex + 1)
    }

    private func executeSelected() {
        guard filtered.indices.contains(selectedIndex) else { return }
        let cmd = filtered[selectedIndex]
        onDismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { cmd.action() }
    }
}

// MARK: – Command row

private struct CommandRow: View {
    let command: AppCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.systemImage)
                .font(.body)
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                if let sub = command.subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
    }
}
