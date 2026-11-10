// Checks the finer desktop art (FineArt) and where things are worn on it, no Droppy needed:
//   cp Tools/fine-art-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/CatSprites.fine.generated.swift Sources/Pixpaw/FineCoats.swift Sources/Pixpaw/CatSprites.generated.swift Sources/Pixpaw/Wardrobe.swift Sources/Pixpaw/Stats.swift /tmp/main.swift -o /tmp/fine-art-check && /tmp/fine-art-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let poses = ["sit", "blink", "happy", "walk1", "walk2", "walk3", "run1", "run2", "groom1", "groom2",
             "sleep1", "sleep2", "eat1", "eat2", "crouch1", "crouch2", "held1", "held2"]
let k = FineArt.scale

/// The 20 x 16 art drawn k times over, as CatSprites does.
func enlarged(_ art: [String]) -> [String] {
    art.flatMap { row in Array(repeating: String(row.flatMap { Array(repeating: $0, count: k) }), count: k) }
}

check(k == 2, "finer art is twice the pixels: 40 x 32 in the 60 x 48 pt frame, 1.5 pt a pixel")
check(!FineArt.palettes.isEmpty, "some look has finer art")

/// Dark enough to be an open eye's pupil.
func isDark(_ rgb: UInt32) -> Bool {
    0.299 * Double(rgb >> 16 & 0xFF) + 0.587 * Double(rgb >> 8 & 0xFF) + 0.114 * Double(rgb & 0xFF) < 80
}

for (look, palette) in FineArt.palettes.sorted(by: { $0.key < $1.key }) {
    check(palette["f"] != nil, "\(look): has an f fur colour, for glasses on dark fur")
    // What it may wear is its kind's, exactly as for the 20 x 16 art.
    let kind = String(look.split(separator: ".")[0])
    let wearer = Wearer(isOwn: false, hasNeck: kind == "cat", looksLike: kind)
    let wearsGlasses = CatAccessory.allCases.contains { $0.slot == .face && $0.fits(wearer) }
    for pose in poses {
        let key = "\(look).\(pose)"
        let smallKey = kind == "cat" ? pose : "\(kind).\(pose)"
        guard let rows = FineArt.frames[key] else { check(false, "\(key): drawn"); continue }
        // Carried: held up from the front (32 x 40, like the cat) or still side on (40 x 32).
        let (w, h) = (rows.first?.count ?? 0, rows.count)
        let sizes = pose.hasPrefix("held") ? [(16 * k, 20 * k), (CatArt.width * k, CatArt.height * k)] : [(CatArt.width * k, CatArt.height * k)]
        check(sizes.contains { $0 == (w, h) } && rows.allSatisfy { $0.count == w }, "\(key): \(w) x \(h)")
        check(rows.allSatisfy { $0.allSatisfy { $0 == "." || palette[$0] != nil } }, "\(key): every pixel in its palette")
        func art(_ x: Int, _ y: Int) -> Bool {
            y >= 0 && y < rows.count && x >= 0 && x < rows[y].count && Array(rows[y])[x] != "."
        }
        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && x < w && y < h }

        // Hats: every one, k times over, inside the frame's width and sitting on the head.
        guard let anchor = FineArt.anchors[key] else { check(false, "\(key): has anchors"); continue }
        let hatX = Int(anchor.0.rounded(.down)), hatRow = anchor.1
        check(art(hatX, hatRow) || art(hatX - 1, hatRow), "\(key): the hat spot (\(anchor.0), \(hatRow)) is on the head")
        // Background within three rows over it (ears, horns and antennae may stand up beside it).
        let open = (hatRow - 3..<hatRow).contains { y in !art(hatX, y) || !art(hatX - 1, y) }
        check(open, "\(key): the hat spot is at the top of the head")
        for item in CatAccessory.allCases where item.slot == .hat && item != .headset && item.fits(wearer) {
            guard let small = CatArt.accessories[item.rawValue] else { continue }
            let big = enlarged(small)
            // CatSprites keeps finer art's hats whole inside the frame; this checks the hat still sits on the head.
            let placed = Int((anchor.0 - Double(big[0].count) / 2).rounded()) + (CatArt.accessoryShift[item.rawValue] ?? 0) * k
            let left = max(0, min(placed, w - big[0].count))
            check(big[0].count <= w && (left...left + big[0].count - 1).contains { art($0, hatRow) || art($0, hatRow + 1) },
                  "\(key): \(item.rawValue) on the head, inside the frame")
        }
        // Collars: where there is one, on the neck: art under every pixel, inside the frame.
        check(anchor.3 < 0 || wearer.hasNeck, "\(key): a collar spot only on a kind that wears one")
        if anchor.3 >= 0 {
            for item in CatAccessory.allCases where item.slot == .collar {
                guard let small = CatArt.accessories[item.rawValue] else { continue }
                let big = enlarged(small)
                let left = Int((anchor.2 - Double(big[0].count) / 2).rounded())
                check(left >= 0 && left + big[0].count <= w && anchor.3 + big.count <= h, "\(key): \(item.rawValue) inside the frame")
            }
            let band = enlarged(CatArt.accessories["redCollar"]!)
            let left = Int((anchor.2 - Double(band[0].count) / 2).rounded())
            let covered = (0..<band.count).allSatisfy { dy in (0..<band[0].count).allSatisfy { art(left + $0, anchor.3 + dy) } }
            check(covered, "\(key): the collar lies on the neck")
        }

        // Glasses: round the eye boxes by the 20 x 16 rule, inside the frame, eyes under them.
        let eyes = FineArt.eyes[key] ?? []
        if !wearsGlasses {
            check(eyes.isEmpty, "\(key): no eye boxes on a kind that wears no glasses")
        } else if WardrobeArt.hidesGlasses(pose) {
            check(eyes.isEmpty, "\(key): no glasses asleep or carried")
        } else {
            // Two eyes from the front, one from the side.
            check(eyes.count == 1 || (eyes.count == 2 && eyes[0].x1 < eyes[1].x0), "\(key): one eye, or two left then right")
            for box in eyes {
                let (bw, bh) = (box.x1 - box.x0 + 1, box.y1 - box.y0 + 1)
                check((3...5).contains(bw) && (3...6).contains(bh), "\(key): the eye box is an eye, \(bw) x \(bh)")
                let lit = (box.y0...box.y1).contains { y in (box.x0...box.x1).contains { art($0, y) } }
                check(lit, "\(key): the eye box is on the face")
                if !WardrobeArt.borrowsSitEyes(pose) {
                    let dark = (box.y0...box.y1).contains { y in
                        (box.x0...box.x1).contains { x in art(x, y) && palette[Array(rows[y])[x]].map(isDark) == true }
                    }
                    check(dark, "\(key): an open eye inside its box")
                }
            }
            for item in CatAccessory.allCases where item.slot == .face {
                let pixels = WardrobeArt.glasses(item, eyes: eyes, darkFur: false)
                check(!pixels.isEmpty && pixels.allSatisfy { inside($0.x, $0.y) && $0.y >= 0 }, "\(key): \(item.rawValue) inside the frame")
                // A 1-pixel rim: nothing drawn over the eye itself for the round ones.
                if item == .roundGlasses {
                    check(!pixels.contains { p in eyes.contains { p.x >= $0.x0 && p.x <= $0.x1 && p.y >= $0.y0 && p.y <= $0.y1 } },
                          "\(key): round glasses leave the eyes showing")
                }
            }
        }

        // Headphones and the headset: in the same frames as the 20 x 16 art,
        // inside the frame, cups on the head (both from the front, the near one side on).
        check((FineArt.headphonesAt[key] != nil) == (CatArt.headphonesAt[smallKey] != nil),
              "\(key): headphones in this frame just when the 20 x 16 art has them")
        if let (view, left, top) = FineArt.headphonesAt[key] {
            guard let phones = FineArt.headphones[view] else { check(false, "\(key): headphones \(view) drawn"); continue }
            check(left >= 0 && left + phones[0].count <= w && top >= 0, "\(key): headphones inside the frame")
            let cupRow = top + phones.count - 2
            let cups = Array(phones[phones.count - 2]).enumerated().filter { $0.element != "." }.map(\.offset)
            let front = cups.max()! >= phones[0].count / 2 && view != "sideBack"
            // Seen from behind the cup is on the far side of the head.
            let cupX = view == "sideBack" ? left + phones[0].count - 2 : left + 1
            check(art(cupX, cupRow) && (!front || art(left + phones[0].count - 2, cupRow)),
                  front ? "\(key): both cups on the head" : "\(key): the cup on the head")
            let headset = WardrobeArt.headset(phones, left: left, top: top, darkFur: false, size: k)
            check(headset.allSatisfy { inside($0.x, $0.y) }, "\(key): headset and its mic inside the frame")
        }
    }
}

// Every coat wears the gray tabby's sheet, ears up or folded, in colours from its 20 x 16 ones.
let coats = ["orange", "black", "white", "gray", "siamese", "calico"]
for look in ["cat.gray", "cat.gray.folded"] {
    check(FineArt.palettes[look] != nil, "\(look): drawn")
    let letters = Set(poses.flatMap { Array(FineArt.frames["\(look).\($0)"]?.joined() ?? "") }).subtracting(["."])
    for coat in coats {
        guard let small = CatArt.coats[coat] else { check(false, "\(coat): a 20 x 16 coat"); continue }
        let fine = FineArt.palette(coat: small)
        check(letters.allSatisfy { fine[$0] != nil }, "\(look) in \(coat): every letter has a colour")
        check(fine["f"] == small["f"] && fine["S"] == small["s"] && fine["w"] == small["w"] && fine["p"] == small["p"],
              "\(look) in \(coat): fur, stripes, white and pink are the coat's own")
        check(fine["o"] != fine["f"] && fine["d"] != fine["e"], "\(look) in \(coat): an outline and eyes that show")
    }
}
// Worked out for the gray coat, the colours land near the gray as drawn.
if let drawn = FineArt.palettes["cat.gray"], let gray = CatArt.coats["gray"] {
    let made = FineArt.palette(coat: gray)
    func near(_ a: UInt32, _ b: UInt32) -> Bool { [16, 8, 0].allSatisfy { abs(Int((a >> $0) & 0xFF) - Int((b >> $0) & 0xFF)) <= 24 } }
    check(drawn.allSatisfy { letter, rgb in made[letter].map { near($0, rgb) } ?? false }, "gray worked out is within 24 of gray as drawn")
}
// Folded ears change only the ears: no inner-ear pink, nothing below the head's top 8 rows touched.
for pose in poses {
    guard let up = FineArt.frames["cat.gray.\(pose)"], let folded = FineArt.frames["cat.gray.folded.\(pose)"] else {
        check(false, "cat.gray.folded.\(pose): drawn"); continue
    }
    check(!folded.joined().contains("r") && !folded.joined().contains("q"), "cat.gray.folded.\(pose): no inner ear showing")
    let top = up.firstIndex { $0.contains { $0 != "." } } ?? 0
    let changed = zip(up, folded).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
    check(!changed.isEmpty && changed.allSatisfy { $0 < top + 8 }, "cat.gray.folded.\(pose): only the ears changed")
    let foldedTop = folded.firstIndex { $0.contains { $0 != "." } } ?? 0
    check(foldedTop >= top, "cat.gray.folded.\(pose): no taller than ears up")
}

// The 20 x 16 headset keeps its 1-pixel mic.
let small = WardrobeArt.headset(["b.b", "b.b"], left: 0, top: 0, darkFur: false)
check(small.filter { $0.y == 2 } == [WornPixel(x: 1, y: 2, colour: "k"), WornPixel(x: 2, y: 2, colour: "r")], "20 x 16 headset mic unchanged")
let big = WardrobeArt.headset(["b.b", "b.b"], left: 0, top: 0, darkFur: false, size: 2)
check(big.filter { $0.y >= 2 }.count == 8 && big.filter { $0.colour == "r" }.count == 4, "finer headset mic is 2 pixels thick, its tip red")

// Every pet's colourways: the same letters as its own look, in both sizes, nothing for the cat.
check(CatArt.petCoats["cat"] == nil, "the cat keeps its coats, no colourways")
for (kind, coats) in CatArt.petCoats.sorted(by: { $0.key < $1.key }) {
    check(coats.count > 1 && CatArt.petCoatPalettes["\(kind).\(coats[0].id)"] == nil, "\(kind): its own look first, drawn as is")
    for coat in coats.dropFirst() {
        check(CatArt.petCoatPalettes["\(kind).\(coat.id)"].map { Set($0.keys) } == CatArt.coats[kind].map { Set($0.keys) },
              "\(kind).\(coat.id): every 20 x 16 letter")
        check(FineArt.petCoatPalettes["\(kind).\(coat.id)"].map { Set($0.keys) } == FineArt.palettes[kind].map { Set($0.keys) },
              "\(kind).\(coat.id): every finer letter")
    }
}

// HD props are twice the 20 x 16 grids, so at 1.5 pt they cover the same points; every letter has a colour.
func twice(_ fine: [String]?, _ old: [String]?) -> Bool {
    guard let fine, let old else { return false }
    return fine.count == 2 * old.count && fine.allSatisfy { $0.count == 2 * (old.map(\.count).max() ?? 0) }
}
for (name, rows) in FineArt.accessories {
    check(twice(rows, CatArt.accessories[name]) && rows.joined().allSatisfy { $0 == "." || FineArt.accessoryColors[$0] != nil },
          "accessory \(name): twice the grid, every letter coloured")
}
for name in ["bowl", "bowlEmpty", "treat", "giftFlower", "giftBone", "giftBall", "giftFeather", "yarn1", "yarn2", "teaser", "laser"] {
    check(twice(FineArt.effects[name], CatArt.effects[name]) && (FineArt.effects[name] ?? []).joined().allSatisfy { $0 == "." || FineArt.effectColors[$0] != nil },
          "effect \(name): twice the grid, every letter coloured")
}
// Over the head they were 2 pt a pixel: 4/3 the grid at 1.5 pt covers the same points.
let overHead = ["heart", "zzz", "fish", "note", "code", "sweat", "dizzy1", "dizzy2", "dizzy3"]
for name in overHead {
    let fine = FineArt.effects[name] ?? [], old = CatArt.effects[name] ?? []
    let w = Int((Double(old.map(\.count).max() ?? 0) * 4 / 3).rounded()), h = Int((Double(old.count) * 4 / 3).rounded())
    check(!old.isEmpty && fine.count == h && fine.allSatisfy { $0.count == w } && fine.joined().allSatisfy { $0 == "." || FineArt.effectColors[$0] != nil },
          "effect \(name): 4/3 the grid (\(w) x \(h)), every letter coloured")
}
// The bug walks on the floor at twice the grid; the rest are over the head at 4/3 (sizes checked against
// AgentArt.swift by `python3 Tools/fine_extras.py`).
for (name, art) in FineArt.toys.map({ ($0.key, [$0.value.rows]) }) + FineArt.agent.map({ ($0.key, $0.value.frames) }) {
    let palette = FineArt.toys[name]?.palette ?? FineArt.agent[name]?.palette ?? [:]
    let even = FineArt.toys[name] != nil || name == "bug" || name == "squashed"
    check(art.allSatisfy { rows in !rows.isEmpty && (!even || rows.count % 2 == 0) && rows.allSatisfy { $0.count == rows[0].count && (!even || $0.count % 2 == 0) }
          && rows.joined().allSatisfy { $0 == "." || $0 == "o" || palette[$0] != nil } }, "toy/agent \(name): \(even ? "even " : "")rectangle, every letter coloured")
}
// Homes: twice the grid, every letter coloured, and a doorway to leave open while someone sleeps inside.
check(Set(FineArt.homes.keys) == Set(CatArt.homes.keys), "homes: an HD home for every home")
for (name, rows) in FineArt.homes.sorted(by: { $0.key < $1.key }) {
    check(rows.count == 2 * CatArt.homeHeight && rows.allSatisfy { $0.count == 2 * CatArt.homeWidth }, "home \(name): twice the grid")
    check(rows.joined().allSatisfy { $0 == "." || FineArt.homeColors[$0] != nil }, "home \(name): every letter coloured")
    check(rows.joined().contains("d") == (CatArt.homes[name] ?? []).joined().contains("d"), "home \(name): has its doorway")
}

print(failures == 0 ? "all fine-art checks pass" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
