import SwiftUI
import EisenhowerCore

@main
struct bzpadApp: App {

    @State private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            macOSRootView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("Undo") { store.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            }
        }
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
        List(selection: $selection) {
            Section("Workspace") {
                Label("Matrix", systemImage: "square.grid.2x2")
                    .tag(SidebarItem.matrix)
                Label("Archive", systemImage: "archivebox")
                    .tag(SidebarItem.archive)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
}
