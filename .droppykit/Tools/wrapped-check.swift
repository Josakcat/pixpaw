// Checks Pixpaw Wrapped (weeks and months added up from the day's counts)
// on its own, no Droppy needed:
//   cp .droppykit/Tools/wrapped-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/Wrapped.swift Sources/Pixpaw/DayRecap.swift /tmp/main.swift -o /tmp/wrapped-check && /tmp/wrapped-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .current, year: y, month: m, day: d, hour: h))!
}

// Weeks: Monday to Sunday.
let friday = date(2026, 11, 13)
let week = Wrapped.lastWeek(before: friday)!
check(week.days == ["2026-11-2", "2026-11-3", "2026-11-4", "2026-11-5", "2026-11-6", "2026-11-7", "2026-11-8"], "last week is Mon 2 to Sun 8")
check(week.key == "2026-W45", "its key is week 45")
check(Wrapped.lastWeek(before: date(2026, 11, 9, 0))!.key == "2026-W45", "Monday just after midnight: still week 45 to wrap")
check(Wrapped.lastWeek(before: date(2027, 1, 6))!.days.first == "2026-12-28", "a week across the new year")
check(Wrapped.soFar(.weekOfYear, now: friday)!.days.count == 5, "this week so far: Mon to Fri")

// Months.
let month = Wrapped.lastMonth(before: friday)!
check(month.days.count == 31 && month.days.first == "2026-10-1" && month.days.last == "2026-10-31", "last month is all of October")
check(month.key == "2026-10", "its key")
check(Wrapped.lastMonth(before: date(2026, 3, 2))!.days.count == 28, "February 2026 has 28 days")
check(Wrapped.lastMonth(before: date(2027, 1, 1))!.key == "2026-12", "January wraps December")
check(Wrapped.soFar(.month, now: friday)!.days.count == 13, "this month so far: 13 days")

// The log.
var log = WrapLog()
log.add("focusSessions", 2, day: "2026-11-3")
log.add("focusSessions", day: "2026-11-8")
log.add("agentRuns", 0, day: "2026-11-4")
check(log.raise("stars", to: 12, day: "2026-11-3"), "stars rise")
check(!log.raise("stars", to: 5, day: "2026-11-3"), "stars never fall back")
log.raise("here", to: 1, day: "2026-11-3")
log.raise("here", to: 1, day: "2026-11-4")
log.add("focusSessions", 9, day: "2026-11-10") // this week, not last
let totals = log.totals(of: week.days)
check(totals["focusSessions"] == 3 && totals["stars"] == 12 && totals["here"] == 2 && totals["agentRuns"] == nil, "totals of the week only")
check(Wrapped.line(totals) == "3 focus sessions · 12 stars · 2 days together", "the week's line")
check(Wrapped.line(["here": 5]) == nil, "only being here isn't news")
check(Wrapped.line([:]) == nil, "nothing, no line")

// Two months kept.
let recent = Wrapped.recentDays(now: friday)
check(recent.count == WrapLog.keptDays && recent.last == "2026-11-13", "62 days up to today")
log.add("notesAdded", day: "2026-1-1")
log.trim(keeping: recent)
check(log.days["2026-1-1"] == nil && log.days["2026-11-3"] != nil, "old days go, recent stay")

// When.
check(Wrapped.due(on: true, shown: nil, key: "2026-W45", hasNews: true, quiet: false, busy: false, idle: 40), "due at a pause")
check(!Wrapped.due(on: false, shown: nil, key: "2026-W45", hasNews: true, quiet: false, busy: false, idle: 40), "never when off")
check(!Wrapped.due(on: true, shown: "2026-W45", key: "2026-W45", hasNews: true, quiet: false, busy: false, idle: 40), "once a week")
check(!Wrapped.due(on: true, shown: nil, key: "2026-W45", hasNews: true, quiet: true, busy: false, idle: 40), "never when quiet")
check(!Wrapped.due(on: true, shown: nil, key: "2026-W45", hasNews: true, quiet: false, busy: false, idle: 3), "not mid-typing")

// Codable round trip.
let data = try! JSONEncoder().encode(log)
check((try? JSONDecoder().decode(WrapLog.self, from: data)) == log, "saves and reads back")

print(failures == 0 ? "All passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
