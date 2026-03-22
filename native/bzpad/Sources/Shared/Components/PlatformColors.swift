import SwiftUI

extension Color {
    /// Equivalent to UIColor.systemGroupedBackground on iOS,
    /// NSColor.windowBackgroundColor on macOS.
    static var groupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    /// Equivalent to UIColor.secondarySystemGroupedBackground on iOS.
    /// Used for card/cell surfaces inside a grouped background.
    static var secondaryGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }

    /// Equivalent to UIColor.tertiarySystemFill on iOS.
    static var tertiaryFill: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemFill)
        #else
        Color(NSColor.quaternaryLabelColor)
        #endif
    }
}
