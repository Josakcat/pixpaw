//
//  TodayWithPet.swift
//  Pixpaw
//
//  What the shelf widget shows of today with your pet (DroppyKit 1.23's
//  widget blocks): three rings for hunger, energy and mood, and a short
//  timeline of today's moments (fed, petted, played, stretched). Pet-only
//  counts and minutes of the day, never what you did. Pure, so the
//  self-check (.droppykit/Tools/today-with-pet-check.swift) runs it alone.
//

import CoreGraphics
import Foundation

/// Today's moments with your pet, newest last. Another day's reads as none.
struct TodayMoments: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case meal, pet, play, stretch

        var symbol: String {
            switch self {
            case .meal: "fish.fill"
            case .pet: "hand.raised.fill"
            case .play: "gamecontroller.fill"
            case .stretch: "figure.cooldown"
            }
        }

        /// "Fed", "Petted ×3": what happened, in a word or two.
        func words(_ count: Int) -> String {
            let word = switch self {
            case .meal: "Fed"
            case .pet: "Petted"
            case .play: "Played"
            case .stretch: "Stretched"
            }
            return count > 1 ? "\(word) ×\(count)" : word
        }
    }

    struct Moment: Codable, Equatable {
        var kind: Kind
        /// Minute of the day it started, and of the latest one joined to it.
        var minute: Int
        var last: Int
        var count: Int
    }

    var day = ""
    var moments: [Moment] = []

    /// The most it keeps; older ones fall off the front.
    static let kept = 6
    /// The same thing again within this many minutes joins the last moment.
    static let joinMinutes = 20

    mutating func note(_ kind: Kind, _ n: Int = 1, minute: Int, today: String) {
        guard n > 0 else { return }
        if day != today {
            day = today
            moments = []
        }
        if var latest = moments.last, latest.kind == kind, minute - latest.last < Self.joinMinutes, minute >= latest.last {
            latest.count += n
            latest.last = minute
            moments[moments.count - 1] = latest
        } else {
            moments.append(Moment(kind: kind, minute: minute, last: minute, count: n))
            if moments.count > Self.kept { moments.removeFirst(moments.count - Self.kept) }
        }
    }

    func shown(today: String) -> [Moment] { day == today ? moments : [] }

    /// How many of a kind today.
    func count(_ kind: Kind, today: String) -> Int {
        shown(today: today).filter { $0.kind == kind }.reduce(0) { $0 + $1.count }
    }

    /// "Just now", "12 min ago", "2 h ago".
    static func ago(_ minute: Int, now: Int) -> String {
        let minutes = max(0, now - minute)
        if minutes < 2 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60) h ago"
    }
}

/// The widget's three rings, 0 through 1. Kind by design: mood never drops
/// below cheerful and energy never to empty, so nothing reads as a reproach.
enum PetGauges {
    /// How full: the pet's own fullness.
    static func hunger(fullness: Double) -> Double { min(max(fullness, 0), 1) }

    /// Play tires it a little and an hour or two of quiet brings it back;
    /// a nap fills it up.
    static func energy(_ today: [TodayMoments.Moment], now: Int, asleep: Bool) -> Double {
        if asleep { return 1 }
        let drain = today.filter { $0.kind == .play }.reduce(0.0) { sum, play in
            let since = Double(max(0, now - play.last))
            return sum + 0.15 * Double(play.count) * max(0, 1 - since / 120)
        }
        return min(max(1 - drain, 0.25), 1)
    }

    /// Cheerful to start with, and a bit more with each pet, meal, game and
    /// stretch today.
    static func mood(_ today: [TodayMoments.Moment]) -> Double {
        let care = today.reduce(0) { $0 + $1.count }
        return min(0.6 + 0.05 * Double(care), 1)
    }
}
