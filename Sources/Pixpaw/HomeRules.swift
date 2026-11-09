import Foundation

/// When the home comes out, where it stands, and when it folds away. Pure,
/// so `Tools/home-rules-check.swift` can check it without Droppy.
enum HomeRules {
    /// A home that is out with nobody in it folds itself away after this.
    static let foldAfter: TimeInterval = 60
    /// Room left between the pet and a home that pops up beside it.
    static let gap: CGFloat = 24

    /// What a nap does: walk into the home (bringing it out first if it is
    /// put away), or sleep right where it is.
    enum NapPlan: Equatable {
        case walkIn(popsUp: Bool)
        case napHere
    }

    /// `fromLink`: a URL asked. Any app or page can open one, so a link never
    /// brings the home out; it only uses one already standing.
    static func napPlan(hasHome: Bool, homeOn: Bool, showing: Bool, fromLink: Bool) -> NapPlan {
        guard hasHome, homeOn else { return .napHere }
        if showing { return .walkIn(popsUp: false) }
        return fromLink ? .napHere : .walkIn(popsUp: true)
    }

    /// When an empty home folds: nil while it is kept out, put away, or the
    /// pet is in it or on its way there; otherwise the deadline already set,
    /// or a minute from now.
    static func foldDeadline(now: Date, showing: Bool, keptOut: Bool, petInside: Bool,
                             headingHome: Bool, current: Date?) -> Date? {
        guard showing, !keptOut, !petInside, !headingHome else { return nil }
        return current ?? now.addingTimeInterval(foldAfter)
    }

    /// A home that came out for a quiet spell folds when it ends, unless
    /// "Keep the home out" was switched on meanwhile.
    static func foldsAfterQuiet(cameOutForQuiet: Bool, keptOut: Bool) -> Bool {
        cameOutForQuiet && !keptOut
    }

    enum FoldStep: Equatable {
        case wait
        case fold
        /// The pointer is over it: look again then.
        case later(Date)
    }

    static func foldStep(now: Date, deadline: Date?, hovering: Bool) -> FoldStep {
        guard let deadline, now >= deadline else { return .wait }
        return hovering ? .later(now.addingTimeInterval(3)) : .fold
    }

    /// The home's left edge on a floor from `floorMinX` to `floorMaxX`: where
    /// you last dragged it, otherwise beside the pet on the side with more room.
    static func placeX(saved: CGFloat?, petMinX: CGFloat, petWidth: CGFloat, homeWidth: CGFloat,
                       floorMinX: CGFloat, floorMaxX: CGFloat) -> CGFloat {
        let highest = max(floorMinX, floorMaxX - homeWidth)
        func clamp(_ x: CGFloat) -> CGFloat { min(max(x, floorMinX), highest) }
        if let saved { return clamp(saved) }
        let roomRight = floorMaxX - (petMinX + petWidth + gap)
        let roomLeft = petMinX - gap - floorMinX
        return roomRight >= roomLeft ? clamp(petMinX + petWidth + gap) : clamp(petMinX - gap - homeWidth)
    }

    /// A pet being held, eating or in mid-air finishes that before a quiet nap.
    static func quietNapWaits(held: Bool, eating: Bool, midAir: Bool) -> Bool {
        held || eating || midAir
    }
}

/// Why the pet goes to bed by itself: it should be quiet.
enum QuietBed: Equatable {
    case call
    /// Sharing the screen (or mirroring it): nothing on it moves.
    case sharing
    /// Past midnight with nobody at the Mac.
    case lateNight

    /// Sharing outranks a call (a shared screen is often a call too), and
    /// either outranks a late night.
    static func pick(call: Bool, sharing: Bool, lateNight: Bool) -> QuietBed? {
        sharing ? .sharing : call ? .call : lateNight ? .lateNight : nil
    }

    enum Action: Equatable {
        /// The home pops up (when it has one) and in it goes.
        case goHome
        /// Sleeps where it is; the home stays where it is too.
        case napHere
    }

    var action: Action { self == .sharing ? .napHere : .goHome }

    enum Step: Equatable {
        case none
        case begin(Action)
        /// Out it comes, and a home that came out for the quiet folds at once.
        case end
    }

    /// Only the start and the end of a quiet spell move the pet: a call that
    /// turns into a share leaves it where it went, and one you woke stays up
    /// until the next quiet.
    static func step(from old: QuietBed?, to new: QuietBed?) -> Step {
        switch (old, new) {
        case (nil, let bed?): .begin(bed.action)
        case (_?, nil): .end
        default: .none
        }
    }

    /// From midnight to five, ten minutes without a key or the pointer moving
    /// sends it to bed; it stays there until you touch the Mac again, five
    /// o'clock or not. Returns when you last touched it as bedtime began, or
    /// nil when it isn't in bed. Checked every 30 s.
    static let lateNightIdle: TimeInterval = 600

    static func lateNightBed(hour: Int, idle: TimeInterval, now: Date, inBedSince lastInput: Date?) -> Date? {
        let touched = now.addingTimeInterval(-idle)
        if let lastInput { return touched.timeIntervalSince(lastInput) <= 5 ? lastInput : nil }
        guard (0..<5).contains(hour), idle >= lateNightIdle else { return nil }
        return touched
    }
}
