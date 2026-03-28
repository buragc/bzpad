import SwiftUI
import EisenhowerCore

/// The main 2×2 Eisenhower matrix.
///
/// Layout: two rows × two columns, separated by faint axis lines.
/// Each quadrant gets exactly half the available width and height,
/// so all four headers stay locked to the same grid positions regardless
/// of how many tasks each quadrant contains.
struct MatrixView: View {

    @Environment(TaskStore.self) private var store
    @State private var quickAddTarget: Quadrant? = nil
    /// Toggled to true to programmatically focus the QuickAddView text field.
    @State private var quickAddFocused = false
    /// Visual focus ring state — which quadrant's header/border is highlighted.
    @State private var focusedQuadrant: Quadrant? = nil
    /// Actual SwiftUI keyboard focus — setting this makes the ScrollView first responder.
    @FocusState private var quadrantFocus: Quadrant?

    var body: some View {
        if store.permissionDenied {
            permissionDeniedView
        } else {
            matrix
        }
    }

    private var permissionDeniedView: some View {
        PermissionDeniedView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.groupedBackground)
    }

    private var matrix: some View {
        VStack(spacing: 0) {
            // ── Top row ──────────────────────────────────────
            HStack(spacing: 0) {
                QuadrantView(
                    quadrant: .doFirst,
                    quickAddTarget: $quickAddTarget,
                    isFocused: focusedQuadrant == .doFirst,
                    onRequestFocus: { focusedQuadrant = .doFirst },
                    onRequestQuickAdd: { quickAddTarget = .doFirst; quickAddFocused = true },
                    quadrantFocus: $quadrantFocus
                )
                axis(.vertical)
                QuadrantView(
                    quadrant: .schedule,
                    quickAddTarget: $quickAddTarget,
                    isFocused: focusedQuadrant == .schedule,
                    onRequestFocus: { focusedQuadrant = .schedule },
                    onRequestQuickAdd: { quickAddTarget = .schedule; quickAddFocused = true },
                    quadrantFocus: $quadrantFocus
                )
            }
            .frame(maxHeight: .infinity)

            axis(.horizontal)

            // ── Bottom row ───────────────────────────────────
            HStack(spacing: 0) {
                QuadrantView(
                    quadrant: .delegate,
                    quickAddTarget: $quickAddTarget,
                    isFocused: focusedQuadrant == .delegate,
                    onRequestFocus: { focusedQuadrant = .delegate },
                    onRequestQuickAdd: { quickAddTarget = .delegate; quickAddFocused = true },
                    quadrantFocus: $quadrantFocus
                )
                axis(.vertical)
                QuadrantView(
                    quadrant: .eliminate,
                    quickAddTarget: $quickAddTarget,
                    isFocused: focusedQuadrant == .eliminate,
                    onRequestFocus: { focusedQuadrant = .eliminate },
                    onRequestQuickAdd: { quickAddTarget = .eliminate; quickAddFocused = true },
                    quadrantFocus: $quadrantFocus
                )
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color.groupedBackground)
        .overlay(alignment: .bottom) {
            QuickAddView(defaultQuadrant: quickAddTarget, focusTrigger: $quickAddFocused)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        // ── Quadrant cycling shortcuts ────────────────────────
        // Cmd+] → next quadrant (clockwise), Cmd+[ → previous
        .background {
            Group {
                Button("") { cycleQuadrant(clockwise: true) }
                    .keyboardShortcut("]", modifiers: .command)
                Button("") { cycleQuadrant(clockwise: false) }
                    .keyboardShortcut("[", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
    }

    private func cycleQuadrant(clockwise: Bool) {
        if let current = focusedQuadrant {
            focusedQuadrant = current.next(clockwise: clockwise)
        } else {
            focusedQuadrant = clockwise ? Quadrant.clockwiseOrder.first : Quadrant.clockwiseOrder.last
        }
        // Transfer AppKit first-responder to the newly focused quadrant's ScrollView.
        // Without this, .onKeyPress never fires after keyboard-only cycling.
        quadrantFocus = focusedQuadrant
        // Clear task focus when cycling — the user re-enters with arrow keys
        store.focusedId = nil
    }

    @ViewBuilder
    private func axis(_ direction: Axis) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(
                width:  direction == .vertical   ? 1 : nil,
                height: direction == .horizontal ? 1 : nil
            )
    }
}

// MARK: – Permission denied placeholder

private struct PermissionDeniedView: View {

    @Environment(\.openURL) private var openURL

    private var settingsURL: URL {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!
        #else
        URL(string: UIApplication.openSettingsURLString)!
        #endif
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Reminders Access Required")
                .font(.title3.bold())
            Text("bzpad stores tasks in Apple Reminders for iCloud sync.\nPlease grant access in System Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Privacy Settings") {
                openURL(settingsURL)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
