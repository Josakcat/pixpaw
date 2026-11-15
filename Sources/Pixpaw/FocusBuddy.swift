//
//  FocusBuddy.swift
//  Pixpaw
//
//  Body doubling in Pixpaw's own focus sessions: at the start the pet asks
//  what you're working on (Skip, or Enter to confirm) and holds it up on its
//  sign; about halfway it asks once, quietly, "Still on it?" (Yes, or Switch
//  to type the new one); at the end, "Did it get done?" Done earns a star,
//  Not yet a kind word and nothing lost. Never in a call or a shared screen,
//  and the halfway card takes the keyboard only if you click it.
//  The flow is pure, so .droppykit/Tools/focus-buddy-check.swift checks it.
//

import Foundation

struct FocusBuddy: Equatable {
    enum Stage: Equatable {
        /// No session, Skip at the start, or Body doubling off.
        case off
        /// "What are you working on?" is up.
        case asking
        /// The task is on the sign.
        case working
        /// "Still on …?" is up.
        case checking
        /// Switch: the field for the new task is up.
        case switching
        /// "Did … get done?" is up.
        case ending
    }

    /// What the end question comes to.
    enum Outcome: Equatable {
        case star
        case kindWord
    }

    static let taskLimit = 40
    /// How long each question waits before it answers itself: the start one
    /// as Skip, halfway as Yes, the end one as Not yet (no line said).
    static let askWaits: TimeInterval = 45
    static let checkWaits: TimeInterval = 60
    static let endWaits: TimeInterval = 120

    private(set) var stage: Stage = .off
    private(set) var task: String?
    /// Halfway is asked once a session.
    private(set) var checked = false

    /// The task while it's on the sign.
    var shownTask: String? { stage == .off || stage == .asking ? nil : task }

    /// A session starts. Asks only when on and started by you (a link or the
    /// next Pomodoro round never asks); true when the question should go up.
    mutating func start(on: Bool, byHand: Bool) -> Bool {
        self = FocusBuddy()
        guard on, byHand else { return false }
        stage = .asking
        return true
    }

    /// The answer to "What are you working on?" or to Switch; nil or empty
    /// is Skip: at the start, no task this session; on Switch, the old one stays.
    mutating func answer(_ raw: String?) {
        let text = raw.flatMap { PlainText.line($0, limit: Self.taskLimit) }
        switch stage {
        case .asking:
            guard let text else { return self = FocusBuddy() }
            task = text
            stage = .working
        case .switching:
            if let text { task = text }
            stage = .working
        default:
            break
        }
    }

    /// Whether to ask "Still on …?" now: halfway or later, once, with a task,
    /// and never while the pet keeps quiet or the card is busy.
    func wantsCheck(elapsed: TimeInterval, length: TimeInterval, quiet: Bool, busy: Bool) -> Bool {
        stage == .working && task != nil && !checked && length > 0 && elapsed >= length / 2 && !quiet && !busy
    }

    mutating func check() {
        guard stage == .working else { return }
        stage = .checking
        checked = true
    }

    /// Yes (or no answer): carry on.
    mutating func stillOn() {
        if stage == .checking { stage = .working }
    }

    /// Switch: type the new one.
    mutating func switchTask() {
        if stage == .checking { stage = .switching }
    }

    /// The session ends; true when "Did … get done?" should go up.
    mutating func end() -> Bool {
        guard task != nil, [.working, .checking, .switching].contains(stage) else {
            self = FocusBuddy()
            return false
        }
        stage = .ending
        return true
    }

    /// The end answered (`done` nil: it went unanswered); what it earns.
    mutating func finish(done: Bool?) -> Outcome? {
        guard stage == .ending || (stage == .working && done == true) else { return nil }
        self = FocusBuddy()
        guard let done else { return nil }
        return done ? .star : .kindWord
    }
}
