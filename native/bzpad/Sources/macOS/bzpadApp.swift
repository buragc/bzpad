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

    @AppStorage("quickAddKeyChar")   private var keyChar: String = "/"
    @AppStorage("quickAddModifiers") private var modifiersRaw: Int = 0

    private var effectiveKeyChar: String { keyChar.isEmpty ? "/" : keyChar }
    private var effectiveModRaw: Int {
        modifiersRaw != 0 ? modifiersRaw
            : Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }

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
        .keyboardShortcut(
            KeyEquivalent(Character(effectiveKeyChar)),
            modifiers: swiftUIModifiers(raw: effectiveModRaw)
        )

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
    @Environment(\.openSettings) private var openSettings
    @State private var selection: SidebarItem = .matrix
    @AppStorage("claudeAPIKey") private var claudeAPIKey: String = ""
    @State private var isAutoCategorizing = false
    @State private var aiErrorMessage: String? = nil

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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    handleAIButton()
                } label: {
                    if isAutoCategorizing {
                        ProgressView().controlSize(.small).frame(width: 16, height: 16)
                    } else {
                        Label("Auto-Categorize with AI", systemImage: "sparkles")
                    }
                }
                .disabled(isAutoCategorizing)
                .help("Ask Claude to categorize all tasks into the right quadrants")
            }
        }
        .alert("AI Categorization Failed", isPresented: Binding(
            get: { aiErrorMessage != nil },
            set: { if !$0 { aiErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { aiErrorMessage = nil }
            if aiErrorMessage?.contains("key") == true {
                Button("Open Settings") {
                    aiErrorMessage = nil
                    openSettingsToAPIKey()
                }
            }
        } message: {
            Text(aiErrorMessage ?? "")
        }
    }

    private func handleAIButton() {
        guard !claudeAPIKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            openSettingsToAPIKey()
            return
        }
        runAutoCategorize()
    }

    private func openSettingsToAPIKey() {
        openSettings()
        // Give the Settings window time to open before posting the focus notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: .focusAPIKeyField, object: nil)
        }
    }

    private func runAutoCategorize() {
        let key = claudeAPIKey
        let tasks = store.tasksByQuadrant.values.flatMap { $0 }
        guard !tasks.isEmpty else { return }

        isAutoCategorizing = true
        _Concurrency.Task {
            defer { isAutoCategorizing = false }
            do {
                let suggestions = try await ClaudeAutoCategorizer.categorize(tasks: tasks, apiKey: key)
                for (id, quadrant) in suggestions {
                    store.moveTask(id: id, to: quadrant)
                }
            } catch {
                aiErrorMessage = error.localizedDescription
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
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
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
                                .font(.body)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .draggable("inbox:\(item.id)")
                        }
                    }
                }
                .frame(maxHeight: 220)
                .padding(.bottom, 8)
            }
        }
    }
}
