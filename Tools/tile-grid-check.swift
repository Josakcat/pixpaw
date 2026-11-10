// Checks the Wardrobe's tile grid (columns that fit, row heights) on its
// own, no Droppy needed:
//   cp Tools/tile-grid-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/TileGrid.swift /tmp/main.swift -o /tmp/tile-grid-check && /tmp/tile-grid-check

import Foundation

// As GridItem(.adaptive(minimum: 104), spacing: 8): as many as fit, sharing the width.
let narrow = TileGrid.columns(width: 100, minimum: 104, spacing: 8, count: 12)
assert(narrow.count == 1 && narrow.width == 100, "never fewer than one column")
let three = TileGrid.columns(width: 328, minimum: 104, spacing: 8, count: 12)
assert(three.count == 3 && three.width == 104, "three fit exactly at 3×104 + 2×8")
let two = TileGrid.columns(width: 327, minimum: 104, spacing: 8, count: 12)
assert(two.count == 2 && two.width == 159.5, "one point short of three is two")
let none = TileGrid.columns(width: 400, minimum: 104, spacing: 8, count: 0)
assert(none.count == 0, "no tiles, no columns")
let unbounded = TileGrid.columns(width: .infinity, minimum: 104, spacing: 8, count: 5)
assert(unbounded.count == 5 && unbounded.width == 104, "unbounded width lays one row at the minimum")

// Rows take their tallest tile; the total adds the gaps between rows.
let rows = TileGrid.rows(heights: [150, 166, 150, 150, 182], columns: 3, spacing: 8)
assert(rows.rows == [166, 182], "a row is as tall as its tallest tile")
assert(rows.total == 166 + 182 + 8, "one gap between two rows")
assert(TileGrid.rows(heights: [], columns: 3, spacing: 8).total == 0, "no tiles, no height")
// The same input always gives the same height: nothing estimated.
assert(TileGrid.rows(heights: [150, 166, 150, 150, 182], columns: 3, spacing: 8).total == rows.total)

print("tile grid: all checks passed")
