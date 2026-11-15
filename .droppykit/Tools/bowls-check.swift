// Checks its own bowls: when a hungry pet goes over by itself, the wait
// between two trips, empty bowls, filling them and how they are saved,
// no Droppy needed:
//   cp .droppykit/Tools/bowls-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/PetBowls.swift /tmp/main.swift -o /tmp/bowls-check && /tmp/bowls-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
var b = PetBowls()
check(b.isFull && b.saved == PetBowls.holds, "new bowls are full")
check(b.trip(on: true, placed: true, hungry: true, free: true, now: t0) == .eat, "hungry, placed, free: over to eat")
check(b.trip(on: false, placed: true, hungry: true, free: true, now: t0) == nil, "setting off: stays")
check(b.trip(on: true, placed: false, hungry: true, free: true, now: t0) == nil, "no bowls placed: stays")
check(b.trip(on: true, placed: true, hungry: false, free: true, now: t0) == nil, "not hungry: stays")
check(b.trip(on: true, placed: true, hungry: true, free: false, now: t0) == nil, "busy, quiet or carried: stays")

b.ate(now: t0)
check(b.saved == PetBowls.holds - 1 && !b.isFull, "a meal takes one")
check(b.trip(on: true, placed: true, hungry: true, free: true, now: t0.addingTimeInterval(60)) == nil, "not again a minute later")
check(b.trip(on: true, placed: true, hungry: true, free: true, now: t0.addingTimeInterval(PetBowls.gap - 1)) == nil, "not before the gap")
check(b.trip(on: true, placed: true, hungry: true, free: true, now: t0.addingTimeInterval(PetBowls.gap)) == .eat, "again after the gap")

for i in 1..<PetBowls.holds { b.ate(now: t0.addingTimeInterval(Double(i) * PetBowls.gap)) }
check(b.isEmpty && b.saved == 0, "empty after \(PetBowls.holds) meals")
b.ate(now: t0)
check(b.saved == 0, "never below empty")
let later = t0.addingTimeInterval(10 * PetBowls.gap)
check(b.trip(on: true, placed: true, hungry: true, free: true, now: later) == .findEmpty, "empty: goes to sniff them")
b.foundEmpty(now: later)
check(b.trip(on: true, placed: true, hungry: true, free: true, now: later.addingTimeInterval(600)) == nil, "says so once per gap, not on and on")

b.fill()
check(b.isFull, "filled: full again")
check(b.trip(on: true, placed: true, hungry: true, free: true, now: later.addingTimeInterval(600)) == .eat, "filled: may come over at once")

check(PetBowls(saved: 2).saved == 2, "saved count kept")
check(PetBowls(saved: 0).isEmpty, "saved empty kept")
check(PetBowls(saved: -4).isFull && PetBowls(saved: 99).isFull, "odd saved values come back full")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
