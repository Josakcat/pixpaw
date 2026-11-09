//
//  NotchScenes.swift
//  Pixpaw
//
//  Beside the notch, a moment at a time: the pet comes out beside the
//  notch when something happens and goes back in when it is over. Which
//  moment shows is decided here, by a pure function the droplet feeds,
//  so it can be checked on its own (Tools/notch-scenes-check.swift).
//
//  Droppy's own activities (music, timers, meetings, its HUDs, an open
//  shelf) always own the notch first. A short moment that gets hidden is
//  dropped rather than shown late; a long one waits its turn.
//

import Foundation

/// When the pet has a row beside the notch.
enum NotchMode: String, CaseIterable, Identifiable {
    /// Never, apart from its focus timer.
    case off
    /// When something happens, then back in.
    case moments
    /// All the time, with what it is up to.
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .moments: "Moments"
        case .always: "Always"
        }
    }
}

/// The moments, each with its own switch in Settings.
enum NotchMomentKind: String, CaseIterable, Identifiable {
    case agentAsks
    case agentFinished
    case longCommands
    case focus
    case lateNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agentAsks: "An agent needs you"
        case .agentFinished: "An agent finishes or hits a snag"
        case .longCommands: "Long commands and CI"
        case .focus: "Your pet's focus timer"
        case .lateNight: "Late-night nudge"
        }
    }

    var onByDefault: Bool { self != .lateNight }
}

/// What the row shows, most pressing first.
enum NotchScene: Int, CaseIterable, Comparable {
    case agentAsks
    case focus
    case agentSnag
    case longCommand
    case agentDone
    case lateNight

    var kind: NotchMomentKind {
        switch self {
        case .agentAsks: .agentAsks
        case .focus: .focus
        case .agentSnag, .agentDone: .agentFinished
        case .longCommand: .longCommands
        case .lateNight: .lateNight
        }
    }

    /// How long a short one stays; nil for one that lasts as long as what
    /// it shows (a question, a command, a focus session).
    var lasts: TimeInterval? {
        switch self {
        case .agentDone: 6
        case .agentSnag: 10
        case .lateNight: 8
        case .agentAsks, .focus, .longCommand: nil
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One thing that wants the row: the scene, its short text, and for a
/// short one the moment it is over, in real time, shown or not.
struct NotchMoment: Equatable {
    let scene: NotchScene
    let text: String
    let until: Date?

    var isShort: Bool { until != nil }

    /// A short scene, starting now.
    static func short(_ scene: NotchScene, _ text: String, at now: Date = Date()) -> NotchMoment {
        NotchMoment(scene: scene, text: text, until: now.addingTimeInterval(scene.lasts ?? 6))
    }
}

enum NotchDirector {
    /// Between two short moments: the row never blinks in and out.
    static let shortGap: TimeInterval = 120

    /// The moment to show now, of those that want the row. `showing` is the
    /// one up now; `lastShortEnded` when a short one last went away. A short
    /// one past its time is gone; a new short one waits out the gap (the one
    /// already up keeps going). Most pressing wins.
    static func pick(_ wants: [NotchMoment], showing: NotchMoment?, lastShortEnded: Date?, now: Date) -> NotchMoment? {
        wants
            .filter { want in
                guard let until = want.until else { return true }
                guard until > now else { return false }
                if showing == want { return true }
                guard let lastShortEnded else { return true }
                return now.timeIntervalSince(lastShortEnded) >= shortGap
            }
            .min { $0.scene < $1.scene }
    }

    /// Whether to drop the moment up now because Droppy hid the row: a
    /// short one hidden is over, a long one waits to come back.
    static func dropsWhenHidden(_ showing: NotchMoment?) -> Bool {
        showing?.isShort == true
    }
}

// MARK: - Light

/// How a light in the wings brightens and fades over time.
enum NotchGlowRhythm: Equatable {
    /// Up and down, slowly, between two levels, `period` seconds a breath.
    case breathe(period: TimeInterval, low: Double, high: Double)
    /// A soft blink, `period` seconds a blink.
    case blink(period: TimeInterval)
    /// One flash, then fading to a dim glow.
    case flashOnce
    /// Two flashes, then a dim glow.
    case flashTwice
    /// Always the same.
    case steady(Double)

    /// How bright, 0 to 1, `t` seconds in. With Reduce Motion it never
    /// moves: one level, or for a flash a brighter level for its first
    /// 1.5 s and then the dim one.
    func level(at t: TimeInterval, reduceMotion: Bool) -> Double {
        let t = max(0, t)
        switch self {
        case let .breathe(period, low, high):
            if reduceMotion { return (low + high) / 2 }
            return low + (high - low) * (0.5 - 0.5 * cos(2 * .pi * t / period))
        case let .blink(period):
            if reduceMotion { return 0.8 }
            // Mostly on, dipping softly.
            return 0.25 + 0.75 * pow(0.5 + 0.5 * cos(2 * .pi * t / period), 0.6)
        case .flashOnce:
            if reduceMotion { return t < 1.5 ? 0.8 : 0.3 }
            if t < 0.15 { return t / 0.15 }
            if t < 1.65 { return 1 - 0.7 * (t - 0.15) / 1.5 }
            return 0.3
        case .flashTwice:
            if reduceMotion { return 0.35 }
            for start in [0.0, 0.45] where t >= start && t < start + 0.3 {
                return 1 - abs((t - start) / 0.15 - 1)
            }
            return t < 0.75 ? 0.35 * (t - 0.3) / 0.45 : 0.35
        case let .steady(level):
            return level
        }
    }

    /// Whether `level(at:)` still changes from `t` on.
    func moves(at t: TimeInterval, reduceMotion: Bool) -> Bool {
        if reduceMotion { return false }
        switch self {
        case .breathe, .blink: return true
        case .flashOnce: return t < 1.65
        case .flashTwice: return t < 0.75
        case .steady: return false
        }
    }
}

/// The light in the wings: a glow round the pet on the left and a lamp
/// before the text on the right, never outside them.
struct NotchGlow: Equatable {
    /// 0xRRGGBB.
    let color: UInt32
    let rhythm: NotchGlowRhythm
    /// Whether the pet glows too, or only the little lamp shows.
    let lightsPet: Bool
    /// When it came on, for a flash; nil for one that repeats.
    let since: Date?

    static let working: UInt32 = 0x5AA9FF
    static let asking: UInt32 = 0xFFC845
    static let done: UInt32 = 0x5FE3B0
    static let snag: UInt32 = 0xFF6B6B
    static let command: UInt32 = 0x8FB8FF
    static let focus: UInt32 = 0xB79CFF
    static let night: UInt32 = 0x8E9BD6

    /// The light for a moment beside the notch.
    static func moment(_ moment: NotchMoment) -> NotchGlow {
        let since = moment.until.map { $0.addingTimeInterval(-(moment.scene.lasts ?? 0)) }
        switch moment.scene {
        case .agentAsks: return NotchGlow(color: asking, rhythm: .blink(period: 1.4), lightsPet: true, since: nil)
        case .focus: return NotchGlow(color: focus, rhythm: .steady(0.3), lightsPet: true, since: nil)
        case .agentSnag: return NotchGlow(color: snag, rhythm: .flashTwice, lightsPet: true, since: since)
        case .longCommand: return NotchGlow(color: command, rhythm: .breathe(period: 4, low: 0.25, high: 0.55), lightsPet: true, since: nil)
        case .agentDone: return NotchGlow(color: done, rhythm: .flashOnce, lightsPet: true, since: since)
        case .lateNight: return NotchGlow(color: night, rhythm: .steady(0.3), lightsPet: true, since: nil)
        }
    }

    /// Always, while an agent works: the pet and the lamp breathe slowly blue (35→70% every 3 s).
    static let agentWorking = NotchGlow(color: working, rhythm: .breathe(period: 3, low: 0.35, high: 0.7), lightsPet: true, since: nil)

    /// The light to show now, if any. None when it is switched off, while
    /// the pet keeps quiet (a call, a shared screen) or takes meeting notes,
    /// and none in Off.
    static func pick(on: Bool, mode: NotchMode, showing: NotchMoment?, agentWorking: Bool, quiet: Bool, recording: Bool) -> NotchGlow? {
        guard on, !quiet, !recording else { return nil }
        switch mode {
        case .off: return nil
        case .moments: return showing.map(moment)
        case .always: return agentWorking ? .agentWorking : nil
        }
    }
}
