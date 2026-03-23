import SwiftUI
import EisenhowerCore

@main
struct bzpadApp: App {

    @State private var store = TaskStore()
    @AppStorage("colorScheme") private var darkMode: DarkMode = .system

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environment(store)
                .preferredColorScheme(darkMode.colorScheme)
        }
    }
}

/// Tab-based root on iPhone; on iPad the full matrix fits a single tab.
private struct iOSRootView: View {

    @Environment(TaskStore.self) private var store

    // Named AppTab to avoid shadowing SwiftUI's Tab view (iOS 18+)
    enum AppTab { case matrix, archive, settings }
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

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(AppTab.settings)
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
