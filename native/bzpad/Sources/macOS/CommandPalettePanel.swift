import AppKit
import SwiftUI
import EisenhowerCore

// MARK: – Key-capable borderless panel

private final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
}

// MARK: – Window delegate

@MainActor
private final class CommandPaletteWindowDelegate: NSObject, NSWindowDelegate {
    var onBecomeKey: (() -> Void)?
    var onResignKey: (() -> Void)?
    func windowDidBecomeKey(_ notification: Notification) { onBecomeKey?() }
    func windowDidResignKey(_ notification: Notification) { onResignKey?() }
}

// MARK: – Controller

@MainActor
final class CommandPaletteController {

    static let shared = CommandPaletteController()
    private var panel: CommandPalettePanel?
    private var windowDelegate: CommandPaletteWindowDelegate?
    /// Tracks whether we need to claim first-responder when the panel becomes key.
    private var pendingFocus = false
    private init() {}

    // MARK: Public API

    func show(commands: [AppCommand]) {
        if panel == nil { makePanel() }
        // Rebuild the content view with the latest commands each show.
        panel?.contentView = NSHostingView(
            rootView: CommandPaletteView(commands: commands, onDismiss: { [weak self] in
                self?.hide()
            })
        )
        panel?.center()
        pendingFocus = true
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: Private

    private func panelBecameKey() {
        guard pendingFocus else { return }
        pendingFocus = false
        // Same technique as QuickAddPanelController: defer one run-loop tick so SwiftUI
        // has finished its first layout pass before we steal first-responder.
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.panel,
                  let tf = Self.firstEditableTextField(in: panel.contentView) else { return }
            panel.makeFirstResponder(tf)
        }
    }

    /// Depth-first search for the first editable NSTextField — mirrors QuickAddPanelController.
    private static func firstEditableTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let tf = view as? NSTextField, tf.isEditable { return tf }
        for sub in view.subviews {
            if let found = firstEditableTextField(in: sub) { return found }
        }
        return nil
    }

    private func makePanel() {
        let p = CommandPalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel  = true
        p.level            = .floating
        p.hasShadow        = true
        p.backgroundColor  = .clear
        p.hidesOnDeactivate = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let del = CommandPaletteWindowDelegate()
        del.onBecomeKey = { [weak self] in self?.panelBecameKey() }
        // Auto-dismiss when the user clicks back into the main window.
        del.onResignKey = { [weak self] in self?.hide() }
        windowDelegate = del
        p.delegate = del

        panel = p
    }
}
