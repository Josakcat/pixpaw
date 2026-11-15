// Checks the end-of-day recap's counting, when it goes up and what it says,
// on its own, no Droppy needed:
//   cp .droppykit/Tools/day-recap-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/DayRecap.swift /tmp/main.swift -o /tmp/day-recap-check && /tmp/day-recap-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Today's counts
var tally = DayTally()
tally.add(.focusSessions, today: "2026-11-13")
tally.add(.focusSessions, today: "2026-11-13")
tally.add(.agentRuns, 3, today: "2026-11-13")
tally.add(.notesAdded, 0, today: "2026-11-13")
check(tally.count(.focusSessions, today: "2026-11-13") == 2, "two sessions counted")
check(tally.count(.agentRuns, today: "2026-11-13") == 3, "three agent runs counted at once")
check(tally.count(.notesAdded, today: "2026-11-13") == 0, "adding nothing counts nothing")
check(tally.count(.focusSessions, today: "2026-11-14") == 0, "yesterday's tally reads as nothing today")
tally.add(.notesAdded, today: "2026-11-14")
check(tally.count(.focusSessions, today: "2026-11-14") == 0 && tally.count(.notesAdded, today: "2026-11-14") == 1,
      "a new day starts again from zero")
check(tally.counts.count == 1, "the old day's counts are gone, not kept")

// What it says
var day = DayTally()
check(DayRecap.line(day, stars: 0, today: "d") == nil, "nothing happened: no line")
day.add(.focusSessions, today: "d")
day.add(.focusTasks, today: "d")
day.add(.agentRuns, 3, today: "d")
day.add(.notesAdded, 2, today: "d")
check(DayRecap.line(day, stars: 12, today: "d") == "1 focus session · 1 task done · 3 agent runs · 2 notes · 12 stars", "the full line, singulars and plurals")
check(DayRecap.line(DayTally(), stars: 1, today: "d") == "1 star", "stars alone still make a line")
check(DayRecap.line(day, stars: 0, today: "other") == nil, "another day's tally says nothing")

// Usual stop
var stops = StopTimes()
check(stops.usual(before: "2026-11-13") == DayRecap.fallbackStop, "no history: six in the evening")
stops.saw(day: "2026-11-10", minute: 17 * 60)
stops.saw(day: "2026-11-11", minute: 19 * 60)
check(stops.usual(before: "2026-11-13") == DayRecap.fallbackStop, "two days are not enough yet")
stops.saw(day: "2026-11-12", minute: 18 * 60 + 30)
check(stops.usual(before: "2026-11-13") == 18 * 60 + 30, "three days: the median")
stops.saw(day: "2026-11-12", minute: 18 * 60)
check(stops.last["2026-11-12"] == 18 * 60 + 30, "an earlier sighting never moves the day's stop back")
stops.saw(day: "2026-11-12", minute: 9 * 60)
check(stops.last["2026-11-12"] == 18 * 60 + 30, "mornings are ignored")
stops.saw(day: "2026-11-13", minute: 23 * 60)
check(stops.usual(before: "2026-11-13") == 18 * 60 + 30, "today never counts toward today's stop")
stops.saw(day: "2026-11-09", minute: 20 * 60)
check(stops.usual(before: "2026-11-13") == (18 * 60 + 30 + 19 * 60) / 2, "even count: the mean of the middle two")
var late = StopTimes()
for d in 1...3 { late.saw(day: "2026-10-0\(d)", minute: 23 * 60 + 59) }
check(late.usual(before: "2026-11-01") == 23 * 60 + 30, "never later than half past eleven")
var early = StopTimes()
for d in 1...3 { early.saw(day: "2026-10-0\(d)", minute: 13 * 60) }
check(early.usual(before: "2026-11-01") == 15 * 60, "never earlier than three")
var many = StopTimes()
for d in 1...20 { many.saw(day: String(format: "2026-10-%02d", d), minute: 18 * 60) }
check(many.last.count == StopTimes.keptDays, "only two weeks are kept")
check(many.last["2026-10-01"] == nil && many.last["2026-10-20"] != nil, "the oldest days go first")

// When it goes up
func due(on: Bool = true, shown: String? = nil, minute: Int = 18 * 60 + 5, quiet: Bool = false,
         busy: Bool = false, idle: TimeInterval = 40, news: Bool = true) -> Bool {
    DayRecap.due(on: on, shownDay: shown, today: "d", minute: minute, usualStop: 18 * 60,
                 quiet: quiet, busy: busy, idle: idle, hasNews: news)
}
check(due(), "after the stop, at a pause, with news: up")
check(!due(on: false), "off: never")
check(!due(shown: "d"), "once a day")
check(due(shown: "yesterday"), "shown yesterday: today's still comes")
check(!due(minute: 17 * 60 + 59), "not before the usual stop")
check(!due(quiet: true), "never in a call, a shared screen or while quiet")
check(!due(busy: true), "never over a focus session, notes or a question")
check(!due(idle: 5), "not while you're typing")
check(!due(news: false), "nothing happened: nothing to say")

print(failures == 0 ? "all passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
