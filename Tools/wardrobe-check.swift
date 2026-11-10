// Checks the Wardrobe's rules on their own, no Droppy needed:
//   cp Tools/wardrobe-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/Wardrobe.swift Sources/Pixpaw/Stats.swift /tmp/main.swift -o /tmp/wardrobe-check && /tmp/wardrobe-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Unlocks.
var p = WardrobeProgress(stars: 299)
check(!CatAccessory.beanie.isUnlocked(p) && CatAccessory.beanie.whatsLeft(p) == "1 ★ to go", "a beanie at 299 stars: 1 to go")
p.stars = 300
check(CatAccessory.beanie.isUnlocked(p), "a beanie at 300 stars")
check(CatAccessory.flowerCrown.unlock == .stars(180) && CatAccessory.roundGlasses.unlock == .stars(260)
      && CatAccessory.acornCap.unlock == .stars(400) && CatAccessory.sunglasses.unlock == .stars(600), "star prices as agreed")
check(CatAccessory.allCases.filter { !$0.isAchievement }.map(\.rawValue).prefix(7) == ["redCollar", "partyHat", "bow", "bellCollar", "witchHat", "santaHat", "crown"],
      "the old things keep their names, so worn ones and ?hat= URLs carry over")
check([CatAccessory.redCollar: 10, .partyHat: 25, .bow: 45, .bellCollar: 70, .witchHat: 100, .santaHat: 150, .crown: 220]
        .allSatisfy { $0.key.unlock == .stars($0.value) }, "the old things keep their prices")
p = WardrobeProgress(counts: [.focusRounds: 99])
check(!CatAccessory.headset.isUnlocked(p) && CatAccessory.headset.whatsLeft(p) == "99 / 100 focus rounds", "headset at 99 rounds")
p.counts[.focusRounds] = 140
check(CatAccessory.headset.isUnlocked(p) && CatAccessory.headset.progress(p) == (100, 100), "headset at 140 rounds, progress capped")
check(CatAccessory.pencil.unlock == .count(.notesDone, 25) && CatAccessory.workTie.unlock == .count(.bugsCaught, 50), "pencil: 25 notes, tie: 50 bugs")
p = WardrobeProgress(daysTogether: 21)
check(CatAccessory.nameBadge.whatsLeft(p) == "21 / 30 days together", "badge counts days together")
p = WardrobeProgress(streak: 5, bestStreak: 5)
check(!CatAccessory.sprout.isUnlocked(p) && CatAccessory.sprout.whatsLeft(p) == "2 more days in a row", "sprout after 5 days: 2 more")
p = WardrobeProgress(streak: 6, bestStreak: 6)
check(CatAccessory.sprout.whatsLeft(p) == "1 more day in a row", "one more day, singular")
p = WardrobeProgress(streak: 0, bestStreak: 7)
check(CatAccessory.sprout.isUnlocked(p), "a sprout stays once a week was reached, run broken or not")
let before = WardrobeProgress(stars: 250, counts: [.notesDone: 24])
let after = WardrobeProgress(stars: 270, counts: [.notesDone: 25])
check(CatAccessory.newlyUnlocked(before: before, after: after) == [.roundGlasses, .pencil], "newly unlocked: glasses and pencil")
check(CatAccessory.nextByStars(after: 220) == .roundGlasses && CatAccessory.nextByStars(after: 600) == nil, "next by stars")

// Who wears what.
let cat = Wearer(isOwn: false, hasNeck: true, looksLike: "cat")
let dog = Wearer(isOwn: false, hasNeck: false, looksLike: "dog")
let hamster = Wearer(isOwn: false, hasNeck: false, looksLike: "hamster")
let drawn = Wearer(isOwn: true, hasNeck: false, looksLike: "rabbit")
let dragon = Wearer(isOwn: false, hasNeck: false, looksLike: "dragon")
check(CatAccessory.workTie.fits(cat) && !CatAccessory.workTie.fits(dog) && !CatAccessory.nameBadge.fits(dog), "tie and badge: cats only")
check(CatAccessory.acornCap.fits(hamster) && CatAccessory.acornCap.fits(drawn) && !CatAccessory.acornCap.fits(cat), "acorn cap: hamster and rabbit only")
check(CatAccessory.sunglasses.fits(dog) && !CatAccessory.sunglasses.fits(drawn), "glasses: every built-in pet, not one you drew")
check(CatAccessory.headset.fits(dog) && !CatAccessory.headset.fits(drawn) && CatAccessory.beanie.fits(drawn), "headset needs headphone spots; hats fit a drawn pet")
check(CatAccessory.crown.fits(dragon) && !CatAccessory.headset.fits(dragon) && !CatAccessory.roundGlasses.fits(dragon) && !CatAccessory.sunglasses.fits(dragon) && !CatAccessory.workTie.fits(dragon), "dragon: hats on the middle head, no glasses, headset or collar")
check(CatAccessory.next(in: .face, for: dragon, WardrobeProgress(stars: 100)) == nil, "nothing next on the face for the dragon")
check(CatAccessory.next(in: .face, for: dog, WardrobeProgress(stars: 100)) == .roundGlasses, "next on the face is the nearer one")
check(CatAccessory.next(in: .collar, for: dog, WardrobeProgress()) == nil, "nothing next at the neck for a dog")
check(CatAccessory.allCases.filter { $0.slot == .face } == [.roundGlasses, .sunglasses], "two things for the face")

// Eye finding.
let front = ["........", "..e..e..", "...pp...", ".ee....."]
check(WardrobeArt.eyes(in: front, eye: "e") == [EyeBox(x0: 2, x1: 2, y0: 1, y1: 1), EyeBox(x0: 5, x1: 5, y0: 1, y1: 1)], "two eyes from the front, lower ones left out")
let tall = ["....", ".e..", ".e..", "...."]
check(WardrobeArt.eyes(in: tall, eye: "e") == [EyeBox(x0: 1, x1: 1, y0: 1, y1: 2)], "a tall eye is one box")
let joined = ["e.e", ".e."]
check(WardrobeArt.eyes(in: joined, eye: "e").count == 1, "pixels touching through a third join up")
check(WardrobeArt.eyes(in: ["...."], eye: "e").isEmpty, "eyes closed: none")
check(WardrobeArt.borrowsSitEyes("dog.blink") && WardrobeArt.borrowsSitEyes("groom2") && !WardrobeArt.borrowsSitEyes("walk1"), "blinks and grooming borrow the sitting eyes")
check(WardrobeArt.moved(EyeBox(x0: 1, x1: 2, y0: 3, y1: 3), x: 0, y: 1) == EyeBox(x0: 1, x1: 2, y0: 4, y1: 4), "borrowed eyes move with the head")
check(WardrobeArt.hidesGlasses("held1") && WardrobeArt.hidesGlasses("dog.sleep2") && !WardrobeArt.hidesGlasses("walk1"), "no glasses held or asleep")
let two = WardrobeArt.eyes(in: front, eye: "e")
let round = WardrobeArt.glasses(.roundGlasses, eyes: two, darkFur: false)
check(!round.contains { $0.x == 2 && $0.y == 1 } && round.contains { $0.x == 1 && $0.y == 1 }, "round glasses leave the eye showing")
check(round.contains { $0.x == 3 && $0.y == 1 } || round.contains { $0.x == 4 && $0.y == 1 }, "a bridge or rims between the eyes")
let side = WardrobeArt.glasses(.sunglasses, eyes: [EyeBox(x0: 6, x1: 6, y0: 3, y1: 3)], darkFur: false)
check(side.contains { $0.x == 6 && $0.y == 4 } && side.contains { $0.x == 3 }, "side sunglasses: two rows tall, an arm back")
let dark = WardrobeArt.glasses(.sunglasses, eyes: two, darkFur: true)
check(dark.contains { $0.colour == "g" } && dark.contains { $0.colour == "l" }, "sunglasses on dark fur get a silver rim and a glint")
check(WardrobeArt.isDark(0x2b2b33) && !WardrobeArt.isDark(0xf2a03d) && !WardrobeArt.isDark(0x7a96b4), "the black cat is dark, orange and the shark aren't")
let set = WardrobeArt.headset([".bbb.", "b...b", "bb.bb"], left: 10, top: 2, darkFur: false)
check(set.contains { $0.colour == "r" && $0.y == 5 && $0.x == 12 }, "headset mic under the left cup, from the front")
let sideSet = WardrobeArt.headset([".bb.", "b..b", "bb.."], left: 10, top: 2, darkFur: true)
check(sideSet.contains { $0.colour == "r" && $0.x == 13 } && sideSet.contains { $0.colour == "G" }, "headset from the side: mic forward; grey on dark fur")

// All-time counts and the run.
var stats = PetStats()
stats.years = ["2025": ["focusRounds": 40], "2026": ["focusRounds": 30, "notesDone": 3]]
var all = PetAllTime.seeded(from: stats)
check(all.count(.focusRounds) == 70 && all.count(.notesDone) == 3, "seeded from every year counted, nothing lost")
all.add(.notesDone, 2)
check(all.count(.notesDone) == 5, "adds")
all = PetAllTime()
all.earnedStars(on: "2026-11-1", yesterday: "2026-10-31")
all.earnedStars(on: "2026-11-1", yesterday: "2026-10-31")
all.earnedStars(on: "2026-11-2", yesterday: "2026-11-1")
check(all.streak == 2 && all.bestStreak == 2, "two days in a row, the same day once")
all.earnedStars(on: "2026-11-5", yesterday: "2026-11-4")
check(all.streak == 1 && all.bestStreak == 2, "a gap starts again, the best stays")
check(all.currentStreak(today: "2026-11-6", yesterday: "2026-11-5") == 1 && all.currentStreak(today: "2026-11-7", yesterday: "2026-11-6") == 0,
      "the run holds till a whole day goes by")
check(StarDay.string(for: Date(timeIntervalSince1970: 1_793_000_000), dayBefore: true) != StarDay.string(for: Date(timeIntervalSince1970: 1_793_000_000)), "the day before is another day")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
