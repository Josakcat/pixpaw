import SwiftUI

/// The Wardrobe's tiles, laid out like `LazyVGrid` with one adaptive column
/// (as many columns of at least `minimum` as fit, sharing the width) but all
/// measured at once. A lazy grid in the settings card guesses the height of
/// rows it has not drawn, and the page redraws a few times a second while the
/// pet walks, so its height kept flipping between the guess and the real one.
struct TileGrid: Layout {
    var minimum: CGFloat
    var spacing: CGFloat

    /// How many columns fit in `width`, and how wide each one is.
    static func columns(width: CGFloat, minimum: CGFloat, spacing: CGFloat, count: Int) -> (count: Int, width: CGFloat) {
        guard count > 0 else { return (0, 0) }
        guard width.isFinite else { return (count, minimum) }
        let fit = max(1, Int(((width + spacing) / (minimum + spacing)).rounded(.down)))
        return (fit, max(0, (width - spacing * CGFloat(fit - 1)) / CGFloat(fit)))
    }

    /// Each row's height (its tallest tile) and the grid's whole height.
    static func rows(heights: [CGFloat], columns: Int, spacing: CGFloat) -> (rows: [CGFloat], total: CGFloat) {
        guard columns > 0, !heights.isEmpty else { return ([], 0) }
        let rows = stride(from: 0, to: heights.count, by: columns).map { heights[$0..<min($0 + columns, heights.count)].max() ?? 0 }
        return (rows, rows.reduce(0, +) + spacing * CGFloat(rows.count - 1))
    }

    private func measure(_ width: CGFloat?, _ subviews: Subviews) -> (columns: Int, column: CGFloat, rows: [CGFloat], total: CGFloat) {
        let grid = Self.columns(width: width ?? minimum, minimum: minimum, spacing: spacing, count: subviews.count)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: grid.width, height: nil)).height }
        let rows = Self.rows(heights: heights, columns: grid.count, spacing: spacing)
        return (grid.count, grid.width, rows.rows, rows.total)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let m = measure(proposal.width, subviews)
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            ?? m.column * CGFloat(m.columns) + spacing * CGFloat(max(0, m.columns - 1))
        return CGSize(width: width, height: m.total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = measure(bounds.width, subviews)
        var y = bounds.minY
        for (row, height) in m.rows.enumerated() {
            for column in 0..<m.columns {
                let index = row * m.columns + column
                guard index < subviews.count else { break }
                // Centred in its cell, as LazyVGrid places them.
                let x = bounds.minX + CGFloat(column) * (m.column + spacing) + m.column / 2
                subviews[index].place(at: CGPoint(x: x, y: y + height / 2), anchor: .center,
                                      proposal: ProposedViewSize(width: m.column, height: nil))
            }
            y += height + spacing
        }
    }
}
