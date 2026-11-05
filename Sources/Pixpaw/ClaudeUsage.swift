//
//  ClaudeUsage.swift
//  Pixpaw
//
//  What's left of your Claude plan, without the status line (which the
//  Claude app doesn't run): the `claude` command answers a `get_usage`
//  request on its stream-json control channel, the way Droppy's own Agents
//  widget asks it. No prompt is sent and nothing is billed; it starts
//  without your settings (so no hooks run), answers in a second or two and
//  is closed. Only the two windows' percentages and reset times are kept,
//  in the file the status line keeps them in.
//

import Foundation

enum ClaudeUsage {
    /// Where the `claude` command usually is; Droppy has no shell PATH.
    static var command: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    /// Asks, and saves what's left to `PlanUsageReader.claudeFile`. True when
    /// it got an answer.
    static func ask(timeout: TimeInterval = 20) async -> Bool {
        guard let command else { return false }
        return await Task.detached(priority: .utility) { () -> Bool in
            guard let limits = run(command, timeout: timeout) else { return false }
            return save(limits)
        }.value
    }

    private nonisolated static func run(_ command: URL, timeout: TimeInterval) -> [String: Any]? {
        // droppykit-lint: allow process: the user's own Claude Code CLI, asked only for its plan usage (`get_usage`, no prompt, no tools, no MCP), only while that is turned on in Settings, off the main thread and ended after the timeout
        let process = Process()
        process.executableURL = command
        process.arguments = ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
                             "--no-session-persistence", "--setting-sources", "", "--strict-mcp-config"]
        var environment = ProcessInfo.processInfo.environment
        environment["PIXPAW_ASKING_USAGE"] = "1"
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        running.set(process)
        defer {
            running.set(nil)
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }
        let id = "pixpaw-\(UUID().uuidString.prefix(8))"
        let request = #"{"type":"control_request","request_id":"\#(id)","request":{"subtype":"get_usage"}}"# + "\n"
        try? input.fileHandleForWriting.write(contentsOf: Data(request.utf8))

        // Read until the answer, or give up.
        let reader = output.fileHandleForReading
        let received = Received()
        let deadline = Date().addingTimeInterval(timeout)
        reader.readabilityHandler = { handle in received.add(handle.availableData) }
        defer { reader.readabilityHandler = nil }
        while Date() < deadline, process.isRunning || !received.isEnded {
            Thread.sleep(forTimeInterval: 0.1)
            // Only the lines new since the last look, each parsed once, in a
            // pool of its own so nothing piles up over twenty seconds.
            let found: [String: Any]?? = autoreleasepool {
                let (lines, finished) = received.takeLines()
                for line in lines {
                    guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                          message["type"] as? String == "control_response",
                          let response = message["response"] as? [String: Any],
                          response["request_id"] as? String == id else { continue }
                    return .some((response["response"] as? [String: Any])?["rate_limits"] as? [String: Any])
                }
                return finished ? .some(nil) : nil
            }
            if let found { return found }
        }
        return nil
    }

    /// The command while it runs, so `stop()` can end it.
    private static let running = Running()

    /// Ends a request still running (from deactivate()).
    static func stop() { running.terminate() }

    /// `{"five_hour": {"utilization": 59, "resets_at": "2026-10-28T08:20:00+00:00"}, "seven_day": {…}}`,
    /// saved as the status line saves it.
    private nonisolated static func save(_ limits: [String: Any]) -> Bool {
        let iso = ISO8601DateFormatter()
        let fractions = ISO8601DateFormatter()
        fractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var saved: [String: Any] = ["saved_at": Date().timeIntervalSince1970]
        for key in ["five_hour", "seven_day"] {
            guard let window = limits[key] as? [String: Any], let used = (window["utilization"] as? NSNumber)?.doubleValue else { continue }
            var entry: [String: Any] = ["used": used]
            if let stamp = window["resets_at"] as? String, let date = fractions.date(from: stamp) ?? iso.date(from: stamp) {
                entry["resets_at"] = date.timeIntervalSince1970
            }
            saved[key] = entry
        }
        guard saved.count > 1, let data = try? JSONSerialization.data(withJSONObject: saved) else { return false }
        let file = PlanUsageReader.claudeFile
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: file, options: .atomic)) != nil
    }
}

/// What the command printed so far, filled from its pipe's own thread.
private final class Received: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var ended = false

    func add(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        if chunk.isEmpty { ended = true } else { data.append(chunk) }
    }

    var isEnded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ended
    }

    /// The whole lines printed since the last call, taken out; a part line
    /// waits for the rest.
    func takeLines() -> ([Data], Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard let last = data.lastIndex(of: UInt8(ascii: "\n")) else { return ([], ended) }
        let whole = data[data.startIndex...last]
        let lines = whole.split(separator: UInt8(ascii: "\n")).map { Data($0) }
        data = Data(data[data.index(after: last)...])
        return (lines, ended)
    }
}

/// The running `claude` process, shared with deactivate().
private final class Running: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    func set(_ new: Process?) {
        lock.lock()
        defer { lock.unlock() }
        process = new
    }

    func terminate() {
        lock.lock()
        defer { lock.unlock() }
        if process?.isRunning == true { process?.terminate() }
    }
}
