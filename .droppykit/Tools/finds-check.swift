// Checks found things: the daily few, the wait between two, the decoration
// every so many, and how they are saved, no Droppy needed:
//   cp .droppykit/Tools/finds-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/Finds.swift Sources/Pixpaw/HomeDecor.swift Sources/Pixpaw/RestSpot.swift Sources/Pixpaw/CatSprites.generated.swift \
//     Sources/Pixpaw/CatSprites.fine.generated.swift Sources/Pixpaw/FineCoats.swift Sources/Pixpaw/Wardrobe.swift Sources/Pixpaw/Stats.swift \
//     /tmp/main.swift -o /tmp/finds-check && /tmp/finds-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
var f = Finds()
check(f.canBring(on: "2026-11-14", now: t0), "a fresh start may bring one")
f.brought(on: "2026-11-14", now: t0)
check(!f.canBring(on: "2026-11-14", now: t0.addingTimeInterval(60)), "not again a minute later")
check(f.canBring(on: "2026-11-14", now: t0.addingTimeInterval(Finds.gap)), "again after the wait")
f.brought(on: "2026-11-14", now: t0.addingTimeInterval(Finds.gap))
f.brought(on: "2026-11-14", now: t0.addingTimeInterval(2 * Finds.gap))
check(f.count(on: "2026-11-14") == Finds.dailyLimit, "three counted today")
check(!f.canBring(on: "2026-11-14", now: t0.addingTimeInterval(10 * Finds.gap)), "no fourth the same day")
check(f.canBring(on: "2026-11-15", now: t0.addingTimeInterval(10 * Finds.gap)), "a new day starts over")
check(f.count(on: "2026-11-15") == 0, "nothing counted on a day not reached yet")
f.brought(on: "2026-11-15", now: t0.addingTimeInterval(10 * Finds.gap))
check(f.today == 1 && f.day == "2026-11-15", "the new day's count")

// Decorations: every eighth, with a home, cheapest not owned, never a repeat.
var g = Finds()
var got: [HomeDecor] = []
for _ in 0..<(Finds.decorEvery * 3) {
    if let d = g.pickedUp(hasHome: true, owned: Set(got)) { got.append(d) }
}
check(got == [.rug, .plant, .bowls], "the cheapest not owned, every eighth, never the framed picture: \(got)")
check(g.total == Finds.decorEvery * 3, "every pick-up counted")
var h = Finds()
var none = 0
for _ in 0..<(Finds.decorEvery * 2) where h.pickedUp(hasHome: false, owned: []) != nil { none += 1 }
check(none == 0, "no decoration without a home")
var all = Finds()
all.total = Finds.decorEvery - 1
check(all.pickedUp(hasHome: true, owned: Set(HomeDecor.allCases)) == nil, "nothing left to find: stars only")
// Stars per find stay small next to the shop's cheapest piece.
check(StarSource.find.amount * StarSource.find.dailyLimit * 2 < HomeDecor.allCases.filter { $0 != .picture }.map(\.price).min()!, "two days of finds buy less than the cheapest decoration on sale")
check(StarSource.find.dailyLimit == Finds.dailyLimit, "star limit matches the daily finds")

// Saved and read back; old or broken values start fresh, never crash.
var s = Finds()
s.brought(on: "2026-11-14", now: t0)
s.total = 17
let back = Finds(saved: s.saved)
check(back.day == "2026-11-14" && back.today == 1 && back.total == 17, "round trip: \(s.saved)")
check(Finds(saved: "") == Finds(), "nothing saved: fresh")
check(Finds(saved: "junk").total == 0, "junk: fresh")
check(Finds(saved: "2026-11-14|-3|x").today == 0, "bad numbers: zero")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
