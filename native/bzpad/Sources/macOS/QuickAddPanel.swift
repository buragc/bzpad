import AppKit
import SwiftUI
import Carbon.HIToolbox
import EisenhowerCore

// MARK: – Global hotkey (Carbon — no accessibility permission required)
//
// RegisterEventHotKey is a Carbon API that intercepts the key combination
// system-wide before it reaches any application, including the frontmost one.
// This is how Alfred, Raycast, Spotlight, etc. register their global triggers.

private func carbonHotKeyCallback(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async { QuickAddPanelController.shared.toggle() }
    return noErr
}

// MARK: – Key-capable borderless panel

/// NSPanel subclass that allows becoming the key window even without a title bar.
/// Required so the embedded NSTextField (via NSHostingView) can receive keyboard events.
private final class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
}

// MARK: – Global hotkey

final class GlobalHotKeyManager: @unchecked Sendable {

    static let shared = GlobalHotKeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private init() {}

    /// Registers the global hotkey from UserDefaults (defaults to Cmd+Shift+/).
    /// Safe to call multiple times — no-op after first registration.
    func register() {
        guard hotKeyRef == nil else { return }

        // Read stored key + modifiers; fall back to Cmd+Shift+/
        let storedChar = UserDefaults.standard.string(forKey: "quickAddKeyChar") ?? "/"
        let storedMods = UserDefaults.standard.integer(forKey: "quickAddModifiers")
        let nsMods = storedMods != 0
            ? NSEvent.ModifierFlags(rawValue: UInt(storedMods))
            : NSEvent.ModifierFlags([.command, .shift])
        let char = Character(storedChar.lowercased())
        guard let keyCode = Self.charToKeyCode[char] else { return }

        var hotKeyID = EventHotKeyID(signature: fourCC("bzpd"), id: 1)
        RegisterEventHotKey(
            keyCode,
            Self.carbonMods(from: nsMods),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        // Install the event handler only once — it persists for the app lifetime
        if handlerRef == nil {
            var eventSpec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                carbonHotKeyCallback,
                1, &eventSpec,
                nil, &handlerRef
            )
        }
    }

    /// Unregisters the current hotkey and re-registers with current UserDefaults values.
    /// Call this after the user changes their shortcut preference.
    func reregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        register()
    }

    private func fourCC(_ s: String) -> OSType {
        s.utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
    }
}

// MARK: – Panel controller

@MainActor
final class QuickAddPanelController {

    static let shared = QuickAddPanelController()
    private var panel: QuickAddPanel?
    private var store: TaskStore?
    private init() {}

    func configure(store: TaskStore) { self.store = store }

    func show() {
        guard let store else { return }
        if panel == nil { makePanel(store: store) }
        panel?.center()
        // Activate first so the panel can actually become key
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .quickAddPanelWillShow, object: nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    private func makePanel(store: TaskStore) {
        let p = QuickAddPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 90),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel  = true
        p.level            = .floating
        p.hasShadow        = true
        p.isMovableByWindowBackground = true
        p.backgroundColor  = .clear
        p.hidesOnDeactivate = true          // auto-dismiss when switching apps
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: FloatingQuickAddView(store: store) { [weak self] in
            self?.hide()
        })
        panel = p
    }
}

extension Notification.Name {
    static let quickAddPanelWillShow = Notification.Name("bzpad.quickAddPanelWillShow")
}

// MARK: – Floating quick-add SwiftUI view

struct FloatingQuickAddView: View {

    let store: TaskStore
    let onDismiss: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)

            TextField("Add a task…", text: $text)
                .font(.system(size: 28, weight: .light))
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit(submit)
                .onKeyPress(.escape) { dismiss(); return .handled }
        }
        .padding(.horizontal, 22)
        .frame(height: 90)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        // Reset + focus whenever the panel is re-shown
        .onReceive(NotificationCenter.default.publisher(for: .quickAddPanelWillShow)) { _ in
            text = ""
            focused = true
        }
        .onAppear { focused = true }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { store.addTask(title: trimmed) }
        dismiss()
    }

    private func dismiss() {
        text = ""
        onDismiss()
    }
}
