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

    // Named AppTab to avoid shadowing SwiftUI's Tab view (iOS 18+)
    enum AppTab { case matrix, archive }
    @State private var selectedTab: AppTab = .matrix

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MatrixView()
                    .navigationTitle("bzpad")
                    .toolbar { toolbarItems }
            }
            .tabItem { Label("Matrix", systemImage: "square.grid.2x2") }
            .tag(AppTab.matrix)

            NavigationStack {
                ArchiveView()
            }
            .tabItem { Label("Archive", systemImage: "archivebox") }
            .tag(AppTab.archive)
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
        }
    }
}
