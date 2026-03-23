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

    var body: some View {
        VStack(spacing: 0) {
            // ── Top row ──────────────────────────────────────
            HStack(spacing: 0) {
                QuadrantView(quadrant: .doFirst,  quickAddTarget: $quickAddTarget)
                axis(.vertical)
                QuadrantView(quadrant: .schedule, quickAddTarget: $quickAddTarget)
            }
            .frame(maxHeight: .infinity)

            axis(.horizontal)

            // ── Bottom row ───────────────────────────────────
            HStack(spacing: 0) {
                QuadrantView(quadrant: .delegate,  quickAddTarget: $quickAddTarget)
                axis(.vertical)
                QuadrantView(quadrant: .eliminate, quickAddTarget: $quickAddTarget)
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color.groupedBackground)
        .overlay(alignment: .bottom) {
            QuickAddView(defaultQuadrant: quickAddTarget)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
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
