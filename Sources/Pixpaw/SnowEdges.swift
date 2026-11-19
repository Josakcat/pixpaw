// Pixpaw
//
// Where snow can lie on your windows (Winter.swift): the stretches of each
// window's top edge that no window in front of it covers. Plain geometry,
// checked by .droppykit/Tools/snow-edges-check.swift.

import CoreGraphics

enum SnowEdges {
    /// The stretches of each window's top edge that no window in front of
    /// it covers (one whose top is level with it, or higher, and reaches down past it), at least 40 points long; front windows first.
    static func open(_ windows: [(id: Int, rect: CGRect)], limit: Int = 8) -> [(id: Int, y: CGFloat, from: CGFloat, to: CGFloat)] {
        var out: [(id: Int, y: CGFloat, from: CGFloat, to: CGFloat)] = []
        for (i, window) in windows.prefix(12).enumerated() {
            let y = window.rect.minY
            var open = [(window.rect.minX, window.rect.maxX)]
            for front in windows[..<i] where front.rect.minY <= y + 8 && front.rect.maxY >= y {
                open = open.flatMap { piece -> [(CGFloat, CGFloat)] in
                    let (a, b) = piece
                    guard front.rect.maxX > a, front.rect.minX < b else { return [piece] }
                    return [(a, front.rect.minX), (front.rect.maxX, b)].filter { $0.1 - $0.0 > 0 }
                }
            }
            for (a, b) in open where b - a >= 40 { out.append((window.id, y, a, b)) }
            if Set(out.map(\.id)).count >= limit { break }
        }
        return out
}
}
