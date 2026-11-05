//
//  ClaudeSessions.swift
//  Pixpaw
//
//  Claude Code without the hooks: the files it keeps while it runs. Each
//  running session leaves `~/.claude/sessions/<pid>.json` (its id and
//  folder) and writes its turn line by line to
//  `~/.claude/projects/<folder>/<id>.jsonl`, in the terminal and in the
//  Claude app alike. Read as AgentFiles.swift says; the `.key` files beside
//  the sessions are never opened.
//

import Darwin
import Foundation

/// Polled only on PixpawDroplet's agent-files queue, never the main thread.
final class ClaudeSessions: @unchecked Sendable {
    private var logs: [String: AgentLog] = [:]
    /// The last read of each session, so the quiet after a tool's answer can
    /// end a turn without reading the file again.
    private var reads: [String: Read] = [:]
    private var looked = false
    static let sessionsFolder = AgentFiles.home.appendingPathComponent(".claude/sessions", isDirectory: true)
    static let projectsFolder = AgentFiles.home.appendingPathComponent(".claude/projects", isDirectory: true)
    /// A tool's result with nothing after it this long: the turn ended there
    /// (the Claude app ends a turn on a tool's answer).
    nonisolated fileprivate static let quietAfterResult: TimeInterval = 10

    /// What happened since the last look, oldest first. The first look at a
    /// session only learns where it is, so nothing old is told.
    func poll(now: Date = Date()) -> [AgentFileEvent] {
        let quietStart = !looked
        looked = true
        var events: [AgentFileEvent] = []
        var alive: Set<String> = []
        for (id, folder) in Self.liveSessions() {
            alive.insert(id)
            let first = logs[id] == nil
            guard var log = logs[id] ?? Self.transcript(id: id, folder: folder).map({ AgentLog(file: $0) }),
                  let (size, modified) = AgentFiles.size(of: log.file) else { continue }
            // Unchanged, only the quiet after a tool's answer can end a turn:
            // worked out from the last read, the file left alone.
            if !first, size == log.size, modified == log.modified {
                if log.busy == true, let last = reads[id] {
                    events += log.update(calls: [], results: [], busy: last.busy(quietFor: now.timeIntervalSince(modified)), first: false, quietStart: quietStart)
                    logs[id] = log
                }
                continue
            }
            log.size = size
            log.modified = modified
            guard let lines = AgentFiles.readTail(log.file, size: size) else { continue }
            let read = Self.read(lines)
            reads[id] = read
            events += log.update(calls: read.order.map { ($0.id, $0.name, $0.target) }, results: read.results.map { ($0.id, $0.failed) },
                                 busy: read.busy(quietFor: now.timeIntervalSince(modified)), first: first, quietStart: quietStart)
            logs[id] = log
        }
        logs = logs.filter { alive.contains($0.key) }
        reads = reads.filter { alive.contains($0.key) }
        return events
    }

    // MARK: Files

    /// The sessions whose Claude is still running: id and folder.
    private static func liveSessions() -> [(id: String, folder: String)] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: sessionsFolder.path) else { return [] }
        return names.compactMap { name in
            // `<pid>.json` only: the `.key` files beside them stay shut.
            guard name.hasSuffix(".json"), let pid = Int32(name.dropLast(5)), pid > 0,
                  kill(pid, 0) == 0 || errno == EPERM,
                  let data = try? Data(contentsOf: sessionsFolder.appendingPathComponent(name)), data.count < 64 * 1024,
                  let entry = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = entry["sessionId"] as? String, id.wholeMatch(of: #/[A-Za-z0-9-]{8,64}/#) != nil,
                  (entry["pid"] as? NSNumber)?.int32Value ?? pid == pid else { return nil }
            return (id, entry["cwd"] as? String ?? "")
        }
    }

    /// `~/.claude/projects/-Users-me-app/<id>.jsonl`: the folder with every
    /// character but letters, digits and dashes made a dash; else looked for.
    private static func transcript(id: String, folder: String) -> URL? {
        let named = String(folder.map { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") ? $0 : "-" })
        let guess = projectsFolder.appendingPathComponent(named, isDirectory: true).appendingPathComponent("\(id).jsonl")
        if FileManager.default.fileExists(atPath: guess.path) { return guess }
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: projectsFolder.path)) ?? []
        return folders.lazy
            .map { projectsFolder.appendingPathComponent($0, isDirectory: true).appendingPathComponent("\(id).jsonl") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: Reading

    private struct Call: Equatable {
        let id: String
        /// Claude's name for the tool, nil for one the pet doesn't show.
        let name: String?
        let target: String?
    }

    private struct Result {
        let id: String
        let failed: Bool
    }

    /// The last thing in the turn, for whether it is still going.
    private enum Last {
        case prompt, request, call, result, finished, interrupted, nothing
    }

    private struct Read {
        var order: [Call] = []
        var results: [Result] = []
        var last = Last.nothing
        /// True while Claude works on a turn, false once it's over, nil when
        /// it can't be told.
        func busy(quietFor quiet: TimeInterval) -> Bool? {
            switch last {
            case .prompt, .request, .call: true
            case .result: quiet < ClaudeSessions.quietAfterResult
            case .finished, .interrupted: false
            case .nothing: nil
            }
        }
    }

    private static func read(_ lines: [Substring]) -> Read {
        var read = Read()
        for line in lines {
            guard let entry = AgentFiles.json(line), entry["isSidechain"] as? Bool != true else { continue }
            let message = entry["message"] as? [String: Any]
            let blocks = message?["content"] as? [[String: Any]] ?? []
            switch entry["type"] as? String {
            case "user":
                // Claude Code's own notes and slash commands aren't a turn.
                if entry["isMeta"] as? Bool == true || entry["isCompactSummary"] as? Bool == true { continue }
                if let said = message?["content"] as? String {
                    if said.hasPrefix("<command-") || said.hasPrefix("<local-command") { continue }
                    read.last = said.hasPrefix("[Request interrupted") ? .interrupted : .prompt
                    continue
                }
                var answered = false
                for block in blocks {
                    switch block["type"] as? String {
                    case "tool_result":
                        if let id = block["tool_use_id"] as? String {
                            read.results.append(Result(id: id, failed: block["is_error"] as? Bool == true))
                        }
                        answered = true
                    case "text":
                        let said = block["text"] as? String ?? ""
                        read.last = said.hasPrefix("[Request interrupted") ? .interrupted : .prompt
                    default:
                        break
                    }
                }
                if answered { read.last = .result }
            case "assistant":
                for block in blocks where block["type"] as? String == "tool_use" {
                    guard let id = block["id"] as? String else { continue }
                    let name = block["name"] as? String ?? ""
                    let input = block["input"] as? [String: Any] ?? [:]
                    read.order.append(Call(id: String(id.prefix(80)), name: shown(name), target: target(of: name, input)))
                }
                switch message?["stop_reason"] as? String {
                case "end_turn", "stop_sequence", "max_tokens", "refusal": read.last = .finished
                default: read.last = .call
                }
            case "api-request":
                read.last = .request
            case "system":
                if entry["subtype"] as? String == "stop_hook_summary" { read.last = .finished }
            default:
                break
            }
        }
        return read
    }

    /// The tools the pet knows by Claude's names.
    private static func shown(_ name: String) -> String? {
        switch name {
        case "Bash", "Read", "Edit", "Write", "Grep", "Glob", "WebFetch", "WebSearch", "Task", "Agent", "NotebookEdit": name
        case "MultiEdit": "Edit"
        default: nil
        }
    }

    /// The least of what it touches, as the hook says it.
    private static func target(of tool: String, _ input: [String: Any]) -> String? {
        AgentFiles.target(path: (input["file_path"] ?? input["notebook_path"]) as? String, command: input["command"] as? String,
                          url: input["url"] as? String)
    }
}
