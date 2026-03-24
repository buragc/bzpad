import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: – GlobalHotKeyManager: key-code table + Carbon helpers

extension GlobalHotKeyManager {

    /// Character → Carbon virtual key code, for every key that makes sense as a global hotkey.
    static let charToKeyCode: [Character: UInt32] = [
        "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9),
        "/": UInt32(kVK_ANSI_Slash),         ".": UInt32(kVK_ANSI_Period),
        ",": UInt32(kVK_ANSI_Comma),         ";": UInt32(kVK_ANSI_Semicolon),
        "'": UInt32(kVK_ANSI_Quote),         "[": UInt32(kVK_ANSI_LeftBracket),
        "]": UInt32(kVK_ANSI_RightBracket),  "\\": UInt32(kVK_ANSI_Backslash),
        "`": UInt32(kVK_ANSI_Grave),         "-": UInt32(kVK_ANSI_Minus),
        "=": UInt32(kVK_ANSI_Equal),         " ": UInt32(kVK_Space),
    ]

    /// Converts AppKit modifier flags to the bitmask Carbon's RegisterEventHotKey expects.
    static func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var r: UInt32 = 0
        if flags.contains(.command) { r |= UInt32(cmdKey)     }
        if flags.contains(.shift)   { r |= UInt32(shiftKey)   }
        if flags.contains(.option)  { r |= UInt32(optionKey)  }
        if flags.contains(.control) { r |= UInt32(controlKey) }
        return r
    }
}

// MARK: – Shortcut display helpers

/// Formats a (keyChar, UserDefaults-modifiers rawValue) pair as "⌘⇧/" etc.
func formatShortcut(keyChar: String, modifiersRaw: Int) -> String {
    let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw))
    var s = ""
    if flags.contains(.control) { s += "⌃" }
    if flags.contains(.option)  { s += "⌥" }
    if flags.contains(.shift)   { s += "⇧" }
    if flags.contains(.command) { s += "⌘" }
    s += (keyChar.isEmpty ? "/" : keyChar).uppercased()
    return s
}

/// Converts a stored modifiers raw value to SwiftUI's EventModifiers.
func swiftUIModifiers(raw: Int) -> SwiftUI.EventModifiers {
    let flags = NSEvent.ModifierFlags(rawValue: UInt(raw))
    var mods: SwiftUI.EventModifiers = []
    if flags.contains(.command) { mods.insert(.command) }
    if flags.contains(.shift)   { mods.insert(.shift)   }
    if flags.contains(.option)  { mods.insert(.option)  }
    if flags.contains(.control) { mods.insert(.control) }
    return mods
}

// MARK: – HotkeyRecorderField

/// A Settings row widget that shows the current shortcut and records a new one on click.
/// Stored in UserDefaults under "quickAddKeyChar" / "quickAddModifiers".
struct HotkeyRecorderField: View {

    @AppStorage("quickAddKeyChar")   private var keyChar: String = "/"
    @AppStorage("quickAddModifiers") private var modifiersRaw: Int = 0

    @State private var isRecording = false

    // Fall back to ⌘⇧/ when nothing has been stored yet (modifiersRaw == 0)
    private var effectiveModRaw: Int {
        modifiersRaw != 0 ? modifiersRaw
            : Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }
    private var effectiveKeyChar: String { keyChar.isEmpty ? "/" : keyChar }

    var body: some View {
        HStack(spacing: 8) {
            badge
            if isRecording {
                Button("Cancel") { isRecording = false }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // Zero-size capture view becomes first responder only while recording
        .background {
            if isRecording {
                KeyCaptureRepresentable { char, flags in
                    keyChar      = char
                    modifiersRaw = Int(flags.rawValue)
                    isRecording  = false
                    GlobalHotKeyManager.shared.reregister()
                } onCancel: {
                    isRecording = false
                }
            }
        }
    }

    private var badge: some View {
        Text(isRecording
             ? "Press shortcut…"
             : formatShortcut(keyChar: effectiveKeyChar, modifiersRaw: effectiveModRaw))
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isRecording ? Color.accentColor : Color(NSColor.separatorColor))
            )
            .onTapGesture { isRecording = true }
    }
}

// MARK: – NSView-based key capture

private struct KeyCaptureRepresentable: NSViewRepresentable {
    let onCapture: (String, NSEvent.ModifierFlags) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        KeyCaptureView(onCapture: onCapture, onCancel: onCancel)
    }
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {}
}

private final class KeyCaptureView: NSView {

    private let onCapture: (String, NSEvent.ModifierFlags) -> Void
    private let onCancel: () -> Void

    init(onCapture: @escaping (String, NSEvent.ModifierFlags) -> Void,
         onCancel:  @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel  = onCancel
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Defer so the SwiftUI layout pass finishes before we steal focus
        DispatchQueue.main.async { self.window?.makeFirstResponder(self) }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) { onCancel(); return }
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty,
              let raw = event.charactersIgnoringModifiers?.lowercased(),
              !raw.isEmpty,
              let char = raw.first,
              GlobalHotKeyManager.charToKeyCode[char] != nil
        else { NSSound.beep(); return }
        onCapture(String(char), mods)
    }
}
