import SwiftUI
import EisenhowerCore

@main
struct bzpadApp: App {

    @State private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environment(store)
        }
    }
}

/// Tab-based root on iPhone; on iPad the full matrix fits a single tab.
private struct iOSRootView: View {

    @Environment(TaskStore.self) private var store
    @State private var selectedTab: Tab = .matrix

    enum Tab { case matrix, archive }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Matrix", systemImage: "square.grid.2x2", value: .matrix) {
                NavigationStack {
                    MatrixView()
                        .navigationTitle("bzpad")
                        .toolbar { toolbarItems }
                }
            }
            Tab("Archive", systemImage: "archivebox", value: .archive) {
                NavigationStack {
                    ArchiveView()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(true) // TODO: expose undoStack.isEmpty from store
        }
    }
}
