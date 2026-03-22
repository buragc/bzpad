import SwiftUI
import EisenhowerCore

/// The main 2×2 Eisenhower matrix grid.
/// On iOS (compact width) this is embedded in a page/tab layout;
/// on macOS it fills the detail pane of a NavigationSplitView.
struct MatrixView: View {

    @Environment(TaskStore.self) private var store
    @State private var quickAddTarget: Quadrant? = nil

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Quadrant.allCases) { quadrant in
                    QuadrantView(quadrant: quadrant, quickAddTarget: $quickAddTarget)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottom) {
            QuickAddView(defaultQuadrant: quickAddTarget)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
    }
}

// MARK: – Supporting extensions

extension Quadrant: CaseIterable {
    public static var allCases: [Quadrant] {
        [.doFirst, .schedule, .delegate, .eliminate]
    }
}

extension Quadrant: Identifiable {
    public var id: Int { rawValue }
}
