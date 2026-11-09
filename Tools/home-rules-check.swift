// Checks when the home comes out, where it stands, when it folds, and what
// a quiet spell does, on its own, no Droppy needed:
//   cp Tools/home-rules-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/HomeRules.swift /tmp/main.swift -o /tmp/home-check && /tmp/home-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Nap
check(HomeRules.napPlan(hasHome: true, homeOn: true, showing: false, fromLink: false) == .walkIn(popsUp: true), "Nap brings the home out, then in it goes")
check(HomeRules.napPlan(hasHome: true, homeOn: true, showing: true, fromLink: false) == .walkIn(popsUp: false), "a home already out is walked into")
check(HomeRules.napPlan(hasHome: false, homeOn: true, showing: false, fromLink: false) == .napHere, "below 500 stars it naps where it is")
check(HomeRules.napPlan(hasHome: true, homeOn: false, showing: false, fromLink: false) == .napHere, "with Home off it naps where it is")
check(HomeRules.napPlan(hasHome: true, homeOn: true, showing: false, fromLink: true) == .napHere, "a link never brings the home out")
check(HomeRules.napPlan(hasHome: true, homeOn: true, showing: true, fromLink: true) == .walkIn(popsUp: false), "a link may use a home already out")

// Folding
let t0 = Date(timeIntervalSince1970: 1_000_000)
let minute = t0.addingTimeInterval(60)
check(HomeRules.foldDeadline(now: t0, showing: true, keptOut: false, petInside: false, headingHome: false, current: nil) == minute, "an empty home folds a minute after the pet comes out")
check(HomeRules.foldDeadline(now: t0.addingTimeInterval(30), showing: true, keptOut: false, petInside: false, headingHome: false, current: minute) == minute, "the minute isn't restarted")
check(HomeRules.foldDeadline(now: t0, showing: true, keptOut: false, petInside: true, headingHome: false, current: minute) == nil, "never while the pet is inside")
check(HomeRules.foldDeadline(now: t0, showing: true, keptOut: false, petInside: false, headingHome: true, current: minute) == nil, "never while it walks there")
check(HomeRules.foldDeadline(now: t0, showing: true, keptOut: true, petInside: false, headingHome: false, current: nil) == nil, "a home kept out never folds itself")
check(HomeRules.foldDeadline(now: t0, showing: false, keptOut: false, petInside: false, headingHome: false, current: minute) == nil, "a home put away has nothing to fold")
check(HomeRules.foldStep(now: t0, deadline: minute, hovering: false) == .wait, "before the minute is up: waits")
check(HomeRules.foldStep(now: minute, deadline: minute, hovering: false) == .fold, "at the minute: folds")
check(HomeRules.foldStep(now: minute, deadline: minute, hovering: true) == .later(minute.addingTimeInterval(3)), "the pointer on it: looks again in 3 s")
check(HomeRules.foldStep(now: minute, deadline: nil, hovering: false) == .wait, "no deadline: nothing")

// Placement on a floor 0...1000, a 102-point home, a 72-point pet
let w: CGFloat = 102, pet: CGFloat = 72
func place(_ saved: CGFloat?, _ petX: CGFloat) -> CGFloat {
    HomeRules.placeX(saved: saved, petMinX: petX, petWidth: pet, homeWidth: w, floorMinX: 0, floorMaxX: 1000)
}
check(place(nil, 200) == 200 + pet + HomeRules.gap, "beside the pet, on the right where there's more room")
check(place(nil, 800) == 800 - HomeRules.gap - w, "beside the pet, on the left where there's more room")
check(place(nil, 0) == pet + HomeRules.gap, "a pet at the left edge gets it on its right")
check(place(nil, 1000 - pet) == 1000 - pet - HomeRules.gap - w, "a pet at the right edge gets it on its left")
check(place(400, 900) == 400, "where you last dragged it wins")
check(place(990, 100) == 1000 - w, "a dragged spot off the floor's end is pulled back on")
check(place(-50, 100) == 0, "and off its start too")
check(HomeRules.placeX(saved: nil, petMinX: 10, petWidth: pet, homeWidth: w, floorMinX: 0, floorMaxX: 150) == 48, "a narrow floor keeps it on the floor")

check(HomeRules.quietNapWaits(held: true, eating: false, midAir: false), "held: waits")
check(HomeRules.quietNapWaits(held: false, eating: true, midAir: false), "eating: waits")
check(!HomeRules.quietNapWaits(held: false, eating: false, midAir: false), "free: goes now")
check(HomeRules.foldsAfterQuiet(cameOutForQuiet: true, keptOut: false), "quiet over: the home it brought folds")
check(!HomeRules.foldsAfterQuiet(cameOutForQuiet: true, keptOut: true), "kept out meanwhile: stays")
check(!HomeRules.foldsAfterQuiet(cameOutForQuiet: false, keptOut: false), "was out already: stays")

// Quiet
check(QuietBed.pick(call: true, sharing: false, lateNight: false) == .call, "a call")
check(QuietBed.pick(call: true, sharing: true, lateNight: true) == .sharing, "sharing outranks a call")
check(QuietBed.pick(call: false, sharing: false, lateNight: true) == .lateNight, "late night")
check(QuietBed.pick(call: false, sharing: false, lateNight: false) == nil, "nothing quiet")
check(QuietBed.call.action == .goHome, "in a call: into its home")
check(QuietBed.sharing.action == .napHere, "sharing: naps where it is, nothing moves")
check(QuietBed.lateNight.action == .goHome, "late night: to bed in its home")
check(QuietBed.step(from: nil, to: .call) == .begin(.goHome), "a call starting sends it home")
check(QuietBed.step(from: nil, to: .sharing) == .begin(.napHere), "a share starting puts it to sleep where it is")
check(QuietBed.step(from: .call, to: nil) == .end, "the quiet ending brings it out")
check(QuietBed.step(from: .call, to: .sharing) == .none, "a call turning into a share moves nothing")
check(QuietBed.step(from: .call, to: .call) == .none, "the same quiet again moves nothing (a pet you woke stays up)")
check(QuietBed.step(from: nil, to: nil) == .none, "no quiet, nothing")

// Late nights: hour, seconds since you touched the Mac
let night = Date(timeIntervalSince1970: 2_000_000)
check(QuietBed.lateNightBed(hour: 2, idle: 599, now: night, inBedSince: nil) == nil, "2 am, 9 min away: still up")
let bedtime = QuietBed.lateNightBed(hour: 2, idle: 600, now: night, inBedSince: nil)
check(bedtime == night.addingTimeInterval(-600), "2 am, 10 min away: to bed")
check(QuietBed.lateNightBed(hour: 12, idle: 3600, now: night, inBedSince: nil) == nil, "noon, an hour away: not a late night")
check(QuietBed.lateNightBed(hour: 5, idle: 3600, now: night, inBedSince: nil) == nil, "5 am is morning")
check(QuietBed.lateNightBed(hour: 3, idle: 630, now: night.addingTimeInterval(30), inBedSince: bedtime) == bedtime, "nobody back: stays in bed")
check(QuietBed.lateNightBed(hour: 6, idle: 4200, now: night.addingTimeInterval(3600), inBedSince: bedtime) == bedtime, "past five with nobody back: still in bed")
check(QuietBed.lateNightBed(hour: 3, idle: 20, now: night.addingTimeInterval(30), inBedSince: bedtime) == nil, "you touch the Mac: up it gets")
check(QuietBed.lateNightBed(hour: 3, idle: 90, now: night.addingTimeInterval(300), inBedSince: bedtime) == nil, "touched since bedtime, even a while ago: up")

print(failures == 0 ? "\nAll good." : "\n\(failures) failed.")
exit(failures == 0 ? 0 : 1)
