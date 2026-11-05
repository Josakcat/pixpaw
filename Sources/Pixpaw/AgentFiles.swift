//
//  AgentFiles.swift
//  Pixpaw
//
//  Coding agents without the hooks: each keeps a log of its turn on this
//  Mac as it works (Claude Code in ~/.claude, see ClaudeSessions.swift;
//  Codex in ~/.codex/sessions; Antigravity in ~/.gemini/antigravity*/brain;
//  Gemini CLI in ~/.gemini/tmp/<project>/chats).
//  Every couple of seconds the end of each one in use is read again for
//  what happened since: a turn starting or over, the tool it reached for, a
//  command back and whether it failed, a helper sent off and back, and for
//  Codex what's left of the plan. The same as the hooks would say, kept to
//  the same little: a tool's name, a file's name without its folders, a
//  command's first two words, a web address's host, and percentages. What
//  you and the agent wrote is never kept, shown or sent.
//

import Foundation

/// What an agent's log says happened.
enum AgentFileEvent: Equatable {
    case working
    case done
    case tool(name: String, target: String?, id: String)
    case toolDone(name: String, id: String, failed: Bool)
    case helper(id: String, back: Bool)
    /// What's left of the plan, as the hooks say it ("5h 77% · week 59% left"),
    /// and the windows with when they reset.
    case usage(String, PlanUsage)
}

enum AgentFiles {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    /// Enough of a log's end for the turn in progress.
    static let tail = 256 * 1024

    /// The lines at the end of a log, the first cut one left out.
    static func readTail(_ file: URL, size: UInt64) -> [Substring]? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let start = size > UInt64(tail) ? size - UInt64(tail) : 0
        guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else { return nil }
        // A cut UTF-8 character at the front is skipped with the cut line.
        let text = String(decoding: data, as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if start > 0, !lines.isEmpty { lines.removeFirst() }
        return lines
    }

    static func json(_ line: Substring) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
    }

    static func size(of file: URL) -> (size: UInt64, modified: Date)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let size = (attributes[.size] as? NSNumber)?.uint64Value,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return (size, modified)
    }

    /// A file's name without its folders, a command's first two words (past
    /// a leading `cd … &&`), a web address's host.
    static func target(path: String?, command: String?, url: String?) -> String? {
        if let path, !path.isEmpty { return String((path as NSString).lastPathComponent.prefix(100)) }
        if let command {
            var words = command.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.first == "cd", let and = words.firstIndex(of: "&&") { words = Array(words[(and + 1)...]) }
            // Past `NAME=value` settings, and a path only by its last part, so
            // no folder (with your user name in it) shows on the tag.
            while let word = words.first, word.wholeMatch(of: #/[A-Za-z_][A-Za-z0-9_]*=.*/#) != nil { words.removeFirst() }
            words = words.map { $0.contains("/") ? (($0 as NSString).lastPathComponent.isEmpty ? $0 : ($0 as NSString).lastPathComponent) : $0 }
            let first = words.prefix(2).map { String($0.prefix(40)) }.joined(separator: " ")
            return first.isEmpty ? nil : String(first.prefix(100))
        }
        if let url, let host = URL(string: url)?.host { return "https://\(host)" }
        return nil
    }
}

/// One log being followed: how far it was read, whether its agent was
/// busy, and the tool calls already told and still out.
/// Which logs to follow. Finding them stats every candidate (hundreds, in a
/// busy ~/.gemini), so that is done only every 20 seconds or when a root
/// folder changes (a new session); in between only the found ones are read.
struct LogFinder {
    private var found: [URL] = []
    private var at = Date.distantPast
    private var stamps: [Date?] = []

    mutating func logs(now: Date, roots: [URL], find: (Date) -> [URL]) -> [URL] {
        let current = roots.map { AgentFiles.size(of: $0)?.modified }
        if now.timeIntervalSince(at) >= 20 || current != stamps {
            found = find(now)
            at = now
            stamps = current
        }
        return found
    }
}

struct AgentLog {
    var file: URL
    var size: UInt64 = 0
    var modified = Date.distantPast
    var busy: Bool?
    var told: Set<String> = []
    var out: [String: String] = [:]
    var usage: String?

    /// What a fresh read adds to what was told. On the first look nothing old
    /// is told, only that the agent is busy if it is, and only once the
    /// follower is past its own first look.
    mutating func update(calls: [(id: String, name: String?, target: String?)], results: [(id: String, failed: Bool)],
                         busy now: Bool?, first: Bool, quietStart: Bool) -> [AgentFileEvent] {
        var events: [AgentFileEvent] = []
        if first {
            told = Set(calls.map(\.id))
            let back = Set(results.map(\.id))
            for call in calls where !back.contains(call.id) { if let name = call.name { out[call.id] = name } }
            if now == true, !quietStart { events.append(.working) }
            busy = now
            return events
        }
        if now == true, busy != true { events.append(.working) }
        for call in calls where !told.contains(call.id) {
            told.insert(call.id)
            guard let name = call.name else { continue }
            events.append(.tool(name: name, target: call.target, id: call.id))
            if name == "Task" || name == "Agent" { events.append(.helper(id: call.id, back: false)) }
            out[call.id] = name
        }
        for result in results {
            guard let name = out.removeValue(forKey: result.id) else { continue }
            events.append(name == "Task" || name == "Agent" ? .helper(id: result.id, back: true)
                          : .toolDone(name: name, id: result.id, failed: result.failed))
        }
        if now == false, busy == true { events.append(.done) }
        if let now { busy = now }
        if told.count > 2000 { told = Set(calls.map(\.id)) }
        return events
    }
}

// MARK: - Codex

/// Codex keeps each session in `~/.codex/sessions/YYYY/MM/DD/rollout-….jsonl`:
/// `task_started` and `task_complete` around a turn, its tool calls and
/// their output, and `token_count` with the plan's rate limits.
/// Polled only on PixpawDroplet's agent-files queue, never the main thread.
final class CodexRollouts: @unchecked Sendable {
    private var finder = LogFinder()
    private var logs: [String: AgentLog] = [:]
    private var looked = false
    static let folder = AgentFiles.home.appendingPathComponent(".codex/sessions", isDirectory: true)
    /// Logs written to this recently are followed.
    private static let recent: TimeInterval = 15 * 60

    func poll(now: Date = Date()) -> [AgentFileEvent] {
        let quietStart = !looked
        looked = true
        var events: [AgentFileEvent] = []
        var seen: Set<String> = []
        for file in finder.logs(now: now, roots: Self.watchedRoots(now: now), find: Self.recentLogs) {
            let key = file.path
            seen.insert(key)
            guard let (size, modified) = AgentFiles.size(of: file) else { continue }
            let first = logs[key] == nil
            var log = logs[key] ?? AgentLog(file: file)
            guard first || size != log.size || modified != log.modified else { continue }
            log.size = size
            log.modified = modified
            guard let lines = AgentFiles.readTail(file, size: size) else { continue }
            let read = Self.read(lines, now: now)
            events += log.update(calls: read.calls, results: read.results, busy: read.busy, first: first, quietStart: quietStart)
            if let usage = read.usage, usage.text != log.usage {
                log.usage = usage.text
                if !first || quietStart { events.append(.usage(usage.text, usage.plan)) }
            }
            logs[key] = log
        }
        logs = logs.filter { seen.contains($0.key) }
        return events
    }

    /// Today's folder: a new session is a new file in it.
    private static func watchedRoots(now: Date) -> [URL] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        return [folder.appendingPathComponent(String(format: "%04d/%02d/%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0), isDirectory: true)]
    }

    /// Today's and yesterday's folders, written to lately.
    private static func recentLogs(now: Date) -> [URL] {
        // Codex names its folders by the Gregorian date, whatever the Mac's calendar.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let days = [now, now.addingTimeInterval(-86400)].map { calendar.dateComponents([.year, .month, .day], from: $0) }
        var found: [URL] = []
        for day in days {
            guard let year = day.year, let month = day.month, let date = day.day else { continue }
            let folder = Self.folder.appendingPathComponent(String(format: "%04d/%02d/%02d", year, month, date), isDirectory: true)
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasSuffix(".jsonl") {
                let file = folder.appendingPathComponent(name)
                if let (_, modified) = AgentFiles.size(of: file), now.timeIntervalSince(modified) < recent { found.append(file) }
            }
        }
        return found
    }

    private struct Read {
        var calls: [(id: String, name: String?, target: String?)] = []
        var results: [(id: String, failed: Bool)] = []
        var busy: Bool?
        var usage: (text: String, plan: PlanUsage)?
    }

    private static func read(_ lines: [Substring], now: Date) -> Read {
        var read = Read()
        for line in lines {
            guard let entry = AgentFiles.json(line), let payload = entry["payload"] as? [String: Any] else { continue }
            let kind = payload["type"] as? String
            switch (entry["type"] as? String, kind) {
            case ("event_msg", "task_started"):
                read.busy = true
            case ("event_msg", "task_complete"), ("event_msg", "turn_aborted"):
                read.busy = false
            case ("event_msg", "token_count"):
                if let limits = payload["rate_limits"] as? [String: Any], let usage = usage(limits, at: entry["timestamp"] as? String, now: now) {
                    read.usage = usage
                }
            case ("response_item", "function_call"), ("response_item", "custom_tool_call"), ("response_item", "local_shell_call"):
                guard let id = (payload["call_id"] ?? payload["id"]) as? String else { continue }
                let name = payload["name"] as? String ?? (kind == "local_shell_call" ? "shell" : "")
                read.calls.append((String(id.prefix(80)), shown(name), target(name, payload)))
            case ("response_item", "function_call_output"), ("response_item", "custom_tool_call_output"):
                guard let id = payload["call_id"] as? String else { continue }
                read.results.append((String(id.prefix(80)), failed(payload["output"])))
            default:
                break
            }
        }
        return read
    }

    private static func shown(_ name: String) -> String? {
        switch name {
        case "shell", "exec_command", "container.exec", "local_shell": "Bash"
        case "apply_patch": "Edit"
        case "web_search", "web_search_call": "WebSearch"
        case "view_image": "Read"
        default: nil
        }
    }

    /// The command's first two words, or the file a patch changes.
    private static func target(_ name: String, _ payload: [String: Any]) -> String? {
        if name == "apply_patch", let patch = (payload["input"] ?? payload["arguments"]) as? String,
           let line = patch.split(separator: "\n").first(where: { $0.hasPrefix("*** Update File: ") || $0.hasPrefix("*** Add File: ") }) {
            return AgentFiles.target(path: String(line.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces),
                                     command: nil, url: nil)
        }
        var arguments = payload["arguments"].flatMap { ($0 as? String).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } } as? [String: Any]
        if arguments == nil, let action = payload["action"] as? [String: Any] { arguments = action }
        guard let arguments else { return nil }
        if let words = arguments["command"] as? [String] {
            // ["bash", "-lc", "npm test"]: the script, else the words.
            let script = words.count >= 3 && ["-lc", "-c"].contains(words[1]) ? words[2] : words.joined(separator: " ")
            return AgentFiles.target(path: nil, command: script, url: nil)
        }
        return AgentFiles.target(path: arguments["path"] as? String, command: (arguments["cmd"] ?? arguments["command"]) as? String, url: nil)
    }

    /// A non-zero exit code, as Codex puts it in a command's output.
    private static func failed(_ output: Any?) -> Bool {
        var text = output as? String ?? ""
        if let object = output as? [String: Any] { text = (object["output"] as? String) ?? "" }
        if let parsed = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any],
           let code = (parsed["metadata"] as? [String: Any])?["exit_code"] as? Int {
            return code != 0
        }
        if let match = text.prefix(400).firstMatch(of: #/(?:Process exited with code|Exit code:?)\s*(-?\d+)/#) {
            return Int(match.1) != 0
        }
        return false
    }

    /// `{"primary": {"used_percent": 23, "window_minutes": 300, "resets_at": …}, "secondary": {…}}`
    private static func usage(_ limits: [String: Any], at stamp: String?, now: Date) -> (text: String, plan: PlanUsage)? {
        let said = stamp.flatMap { ISO8601DateFormatter.withFractions.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) } ?? now
        var windows: [PlanWindow] = []
        for key in ["primary", "secondary"] {
            guard let window = limits[key] as? [String: Any], let used = (window["used_percent"] as? NSNumber)?.doubleValue else { continue }
            let minutes = (window["window_minutes"] as? NSNumber)?.intValue ?? (key == "primary" ? 300 : 10080)
            var resets = (window["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            if resets == nil, let seconds = (window["resets_in_seconds"] as? NSNumber)?.doubleValue { resets = said.addingTimeInterval(seconds) }
            let left = max(0, min(100, Int((100 - used).rounded())))
            windows.append(PlanWindow(label: minutes <= 24 * 60 ? "5h" : "Week", left: resets.map { $0 <= now } == true ? 100 : left,
                                      resets: resets.flatMap { $0 > now ? $0 : nil }))
        }
        guard !windows.isEmpty else { return nil }
        let text = windows.map { "\($0.label == "5h" ? "5h" : "week") \($0.left)%" }.joined(separator: " · ") + " left"
        return (text, PlanUsage(agent: "Codex", windows: windows, at: said))
    }
}

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractions: ISO8601DateFormatter = {
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return format
    }()
}

// MARK: - Antigravity

/// Antigravity (the app, the IDE and the agy CLI) keeps each conversation in
/// `~/.gemini/antigravity*/brain/<id>/.system_generated/logs/transcript.jsonl`,
/// a step per line: what you asked, its plan with the tools it calls, each
/// tool's result, and its answer.
/// Polled only on PixpawDroplet's agent-files queue, never the main thread.
final class AntigravityBrains: @unchecked Sendable {
    private var finder = LogFinder()
    private var logs: [String: AgentLog] = [:]
    private var looked = false
    static let roots = ["antigravity", "antigravity-cli", "antigravity-ide"].map {
        AgentFiles.home.appendingPathComponent(".gemini/\($0)/brain", isDirectory: true)
    }
    private static let recent: TimeInterval = 15 * 60

    func poll(now: Date = Date()) -> [AgentFileEvent] {
        let quietStart = !looked
        looked = true
        var events: [AgentFileEvent] = []
        var seen: Set<String> = []
        for file in finder.logs(now: now, roots: Self.watchedRoots(now: now), find: Self.recentLogs) {
            let key = file.path
            seen.insert(key)
            guard let (size, modified) = AgentFiles.size(of: file) else { continue }
            let first = logs[key] == nil
            var log = logs[key] ?? AgentLog(file: file)
            guard first || size != log.size || modified != log.modified else { continue }
            log.size = size
            log.modified = modified
            guard let lines = AgentFiles.readTail(file, size: size) else { continue }
            let read = Self.read(lines)
            events += log.update(calls: read.calls, results: read.results, busy: read.busy, first: first, quietStart: quietStart)
            logs[key] = log
        }
        logs = logs.filter { seen.contains($0.key) }
        return events
    }

    private static func watchedRoots(now: Date) -> [URL] { roots }

    private static func recentLogs(now: Date) -> [URL] {
        var found: [URL] = []
        for root in roots {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [] {
                let file = root.appendingPathComponent(name, isDirectory: true).appendingPathComponent(".system_generated/logs/transcript.jsonl")
                if let (_, modified) = AgentFiles.size(of: file), now.timeIntervalSince(modified) < recent { found.append(file) }
            }
        }
        return found
    }

    private struct Read {
        var calls: [(id: String, name: String?, target: String?)] = []
        var results: [(id: String, failed: Bool)] = []
        var busy: Bool?
    }

    /// Each plan's tool calls take the next steps' results, in order; a plan
    /// with no tool calls is the answer, and the turn is over.
    private static func read(_ lines: [Substring]) -> Read {
        var read = Read()
        var waiting: [String] = []
        for line in lines {
            guard let entry = AgentFiles.json(line) else { continue }
            let step = (entry["step_index"] as? NSNumber)?.intValue ?? -1
            switch (entry["source"] as? String, entry["type"] as? String) {
            case ("USER_EXPLICIT", "USER_INPUT"):
                read.busy = true
                waiting = []
            case ("MODEL", "PLANNER_RESPONSE"):
                let calls = entry["tool_calls"] as? [[String: Any]] ?? []
                if calls.isEmpty, entry["status"] as? String != "RUNNING" {
                    read.busy = false
                    waiting = []
                    continue
                }
                read.busy = true
                for (index, call) in calls.enumerated() {
                    let id = "\(step)-\(index)"
                    let name = call["name"] as? String ?? ""
                    let args = call["args"] as? [String: Any] ?? [:]
                    let shown = shown(name)
                    read.calls.append((id, shown, AgentFiles.target(path: ["Path", "AbsolutePath", "TargetFile", "FilePath", "File"].lazy.compactMap { args[$0] as? String }.first,
                                                                     command: shown == "Bash" ? args["CommandLine"] as? String : nil,
                                                                     url: (args["Url"] ?? args["url"]) as? String)))
                    waiting.append(id)
                }
            case ("MODEL", "GENERIC"):
                // A tool's result; one still running comes back again done.
                let status = entry["status"] as? String
                guard status != "RUNNING", !waiting.isEmpty else { continue }
                read.results.append((waiting.removeFirst(), status == "ERROR"))
            default:
                break
            }
        }
        return read
    }

    /// Antigravity's tools by the names Pixpaw knows them by (Claude Code's).
    private static func shown(_ name: String) -> String? {
        switch name {
        case "read_file", "view_file", "view_content_chunk", "read_notebook": "Read"
        case "edit_file", "replace_file_content", "multi_replace_file_content", "edit_notebook": "Edit"
        case "write_to_file", "write_file": "Write"
        case "run_command": "Bash"
        case "grep_search", "find_by_name", "code_search", "find": "Grep"
        case "search_web": "WebSearch"
        case "read_url_content", "read_url": "WebFetch"
        case "invoke_subagent", "browser_subagent": "Task"
        default: name.hasPrefix("browser_") ? "Browser" : nil
        }
    }
}

// MARK: - Gemini CLI

/// Gemini CLI records each session in
/// `~/.gemini/tmp/<project>/chats/session-<time>-<id>.jsonl`, a line per
/// message as it goes: what you asked, its answers with the tool calls in
/// them (written again as each call's status changes), and errors. Its
/// final answer, a reply with no tool calls once its tokens are counted,
/// ends the turn.
/// Polled only on PixpawDroplet's agent-files queue, never the main thread.
final class GeminiChats: @unchecked Sendable {
    private var finder = LogFinder()
    private var logs: [String: AgentLog] = [:]
    private var looked = false
    static let root = AgentFiles.home.appendingPathComponent(".gemini/tmp", isDirectory: true)
    private static let recent: TimeInterval = 15 * 60

    func poll(now: Date = Date()) -> [AgentFileEvent] {
        let quietStart = !looked
        looked = true
        var events: [AgentFileEvent] = []
        var seen: Set<String> = []
        for file in finder.logs(now: now, roots: Self.watchedRoots(now: now), find: Self.recentLogs) {
            let key = file.path
            seen.insert(key)
            guard let (size, modified) = AgentFiles.size(of: file) else { continue }
            let first = logs[key] == nil
            var log = logs[key] ?? AgentLog(file: file)
            guard first || size != log.size || modified != log.modified else { continue }
            log.size = size
            log.modified = modified
            guard let lines = AgentFiles.readTail(file, size: size) else { continue }
            let read = Self.read(lines)
            events += log.update(calls: read.calls, results: read.results, busy: read.busy, first: first, quietStart: quietStart)
            logs[key] = log
        }
        logs = logs.filter { seen.contains($0.key) }
        return events
    }

    private static func watchedRoots(now: Date) -> [URL] { [root] }

    private static func recentLogs(now: Date) -> [URL] {
        var found: [URL] = []
        for project in (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [] {
            let chats = root.appendingPathComponent(project, isDirectory: true).appendingPathComponent("chats", isDirectory: true)
            for name in (try? FileManager.default.contentsOfDirectory(atPath: chats.path)) ?? []
            where name.hasPrefix("session-") && name.hasSuffix(".jsonl") {
                let file = chats.appendingPathComponent(name)
                if let (_, modified) = AgentFiles.size(of: file), now.timeIntervalSince(modified) < recent { found.append(file) }
            }
        }
        return found
    }

    private struct Read {
        var calls: [(id: String, name: String?, target: String?)] = []
        var results: [(id: String, failed: Bool)] = []
        var busy: Bool?
    }

    private static let finished: Set<String> = ["success", "error", "cancelled"]

    private static func read(_ lines: [Substring]) -> Read {
        var read = Read()
        var called: Set<String> = []
        var back: Set<String> = []
        for line in lines {
            // Metadata and "$set", "$patch", "$rewindTo" lines have no message id.
            guard let entry = AgentFiles.json(line), entry["id"] is String else { continue }
            switch entry["type"] as? String {
            case "user":
                read.busy = true
            case "error":
                read.busy = false
            case "gemini":
                let calls = entry["toolCalls"] as? [[String: Any]] ?? []
                if calls.isEmpty {
                    if let tokens = entry["tokens"], !(tokens is NSNull) { read.busy = false }
                    continue
                }
                read.busy = true
                for call in calls {
                    guard let id = (call["id"] as? String).map({ String($0.prefix(80)) }) else { continue }
                    let name = call["name"] as? String ?? ""
                    if called.insert(id).inserted {
                        let args = call["args"] as? [String: Any] ?? [:]
                        let shown = shown(name)
                        read.calls.append((id, shown, AgentFiles.target(
                            path: ["file_path", "absolute_path", "path", "dir_path"].lazy.compactMap { args[$0] as? String }.first,
                            command: shown == "Bash" ? args["command"] as? String : nil,
                            url: (args["url"] as? String) ?? (args["urls"] as? [String])?.first)))
                    }
                    if let status = call["status"] as? String, finished.contains(status), back.insert(id).inserted {
                        read.results.append((id, status == "error"))
                    }
                }
            default:
                break
            }
        }
        return read
    }

    /// Gemini CLI's tools by the names Pixpaw knows them by (Claude Code's).
    private static func shown(_ name: String) -> String? {
        switch name {
        case "read_file", "read_many_files", "list_directory": "Read"
        case "replace", "edit": "Edit"
        case "write_file": "Write"
        case "run_shell_command": "Bash"
        case "search_file_content", "grep", "grep_search", "glob": "Grep"
        case "google_web_search", "web_search": "WebSearch"
        case "web_fetch": "WebFetch"
        case "delegate_to_agent", "codebase_investigator": "Task"
        default: nil
        }
    }
}
