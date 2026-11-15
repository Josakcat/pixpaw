//
//  RestSpot.swift
//  Pixpaw
//
//  The cushion decoration is each pet's own resting spot (a cat's round
//  cushion, a hamster's nest of shavings, a dragon's hoard: drawn in
//  `HomeDecor.variants`), and how the pet rests on it: the pose the
//  controller plays on the cushion, and the small changes to a frame's
//  pixels it needs (a foot tucked, feathers fluffed, the part under the
//  water line left out). Pure values, checked on their own
//  (.droppykit/Tools/home-decor-check.swift).
//

import Foundation

/// How a pet rests on its spot. Most poses play the pet's sleep frames
/// (`sleep1`, `sleep2`), centred on the spot and moved `dx` across; the
/// parrot stands on one foot and the chicken sits fluffed up (`reshape`).
/// Numbers are classic pixels (twice that in HD), counted up from the floor
/// row the spot stands on (0 is that row). The preview sheet in
/// pixpaw-extras/decor-actions-2.1/rest-poses.png is drawn by these.
struct RestPose: Equatable {
    enum Style: String, CaseIterable {
        case curl, lieDown, burrow, flop, fluffed, perch, sitIn, wallow, soak, finOut, foldedLegs
    }

    /// A small change to the frame's own pixels, in place of a new drawing.
    enum Reshape: String {
        case none
        /// Stands on one foot: the rear foot drawn up into the feathers.
        case tuckFoot
        /// Feathers puffed out: the lower body a pixel wider each side.
        case fluff
    }

    let style: Style
    /// What it does there, in words: "curls up".
    let words: String
    /// Where the pet's lowest drawn row sits, above the floor.
    let lift: Int
    /// Below this height none of the pet is drawn: it is down in the nest,
    /// the water or behind the rim, and the spot shows. 0: all of it.
    let hiddenBelow: Int
    /// Across from the spot's centre (+ is the way the pet faces).
    let dx: Int
    /// Now and then left beside it (the chicken's egg): a picture in
    /// `CatArt.decor` / `FineArt.decor`, or nil.
    let leaves: String?
    /// The frames it plays there, in turn (`CatFrame` names).
    let frames: [String]
    let reshape: Reshape

    init(_ style: Style, _ words: String, lift: Int, hiddenBelow: Int = 0, dx: Int = 0, leaves: String? = nil,
         frames: [String] = ["sleep1", "sleep2"], reshape: Reshape = .none) {
        self.style = style
        self.words = words
        self.lift = lift
        self.hiddenBelow = hiddenBelow
        self.dx = dx
        self.leaves = leaves
        self.frames = frames
        self.reshape = reshape
    }

    /// Rows of the pet hidden in the spot, counted up from its lowest drawn row.
    func hiddenRows(factor: Int) -> Int { max(0, hiddenBelow - lift) * factor }

    /// The frame to show `ticks` into the rest: each held for `hold` ticks;
    /// under Reduce Motion, the first one only.
    func frame(ticks: Int, hold: Int = 14, reduceMotion: Bool) -> String {
        guard !reduceMotion, frames.count > 1 else { return frames.first ?? "sleep1" }
        return frames[(max(0, ticks) / max(1, hold)) % frames.count]
    }
}

enum RestSpot {
    /// A pet you drew is looked up as "own.<kind it acts like>" (`PetKind.decorLook`):
    /// everything else is that kind's, but its rest spot stays the cat's cushion.
    static let ownPrefix = "own."

    /// The look `item` is drawn as for `look`: the kind it acts like, except
    /// the cushion of a pet you drew, which is the cat's.
    static func look(_ look: String?, for item: HomeDecor) -> String? {
        guard let look, look.hasPrefix(ownPrefix) else { return look }
        return item == .cushion ? "cat" : String(look.dropFirst(ownPrefix.count))
    }

    /// Each kind on its own spot (the cushion's version in `HomeDecor.variants`).
    static let poses: [String: RestPose] = [
        "cat": RestPose(.curl, "curls up", lift: 4),
        "dog": RestPose(.lieDown, "lies down", lift: 2, hiddenBelow: 3),
        "hamster": RestPose(.burrow, "burrows in, only its ears showing", lift: 0, hiddenBelow: 7),
        "rabbit": RestPose(.flop, "flops on its side", lift: 4),
        "chicken": RestPose(.fluffed, "sits fluffed up", lift: 2, hiddenBelow: 3, leaves: "cushion.chicken.egg", reshape: .fluff),
        "parrot": RestPose(.perch, "perches with one foot tucked", lift: 14, dx: -4, frames: ["blink"], reshape: .tuckFoot),
        "bee": RestPose(.sitIn, "sits in the flower", lift: 4, hiddenBelow: 8),
        "pig": RestPose(.wallow, "rolls in the mud", lift: 1, hiddenBelow: 3),
        "hippo": RestPose(.soak, "soaks, half under", lift: 0, hiddenBelow: 5),
        "shark": RestPose(.finOut, "dips in, its fin poking out", lift: 3, hiddenBelow: 8),
        "giraffe": RestPose(.foldedLegs, "lies with its legs folded, neck up", lift: 1, hiddenBelow: 3),
        "dino": RestPose(.curl, "curls up in the leaves", lift: 2, hiddenBelow: 3),
        "dragon": RestPose(.curl, "curls up on its hoard", lift: 6),
    ]

    /// The pose for `look` (`PetKind.decorLook`); a pet you drew curls up like the cat.
    static func pose(for look: String?) -> RestPose {
        poses[Self.look(look, for: .cushion) ?? "cat"] ?? RestPose(.curl, "curls up", lift: 4)
    }

    // MARK: The frame on the spot

    /// The letters a parrot's legs and feet are drawn in (HD shades them with
    /// "a" and "s"; classic is "F" alone).
    static let footLetters: Set<Character> = ["F", "a", "s"]

    /// `rows` changed for `reshape`; `factor` is the art's pixels per classic pixel.
    static func reshaped(_ rows: [String], _ reshape: RestPose.Reshape, factor: Int) -> [String] {
        switch reshape {
        case .none: rows
        case .tuckFoot: tuckFoot(rows)
        case .fluff: fluff(rows, by: max(1, factor))
        }
    }

    /// Stands on one foot: the toes ("F") fall in two groups, and every leg
    /// and foot pixel left of the line between them goes. Where one met the
    /// body, the body gets its outline back; elsewhere it is empty.
    static func tuckFoot(_ rows: [String], outline: Character = "o") -> [String] {
        var grid = rows.map(Array.init)
        var seen = Set<[Int]>(), groups: [[(x: Int, y: Int)]] = []
        for y in grid.indices {
            for x in grid[y].indices where grid[y][x] == "F" && !seen.contains([x, y]) {
                var group: [(x: Int, y: Int)] = [], todo = [(x, y)]
                seen.insert([x, y])
                while let (px, py) = todo.popLast() {
                    group.append((px, py))
                    for (nx, ny) in [(px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)]
                        where grid.indices.contains(ny) && grid[ny].indices.contains(nx) && grid[ny][nx] == "F" && !seen.contains([nx, ny]) {
                        seen.insert([nx, ny])
                        todo.append((nx, ny))
                    }
                }
                groups.append(group)
            }
        }
        let middles = groups.map { group in Double(group.map(\.x).reduce(0, +)) / Double(group.count) }.sorted()
        guard middles.count >= 2 else { return rows }
        let split = (middles[0] + middles[1]) / 2
        var gone: [(x: Int, y: Int)] = []
        for y in grid.indices {
            for x in grid[y].indices where footLetters.contains(grid[y][x]) && Double(x) < split {
                grid[y][x] = "."
                gone.append((x, y))
            }
        }
        let original = grid
        for (x, y) in gone {
            let touchesBody = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { nx, ny in
                guard original.indices.contains(ny), original[ny].indices.contains(nx) else { return false }
                let c = original[ny][nx]
                return c != "." && c != outline && !footLetters.contains(c)
            }
            if touchesBody { grid[y][x] = outline }
        }
        return grid.map { String($0) }
    }

    /// Feathers puffed out: each row of the lower three fifths of what is
    /// drawn that ends in outline grows `n` pixels out on that side, its old
    /// outline filled with the colour just inside. A beak, comb or tail tip
    /// at a row's end (not outline) stays as it is.
    static func fluff(_ rows: [String], by n: Int, outline: Character = "o") -> [String] {
        var grid = rows.map(Array.init)
        let drawn = grid.indices.filter { grid[$0].contains { $0 != "." } }
        guard let top = drawn.first, let bottom = drawn.last, n > 0 else { return rows }
        let from = bottom - max(1, ((bottom - top + 1) * 3 + 4) / 5) + 1
        for y in from...bottom {
            let row = grid[y]
            guard let left = row.firstIndex(where: { $0 != "." }), let right = row.lastIndex(where: { $0 != "." }) else { continue }
            if row[left] == outline, left - n >= 0 {
                let inside = left + 1 < row.count && row[left + 1] != "." ? row[left + 1] : outline
                for x in (left - n)...left { grid[y][x] = x == left - n ? outline : inside }
            }
            if row[right] == outline, right + n < row.count {
                let inside = right - 1 >= 0 && row[right - 1] != "." ? row[right - 1] : outline
                for x in right...(right + n) { grid[y][x] = x == right + n ? outline : inside }
            }
        }
        return grid.map { String($0) }
    }

    /// The finished picture on its spot: the empty rows under it dropped (so
    /// its lowest drawn row is the image's bottom, `lift` up from the floor),
    /// and its lowest `rows` drawn rows left out, down in the nest or water.
    static func sunk<T>(_ grid: [[T?]], hiding rows: Int) -> [[T?]] {
        var out = grid
        while let last = out.last, last.allSatisfy({ $0 == nil }) { out.removeLast() }
        guard rows > 0, !out.isEmpty else { return out }
        for y in max(0, out.count - rows)..<out.count { out[y] = out[y].map { _ in nil } }
        return out
    }

    // MARK: Clicking it there

    /// Where the pet on its spot shows in its window, in points: the
    /// finished picture (`width` x `height` pixels of `pixel` points, `factor`
    /// art pixels to a classic one) centred across a window `windowWidth`
    /// wide, its bottom row on the window's floor `bob` up, less the rows
    /// left out down in the spot.
    static func drawnRect(width: Int, height: Int, pixel: CGFloat, factor: Int, windowWidth: CGFloat, bob: CGFloat = 0,
                          pose: RestPose) -> CGRect {
        let hidden = CGFloat(min(height, pose.hiddenRows(factor: factor))) * pixel
        let w = CGFloat(width) * pixel, h = CGFloat(height) * pixel
        return CGRect(x: (windowWidth - w) / 2, y: bob + hidden, width: w, height: max(0, h - hidden))
    }

    /// What takes a click while it rests there: its usual body and all of
    /// what is drawn of it, a couple of points around, so a pet down in its
    /// nest or water (only ears or a fin showing) is as easy to get up as
    /// one lying on top.
    static func clickRect(body: CGRect, drawn: CGRect) -> CGRect {
        drawn.isEmpty ? body : body.union(drawn.insetBy(dx: -2, dy: -2))
    }
}
