//
//  PlanUsage.swift
//  Pixpaw
//
//  What's left of each coding agent's plan, for the menu bar: Claude Code's
//  five-hour and weekly windows from what its status line saved
//  (Tools/agent-hooks/usage.py), Antigravity's from the last `agy -p /usage`
//  its plugin kept, and any other agent's from the "5h 77% · week 59% left"
//  its hook sent when a turn ended. Only percentages and reset times, all
//  read from files on this Mac.
//

import Foundation

/// One window of a plan: the five hours or the week.
struct PlanWindow: Equatable, Identifiable {
    /// "5h" or "Week".
    let label: String
    /// Percent left, 0 to 100.
    let left: Int
    /// When it fills up again, when the agent says.
    let resets: Date?
    /// When it runs dry at the pace of the last hour, if that comes before
    /// it resets (see `PlanPace`).
    var runsOut: Date? = nil

    var id: String { label }

    /// How it's doing: plenty, getting low (20% or less), nearly out (10%).
    enum Level { case plenty, low, out }
    var level: Level { left <= 10 ? .out : left <= 20 ? .low : .plenty }

    /// "resets in 1h 42m" today, "resets Thu 14:00" further off.
    func resetText(now: Date = Date()) -> String? {
        guard let resets, resets > now else { return nil }
        let seconds = Int(resets.timeIntervalSince(now))
        if seconds < 3600 { return "resets in \(max(1, seconds / 60))m" }
        if seconds < 12 * 3600 { return "resets in \(seconds / 3600)h \(seconds % 3600 / 60)m" }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.dateFormat = "EEE HH:mm"
        return "resets \(format.string(from: resets))"
    }

    /// For a narrow row: "~25m", "15:20", "Thu 15:20".
    func paceShort(now: Date = Date()) -> String? {
        guard let runsOut, runsOut > now else { return nil }
        let seconds = Int(runsOut.timeIntervalSince(now))
        if seconds < 3600 { return "~\(max(1, seconds / 60))m" }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.dateFormat = Calendar.current.isDate(runsOut, inSameDayAs: now) ? "HH:mm" : "EEE HH:mm"
        return format.string(from: runsOut)
    }

    /// "out in ~25m at this pace", "out ~15:20 at this pace".
    func paceText(now: Date = Date()) -> String? {
        guard let runsOut, runsOut > now else { return nil }
        let seconds = Int(runsOut.timeIntervalSince(now))
        if seconds < 3600 { return "out in ~\(max(1, seconds / 60))m at this pace" }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.dateFormat = Calendar.current.isDate(runsOut, inSameDayAs: now) ? "HH:mm" : "EEE HH:mm"
        return "out ~\(format.string(from: runsOut)) at this pace"
    }
}

/// One agent's plan, or one group of models in it ("Claude and GPT").
struct PlanUsage: Equatable, Identifiable {
    let agent: String
    /// A group of models with limits of their own, for Antigravity.
    var group: String? = nil
    var windows: [PlanWindow]
    /// When the agent last said.
    let at: Date

    var id: String { group.map { "\(agent) \($0)" } ?? agent }
    var lowest: Int? { windows.map(\.left).min() }

    /// Older than this, the menu says when it was from.
    static let freshFor: TimeInterval = 15 * 60
    /// Older than this, it's left out.
    static let keptFor: TimeInterval = 7 * 24 * 3600

    /// "as of 12 min ago", or nil while it's fresh.
    func age(now: Date = Date()) -> String? {
        let seconds = now.timeIntervalSince(at)
        guard seconds >= Self.freshFor else { return nil }
        if seconds < 3600 { return "as of \(Int(seconds / 60)) min ago" }
        if seconds < 86400 { return "as of \(Int(seconds / 3600)) h ago" }
        return "as of \(Int(seconds / 86400)) d ago"
    }

    /// Each agent's plans together, in the order they come: Claude Code's,
    /// then Antigravity's model groups, then Codex's.
    static func byAgent(_ plans: [PlanUsage]) -> [AgentPlans] {
        var order: [String] = []
        var found: [String: [PlanUsage]] = [:]
        for plan in plans {
            if found[plan.agent] == nil { order.append(plan.agent) }
            found[plan.agent, default: []].append(plan)
        }
        return order.map { AgentPlans(agent: $0, plans: found[$0] ?? []) }
    }
}

/// One agent's section: its name, and a plan per model group.
struct AgentPlans: Identifiable {
    let agent: String
    let plans: [PlanUsage]
    var id: String { agent }

    /// The plan when there's one with no group (Claude Code, Codex): its
    /// bars go on the agent's own line.
    var single: PlanUsage? { plans.count == 1 && plans[0].group == nil ? plans[0] : nil }
}

/// How fast each window has been going down, from what the agents said, to
/// tell when it runs dry at this pace. The five hours go by a line fitted
/// through the last hour's readings, the latest counting most (half again
/// every 15 minutes): a percent rounded down once doesn't swing it, and
/// getting down to work shows at once. The week goes by the average over
/// the last day, nights and breaks in it, since an hour's pace carried over
/// a whole week would be far too gloomy. Kept in memory only.
struct PlanPace {
    /// What each window said and when, by plan and window ("Claude 5h").
    private var said: [String: [Reading]] = [:]

    struct Reading {
        let at: Date
        let left: Int
    }

    /// How far back each kind of window looks, the least of that it needs
    /// before it says anything, and how often it keeps a reading. With a
    /// half-life, a line weighted to the latest; without, the average.
    struct Span {
        let lookBack: TimeInterval
        let shortest: TimeInterval
        let every: TimeInterval
        var halfLife: TimeInterval? = nil
    }

    static let fiveHours = Span(lookBack: 60 * 60, shortest: 10 * 60, every: 60, halfLife: 15 * 60)
    static let week = Span(lookBack: 24 * 3600, shortest: 12 * 3600, every: 10 * 60)
    /// With no reset time, further off than this isn't worth a line.
    static let lookAhead: TimeInterval = 24 * 3600

    static func span(_ label: String) -> Span { label == "Week" ? week : fiveHours }

    /// Notes what each window says now, and gives the plans back with when
    /// each runs out. A window that went up has reset: its pace starts over.
    mutating func note(_ plans: [PlanUsage], now: Date = Date()) -> [PlanUsage] {
        plans.map { plan in
            var plan = plan
            plan.windows = plan.windows.map { window in
                let key = "\(plan.id) \(window.label)", span = Self.span(window.label)
                var list = said[key] ?? []
                if let last = list.last, window.left > last.left { list = [] }
                if list.last.map({ plan.at.timeIntervalSince($0.at) >= span.every }) ?? true {
                    list.append(Reading(at: plan.at, left: window.left))
                }
                list.removeAll { plan.at.timeIntervalSince($0.at) > span.lookBack }
                said[key] = list
                var window = window
                window.runsOut = Self.runsOut(list, now: Reading(at: plan.at, left: window.left), span: span,
                                              resets: window.resets, clock: now)
                return window
            }
            return plan
        }
    }

    /// Where the line through the readings, from `now` on, reaches 0%.
    static func runsOut(_ kept: [Reading], now latest: Reading, span: Span, resets: Date?, clock: Date) -> Date? {
        // The reading in hand counts even when it came too soon to be kept.
        let readings = kept.last.map { latest.at > $0.at } ?? true ? kept + [latest] : kept
        guard let first = readings.first, latest.left > 0,
              latest.at.timeIntervalSince(first.at) >= span.shortest,
              // Two points or more, so a percent rounded down once isn't a pace.
              first.left - latest.left >= 2 else { return nil }
        let perSecond: Double
        if let halfLife = span.halfLife {
            // Weighted least squares: percent left against seconds.
            let xs = readings.map { $0.at.timeIntervalSince(first.at) }, ys = readings.map { Double($0.left) }
            let ws = readings.map { pow(0.5, latest.at.timeIntervalSince($0.at) / halfLife) }
            let total = ws.reduce(0, +)
            let meanX = zip(ws, xs).reduce(0) { $0 + $1.0 * $1.1 } / total
            let meanY = zip(ws, ys).reduce(0) { $0 + $1.0 * $1.1 } / total
            var across = 0.0, spread = 0.0
            for i in xs.indices {
                across += ws[i] * (xs[i] - meanX) * (ys[i] - meanY)
                spread += ws[i] * (xs[i] - meanX) * (xs[i] - meanX)
            }
            guard spread > 0 else { return nil }
            perSecond = -across / spread
        } else {
            perSecond = Double(first.left - latest.left) / latest.at.timeIntervalSince(first.at)
        }
        guard perSecond > 0 else { return nil }
        let out = latest.at.addingTimeInterval(Double(latest.left) / perSecond)
        guard out > clock else { return nil }
        if let resets { return out < resets ? out : nil }
        return out.timeIntervalSince(clock) < lookAhead ? out : nil
    }
}

enum PlanUsageReader {
    static let claudeFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/Pixpaw/claude-usage.json")
    static let antigravityFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Pixpaw/antigravity-usage.json")

    /// Everything known, Claude first, then Antigravity's groups, then the
    /// agents that only said so at the end of a turn.
    static func all(reported: [String: (usage: String, at: Date)], read: [PlanUsage] = [], now: Date = Date()) -> [PlanUsage] {
        var found = [claude(now: now)].compactMap { $0 } + antigravity(now: now)
        // From an agent's own log (Codex's), with when each window resets.
        for plan in read.sorted(by: { $0.agent < $1.agent }) where !found.contains(where: { $0.agent == plan.agent }) {
            if now.timeIntervalSince(plan.at) < PlanUsage.keptFor { found.append(plan) }
        }
        let named = Set(found.map(\.agent))
        for (agent, said) in reported.sorted(by: { $0.key < $1.key }) where !named.contains(agent) {
            if let usage = parse(said.usage, agent: agent, at: said.at, now: now) { found.append(usage) }
        }
        return found
    }

    /// `{"saved_at": …, "five_hour": {"used": 23, "resets_at": …}, "seven_day": {…}}`
    static func claude(now: Date = Date()) -> PlanUsage? {
        guard let data = try? Data(contentsOf: claudeFile),
              let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let at = (saved["saved_at"] as? NSNumber)?.doubleValue else { return nil }
        let windows: [PlanWindow] = [("five_hour", "5h"), ("seven_day", "Week")].compactMap { key, label in
            guard let entry = saved[key] as? [String: Any], let used = (entry["used"] as? NSNumber)?.doubleValue else { return nil }
            let resets = (entry["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            return window(label, left: Int((100 - used).rounded()), resets: resets, now: now)
        }
        return usage("Claude", group: nil, windows: windows, at: Date(timeIntervalSince1970: at), now: now)
    }

    /// `{"at": …, "table": "Claude and GPT models\tFive Hour Limit Remaining\t93%\t2026-10-26T15:01:49Z\n…"}`:
    /// a row per group and window, with what's left and when it resets.
    static func antigravity(now: Date = Date()) -> [PlanUsage] {
        guard let data = try? Data(contentsOf: antigravityFile),
              let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let at = (saved["at"] as? NSNumber)?.doubleValue, let table = saved["table"] as? String else { return [] }
        let iso = ISO8601DateFormatter()
        var groups: [(name: String, windows: [PlanWindow])] = []
        for row in table.split(separator: "\n") {
            let cells = row.split(separator: "\t", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 3, cells[2].hasSuffix("%"), let left = Int(cells[2].dropLast()) else { continue }
            let kind = cells[1].lowercased()
            guard let label = kind.contains("five hour") ? "5h" : kind.contains("weekly") ? "Week" : nil else { continue }
            let name = groupName(cells[0])
            let resets = cells.count > 3 ? iso.date(from: cells[3]) : nil
            if let index = groups.firstIndex(where: { $0.name == name }) {
                groups[index].windows.append(window(label, left: left, resets: resets, now: now))
            } else {
                groups.append((name, [window(label, left: left, resets: resets, now: now)]))
            }
        }
        return groups.compactMap { group in
            usage("Antigravity", group: group.name, windows: group.windows.sorted { $0.label == "5h" && $1.label != "5h" },
                  at: Date(timeIntervalSince1970: at), now: now)
        }
    }

    /// "5h 77% · week 59% left", as a hook sends it.
    static func parse(_ text: String, agent: String, at: Date, now: Date = Date()) -> PlanUsage? {
        let windows: [PlanWindow] = text.replacingOccurrences(of: " left", with: "").components(separatedBy: " · ").compactMap { part in
            let bits = part.split(separator: " ")
            guard bits.count == 2, bits[1].hasSuffix("%"), let left = Int(bits[1].dropLast()) else { return nil }
            let label = bits[0].lowercased() == "5h" ? "5h" : bits[0].lowercased() == "week" ? "Week" : nil
            return label.map { PlanWindow(label: $0, left: max(0, min(100, left)), resets: nil) }
        }
        return usage(agent, group: nil, windows: windows, at: at, now: now)
    }

    /// A window that has reset since the agent said is full again.
    private static func window(_ label: String, left: Int, resets: Date?, now: Date) -> PlanWindow {
        if let resets, resets <= now { return PlanWindow(label: label, left: 100, resets: nil) }
        return PlanWindow(label: label, left: max(0, min(100, left)), resets: resets)
    }

    private static func usage(_ agent: String, group: String?, windows: [PlanWindow], at: Date, now: Date) -> PlanUsage? {
        guard !windows.isEmpty, now.timeIntervalSince(at) < PlanUsage.keptFor else { return nil }
        return PlanUsage(agent: agent, group: group, windows: windows, at: at)
    }

    /// "Claude and GPT models" → "Claude and GPT", "Gemini Models" → "Gemini".
    private static func groupName(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"\s+models?$"#, with: "", options: [.regularExpression, .caseInsensitive])
    }

    /// For the harness's picture, when this Mac has nothing saved yet.
    static func sample(now: Date = Date()) -> [PlanUsage] {
        [
            PlanUsage(agent: "Claude", windows: [
                PlanWindow(label: "5h", left: 77, resets: now.addingTimeInterval(102 * 60)),
                PlanWindow(label: "Week", left: 59, resets: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
            ], at: now),
            PlanUsage(agent: "Antigravity", group: "Gemini", windows: [
                PlanWindow(label: "5h", left: 18, resets: now.addingTimeInterval(41 * 60), runsOut: now.addingTimeInterval(24 * 60)),
                PlanWindow(label: "Week", left: 64, resets: now.addingTimeInterval(4 * 86400)),
            ], at: now.addingTimeInterval(-20 * 60)),
            PlanUsage(agent: "Antigravity", group: "Claude and GPT", windows: [
                PlanWindow(label: "5h", left: 100, resets: nil),
                PlanWindow(label: "Week", left: 96, resets: now.addingTimeInterval(6 * 86400)),
            ], at: now.addingTimeInterval(-20 * 60)),
            PlanUsage(agent: "Antigravity", group: "Gemini 4 Argon", windows: [
                PlanWindow(label: "Week", left: 96, resets: now.addingTimeInterval(6 * 86400)),
            ], at: now.addingTimeInterval(-20 * 60)),
            PlanUsage(agent: "Codex", windows: [
                PlanWindow(label: "5h", left: 8, resets: nil),
                PlanWindow(label: "Week", left: 71, resets: nil),
            ], at: now.addingTimeInterval(-5 * 60)),
        ]
    }
}
