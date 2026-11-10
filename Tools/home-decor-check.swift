// Checks home decorations: prices, the wallet, buying, where things stand
// and how they are saved, on their own, no Droppy needed:
//   cp Tools/home-decor-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/HomeDecor.swift Sources/Pixpaw/CatSprites.generated.swift \
//     Sources/Pixpaw/CatSprites.fine.generated.swift Sources/Pixpaw/FineCoats.swift Sources/Pixpaw/Wardrobe.swift Sources/Pixpaw/Stats.swift \
//     /tmp/main.swift -o /tmp/home-decor-check && /tmp/home-decor-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Prices, cheapest first, 1,040 for everything.
check(HomeDecor.allCases.map(\.price) == [60, 80, 90, 110, 140, 160, 180, 220], "prices in order")
check(HomeDecor.allCases.map(\.price).reduce(0, +) == 1040, "1,040 ★ for all eight")
check(HomeDecor.rug.spots == [.front] && HomeDecor.allCases.filter { $0 != .rug }.allSatisfy { $0.spots == [.left, .right] },
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
check(variants.count == 42, "42 pet versions (\(variants.count))")
check(Set(HomeDecor.variants.keys).isSubset(of: Set(CatArt.homes.keys)), "versions only for kinds with a home")
check(variants.allSatisfy { $0.v.title.count <= 16 }, "every title fits (16 characters at most)")
check(variants.allSatisfy { $0.item != .rug }, "the doormat stays the same for everyone")
check(Set(variants.map(\.v.art)).count == 41, "41 pictures: only seed dish/cup share one")
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

print(failures == 0 ? "home decor: all ok" : "home decor: \(failures) failed")
exit(failures == 0 ? 0 : 1)
