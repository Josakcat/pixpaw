//
//  ToolTag.swift
//  Pixpaw
//
//  A little tag at the pet's side while a coding agent works: what it is
//  doing right now and to what ("Editing CatController.swift", "Running
//  swift build"). Only a file's name and a command's first words; never a
//  path, never the rest of a command.
//

import AppKit
import SwiftUI

/// One thing an agent is doing, as the hook tells it: the tool's name and
/// what it touches (a file path, a command, a pattern, a web address).
struct AgentTool: Equatable {
    let agent: String
    let symbol: String
    let text: String
    /// How long the tag stays up with nothing new from the agent: a while
    /// for a command or a helper, which can run for minutes.
    var lasts: TimeInterval = 8

    init?(agent: String, tool rawTool: String, target rawTarget: String?) {
        let tool = rawTool.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tool.isEmpty else { return nil }
        let target = (rawTarget ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let file = Self.fileName(target)
        self.agent = agent
        switch tool {
        case "Edit", "MultiEdit", "NotebookEdit":
            symbol = "pencil"
            text = file.map { "Editing \($0)" } ?? "Editing"
        case "Write":
            symbol = "doc.badge.plus"
            text = file.map { "Writing \($0)" } ?? "Writing"
        case "Read":
            symbol = "doc.text.magnifyingglass"
            text = file.map { "Reading \($0)" } ?? "Reading"
        case "Bash":
            symbol = "terminal"
            text = Self.command(target).map { "Running \($0)" } ?? "Running a command"
            lasts = 180
        case "Grep", "Glob":
            symbol = "magnifyingglass"
            text = "Searching"
        case "WebFetch":
            symbol = "globe"
            text = URL(string: target)?.host().map { "Reading \($0)" } ?? "On the web"
        case "WebSearch":
            symbol = "globe"
            text = "Searching the web"
        case "Browser":
            symbol = "safari"
            text = "Using the browser"
        case "Task", "Agent":
            symbol = "person.2.fill"
            text = "Sent a helper"
            lasts = 180
        default:
            // MCP tools and the rest: just that it's busy.
            return nil
        }
    }

    /// The last part of a path, without the folders it is in.
    private static func fileName(_ path: String) -> String? {
        let name = (path as NSString).lastPathComponent
        guard !name.isEmpty, name != "/" else { return nil }
        return String(name.prefix(36))
    }

    /// A command's program and, when it is a plain word, what it is told to
    /// do ("git status", "swift build"); nothing after that, which is where
    /// tokens and paths would be.
    private static func command(_ line: String) -> String? {
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard var program = words.first else { return nil }
        // `cd somewhere && …` says nothing; look past it.
        if program == "cd", let and = words.firstIndex(of: "&&"), and + 1 < words.count {
            return command(words[(and + 1)...].joined(separator: " "))
        }
        program = (program as NSString).lastPathComponent
        guard program.range(of: #"^[A-Za-z0-9._+-]{1,24}$"#, options: .regularExpression) != nil else { return nil }
        if words.count > 1, words[1].range(of: #"^[a-z][a-z0-9-]{0,15}$"#, options: .regularExpression) != nil {
            return "\(program) \(words[1])"
        }
        return program
    }
}

/// The tag itself, in a panel of its own that clicks pass through.
@MainActor
final class ToolTag {
    private var panel: CatPanel?
    private var hosting: NSHostingView<ToolTagView>?
    private(set) var tool: AgentTool?

    func show(_ tool: AgentTool?) {
        guard tool != self.tool else { return }
        self.tool = tool
        guard let tool else { return close() }
        let view = ToolTagView(tool: tool)
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            let panel = CatPanel(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10))
            panel.ignoresMouseEvents = true
            panel.contentView = hosting
            self.hosting = hosting
            self.panel = panel
        }
        panel?.setContentSize(hosting?.fittingSize ?? .zero)
    }

    /// Beside the pet, behind it: `side` is the pet's back edge on screen
    /// and `toRight` which way from there; or out of sight with nil.
    func place(beside side: CGPoint?, toRight: Bool) {
        guard let panel, tool != nil else { return }
        guard let side else { return panel.orderOut(nil) }
        let size = panel.frame.size
        var origin = CGPoint(x: toRight ? side.x : side.x - size.width, y: side.y)
        if let area = NSScreen.screens.first(where: { NSMouseInRect(side, $0.frame, false) })?.frame {
            origin.x = min(max(origin.x, area.minX + 2), area.maxX - size.width - 2)
        }
        panel.setFrameOrigin(CGPoint(x: origin.x.rounded(), y: origin.y.rounded()))
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func close() {
        tool = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hosting = nil
    }
}

/// A small dark capsule: the tool's symbol and what it's doing.
struct ToolTagView: View {
    let tool: AgentTool

    var body: some View {
        Label(tool.text, systemImage: tool.symbol)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Color(white: 0.12).opacity(0.88)))
            .padding(1)
            .fixedSize()
            .accessibilityLabel("\(tool.agent): \(tool.text)")
    }
}
