//
//  DayRecap.swift
//  Pixpaw
//
//  The end-of-day recap: once a day, after the time you usually stop, the
//  pet sums up the day in one short line (focus sessions, tasks done in
//  them, agent runs finished, notes added, stars). Counts only, of things
//  the pet already handles; nothing about what they were. Kept in the
//  droplet's preferences on this Mac and nowhere else, and today's counts
//  start again at midnight. Pure, so .droppykit/Tools/day-recap-check.swift
//  can run it without Droppy.
//

import Foundation

/// What today's line counts.
enum DayCount: String, CaseIterable {
    case focusSessions, focusTasks, agentRuns, notesAdded
}

/// Today's counts. A tally from another day reads as nothing.
struct DayTally: Codable, Equatable {
    var day = ""
    var counts: [String: Int] = [:]

    mutating func add(_ count: DayCount, _ n: Int = 1, today: String) {
        guard n > 0 else { return }
        if day != today {
            day = today
            counts = [:]
        }
        counts[count.rawValue, default: 0] += n
    }

    func count(_ count: DayCount, today: String) -> Int {
        day == today ? counts[count.rawValue] ?? 0 : 0
    }
}

/// When you usually stop: the last minute of each of the last two weeks'
/// days the pet saw you at the Mac in the afternoon or evening. Minutes of
/// the day only, never what you did.
struct StopTimes: Codable, Equatable {
    /// Day ("yyyy-MM-dd") to minute of the day.
    var last: [String: Int] = [:]

    static let keptDays = 14
    /// Before noon is a morning, not an end of the day.
    static let earliest = 12 * 60

    /// Seen at the Mac at `minute` on `day`.
    mutating func saw(day: String, minute: Int) {
        guard minute >= Self.earliest, minute < 24 * 60 else { return }
        last[day] = max(last[day] ?? 0, minute)
        if last.count > Self.keptDays {
            for old in last.keys.sorted().prefix(last.count - Self.keptDays) { last[old] = nil }
        }
    }

    /// The median stop of the days before today, once there are three;
    /// six in the evening until then. Never before three in the afternoon
    /// or after half past eleven.
    func usual(before today: String) -> Int {
        let days = last.filter { $0.key < today }.map(\.value).sorted()
        guard days.count >= 3 else { return DayRecap.fallbackStop }
        let middle = days.count / 2
        let median = days.count.isMultiple(of: 2) ? (days[middle - 1] + days[middle]) / 2 : days[middle]
        return min(max(median, 15 * 60), 23 * 60 + 30)
    }
}

enum DayRecap {
    static let fallbackStop = 18 * 60
    /// A pause this long (no key or mouse) is a quiet moment to say it.
    static let quietPause: TimeInterval = 30

    /// Whether the day's recap goes up now: on, not yet today, at or after
    /// the usual stop, nothing keeping the pet quiet or busy, a pause in
    /// your typing, and something to say.
    static func due(on: Bool, shownDay: String?, today: String, minute: Int, usualStop: Int,
                    quiet: Bool, busy: Bool, idle: TimeInterval, hasNews: Bool) -> Bool {
        on && shownDay != today && minute >= usualStop && !quiet && !busy && idle >= quietPause && hasNews
    }

    /// "2 focus sessions · 1 task done · 3 agent runs · 1 note · 12 stars",
    /// nil when nothing happened today.
    static func line(_ tally: DayTally, stars: Int, today: String) -> String? {
        let parts = [
            plural(tally.count(.focusSessions, today: today), "focus session", "focus sessions"),
            plural(tally.count(.focusTasks, today: today), "task done", "tasks done"),
            plural(tally.count(.agentRuns, today: today), "agent run", "agent runs"),
            plural(tally.count(.notesAdded, today: today), "note", "notes"),
            plural(stars, "star", "stars"),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func plural(_ count: Int, _ one: String, _ many: String) -> String? {
        count <= 0 ? nil : "\(count) \(count == 1 ? one : many)"
    }
}
