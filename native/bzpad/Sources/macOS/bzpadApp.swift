import SwiftUI
import EisenhowerCore

@main
struct bzpadApp: App {

    @State private var store = TaskStore()
    @AppStorage("colorScheme") private var darkMode: DarkMode = .system
    @AppStorage("showMenuBarItem") private var showMenuBarItem: Bool = true
    @AppStorage("textSizeStep") private var textSizeStep: Int = 0

    var body: some Scene {
        WindowGroup {
            macOSRootView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(darkMode.colorScheme)
                .onAppear {
                    QuickAddPanelController.shared.configure(store: store)
                    GlobalHotKeyManager.shared.register()
                }
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("Undo") { store.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Larger Text")  { textSizeStep = min(textSizeStep + 1, 3) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Smaller Text") { textSizeStep = max(textSizeStep - 1, -3) }
                    .keyboardShortcut("-", modifiers: .command)
            }
        }

        // Native macOS Preferences window — opens with Cmd+,
        Settings {
            SettingsView()
                .frame(width: 360)
        }

        // Menu bar item — isInserted binding toggles visibility without a SceneBuilder conditional
        // .menu style enables keyboard shortcut display in menu items
        MenuBarExtra("bzpad", systemImage: "square.grid.2x2", isInserted: $showMenuBarItem) {
            MenuBarMenuView(store: store)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: – Menu bar drop-down

private struct MenuBarMenuView: View {

    let store: TaskStore

    var body: some View {
        Button("Open bzpad") {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.isKind(of: NSPanel.self) == false {
                window.makeKeyAndOrderFront(nil)
            }
        }
        .keyboardShortcut("o", modifiers: [.command])

        Button("Quick Add Task") {
            QuickAddPanelController.shared.configure(store: store)
            QuickAddPanelController.shared.show()
        }
        .keyboardShortcut("/", modifiers: [.command, .shift])

        Divider()

        Button("Quit bzpad") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

/// Three-column layout: sidebar navigation | matrix | (future: task detail)
private struct macOSRootView: View {

    @Environment(TaskStore.self) private var store
    @State private var selection: SidebarItem = .matrix

    enum SidebarItem: Hashable {
        case matrix
        case archive
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch selection {
            case .matrix:
                MatrixView()
                    .navigationTitle("Matrix")
            case .archive:
                ArchiveView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Workspace") {
                    Label("Matrix", systemImage: "square.grid.2x2")
                        .tag(SidebarItem.matrix)
                    Label("Archive", systemImage: "archivebox")
                        .tag(SidebarItem.archive)
                }
            }
            .listStyle(.sidebar)

            Divider()

            inboxPanel
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }

    private var inboxPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inbox")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.inboxItems.isEmpty {
                    Text("\(store.inboxItems.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if store.inboxItems.isEmpty {
                Text("No other reminders")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(store.inboxItems) { item in
                            Text(item.title)
                                .font(.caption)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .draggable("inbox:\(item.title)")
                        }
                    }
                }
                .frame(maxHeight: 220)
                .padding(.bottom, 8)
            }
        }
    }
}
