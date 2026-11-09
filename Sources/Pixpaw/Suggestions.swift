//
//  Suggestions.swift
//  Pixpaw
//
//  Right now: after something happens (a screenshot, a download, a meeting
//  about to start, an agent done, a dev server up, CI failing, a Pomodoro
//  over, meeting notes written), the pet gets a button or two ready for
//  what you'd likely do next. It never runs one itself. Each suggestion
//  has an end time, checked whenever the menu or card is built, so no
//  timer keeps them. Pure functions, checked on their own
//  (Tools/askbox-check.swift).
//

import Foundation

enum PetSuggestionKind: String, CaseIterable {
    case meeting, ci, server, agent, pomodoro, meetingNotes, screenshot, download
}

/// A button a suggestion offers.
enum PetSuggestionAction: String, CaseIterable {
    case toShelf, showInFinder, join, takeNotes, agents, openServer, openCI, focusAgain, stretch, openNotes

    /// On the card's button.
    func button(port: Int? = nil) -> String {
        switch self {
        case .toShelf: "To the shelf"
        case .showInFinder: "Show in Finder"
        case .join: "Join"
        case .takeNotes: "Meeting notes"
        case .agents: "Agents"
        case .openServer: "Open localhost:\(port.map(String.init) ?? "")"
        case .openCI: "See why CI failed"
        case .focusAgain: "Focus again"
        case .stretch: "Stretch with me"
        case .openNotes: "Open the meeting notes"
        }
    }

    /// In the menu, where there's no line above to say what it is about.
    func menu(_ suggestion: PetSuggestion) -> String {
        switch (self, suggestion.kind) {
        case (.toShelf, .screenshot): "Put the screenshot on the shelf"
        case (.toShelf, _): "Put the download on the shelf"
        case (.showInFinder, .screenshot): "Show the screenshot in Finder"
        case (.showInFinder, _): "Show the download in Finder"
        case (.join, _): "Join \(suggestion.title)"
        case (.takeNotes, _): "Take meeting notes"
        case (.agents, _): "Open Agents"
        case (.openServer, _): button(port: suggestion.port)
        case (.openCI, _): suggestion.repo.map { "See why \($0)'s CI failed" } ?? "See why CI failed"
        default: button()
        }
    }

    var symbol: String {
        switch self {
        case .toShelf: "tray.and.arrow.up"
        case .showInFinder: "folder"
        case .join: "video.fill"
        case .takeNotes: "waveform.badge.mic"
        case .agents: "sparkles"
        case .openServer: "safari"
        case .openCI: "xmark.octagon"
        case .focusAgain: "timer"
        case .stretch: "figure.cooldown"
        case .openNotes: "doc.text"
        }
    }
}

struct PetSuggestion: Equatable {
    let kind: PetSuggestionKind
    /// "Screenshot", "“Team standup”", "Claude finished".
    let title: String
    let at: Date
    /// Gone after this; nil while what it is about lasts (a server up, CI red).
    let until: Date?
    /// Its buttons, best first; only two are shown.
    let actions: [PetSuggestionAction]
    /// The screenshot or the download.
    var file: URL?
    /// A meeting's start, for "in 2 min".
    var start: Date?
    var port: Int?
    var repo: String?

    var key: String { kind.rawValue }
}

enum PetSuggestions {
    /// The card shows one; its buttons, two at most.
    static let buttons = 2

    /// How long each kind stays. A meeting stays until ten minutes after
    /// it starts; a server and CI as long as they are true.
    static func lasts(_ kind: PetSuggestionKind) -> TimeInterval? {
        switch kind {
        case .screenshot: 3 * 60
        case .download, .pomodoro: 5 * 60
        case .agent: 10 * 60
        case .meetingNotes: 15 * 60
        case .meeting, .server, .ci: nil
        }
    }

    static func screenshot(_ file: URL, at: Date) -> PetSuggestion {
        PetSuggestion(kind: .screenshot, title: "Screenshot", at: at, until: at + lasts(.screenshot)!, actions: [.toShelf, .showInFinder], file: file)
    }

    static func download(_ file: URL, at: Date) -> PetSuggestion {
        PetSuggestion(kind: .download, title: "Downloaded “\(shortened(file.lastPathComponent))”", at: at,
                      until: at + lasts(.download)!, actions: [.toShelf, .showInFinder], file: file)
    }

    static func meeting(_ title: String, start: Date, at: Date) -> PetSuggestion {
        PetSuggestion(kind: .meeting, title: "“\(shortened(title))”", at: at, until: start + 10 * 60, actions: [.join, .takeNotes], start: start)
    }

    static func agent(_ name: String, failed: Bool, at: Date) -> PetSuggestion {
        PetSuggestion(kind: .agent, title: failed ? "\(name) hit a snag" : "\(name) finished", at: at, until: at + lasts(.agent)!, actions: [.agents])
    }

    static func pomodoro(at: Date) -> PetSuggestion {
        PetSuggestion(kind: .pomodoro, title: "Focus done", at: at, until: at + lasts(.pomodoro)!, actions: [.focusAgain, .stretch])
    }

    static func meetingNotes(at: Date) -> PetSuggestion {
        PetSuggestion(kind: .meetingNotes, title: "Meeting notes ready", at: at, until: at + lasts(.meetingNotes)!, actions: [.openNotes])
    }

    static func server(_ port: Int, at: Date) -> PetSuggestion {
        PetSuggestion(kind: .server, title: "localhost:\(port) is up", at: at, until: nil, actions: [.openServer], port: port)
    }

    static func ci(_ repo: String, at: Date) -> PetSuggestion {
        PetSuggestion(kind: .ci, title: "CI failed in \(repo)", at: at, until: nil, actions: [.openCI], repo: repo)
    }

    /// Keeps one of each kind, the newest, and drops the ones whose time is up.
    static func record(_ new: PetSuggestion, into list: [PetSuggestion], now: Date) -> [PetSuggestion] {
        prune(list.filter { $0.kind != new.kind } + [new], now: now)
    }

    static func prune(_ list: [PetSuggestion], now: Date) -> [PetSuggestion] {
        list.filter { ($0.until ?? .distantFuture) > now }
    }

    /// What to show right now: unexpired, with only the buttons that can
    /// run here (two at most), none left with no button, the screenshot
    /// one only while screenshots aren't carried to the shelf already.
    /// A meeting first, then failed CI, a server, then the newest.
    static func choose(_ list: [PetSuggestion], now: Date, carriesScreenshots: Bool,
                       canRun: (PetSuggestionAction) -> Bool) -> [PetSuggestion] {
        prune(list, now: now)
            .filter { !(carriesScreenshots && $0.kind == .screenshot) }
            .compactMap { suggestion in
                let actions = Array(suggestion.actions.filter(canRun).prefix(buttons))
                guard !actions.isEmpty else { return nil }
                return PetSuggestion(kind: suggestion.kind, title: suggestion.title, at: suggestion.at, until: suggestion.until,
                                     actions: actions, file: suggestion.file, start: suggestion.start, port: suggestion.port,
                                     repo: suggestion.repo)
            }
            .sorted { a, b in
                let ra = rank(a.kind), rb = rank(b.kind)
                return ra != rb ? ra < rb : a.at > b.at
            }
    }

    private static func rank(_ kind: PetSuggestionKind) -> Int {
        switch kind {
        case .meeting: 0
        case .ci: 1
        case .server: 2
        default: 3
        }
    }

    /// "Screenshot just now", "Claude finished 4 min ago", "“Standup” in 2 min".
    static func line(_ suggestion: PetSuggestion, now: Date) -> String {
        switch suggestion.kind {
        case .meeting:
            guard let start = suggestion.start else { return suggestion.title }
            let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
            if minutes > 0 { return "\(suggestion.title) in \(minutes) min" }
            let ago = Int((now.timeIntervalSince(start) / 60).rounded(.down))
            return ago < 1 ? "\(suggestion.title) now" : "\(suggestion.title) began \(ago) min ago"
        case .server, .ci:
            return suggestion.title
        default:
            let ago = Int(now.timeIntervalSince(suggestion.at) / 60)
            return ago < 1 ? "\(suggestion.title) just now" : "\(suggestion.title) \(ago) min ago"
        }
    }

    /// How long until it goes, "3 min", rounded up; nil when it has no end.
    static func left(_ suggestion: PetSuggestion, now: Date) -> String? {
        guard let until = suggestion.until else { return nil }
        return "\(max(1, Int((until.timeIntervalSince(now) / 60).rounded(.up)))) min"
    }

    private static func shortened(_ name: String) -> String {
        name.count <= 32 ? name : String(name.prefix(22)) + "…" + String(name.suffix(8))
    }
}
