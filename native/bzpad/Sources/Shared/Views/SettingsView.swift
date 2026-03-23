import SwiftUI
import EisenhowerCore

struct SettingsView: View {

    @AppStorage("colorScheme") private var darkMode: DarkMode = .system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $darkMode) {
                    Label("System", systemImage: "circle.lefthalf.filled")
                        .tag(DarkMode.system)
                    Label("Light",  systemImage: "sun.max")
                        .tag(DarkMode.light)
                    Label("Dark",   systemImage: "moon")
                        .tag(DarkMode.dark)
                }
                #if os(iOS)
                .pickerStyle(.inline)
                #else
                .pickerStyle(.radioGroup)
                #endif
            }
        }
        .formStyle(.grouped)
        #if os(iOS)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: – DarkMode → ColorScheme bridge

extension DarkMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
