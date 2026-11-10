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
        case .nextTrack: "forward"
        case .previousTrack: "backward"
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

/// How running one of Droppy's items went.
enum DroppyRun: Equatable {
    case done
    /// Droppy would show it only inside its own launcher, which the pet can't.
    case opensInside
    case failed(String)
}

@MainActor
final class DroppyTools {
    /// The launcher item for each tool this Droppy has.
    private(set) var found: [DroppyTool: String] = [:]
    /// Launcher items that answered presentDetail: shown only inside
    /// Droppy's own launcher, so never offered again this run.
    private var opensInside: Set<String> = []
    /// Each found tool's launcher kind: a surface opens inside the launcher.
    private var kinds: [DroppyTool: DropletLauncherItem.Kind] = [:]
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
        kinds = [:]
        opensInside = []
        switchedOn = []
    }

    func has(_ tool: DroppyTool) -> Bool { found[tool] != nil }

    /// Has it, and running it does something the pet can see through: not
    /// a surface (Droppy answers those with presentDetail, a view only its
    /// own launcher can show; Agents is one, the Agents droplet's widget).
    func runsHere(_ tool: DroppyTool) -> Bool {
        guard let id = found[tool] else { return false }
        return kinds[tool] != .surface && !opensInside.contains(id)
    }

    /// Everything in Droppy's catalog, for the "What can I do?" box.
    var catalog: [DropletLauncherItem] {
        guard let launcher else { return [] }
        return launcher.catalog.filter { !opensInside.contains($0.id) }
    }

    /// Droppy's search, only ever for text being typed in the box. Nothing
    /// is kept: the answer goes straight to the box.
    func search(_ query: String) async -> [DropletLauncherItem] {
        guard let launcher else { return [] }
        return await launcher.search(query).filter { !opensInside.contains($0.id) }
    }

    /// Runs a launcher item's main action, from your own Return in the box.
    func perform(itemID: String, query: String) -> DroppyRun {
        guard let launcher else { return .failed("Droppy can't run things for me here.") }
        switch launcher.perform(itemID: itemID, actionID: nil, query: query) {
        case .failed(let why): return .failed(why)
        case .presentDetail:
            opensInside.insert(itemID)
            return .opensInside
        case .dismiss, .stay: return .done
        @unknown default: return .done
        }
    }

    /// Whether Droppy's own feature by this name is on, e.g. "Meetings".
    func isOn(_ feature: String) -> Bool { switchedOn.contains(feature.lowercased()) }

    /// Runs it. Nil when Droppy took it, else a sentence saying why not.
    func run(_ tool: DroppyTool) -> String? {
        guard let id = found[tool] else { return "Droppy doesn't have \(tool.title.lowercased()) here." }
        switch perform(itemID: id, query: "") {
        case .done: return nil
        case .opensInside: return "Droppy shows \(tool.title.lowercased()) only in its own launcher."
        case .failed(let why): return why
        }
    }

    private func read(_ items: [DropletLauncherItem]) {
        // Only commands and surfaces, whose main action is safe to run.
        let usable = items.filter { ($0.kind == .command || $0.kind == .surface) && $0.primaryAction?.isDestructive != true }
        var byName: [String: DropletLauncherItem] = [:]
        for item in usable {
            let name = item.title.lowercased()
            if name.hasPrefix("turn off ") || name.hasPrefix("remove ") { continue }
            if byName[name] == nil { byName[name] = item }
        }
        found = [:]
        kinds = [:]
        for tool in DroppyTool.allCases {
            if let item = tool.names.lazy.compactMap({ byName[$0] }).first {
                found[tool] = item.id
                kinds[tool] = item.kind
            }
        }
        switchedOn = Set(items.compactMap { item in
            let name = item.title.lowercased()
            return name.hasPrefix("turn off ") ? String(name.dropFirst("turn off ".count)) : nil
        })
    }
}
