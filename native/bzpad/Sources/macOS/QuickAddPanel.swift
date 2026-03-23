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

final class GlobalHotKeyManager: @unchecked Sendable {

    static let shared = GlobalHotKeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private init() {}

    /// Registers Cmd+Shift+/ globally. Safe to call multiple times (no-op after first).
    func register() {
        guard hotKeyRef == nil else { return }

        var hotKeyID = EventHotKeyID(
            signature: fourCC("bzpd"),
            id: 1
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Slash),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

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

    private func fourCC(_ s: String) -> OSType {
        s.utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
    }
}

// MARK: – Panel controller

@MainActor
final class QuickAddPanelController {

    static let shared = QuickAddPanelController()
    private var panel: NSPanel?
    private var store: TaskStore?
    private init() {}

    func configure(store: TaskStore) { self.store = store }

    func show() {
        guard let store else { return }
        if panel == nil { makePanel(store: store) }
        // Re-center each time and post notification to reset the text field + focus
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .quickAddPanelWillShow, object: nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    private func makePanel(store: TaskStore) {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 90),
            styleMask: [.borderless],
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
