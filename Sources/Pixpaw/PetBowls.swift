// Pixpaw
//
// Its own bowls beside the home: once you've bought and placed them, a
// hungry pet with nothing else on walks over and eats by itself. They hold a
// few meals; you fill them again from the pet's menu (Care, Fill the bowls).
// Empty bowls never hurt: the pet just sniffs them, says so once in a while,
// and Feed works as it always did. Nothing here starts work of its own: the
// pet's loop asks `trip` when it picks something to do.

import Foundation

struct PetBowls: Equatable {
    /// Meals a fill holds.
    static let holds = 3
    /// At least this long between two trips it made by itself (fed or not).
    static let gap: TimeInterval = 2 * 3600

    /// Meals left in them; full for anyone who had bowls before this.
    private(set) var left = PetBowls.holds
    /// When it last went over by itself (not saved: hunger already spaces
    /// meals hours apart, so a relaunch losing it changes nothing).
    private(set) var lastTrip: Date?

    init() {}

    /// From the saved meal count; anything missing or odd is full.
    init(saved: Int) {
        left = (0...Self.holds).contains(saved) ? saved : Self.holds
    }

    var saved: Int { left }
    var isFull: Bool { left >= Self.holds }
    var isEmpty: Bool { left <= 0 }

    enum Trip: Equatable {
        /// Over to eat.
        case eat
        /// Over to find them empty, and say so.
        case findEmpty
    }

    /// Whether it goes to its bowls by itself now: the setting on, the bowls
    /// placed by its home, hungry, free (`free`: idle, out, not quiet, not
    /// focusing, not carried), and the wait since the last trip over.
    func trip(on: Bool, placed: Bool, hungry: Bool, free: Bool, now: Date) -> Trip? {
        guard on, placed, hungry, free else { return nil }
        if let lastTrip, now.timeIntervalSince(lastTrip) < Self.gap { return nil }
        return isEmpty ? .findEmpty : .eat
    }

    /// Ate a meal from them.
    mutating func ate(now: Date) {
        left = max(0, left - 1)
        lastTrip = now
    }

    /// Went over and found them empty.
    mutating func foundEmpty(now: Date) { lastTrip = now }

    /// Filled: full again, and it may come over straight away.
    mutating func fill() {
        left = Self.holds
        lastTrip = nil
    }
}
