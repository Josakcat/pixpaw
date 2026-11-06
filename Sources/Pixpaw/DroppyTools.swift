//
//  DroppyTools.swift
//  Pixpaw
//
//  Your pet as Droppy's assistant: where Droppy already has a tool (its
//  notes, tasks, clipboard, meetings, scrolling capture, play/pause, the
//  Pomodoro droplet), the pet asks Droppy to run it through DroppyKit's
//  launcher instead of doing the same thing itself. Only ever from your
//  own click, shortcut or words, never from a URL; never a destructive
//  action and never one that switches something off.
//

import Combine
import DroppyKit
import Foundation

/// What the pet knows how to ask Droppy for.
enum DroppyTool: String, CaseIterable {
    case notes, newNote, tasks, clipboard, todaysMeetings, joinMeeting, captureScrolling, playPause, nextTrack, previousTrack, pomodoro, agents

    var title: String {
        switch self {
        case .notes: "Notes"
        case .newNote: "New note"
        case .tasks: "Tasks"
        case .clipboard: "Clipboard"
        case .todaysMeetings: "Today's meetings"
        case .joinMeeting: "Join the next meeting"
        case .captureScrolling: "Scrolling capture"
        case .playPause: "Play or pause"
        case .nextTrack: "Next song"
        case .previousTrack: "Previous song"
        case .pomodoro: "Pomodoro"
        case .agents: "Agents"
        }
    }

    var symbol: String {
        switch self {
        case .notes, .newNote: "note.text"
        case .tasks: "checklist"
        case .clipboard: "doc.on.clipboard"
        case .todaysMeetings, .joinMeeting: "video"
        case .captureScrolling: "camera.viewfinder"
        case .playPause: "playpause"
        case .nextTrack: "forward.fill"
        case .previousTrack: "backward.fill"
        case .pomodoro: "timer"
        case .agents: "sparkles"
        }
    }

    /// The names Droppy gives it in its launcher, lowercased; the first
    /// one found wins. Matched by name because ids may differ per Mac.
    fileprivate var names: [String] {
        switch self {
        case .notes: ["show notes", "notes"]
        case .newNote: ["new note"]
        case .tasks: ["quick open tasks"]
        case .clipboard: ["clipboard history"]
        case .todaysMeetings: ["show today's meetings"]
        case .joinMeeting: ["join next meeting"]
        case .captureScrolling: ["capture scrolling"]
        case .playPause: ["toggle play/pause"]
        case .nextTrack: ["next"]
        case .previousTrack: ["previous"]
        case .pomodoro: ["start a pomodoro", "start pomodoro"]
        case .agents: ["agents"]
        }
    }

    /// The ones offered in the pet's menu, in this order.
    /// (Meetings sit with the pet's own meeting items.)
    static let inMenu: [DroppyTool] = [.notes, .tasks, .clipboard, .agents]
}

@MainActor
final class DroppyTools {
    /// The launcher item for each tool this Droppy has.
    private(set) var found: [DroppyTool: String] = [:]
    /// Droppy's own features that are switched on (it offers "Turn Off <name>").
    private var switchedOn: Set<String> = []
    private var launcher: (any DropletLauncherService)?
    private var watch: AnyCancellable?
    /// After the catalog changed: a tool came or went.
    var changed: (() -> Void)?

    var isAvailable: Bool { launcher?.isAvailable == true }

    func start(_ launcher: any DropletLauncherService) {
        guard launcher.isAvailable else { return }
        self.launcher = launcher
        read(launcher.catalog)
        watch = launcher.catalogDidChange.receive(on: DispatchQueue.main).sink { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let launcher = self.launcher else { return }
                self.read(launcher.catalog)
                self.changed?()
            }
        }
    }

    func stop() {
        watch = nil
        launcher = nil
        found = [:]
        switchedOn = []
    }

    func has(_ tool: DroppyTool) -> Bool { found[tool] != nil }

    /// Whether Droppy's own feature by this name is on, e.g. "Meetings".
    func isOn(_ feature: String) -> Bool { switchedOn.contains(feature.lowercased()) }

    /// Runs it. Nil when Droppy took it, else a sentence saying why not.
    func run(_ tool: DroppyTool) -> String? {
        guard let launcher, let id = found[tool] else { return "Droppy doesn't have \(tool.title.lowercased()) here." }
        switch launcher.perform(itemID: id, actionID: nil, query: "") {
        case .failed(let why): return why
        default: return nil
        }
    }

    private func read(_ items: [DropletLauncherItem]) {
        // Only commands and surfaces, whose main action is safe to run.
        let usable = items.filter { ($0.kind == .command || $0.kind == .surface) && $0.primaryAction?.isDestructive != true }
        var byName: [String: String] = [:]
        for item in usable {
            let name = item.title.lowercased()
            if name.hasPrefix("turn off ") || name.hasPrefix("remove ") { continue }
            if byName[name] == nil { byName[name] = item.id }
        }
        found = [:]
        for tool in DroppyTool.allCases {
            if let id = tool.names.lazy.compactMap({ byName[$0] }).first { found[tool] = id }
        }
        switchedOn = Set(items.compactMap { item in
            let name = item.title.lowercased()
            return name.hasPrefix("turn off ") ? String(name.dropFirst("turn off ".count)) : nil
        })
    }
}
