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

// MARK: – Window delegate (fires when the panel actually becomes key)

/// Separate NSObject subclass so QuickAddPanelController doesn't need to
/// inherit from NSObject. windowDidBecomeKey fires at the exact moment the
/// panel is the key window — the only safe point to request first responder.
@MainActor
private final class QuickAddWindowDelegate: NSObject, NSWindowDelegate {
    var onBecomeKey: (() -> Void)?
    func windowDidBecomeKey(_ notification: Notification) { onBecomeKey?() }
}

// MARK: – Panel controller

@MainActor
final class QuickAddPanelController {

    static let shared = QuickAddPanelController()
    private var panel: QuickAddPanel?
    private var store: TaskStore?
    private var windowDelegate: QuickAddWindowDelegate?
    /// Set to true by show() so the next windowDidBecomeKey fires focus logic.
    private var pendingFocus = false
    private init() {}

    func configure(store: TaskStore) { self.store = store }

    func show() {
        guard let store else { return }
        if panel == nil { makePanel(store: store) }
        panel?.center()
        pendingFocus = true
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    private func panelBecameKey() {
        guard pendingFocus else { return }
        pendingFocus = false
        // Tell the SwiftUI view to clear its text binding
        NotificationCenter.default.post(name: .quickAddPanelWillShow, object: nil)
        // Directly move first responder via AppKit — more reliable than @FocusState
        // because it runs at exactly the right moment (window is already key here).
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.panel,
                  let tf = Self.firstEditableTextField(in: panel.contentView) else { return }
            panel.makeFirstResponder(tf)
        }
    }

    /// Depth-first search for the first editable NSTextField in the view tree.
    /// SwiftUI embeds its NSTextField somewhere inside NSHostingView's subviews.
    private static func firstEditableTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let tf = view as? NSTextField, tf.isEditable { return tf }
        for sub in view.subviews {
            if let found = firstEditableTextField(in: sub) { return found }
        }
        return nil
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

        let del = QuickAddWindowDelegate()
        del.onBecomeKey = { [weak self] in self?.panelBecameKey() }
        windowDelegate = del
        p.delegate = del

        panel = p
    }
}

extension Notification.Name {
    static let quickAddPanelWillShow = Notification.Name("bzpad.quickAddPanelWillShow")
    static let focusAPIKeyField      = Notification.Name("bzpad.focusAPIKeyField")
}

// MARK: – Floating quick-add SwiftUI view

struct FloatingQuickAddView: View {

    let store: TaskStore
    let onDismiss: () -> Void

    @State private var text = ""

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)

            TextField("Add a task…", text: $text)
                .font(.system(size: 28, weight: .light))
                .textFieldStyle(.plain)
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
        // Reset text whenever the panel is re-shown.
        // Focus is handled by QuickAddPanelController.panelBecameKey() via makeFirstResponder.
        .onReceive(NotificationCenter.default.publisher(for: .quickAddPanelWillShow)) { _ in
            text = ""
        }
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
