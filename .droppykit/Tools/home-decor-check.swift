// Checks home decorations: prices, the wallet, buying, where things stand
// and how they are saved, on their own, no Droppy needed:
//   cp .droppykit/Tools/home-decor-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/HomeDecor.swift Sources/Pixpaw/RestSpot.swift Sources/Pixpaw/CatSprites.generated.swift \
//     Sources/Pixpaw/CatSprites.fine.generated.swift Sources/Pixpaw/FineCoats.swift Sources/Pixpaw/Wardrobe.swift Sources/Pixpaw/Stats.swift \
//     /tmp/main.swift -o /tmp/home-decor-check && /tmp/home-decor-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Prices, cheapest first, 1,040 for everything.
check(HomeDecor.shown(owned: []).map(\.price) == [60, 80, 90, 110, 140, 160, 180, 220], "prices in order")
// The framed picture from a widget drop: never in the shop, listed once it's yours.
check(!HomeDecor.shown(owned: []).contains(.picture) && HomeDecor.shown(owned: [.picture]).last == .picture, "picture listed only once yours")
check(HomeDecor.picture.spots == [.left, .right, .outer] && DecorShop.owned(saved: "rug,picture") == [.rug, .picture], "picture stands beside the home and is saved")
check(HomeDecor.allCases.map(\.price).reduce(0, +) == 1040, "1,040 ★ for all eight")
check(HomeDecor.rug.spots == [.front] && HomeDecor.allCases.filter { $0 != .rug }.allSatisfy { $0.spots == [.left, .right, .outer] },
      "the rug is the doormat, the rest stand beside")
check(HomeDecor.lamp.thanks == "A floor lamp, for me?", "the pet's thanks")

// The wallet: earned minus spent, never below zero.
check(DecorShop.wallet(points: 640, spent: 460) == 180, "wallet = earned - spent")
check(DecorShop.wallet(points: 100, spent: 300) == 0, "wallet never below zero")
check(DecorShop.label(.lamp, points: 640, spent: 500) == "Floor lamp · 140 ★", "affordable label")
check(DecorShop.label(.lamp, points: 610, spent: 500) == "Floor lamp · 30 ★ more", "short label")

// Buying.
let none = HomeDecorSet()
let first = DecorShop.buy(.lamp, points: 640, spent: 0, owned: [], placed: none)
check(first == .init(spent: 140, owned: [.lamp], placed: HomeDecorSet(left: .lamp)), "a buy spends, owns, puts it left")
check(DecorShop.buy(.lamp, points: 640, spent: 140, owned: [.lamp], placed: HomeDecorSet(left: .lamp)) == nil, "owned can't be bought again")
check(DecorShop.buy(.mailbox, points: 500, spent: 300, owned: [], placed: none) == nil, "short wallet can't buy")
check(DecorShop.buy(.mailbox, points: 520, spent: 300, owned: [], placed: none)?.spent == 520, "exactly enough buys")
let second = DecorShop.buy(.plant, points: 640, spent: 140, owned: [.lamp], placed: HomeDecorSet(left: .lamp))
check(second?.placed == HomeDecorSet(left: .lamp, right: .plant), "the next goes in the free side")
let third = DecorShop.buy(.books, points: 1000, spent: 220, owned: [.lamp, .plant], placed: HomeDecorSet(left: .lamp, right: .plant))
check(third?.placed == HomeDecorSet(left: .lamp, right: .plant) && third?.owned.contains(.books) == true, "no room: owned, not placed")
check(DecorShop.buy(.rug, points: 1000, spent: 0, owned: [], placed: HomeDecorSet(left: .lamp, right: .plant))?.placed.front == .rug,
      "the rug goes in front")

// Placing: one spot a thing, one thing a spot, only where it fits.
let both = HomeDecorSet(left: .lamp, right: .plant)
check(both.placing(.lamp, in: .right) == HomeDecorSet(right: .lamp), "moving a thing leaves its old spot")
check(both.placing(nil, in: .left) == HomeDecorSet(right: .plant), "taking it off empties the spot")
check(both.placing(.rug, in: .left) == both, "the rug doesn't stand beside")
check(both.placing(.lamp, in: .front) == both, "a lamp isn't a doormat")

// Saved and read back.
let full = HomeDecorSet(left: .lamp, right: .plant, front: .rug)
check(full.saved == "left=lamp,right=plant,front=rug", "saved words")
check(HomeDecorSet(saved: full.saved, owned: [.lamp, .plant, .rug]) == full, "read back")
check(HomeDecorSet(saved: full.saved, owned: [.lamp]) == HomeDecorSet(left: .lamp), "only what is owned comes back")
check(HomeDecorSet(saved: "left=lamp,right=lamp,front=plant,x=y", owned: [.lamp, .plant]) == HomeDecorSet(left: .lamp),
      "a thing in two spots or the wrong one is dropped")
check(DecorShop.saved([.mailbox, .rug]) == "rug,mailbox" && DecorShop.owned(saved: "rug,mailbox,hat") == [.rug, .mailbox], "owned list")

// Layout: a slot each side only while something stands there.
let layout = HomeDecorLayout(HomeDecorSet(left: .lamp), slot: 20)
check(layout.left == 20 && layout.right == 0 && layout.width(home: 34) == 54, "left slot only")
check(layout.sideX(.left, itemWidth: 10, home: 34, slot: 20, gap: 1) == 9, "left item hugs the home")
check(HomeDecorLayout(full, slot: 20).sideX(.right, itemWidth: 12, home: 34, slot: 20, gap: 1) == 55, "right item hugs the home")
check(layout.frontX(itemWidth: 18, spotX: 7, frameWidth: 20) == 28, "doormat centred under the sleeping pet")
check(HomeDecorLayout(none, slot: 20).width(home: 34) == 34, "no decor, no wider")

// Each pet's own version: same slot, price and save key; only the look and name change.
let variants = HomeDecor.variants.flatMap { kind, items in items.map { (kind: kind, item: $0.key, v: $0.value) } }
check(variants.count == 47, "47 pet versions (\(variants.count))")
check(Set(HomeDecor.variants.keys).isSubset(of: Set(CatArt.homes.keys)), "versions only for kinds with a home")
check(variants.allSatisfy { $0.v.title.count <= 16 }, "every title fits (16 characters at most)")
check(variants.allSatisfy { $0.item != .rug }, "the doormat stays the same for everyone")
check(Set(variants.map(\.v.art)).count == 46, "46 pictures: only seed dish/cup share one")
check(variants.allSatisfy { v in
    guard let classic = CatArt.decor[v.v.art], let fine = FineArt.decor[v.v.art] else { return false }
    return fine.count == classic.count * 2 && fine.first?.count == (classic.first?.count ?? 0) * 2
}, "every version drawn in classic and HD (twice the grid)")
check(variants.allSatisfy { v in
    (CatArt.decor[v.v.art] ?? []).allSatisfy { $0.count <= CatArt.decorSlotWidth } && (CatArt.decor[v.v.art] ?? []).count <= 16
}, "every version fits its 20 x 16 slot")
check(variants.allSatisfy { v in
    (CatArt.decor[v.v.art] ?? []).joined().allSatisfy { $0 == "." || CatArt.homeColors[$0] != nil }
        && (FineArt.decor[v.v.art] ?? []).joined().allSatisfy { $0 == "." || FineArt.homeColors[$0] != nil }
}, "every version in the homes' own letters")
check(HomeDecor.bowls.title(for: "cat") == "Fish dish" && HomeDecor.bowls.artKey(for: "cat") == "bowls.cat", "a cat's bowls are a fish dish")
check(HomeDecor.lamp.title(for: "cat") == "Floor lamp" && HomeDecor.lamp.artKey(for: "cat") == "lamp", "no version: the usual one")
check(HomeDecor.bowls.title(for: nil) == "Pet bowls" && HomeDecor.bowls.title(for: "own1") == "Pet bowls", "no look: the usual one")
check(HomeDecor.bowls.artKey(for: "hamster") == HomeDecor.bowls.artKey(for: "parrot"), "seed dish and seed cup share art")
check(HomeDecor.bowls.artKey(for: "rabbit") != HomeDecor.lamp.artKey(for: "giraffe"), "the giraffe hangs its own tall hay feeder")
check(HomeDecor.lamp.thanks(for: "hamster") == "A water bottle, for me?" && HomeDecor.plant.thanks(for: "cat") == "Cat grass, for me?",
      "thanks in the pet's words")
check(HomeDecor.basket.thanks(for: "dino") == "An egg nest, for me?", "an before a vowel")
check(DecorShop.label(.bowls, points: 640, spent: 500, look: "dog") == "Bone bowl · 90 ★", "the shop names the pet's version")

// Using them: what it picks by itself, and when.
let all = HomeDecorSet(left: .cushion, right: .bowls, front: .rug)
check(DecorUse.pick(all, hungry: true, night: false, hasMail: false, roll: 0) == .bowls, "hungry: the bowls first")
check(DecorUse.pick(HomeDecorSet(left: .cushion, right: .mailbox), hungry: true, night: false, hasMail: true, roll: 0.9) == .mailbox,
      "a letter waiting: the mailbox (no bowls to eat from)")
check(DecorUse.pick(HomeDecorSet(left: .mailbox, right: .bowls), hungry: false, night: false, hasMail: false, roll: 0.5) == nil,
      "nothing to do at an empty mailbox or full bowls")
check(DecorUse.pick(HomeDecorSet(front: .rug), hungry: false, night: true, hasMail: true, roll: 0) == nil, "the doormat is never picked")
check(DecorUse.pick(HomeDecorSet(), hungry: true, night: true, hasMail: true, roll: 0) == nil, "nothing placed, nothing picked")
let pair = HomeDecorSet(left: .cushion, right: .lamp)
check(DecorUse.pick(pair, hungry: false, night: false, hasMail: false, roll: 0) == .cushion
      && DecorUse.pick(pair, hungry: false, night: false, hasMail: false, roll: 0.99) == .lamp, "by weight, only what is placed")
let lampByDay = (0..<100).filter { DecorUse.pick(pair, hungry: false, night: false, hasMail: false, roll: Double($0) / 100) == .lamp }.count
let lampAtNight = (0..<100).filter { DecorUse.pick(pair, hungry: false, night: true, hasMail: false, roll: Double($0) / 100) == .lamp }.count
check(lampByDay == 25 && lampAtNight > 50, "the lamp is picked more at night (\(lampByDay) vs \(lampAtNight) in 100)")
check(DecorUse.pick(pair, hungry: false, night: false, hasMail: false, roll: 1.5) == .lamp
      && DecorUse.pick(pair, hungry: false, night: false, hasMail: false, roll: -1) == .cushion, "rolls out of range are clamped")
let used = Date(timeIntervalSince1970: 1_000_000)
check(DecorUse.ready(now: used, last: nil), "never used: ready")
check(!DecorUse.ready(now: used.addingTimeInterval(DecorUse.cooldown - 1), last: used), "not again within the cooldown")
check(DecorUse.ready(now: used.addingTimeInterval(DecorUse.cooldown), last: used), "ready once the cooldown is over")

// The lamp is lit from 19:00 to 06:00.
check((0..<24).filter(DecorUse.isNight) == [0, 1, 2, 3, 4, 5, 19, 20, 21, 22, 23], "lamp lit 19:00 to 06:00")

// Clicks on the things beside the home (art pixels, y up from the floor).
let sides = HomeDecorLayout(HomeDecorSet(left: .plant, right: .books, front: .rug), slot: 20)
let plantRect = sides.rect(.left, itemWidth: 12, itemHeight: 14, home: 34, slot: 20, gap: 1, spotX: 7, frameWidth: 20)
let booksRect = sides.rect(.right, itemWidth: 12, itemHeight: 14, home: 34, slot: 20, gap: 1, spotX: 7, frameWidth: 20)
let rugRect = sides.rect(.front, itemWidth: 24, itemHeight: 4, home: 34, slot: 20, gap: 1, spotX: 7, frameWidth: 20)
check(plantRect == CGRect(x: 7, y: 0, width: 12, height: 14), "left thing hugs the home (\(plantRect))")
check(booksRect == CGRect(x: 55, y: 0, width: 12, height: 14), "right thing hugs the home (\(booksRect))")
check(rugRect == CGRect(x: 25, y: 0, width: 24, height: 4), "the doormat under where it sleeps (\(rugRect))")
let rects: [(HomeDecor, CGRect)] = [(.plant, plantRect), (.books, booksRect), (.rug, rugRect)]
check(HomeDecorLayout.hit(CGPoint(x: 10, y: 5), in: rects) == .plant, "a click on the plant")
check(HomeDecorLayout.hit(CGPoint(x: 66, y: 15), in: rects) == .books, "a click just off the shelf's corner still counts")
check(HomeDecorLayout.hit(CGPoint(x: 37, y: 2), in: rects) == nil, "a click on the doormat is the home's")
check(HomeDecorLayout.hit(CGPoint(x: 37, y: 20), in: rects) == nil, "a click on the home itself is the home's")
let hd = HomeDecorLayout(HomeDecorSet(left: .plant), slot: 40)
check(hd.rect(.left, itemWidth: 24, itemHeight: 28, home: 68, slot: 40, gap: 2, spotX: 14, frameWidth: 40)
      == CGRect(x: 14, y: 0, width: 24, height: 28), "HD: the same place at twice the grid")

// The mailbox: a letter for each thing earned, its flag up while one waits.
var box = Mailbox()
check(!box.hasMail && box.take() == nil, "empty: flag down")
box.post("Unlocked: Sun hat")
box.post("Unlocked: Sun hat")
check(box.hasMail && box.letters.count == 1, "a letter: flag up, the same one once")
for n in 1...4 { box.post("\(n * 100) stars!") }
check(box.letters.count == Mailbox.holds && box.letters.last == "400 stars!", "holds the newest three")
check(box.take() == "400 stars!" && box.letters.count == 2, "takes the newest out")
_ = box.take(); _ = box.take()
check(!box.hasMail, "all taken: flag down")
check(Mailbox.milestone(before: 95, after: 103) == 100 && Mailbox.milestone(before: 480, after: 520) == 500, "a hundred passed")
check(Mailbox.milestone(before: 100, after: 140) == nil && Mailbox.milestone(before: 20, after: 60) == nil, "no hundred passed")
check(Mailbox.milestone(before: 0, after: 0) == nil && Mailbox.milestone(before: 210, after: 200) == nil, "none at zero or going down")

// The flag-down mailbox is drawn in classic and HD, the same size as the flag up.
check(CatArt.decor["mailbox.down"]?.count == CatArt.decor["mailbox"]?.count
      && FineArt.decor["mailbox.down"]?.count == FineArt.decor["mailbox"]?.count
      && FineArt.decor["mailbox.down"]?.first?.count == FineArt.decor["mailbox"]?.first?.count, "flag-down mailbox, classic and HD")

// The cushion is each pet's own resting spot: one shop entry, one price, the
// drawing and name follow the pet; a pet you drew keeps the cat's cushion.
let restKinds = ["cat", "dog", "hamster", "rabbit", "chicken", "parrot", "bee", "pig", "hippo", "shark", "giraffe", "dino", "dragon"]
check(restKinds.allSatisfy { HomeDecor.cushion.artKey(for: $0) == "cushion.\($0)" }, "every pet has its own rest spot")
check(Set(restKinds) == Set(CatArt.homes.keys), "every kind with a home has a rest spot")
check(Set(restKinds.map { HomeDecor.cushion.title(for: $0) }).count == restKinds.count, "each rest spot has its own name")
check(HomeDecor.cushion.title(for: "dog") == "Dog bed" && HomeDecor.cushion.title(for: "rabbit") == "Hay pile"
      && HomeDecor.cushion.title(for: "dragon") == "Gold hoard", "the shop names the pet's rest spot")
check(HomeDecor.cushion.price == 110 && HomeDecor.cushion.title == "Comfy cushion", "one cushion entry, price unchanged")
check(DecorShop.label(.cushion, points: 640, spent: 500, look: "parrot") == "Perch stand · 110 ★", "perch stand label")
check(restKinds.allSatisfy { k in
    let c = CatArt.decor["cushion.\(k)"] ?? [], cat = CatArt.decor["cushion.cat"] ?? []
    return c.first?.count == cat.first?.count && c.count <= 16
}, "every rest spot is the cushion's width, so the home's layout doesn't move")
check(HomeDecor.cushion.artKey(for: "own.dog") == "cushion.cat" && HomeDecor.cushion.title(for: "own.shark") == "Round cushion",
      "a pet you drew keeps the cat cushion")
check(HomeDecor.bowls.artKey(for: "own.dog") == HomeDecor.bowls.artKey(for: "dog") && HomeDecor.plant.title(for: "own.cat") == "Cat grass",
      "a pet you drew keeps the other things of the kind it acts like")
check(HomeDecor.cushion.artKey(for: "own.dog") != HomeDecor.cushion.artKey(for: "dog"), "switching pet swaps the drawing")
check(Set(RestSpot.poses.keys) == Set(restKinds), "a rest pose for every kind")
check(RestSpot.pose(for: "own.parrot") == RestSpot.pose(for: "cat") && RestSpot.pose(for: nil).style == .curl, "a pet you drew curls up like the cat")
check(RestSpot.pose(for: "hamster").style == .burrow && RestSpot.pose(for: "parrot").style == .perch
      && RestSpot.pose(for: "rabbit").style == .flop && RestSpot.pose(for: "shark").style == .finOut, "poses fit the pet")
check(RestSpot.poses.values.allSatisfy { $0.lift >= 0 && $0.lift <= 16 && $0.hiddenBelow >= 0 && $0.hiddenBelow <= 16 }, "poses stay in the 16-row frame")
check(RestSpot.poses.values.allSatisfy { p in p.leaves.map { CatArt.decor[$0] != nil && FineArt.decor[$0] != nil } ?? true },
      "what a pose leaves behind is drawn in both sizes")

// The pose played on the spot: its frames, the reshaped frames, what sinks.
let frameNames: Set<String> = ["sit", "blink", "walk1", "walk2", "walk3", "run1", "run2", "groom1", "groom2", "sleep1", "sleep2",
                               "happy", "eat1", "eat2", "crouch1", "crouch2", "held1", "held2"]
check(RestSpot.poses.values.allSatisfy { !$0.frames.isEmpty && $0.frames.allSatisfy(frameNames.contains) }, "every pose plays real frames")
check(RestSpot.poses.filter { $0.value.reshape != .none }.mapValues(\.reshape) == ["parrot": .tuckFoot, "chicken": .fluff],
      "only the parrot and the chicken change their frames")
check(RestSpot.poses.allSatisfy { kind, pose in
    pose.frames.allSatisfy { CatArt.frames["\(kind == "cat" ? "" : kind + ".")\($0)"] != nil && FineArt.frames["\(kind == "cat" ? "cat.gray" : kind).\($0)"] != nil }
}, "every pose's frames are drawn in classic and HD")
let curl = RestSpot.pose(for: "cat"), perch = RestSpot.pose(for: "parrot")
check(curl.frame(ticks: 0, reduceMotion: false) == "sleep1" && curl.frame(ticks: 14, reduceMotion: false) == "sleep2"
      && curl.frame(ticks: 28, reduceMotion: false) == "sleep1", "the sleep frames take turns")
check(curl.frame(ticks: 14, reduceMotion: true) == "sleep1" && perch.frame(ticks: 99, reduceMotion: false) == "blink",
      "Reduce Motion holds the first frame; one frame stays")
check(RestSpot.pose(for: "hamster").hiddenRows(factor: 1) == 7 && RestSpot.pose(for: "hamster").hiddenRows(factor: 2) == 14
      && curl.hiddenRows(factor: 2) == 0 && RestSpot.pose(for: "shark").hiddenRows(factor: 1) == 5, "rows hidden, twice in HD")
check(RestSpot.poses.values.allSatisfy { $0.hiddenBelow == 0 || $0.hiddenBelow > $0.lift }, "a hidden line is above the lowest row")
check(RestSpot.poses.allSatisfy { kind, pose in
    let spot = CatArt.decor[HomeDecor.cushion.artKey(for: kind)]?.count ?? 0
    return pose.hiddenBelow <= spot + 1
}, "what is hidden is hidden by the spot's own height")

func count(_ rows: [String], _ c: Character) -> Int { rows.reduce(0) { $0 + $1.filter { $0 == c }.count } }
for (name, rows, factor) in [("classic", CatArt.frames["parrot.blink"]!, 1), ("HD", FineArt.frames["parrot.blink"]!, 2)] {
    let tucked = RestSpot.reshaped(rows, .tuckFoot, factor: factor)
    let toes = { (r: [String]) in Set(r.flatMap { $0.enumerated().filter { $0.element == "F" }.map(\.offset) }) }
    check(tucked.count == rows.count && tucked.allSatisfy { $0.count == rows[0].count }, "\(name) parrot: one foot keeps the frame's size")
    check(count(tucked, "F") > 0 && count(tucked, "F") < count(rows, "F") && toes(tucked).min()! > toes(rows).min()!,
          "\(name) parrot: the rear foot is tucked, the front one stands")
    check(zip(rows, tucked).allSatisfy { a, b in zip(a, b).allSatisfy { x, y in x == y || RestSpot.footLetters.contains(x) } },
          "\(name) parrot: only its legs change")
}
for (name, rows, factor) in [("classic", CatArt.frames["chicken.sleep1"]!, 1), ("HD", FineArt.frames["chicken.sleep1"]!, 2)] {
    let puffed = RestSpot.reshaped(rows, .fluff, factor: factor)
    let width = { (r: [String]) in r.map { row in row.filter { $0 != "." }.count }.reduce(0, +) }
    check(puffed.count == rows.count && puffed.allSatisfy { $0.count == rows[0].count }, "\(name) chicken: fluffed in its frame")
    check(width(puffed) > width(rows) && puffed.prefix(5) == rows.prefix(5), "\(name) chicken: wider below, head as drawn")
}
check(RestSpot.fluff(["....", ".oo.", "...."], by: 1) == ["....", "oooo", "...."], "fluff grows a row by its outline")
check(RestSpot.tuckFoot(["oDDo", "F..F"]) == ["oDDo", "...F"], "a foot under outline goes, the other stays")
check(RestSpot.tuckFoot(["oDDo", "oFoF"]) == ["oDDo", "oooF"], "where a tucked foot met the body, the body gets its outline")
let sunkGrid: [[Int?]] = [[nil, 1], [2, 3], [4, nil], [nil, nil]]
let sunk = RestSpot.sunk(sunkGrid, hiding: 1)
check(sunk.count == 3 && sunk[2] == [nil, nil] && sunk[1] == [2, 3], "sunk drops empty rows under it, then hides its lowest")
check(RestSpot.sunk(sunkGrid, hiding: 9).count == 3 && RestSpot.sunk(sunkGrid, hiding: 0) == Array(sunkGrid.prefix(3)), "sunk never goes past the picture")

// Clicking it there: for every kind, classic and HD, every frame of its pose,
// the click target covers all of what is drawn of it on the spot (a
// hamster's ears, a shark's fin), and something of it is there to click.
let window = CGSize(width: CGFloat(CatArt.width) * 3, height: CGFloat(CatArt.height) * 3)
let body = CGRect(origin: .zero, size: window).insetBy(dx: 6, dy: 2)
for (kind, pose) in RestSpot.poses.sorted(by: { $0.key < $1.key }) {
    for (name, factor, pixel) in [("classic", 1, CGFloat(3)), ("HD", 2, CGFloat(1.5))] {
        var covered = true, something = true
        for frame in pose.frames {
            guard let rows = factor == 1 ? CatArt.frames["\(kind == "cat" ? "" : kind + ".")\(frame)"]
                                         : FineArt.frames["\(kind == "cat" ? "cat.gray" : kind).\(frame)"] else { covered = false; continue }
            let grid: [[Int?]] = RestSpot.reshaped(rows, pose.reshape, factor: factor).map { $0.map { $0 == "." ? nil : 1 } }
            let shown = RestSpot.sunk(grid, hiding: pose.hiddenRows(factor: factor))
            let height = shown.count, width = shown.first?.count ?? 0
            // Every drawn pixel, flipped to the window's bottom-up points, centred across it.
            var drawn = CGRect.null
            for (y, row) in shown.enumerated() {
                for (x, cell) in row.enumerated() where cell != nil {
                    drawn = drawn.union(CGRect(x: (window.width - CGFloat(width) * pixel) / 2 + CGFloat(x) * pixel,
                                               y: CGFloat(height - 1 - y) * pixel, width: pixel, height: pixel))
                }
            }
            let target = RestSpot.clickRect(body: body, drawn: RestSpot.drawnRect(width: width, height: height, pixel: pixel, factor: factor,
                                                                                windowWidth: window.width, pose: pose))
            if drawn.isNull { something = false } else if !target.contains(drawn) { covered = false }
        }
        check(covered, "\(name) \(kind) (\(pose.style)): clicking anywhere on what shows of it on the spot reaches it")
        check(something, "\(name) \(kind): something of it shows on the spot to click")
    }
}
let hamsterDrawn = RestSpot.drawnRect(width: 20, height: 16, pixel: 3, factor: 1, windowWidth: 60, pose: RestSpot.pose(for: "hamster"))
check(hamsterDrawn.minY == 21 && hamsterDrawn.height == 27, "a hamster's nest hides its lowest 7 rows from the target too")
check(RestSpot.clickRect(body: body, drawn: .zero) == body && RestSpot.clickRect(body: body, drawn: CGRect(x: 0, y: 0, width: 60, height: 60)).contains(CGRect(x: 0, y: 0, width: 60, height: 60)),
      "off the spot the target is its body; on it, the body and all that is drawn")

// A grown home: one more spot, far right, only once it has grown.
let bothSides = HomeDecorSet(left: .lamp, right: .plant)
check(bothSides.freeSpot(for: .books) == nil && bothSides.freeSpot(for: .books, wide: true) == .outer, "far right only in a grown home")
check(DecorShop.buy(.books, points: 1000, spent: 0, owned: [], placed: bothSides, wide: true)?.placed.outer == .books, "buying fills far right when it's open")
check(HomeDecor.rug.spots(wide: true) == [.front] && HomeDecor.lamp.spots(wide: false) == [.left, .right], "far right is for things that stand, and not before")
let wideSet = HomeDecorSet(left: .lamp, right: .plant, outer: .books)
check(HomeDecorSet(saved: wideSet.saved, owned: [.lamp, .plant, .books]) == wideSet, "far right saves and reads back")
let wideLayout = HomeDecorLayout(wideSet, slot: 14)
check(wideLayout.right == 28 && wideLayout.width(home: 34) == 76, "far right adds a second slot on the right")
check(wideLayout.sideX(.outer, itemWidth: 10, home: 34, slot: 14, gap: 1) == 14 + 34 + 14 + 1, "far right stands beyond the right slot")
check(HomeDecorLayout(HomeDecorSet(outer: .books), slot: 14).right == 28, "far right alone keeps its place")

print(failures == 0 ? "home decor: all ok" : "home decor: \(failures) failed")
exit(failures == 0 ? 0 : 1)
