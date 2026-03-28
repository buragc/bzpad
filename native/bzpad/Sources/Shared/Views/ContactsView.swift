import SwiftUI
import EisenhowerCore

// MARK: – Root

struct ContactsView: View {

    /// Allows parent (macOSRootView) to trigger "Add Contact" from command palette / keyboard.
    var externalShowAdd: Binding<Bool>? = nil
    /// Allows parent to trigger "Mark Meeting Done" from the M key or command palette.
    var externalMarkDone: Binding<Bool>? = nil

    @Environment(ContactStore.self) private var contactStore
    @State private var selectedId: UUID?
    @State private var showingAdd = false
    /// Forwarded from ContactDetailView so J/K stay available at the top level.
    @State private var showingMarkDone = false

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: contact list ──────────────────────────────
            VStack(spacing: 0) {
                Group {
                    if contactStore.contacts.isEmpty {
                        ContentUnavailableView {
                            Label("No Contacts", systemImage: "person.slash")
                        } description: {
                            Text("Add someone you need to stay in touch with.")
                        }
                    } else {
                        List(contactStore.contacts, selection: $selectedId) { contact in
                            ContactRowView(contact: contact)
                                .tag(contact.id)
                        }
                        .listStyle(.sidebar)
                        // J / K vim-style navigation (supplemental to native ↑/↓)
                        .onKeyPress(phases: .down) { press in
                            guard press.modifiers.isEmpty else { return .ignored }
                            switch press.characters {
                            case "j": moveCursor(down: true);  return .handled
                            case "k": moveCursor(down: false); return .handled
                            default:  return .ignored
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()

                Button {
                    showingAdd = true
                } label: {
                    Label("Add Contact", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(width: 220)
            // N — new contact, M — mark meeting done, Delete — delete selected contact
            .onKeyPress(phases: .down) { press in
                guard press.modifiers.isEmpty else { return .ignored }
                switch press.characters {
                case "n":
                    showingAdd = true
                    return .handled
                case "m":
                    if selectedId != nil { showingMarkDone = true }
                    return selectedId != nil ? .handled : .ignored
                default:
                    return .ignored
                }
            }

            Divider()

            // ── Right: detail ───────────────────────────────────
            if let id = selectedId,
               let contact = contactStore.contacts.first(where: { $0.id == id }) {
                ContactDetailView(
                    contact: contact,
                    externalMarkDone: $showingMarkDone,
                    onDelete: {
                        selectedId = nil
                        try? contactStore.deleteContact(id: id)
                    }
                )
            } else {
                ContentUnavailableView(
                    "Select a Contact",
                    systemImage: "person.circle",
                    description: Text("Choose someone from the list.")
                )
            }
        }
        .navigationTitle("People")
        .sheet(isPresented: $showingAdd) {
            AddContactSheet { newContact in
                try? contactStore.addContact(newContact)
                selectedId = newContact.id
            }
        }
        // Bridge external bindings → internal state
        .onChange(of: externalShowAdd?.wrappedValue) { _, newValue in
            if newValue == true {
                showingAdd = true
                externalShowAdd?.wrappedValue = false
            }
        }
        .onChange(of: externalMarkDone?.wrappedValue) { _, newValue in
            if newValue == true {
                if selectedId != nil { showingMarkDone = true }
                externalMarkDone?.wrappedValue = false
            }
        }
    }

    private func moveCursor(down: Bool) {
        let contacts = contactStore.contacts
        guard !contacts.isEmpty else { return }
        if let current = selectedId, let idx = contacts.firstIndex(where: { $0.id == current }) {
            let next = down ? idx + 1 : idx - 1
            if contacts.indices.contains(next) {
                selectedId = contacts[next].id
            }
        } else {
            selectedId = down ? contacts.first?.id : contacts.last?.id
        }
    }
}

// MARK: – Contact row

private struct ContactRowView: View {

    let contact: Contact

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(contact.name)
                    .font(.subheadline)
                    .fontWeight(contact.isDue ? .semibold : .regular)
                if contact.isDue {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }
            if let role = contact.role {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(nextCheckInLabel(contact))
                .font(.caption2)
                .foregroundStyle(contact.isDue ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
        }
        .padding(.vertical, 2)
    }

    private func nextCheckInLabel(_ c: Contact) -> String {
        if c.isDue { return "Due now" }
        let next = c.nextReminderDate
        return "Next: \(next.formatted(date: .abbreviated, time: .omitted))"
    }
}

// MARK: – Detail view

private struct ContactDetailView: View {

    let contact: Contact
    /// Binding so ContactsView can trigger "Mark Meeting Done" via the M key.
    @Binding var externalMarkDone: Bool
    let onDelete: () -> Void

    @Environment(ContactStore.self) private var contactStore
    @AppStorage("claudeAPIKey") private var claudeAPIKey: String = ""

    @State private var draft: Contact
    @State private var sessions: [Session] = []
    @State private var showingMarkDone = false
    @State private var suggestions: [String] = []
    @State private var isFetchingSuggestions = false
    @State private var suggestionError: String?
    @State private var showDeleteConfirm = false

    init(contact: Contact, externalMarkDone: Binding<Bool>, onDelete: @escaping () -> Void) {
        self.contact = contact
        self._externalMarkDone = externalMarkDone
        self.onDelete = onDelete
        _draft = State(initialValue: contact)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ── Info ─────────────────────────────────────────
                GroupBox("Contact Info") {
                    VStack(spacing: 12) {
                        labeled("Name") {
                            TextField("Name", text: $draft.name)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeled("Role") {
                            TextField("Director of Engineering", text: Binding(
                                get: { draft.role ?? "" },
                                set: { draft.role = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        labeled("Area / Team") {
                            TextField("Platform", text: Binding(
                                get: { draft.area ?? "" },
                                set: { draft.area = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        labeled("Check-in every") {
                            CadenceField(cadenceDays: $draft.cadenceDays)
                        }
                    }
                    .padding(.top, 4)
                }

                // ── Notes ────────────────────────────────────────
                GroupBox("Agenda / Topics for Next 1:1") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $draft.notes)
                            .font(.body)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.secondary.opacity(0.3))
                            )

                        if !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Suggestions")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                ForEach(suggestions, id: \.self) { topic in
                                    Button {
                                        let sep = draft.notes.isEmpty ? "" : "\n"
                                        draft.notes += sep + "• " + topic
                                    } label: {
                                        Label(topic, systemImage: "plus.circle")
                                            .font(.caption)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.blue)
                                }
                            }
                        }

                        if let err = suggestionError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }

                        HStack {
                            Button {
                                fetchSuggestions()
                            } label: {
                                if isFetchingSuggestions {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Suggest Topics", systemImage: "sparkles")
                                }
                            }
                            .disabled(isFetchingSuggestions || claudeAPIKey.isEmpty)
                            .help(claudeAPIKey.isEmpty ? "Add a Claude API key in Settings to enable AI suggestions." : "")
                        }
                    }
                    .padding(.top, 4)
                }

                // ── Actions ──────────────────────────────────────
                HStack {
                    Button("Mark Meeting Done") {
                        showingMarkDone = true
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Delete Contact", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                }

                // ── Session history ──────────────────────────────
                if !sessions.isEmpty {
                    GroupBox("Meeting History") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(sessions) { session in
                                SessionRowView(session: session)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            loadSessions()
            draft = contact
        }
        .onChange(of: contact.id) { _, _ in
            draft = contact
            loadSessions()
            suggestions = []
        }
        .onChange(of: draft) { _, new in
            try? contactStore.updateContact(new)
        }
        // Allow parent (ContactsView via M key) to trigger the mark-done sheet
        .onChange(of: externalMarkDone) { _, triggered in
            if triggered { showingMarkDone = true }
        }
        .onChange(of: showingMarkDone) { _, showing in
            if !showing { externalMarkDone = false }
        }
        .sheet(isPresented: $showingMarkDone) {
            MarkMeetingDoneSheet(contact: contact) { date, notes in
                try? contactStore.markMeetingDone(contactId: contact.id, date: date, notes: notes)
                loadSessions()
            }
        }
        .confirmationDialog(
            "Delete \(contact.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will also delete all meeting history for this contact.")
        }
    }

    // MARK: – Helpers

    private func loadSessions() {
        sessions = (try? contactStore.sessions(for: contact.id)) ?? []
    }

    private func fetchSuggestions() {
        let key = claudeAPIKey
        let c   = contact
        let s   = sessions
        isFetchingSuggestions = true
        suggestionError = nil
        _Concurrency.Task {
            defer { isFetchingSuggestions = false }
            do {
                suggestions = try await ClaudeContactSuggester.suggestTopics(
                    for: c, sessions: s, apiKey: key
                )
            } catch {
                suggestionError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

}

// MARK: – Session row

private struct SessionRowView: View {
    let session: Session
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                expanded.toggle()
            } label: {
                HStack {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                Text(session.notes.isEmpty ? "(no notes)" : session.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: – Add contact sheet

private struct AddContactSheet: View {

    let onAdd: (Contact) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var role = ""
    @State private var area = ""
    @State private var cadenceDays = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Contact")
                .font(.headline)

            VStack(spacing: 10) {
                TextField("Name *", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Role (optional)", text: $role)
                    .textFieldStyle(.roundedBorder)
                TextField("Area / Team (optional)", text: $area)
                    .textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-in every")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CadenceField(cadenceDays: $cadenceDays)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Add") {
                    let c = Contact(
                        name: name.trimmingCharacters(in: .whitespaces),
                        role: role.isEmpty ? nil : role,
                        area: area.isEmpty ? nil : area,
                        cadenceDays: cadenceDays
                    )
                    onAdd(c)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

// MARK: – Mark meeting done sheet

private struct MarkMeetingDoneSheet: View {

    let contact: Contact
    let onDone: (Date, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var date  = Date()
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mark Meeting Done")
                .font(.headline)
            Text("1:1 with \(contact.name)")
                .foregroundStyle(.secondary)

            DatePicker("Date", selection: $date, displayedComponents: .date)

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes / Topics Covered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3)))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Done") {
                    onDone(date, notes)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: – CadenceField

/// Text field that accepts shorthand cadence input ("2w", "1m", "15d", or bare numbers)
/// and converts to a stored `cadenceDays: Int` value.
private struct CadenceField: View {

    @Binding var cadenceDays: Int
    @State private var text: String = ""
    @State private var invalid: Bool = false
    @FocusState private var focused: Bool

    private let presets: [(Int, String)] = [(7, "1w"), (14, "2w"), (30, "1m")]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("e.g. 2w, 1m, 15d", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .focused($focused)
                    .onSubmit(commit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(invalid ? Color.red : Color.clear, lineWidth: 1.5)
                    )

                Text("= \(cadenceDays) day\(cadenceDays == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: cadenceDays)
            }

            HStack(spacing: 4) {
                ForEach(presets, id: \.0) { days, label in
                    Button(label) {
                        cadenceDays = days
                        text = label
                        invalid = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundStyle(cadenceDays == days ? Color.blue : Color.secondary)
                }
            }
        }
        .onAppear { text = formatCadence(cadenceDays) }
        .onChange(of: cadenceDays) { _, new in
            if !focused { text = formatCadence(new) }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    private func commit() {
        if let days = parseCadence(text), days >= 1 {
            cadenceDays = min(days, 730)
            text = formatCadence(cadenceDays)
            invalid = false
        } else if !text.isEmpty {
            invalid = true
        }
    }
}

// MARK: – Cadence helpers

/// Parses shorthand input into a day count.
/// Accepts: "4w"/"4 weeks", "1m"/"1 month", "15d"/"15 days", or a bare number (days).
private func parseCadence(_ input: String) -> Int? {
    let s = input.trimmingCharacters(in: .whitespaces).lowercased()
    guard !s.isEmpty else { return nil }
    let digits = String(s.prefix(while: { $0.isNumber }))
    guard let n = Int(digits), n > 0 else { return nil }
    let rest = s.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
    if rest.hasPrefix("w") { return n * 7 }
    if rest.hasPrefix("m") { return n * 30 }
    // "d", "days", bare number — all mean days
    return n
}

/// Formats a day count back to a compact label ("1w", "2m", "15d").
private func formatCadence(_ days: Int) -> String {
    if days > 0 && days % 30 == 0 { return "\(days / 30)m" }
    if days > 0 && days % 7  == 0 { return "\(days / 7)w" }
    return "\(days)d"
}
