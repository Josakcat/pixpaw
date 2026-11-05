//
//  Stats.swift
//  Pixpaw
//
//  A tally of each year with your pet: minutes focused, bugs caught, games
//  won, commands waited out together. Counts only, never what they were,
//  kept in the droplet's preferences on this Mac and nowhere else, for a
//  card at the end of the year.
//

import Foundation

enum PetStat: String, CaseIterable {
    case focusMinutes, focusRounds, bugsCaught, gamesPlayed, gamesWon, longCommands, minutesWaited, parcels, notesDone, carefulAsks
}

struct PetStats: Codable, Equatable {
    /// The day counting began.
    var since: String?
    /// Year, then stat, then count; a stat it doesn't know yet is kept as it is.
    var years: [String: [String: Int]] = [:]

    static var thisYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }

    mutating func add(_ stat: PetStat, _ count: Int = 1) {
        guard count > 0 else { return }
        if since == nil { since = StarDay.today }
        years[String(Self.thisYear), default: [:]][stat.rawValue, default: 0] += count
    }

    func count(_ stat: PetStat, in year: Int = PetStats.thisYear) -> Int {
        years[String(year)]?[stat.rawValue] ?? 0
    }

    /// "12 h focused · 5 bugs caught · 8 games won", what this year has so far.
    var summary: String? {
        let minutes = count(.focusMinutes)
        let parts = [
            minutes >= 60 ? "\(minutes / 60) h focused" : minutes > 0 ? "\(minutes) min focused" : nil,
            plural(count(.bugsCaught), "bug caught", "bugs caught"),
            plural(count(.gamesWon), "game won", "games won"),
            plural(count(.longCommands), "long command", "long commands"),
            plural(count(.notesDone), "note done", "notes done"),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func plural(_ count: Int, _ one: String, _ many: String) -> String? {
        count == 0 ? nil : "\(count) \(count == 1 ? one : many)"
    }
}
