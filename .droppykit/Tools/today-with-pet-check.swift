// Checks the widget's "today with your pet" timeline and its three rings,
// on their own, no Droppy needed:
//   cp .droppykit/Tools/today-with-pet-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/TodayWithPet.swift /tmp/main.swift -o /tmp/today-check && /tmp/today-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

var t = TodayMoments()
t.note(.meal, minute: 540, today: "2026-11-14")
t.note(.pet, minute: 600, today: "2026-11-14")
t.note(.pet, 2, minute: 610, today: "2026-11-14")
check(t.moments.count == 2 && t.moments[1].count == 3 && t.moments[1].minute == 600 && t.moments[1].last == 610, "pets close together join")
t.note(.pet, minute: 640, today: "2026-11-14")
check(t.moments.count == 3, "a pet half an hour later is a new moment")
t.note(.play, 0, minute: 650, today: "2026-11-14")
check(t.moments.count == 3, "nothing counted, nothing noted")
check(t.count(.pet, today: "2026-11-14") == 4 && t.count(.meal, today: "2026-11-14") == 1, "counts per kind")
check(t.shown(today: "2026-11-15").isEmpty && t.count(.pet, today: "2026-11-15") == 0, "another day reads as none")
t.note(.stretch, minute: 5, today: "2026-11-15")
check(t.day == "2026-11-15" && t.moments.count == 1, "a new day starts again")
for m in 0..<20 { t.note(m % 2 == 0 ? .meal : .play, minute: 100 + m, today: "2026-11-15") }
check(t.moments.count == TodayMoments.kept && t.moments.last?.kind == .play, "keeps the newest few")
let data = try! JSONEncoder().encode(t)
check((try? JSONDecoder().decode(TodayMoments.self, from: data)) == t, "saved and read back")

check(TodayMoments.ago(600, now: 601) == "just now" && TodayMoments.ago(600, now: 612) == "12 min ago" && TodayMoments.ago(600, now: 735) == "2 h ago", "how long ago")
check(TodayMoments.Kind.pet.words(1) == "Petted" && TodayMoments.Kind.meal.words(3) == "Fed ×3", "words")

// Rings: kind, never empty.
check(PetGauges.hunger(fullness: 1.4) == 1 && PetGauges.hunger(fullness: -1) == 0, "fullness clamped")
let play = TodayMoments.Moment(kind: .play, minute: 600, last: 600, count: 2)
check(abs(PetGauges.energy([play], now: 600, asleep: false) - 0.7) < 0.001, "play tires it a little")
check(PetGauges.energy([play], now: 720, asleep: false) == 1, "two quiet hours bring it back")
check(PetGauges.energy([TodayMoments.Moment(kind: .play, minute: 0, last: 600, count: 30)], now: 600, asleep: false) == 0.25, "never runs empty")
check(PetGauges.energy([play], now: 600, asleep: true) == 1, "a nap fills it up")
check(PetGauges.mood([]) == 0.6, "cheerful to start with")
check(PetGauges.mood([TodayMoments.Moment(kind: .pet, minute: 0, last: 0, count: 4)]) > 0.6, "care lifts it")
check(PetGauges.mood([TodayMoments.Moment(kind: .pet, minute: 0, last: 0, count: 400)]) == 1, "at most full")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
