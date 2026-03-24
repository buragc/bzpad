import SwiftUI
import EisenhowerCore

struct SettingsView: View {

    @AppStorage("colorScheme") private var darkMode: DarkMode = .system
    #if os(macOS)
    @AppStorage("showMenuBarItem")     private var showMenuBarItem: Bool = true
    @AppStorage("reminderListPrefix")  private var reminderListPrefix: String = "bzpad"
    @AppStorage("claudeAPIKey")        private var claudeAPIKey: String = ""
    @FocusState private var focusedField: SettingsField?

    private enum SettingsField { case apiKey }
    #endif

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

            #if os(macOS)
            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $showMenuBarItem)
            }

            Section {
                TextField("Prefix", text: $reminderListPrefix)
                    .textFieldStyle(.roundedBorder)
                Text("Lists are named \"\(reminderListPrefix) – Do First\" etc. Changing this creates new lists; existing tasks won't appear until you restore the old prefix.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Reminder List Prefix")
            }

            Section {
                LabeledContent("Quick Add Shortcut") {
                    HotkeyRecorderField()
                }
            } header: {
                Text("Global Shortcut")
            } footer: {
                Text("Click the badge and press a new key combination to change the shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                SecureField("sk-ant-…", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .apiKey)
                Text("Used for the ✦ AI auto-categorize button. Get a key at console.anthropic.com.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Claude API")
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusAPIKeyField)) { _ in
                focusedField = .apiKey
            }
            #endif
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
