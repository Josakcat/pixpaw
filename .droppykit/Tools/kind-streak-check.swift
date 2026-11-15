// Checks the kind streak (a missed day pauses, never resets) and the
// backup file's checks, on their own, no Droppy needed:
//   cp .droppykit/Tools/kind-streak-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/KindStreak.swift /tmp/main.swift -o /tmp/kind-streak-check && /tmp/kind-streak-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Days aren't zero-padded: the 10th comes after the 9th.
var pad = KindStreak()
pad.saw(day: "2026-11-9")
check(pad.saw(day: "2026-11-10"), "the 10th counts after the 9th")
check(!pad.saw(day: "2026-11-9"), "the clock going back counts nothing")
check(KindStreak(days: 3, lastDay: "2026-11-9").merged(with: KindStreak(days: 2, lastDay: "2026-11-10")).lastDay == "2026-11-10", "merge keeps the later day")

// The streak
var s = KindStreak()
check(s.line(today: "2026-11-13", yesterday: "2026-11-12") == nil, "nothing before the first day")
check(s.saw(day: "2026-11-10"), "first day counts")
check(!s.saw(day: "2026-11-10"), "same day counts once")
check(s.saw(day: "2026-11-11"), "next day counts")
check(s.days == 2, "two days")
check(s.isPaused(today: "2026-11-15", yesterday: "2026-11-14"), "missed days pause")
check(s.line(today: "2026-11-15", yesterday: "2026-11-14")?.contains("resting") == true, "paused line is kind")
check(!s.isPaused(today: "2026-11-12", yesterday: "2026-11-11"), "not paused before today is counted")
s.saw(day: "2026-11-15")
check(s.days == 3, "after a break it carries on, never resets")
check(!s.saw(day: "2026-11-01"), "clock going back counts nothing")
let bigger = KindStreak(days: 40, lastDay: "2026-10-01")
let merged = s.merged(with: bigger)
check(merged.days == 40 && merged.lastDay == "2026-11-15", "merge keeps the larger count and the latest day")

// The backup
let values: [String: JSONValue] = [
    "points": .int(1240), "hat": .string("crown"), "collar": .string(""),
    "starDay": .object(["day": .string("2026-11-13"), "stars": .int(4)]),
    "kindStreak": .object(["days": .int(31), "lastDay": .string("2026-11-13")]),
    "notes": .string("secret"),
]
let backup = PixpawBackup(values: values, saved: "2026-11-13")
check(backup.values["notes"] == nil, "keys outside the list never go in")
let data = try! backup.encoded()
let back = try? PixpawBackup.read(data)
check(back == backup, "round trip")
check(back?.summary == "1240 stars · 1 thing worn · 31 days together, saved 2026-11-13", "summary: \(back?.summary ?? "-")")

func problem(_ data: Data) -> PixpawBackup.Problem? {
    do { _ = try PixpawBackup.read(data); return nil } catch { return error as? PixpawBackup.Problem }
}
check(problem(Data("hello".utf8)) == .notABackup, "not JSON is refused")
check(problem(Data(#"{"schema":1,"app":"other","saved":"x","values":{"points":1}}"#.utf8)) == .notABackup, "another app is refused")
check(problem(Data(#"{"schema":9,"app":"pixpaw","saved":"x","values":{"points":1}}"#.utf8)) == .newer(9), "newer format is refused")
check(problem(Data(#"{"schema":0,"app":"pixpaw","saved":"x","values":{"points":1}}"#.utf8)) == .notABackup, "format 0 is refused")
check(problem(Data(#"{"schema":1,"app":"pixpaw","saved":"x","values":{"notes":"a"}}"#.utf8)) == .empty, "only unknown keys is empty")
check(problem(Data(count: PixpawBackup.maxBytes + 1)) == .tooBig, "too big is refused")
let filtered = try? PixpawBackup.read(Data(#"{"schema":1,"app":"pixpaw","saved":"x","values":{"points":3,"meetingNotesModel":"x","hat":null}}"#.utf8))
check(filtered?.values.keys.sorted() == ["points"], "unknown keys and nulls are dropped on load")
check(JSONValue.bool(true) != JSONValue.int(1), "bools stay bools")
let boolBack = try? JSONDecoder().decode(JSONValue.self, from: Data("true".utf8))
check(boolBack == .bool(true), "true decodes as a bool")
let dbl = try? JSONDecoder().decode(JSONValue.self, from: Data("1.5".utf8))
check(dbl == .double(1.5), "1.5 decodes as a double")

print(failures == 0 ? "All passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
