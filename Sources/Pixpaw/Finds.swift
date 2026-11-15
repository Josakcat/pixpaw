// Pixpaw
//
// Found things: after a focus round or an agent run that finished, the pet
// sometimes brings something it found and leaves it in front of it, like
// its daily gift. A few a day at most, a short wait between them, nothing
// that runs out or expires, and nothing lost by missing a day. Picking one up
// earns a couple of stars; every so many finds (once it has a home), the
// find is a decoration it doesn't own yet, the cheapest first, so finds help
// along the Decorate shop without replacing it.

import Foundation

/// What finished, for the pet's words when it brings the find.
enum FindReason: String {
    case focus, agent
}

struct Finds: Equatable {
    /// The day `today` counts ("yyyy-MM-dd").
    var day = ""
    /// Finds brought that day.
    var today = 0
    /// Finds picked up, ever.
    var total = 0
    /// When the last one was brought (not saved: a relaunch starts the wait over).
    var lastAt: Date?

    /// No more than this many a day.
    static let dailyLimit = 3
    /// At least this long between two finds.
    static let gap: TimeInterval = 20 * 60
    /// Every this-many-th find picked up is a decoration (with a home).
    static let decorEvery = 8

    /// Whether it may bring one now.
    func canBring(on day: String, now: Date) -> Bool {
        let count = day == self.day ? today : 0
        guard count < Self.dailyLimit else { return false }
        if let lastAt, now.timeIntervalSince(lastAt) < Self.gap { return false }
        return true
    }

    /// Brought one: counted against the day.
    mutating func brought(on day: String, now: Date) {
        if day != self.day { self.day = day; today = 0 }
        today += 1
        lastAt = now
    }

    /// How many it brought on `day`.
    func count(on day: String) -> Int { day == self.day ? today : 0 }

    /// Picked one up. Returns the decoration it turned out to be, if this one
    /// is a decoration: every `decorEvery`-th find, with a home, and only one
    /// not owned yet (the cheapest of those). Never your framed picture:
    /// only a PNG dropped on the widget makes that. Otherwise nil: stars.
    mutating func pickedUp(hasHome: Bool, owned: Set<HomeDecor>) -> HomeDecor? {
        total += 1
        guard hasHome, total % Self.decorEvery == 0 else { return nil }
        return HomeDecor.allCases.filter { $0 != .picture && !owned.contains($0) }.min { $0.price < $1.price }
    }

    /// "2026-11-14|2|17", for preferences.
    var saved: String { "\(day)|\(today)|\(total)" }

    init() {}

    init(saved: String) {
        let parts = saved.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return }
        day = parts[0]
        today = max(0, Int(parts[1]) ?? 0)
        total = max(0, Int(parts[2]) ?? 0)
    }
}
