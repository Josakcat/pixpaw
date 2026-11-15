//
//  KindStreak.swift
//  Pixpaw
//
//  Days with your pet, counted kindly: each day you're at your Mac with
//  Pixpaw on counts once, and a day you miss only pauses the count. It
//  never goes back to zero. Beside it, the backup: home, wardrobe, stars
//  and stats in one versioned file you save and load from Settings, checked
//  before anything is written. Pure, so .droppykit/Tools/kind-streak-check.swift
//  can run it without Droppy.
//

import Foundation

/// The days you and your pet have had together.
struct KindStreak: Codable, Equatable {
    /// Days counted, all of them; a missed day takes none away.
    var days = 0
    /// The last day counted ("2026-11-8").
    var lastDay: String?

    /// Seen together on `day`; true when that's a new day for the count.
    @discardableResult
    mutating func saw(day: String) -> Bool {
        guard lastDay != day else { return false }
        // A day earlier than the last one (the clock went back) counts nothing.
        if let lastDay, Self.order(day) < Self.order(lastDay) { return false }
        days += 1
        lastDay = day
        return true
    }

    /// A day or more went by without you: the count waits for you.
    func isPaused(today: String, yesterday: String) -> Bool {
        guard let lastDay else { return false }
        return lastDay != today && lastDay != yesterday
    }

    /// "12 days together", with a kind word when it's resting.
    func line(today: String, yesterday: String) -> String? {
        guard days > 0 else { return nil }
        let count = days == 1 ? "1 day together" : "\(days) days together"
        return isPaused(today: today, yesterday: yesterday) ? "\(count) · resting, it carries on when you're back" : count
    }

    /// Keeps the larger of two counts (a backup never takes days away).
    func merged(with other: KindStreak) -> KindStreak {
        var out = days >= other.days ? self : other
        out.lastDay = [lastDay, other.lastDay].compactMap { $0 }.max { Self.order($0) < Self.order($1) }
        return out
    }

    /// Days are named "2026-11-8" (not zero-padded), so they're compared as
    /// numbers: 20261108.
    static func order(_ day: String) -> Int {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 0 }
        return parts[0] * 10_000 + parts[1] * 100 + parts[2]
    }
}

// MARK: - Backup

/// Any JSON value: how the droplet's preferences are kept, so a backup can
/// carry each one as it is, whatever its type.
enum JSONValue: Codable, Equatable {
    case null, bool(Bool), int(Int), double(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

/// One file with your pet's home, wardrobe, stars and stats.
struct PixpawBackup: Codable, Equatable {
    /// Which shape of file this is; a newer one than this build knows is refused.
    var schema: Int
    var app: String
    /// The day it was saved ("2026-11-8").
    var saved: String
    /// Preference key to its stored value, only the keys below.
    var values: [String: JSONValue]

    static let schemaVersion = 1
    static let appName = "pixpaw"
    /// Bigger than any real backup by far; anything larger isn't one.
    static let maxBytes = 512 * 1024
    static let fileName = "Pixpaw backup.pixpaw-backup"
    static let fileExtension = "pixpaw-backup"

    /// What a backup carries: the home and its decorations, what's worn,
    /// stars, the year's and all-time counts and the days together. Never
    /// notes, meetings, agents or anything about what you do.
    static let keys: [String] = [
        "points", "starDay", "starsSpent", "decorOwned", "homeDecor",
        "hat", "collar", "glasses", "friendHat", "friendCollar", "friendGlasses",
        "stats", "allTime", "firstMet", "kindStreak", "framedPicture",
    ]

    enum Problem: Error, Equatable {
        case tooBig, notABackup, newer(Int), empty

        var message: String {
            switch self {
            case .tooBig: "That file is too big to be a Pixpaw backup."
            case .notABackup: "That file isn't a Pixpaw backup."
            case .newer(let v): "That backup comes from a newer Pixpaw (format \(v)). Update Pixpaw, then load it."
            case .empty: "That backup has nothing in it to load."
            }
        }
    }

    init(values: [String: JSONValue], saved: String) {
        schema = Self.schemaVersion
        app = Self.appName
        self.saved = saved
        self.values = values.filter { Self.keys.contains($0.key) }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Reads and checks a file: size, shape, app, format version; keys this
    /// build doesn't carry are dropped, never written.
    static func read(_ data: Data) throws -> PixpawBackup {
        guard data.count <= maxBytes else { throw Problem.tooBig }
        guard var backup = try? JSONDecoder().decode(PixpawBackup.self, from: data),
              backup.app == appName, backup.schema >= 1 else { throw Problem.notABackup }
        guard backup.schema <= schemaVersion else { throw Problem.newer(backup.schema) }
        backup.values = backup.values.filter { keys.contains($0.key) && $0.value != .null }
        guard !backup.values.isEmpty else { throw Problem.empty }
        return backup
    }

    /// "1,240 stars · 6 things to wear · 31 days together", for the question
    /// before it replaces anything.
    var summary: String {
        var parts: [String] = []
        if case .int(let points)? = values["points"] { parts.append("\(points) stars") }
        let worn = ["hat", "collar", "glasses"].filter { if case .string(let s)? = values[$0] { !s.isEmpty } else { false } }.count
        if worn > 0 { parts.append(worn == 1 ? "1 thing worn" : "\(worn) things worn") }
        if case .object(let streak)? = values["kindStreak"], case .int(let days)? = streak["days"], days > 0 {
            parts.append(days == 1 ? "1 day together" : "\(days) days together")
        }
        return parts.isEmpty ? "saved \(saved)" : parts.joined(separator: " · ") + ", saved \(saved)"
    }
}
