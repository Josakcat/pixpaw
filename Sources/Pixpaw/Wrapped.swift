//
//  Wrapped.swift
//  Pixpaw
//
//  Pixpaw Wrapped: the end-of-day recap's counts added up over a week and
//  a month (focus sessions, tasks done, agent runs, notes, stars, days at
//  your Mac with your pet), said once when a new week or month starts and
//  any time from the pet's menu. Off by default like the recap, kept only
//  while it's on (turning it off forgets the log), on this Mac, counts
//  only and nothing about what they were. A milestone of days together
//  gives the home one more spot. Pure, so .droppykit/Tools/wrapped-check.swift
//  can run it without Droppy.
//

import Foundation

/// The counts of the last two months, a day at a time.
struct WrapLog: Codable, Equatable {
    /// Day ("2026-11-8") to its counts: `DayCount` names, `stars`, `here`.
    var days: [String: [String: Int]] = [:]
    /// The last week ("2026-W45") and month ("2026-10") already said.
    var weekShown: String?
    var monthShown: String?

    static let keptDays = 62
    static let stars = "stars"
    static let here = "here"

    mutating func add(_ key: String, _ n: Int = 1, day: String) {
        guard n > 0 else { return }
        days[day, default: [:]][key, default: 0] += n
    }

    /// Raises a count to `n` (today's stars so far, being here); false when
    /// it already was.
    @discardableResult
    mutating func raise(_ key: String, to n: Int, day: String) -> Bool {
        guard n > (days[day]?[key] ?? 0) else { return false }
        days[day, default: [:]][key] = n
        return true
    }

    /// Forgets days older than two months.
    mutating func trim(keeping recent: [String]) {
        let keep = Set(recent)
        days = days.filter { keep.contains($0.key) }
    }

    func totals(of span: [String]) -> [String: Int] {
        var out: [String: Int] = [:]
        for day in span {
            guard let counts = days[day] else { continue }
            for (key, n) in counts { out[key, default: 0] += key == Self.here ? min(n, 1) : n }
        }
        return out
    }
}

enum Wrapped {
    /// Days together that give the home a fourth spot (far right).
    static let widerHomeAt = 28

    /// Weeks start on Monday, the way most of the world counts them.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    /// A day's name, the same as `StarDay`'s ("2026-11-8").
    static func dayName(_ date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    struct Span: Equatable {
        /// "2026-W45" or "2026-10".
        var key: String
        /// "Last week", "October", "This week", "This month".
        var title: String
        var days: [String]
    }

    private static func names(from start: Date, through end: Date) -> [String] {
        var out: [String] = [], day = start
        let cal = calendar
        while day <= end, out.count < 70 {
            out.append(dayName(day))
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
    }

    private static func weekKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(parts.yearForWeekOfYear ?? 0)-W\(parts.weekOfYear ?? 0)"
    }

    private static func monthKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    /// The whole week before this one, Monday to Sunday.
    static func lastWeek(before now: Date) -> Span? {
        let cal = calendar
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now),
              let start = cal.date(byAdding: .day, value: -7, to: thisWeek.start),
              let end = cal.date(byAdding: .day, value: -1, to: thisWeek.start) else { return nil }
        return Span(key: weekKey(start), title: "Last week", days: names(from: start, through: end))
    }

    /// The whole month before this one.
    static func lastMonth(before now: Date) -> Span? {
        let cal = calendar
        guard let thisMonth = cal.dateInterval(of: .month, for: now),
              let end = cal.date(byAdding: .day, value: -1, to: thisMonth.start),
              let month = cal.dateInterval(of: .month, for: end) else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.dateFormat = "LLLL"
        return Span(key: monthKey(month.start), title: formatter.string(from: month.start),
                    days: names(from: month.start, through: end))
    }

    /// This week or this month, from its first day to today.
    static func soFar(_ component: Calendar.Component, now: Date) -> Span? {
        guard let span = calendar.dateInterval(of: component, for: now) else { return nil }
        return Span(key: component == .month ? monthKey(now) : weekKey(now),
                    title: component == .month ? "This month" : "This week",
                    days: names(from: span.start, through: now))
    }

    /// The days a log keeps: the last two months up to today.
    static func recentDays(now: Date) -> [String] {
        guard let start = calendar.date(byAdding: .day, value: -(WrapLog.keptDays - 1), to: now) else { return [dayName(now)] }
        return names(from: start, through: now)
    }

    /// "9 focus sessions · 14 tasks done · 22 agent runs · 3 notes · 140 stars ·
    /// 5 days together", nil when nothing was counted.
    static func line(_ totals: [String: Int]) -> String? {
        func plural(_ key: String, _ one: String, _ many: String) -> String? {
            let n = totals[key] ?? 0
            return n <= 0 ? nil : "\(n) \(n == 1 ? one : many)"
        }
        let parts = [
            plural(DayCount.focusSessions.rawValue, "focus session", "focus sessions"),
            plural(DayCount.focusTasks.rawValue, "task done", "tasks done"),
            plural(DayCount.agentRuns.rawValue, "agent run", "agent runs"),
            plural(DayCount.notesAdded.rawValue, "note", "notes"),
            plural(WrapLog.stars, "star", "stars"),
        ].compactMap { $0 }
        // Days together alone isn't news; it closes a line that has some.
        guard !parts.isEmpty else { return nil }
        return (parts + [plural(WrapLog.here, "day together", "days together")].compactMap { $0 }).joined(separator: " · ")
    }

    /// Whether a wrap goes up now: on, not yet said, something to say, and
    /// a quiet pause with nothing keeping the pet quiet or busy.
    static func due(on: Bool, shown: String?, key: String, hasNews: Bool,
                    quiet: Bool, busy: Bool, idle: TimeInterval) -> Bool {
        on && shown != key && hasNews && !quiet && !busy && idle >= DayRecap.quietPause
    }
}
