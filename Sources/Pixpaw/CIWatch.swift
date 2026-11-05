//
//  CIWatch.swift
//  Pixpaw
//
//  After your agent pushes to GitHub, your pet waits for the checks with
//  you: the hook says which repository and branch were pushed, and every
//  twenty seconds `gh run list` (GitHub's own command, signed in as you)
//  says how its Actions runs are doing. Green, it jumps for joy; red, a bug
//  turns up until a push makes it green again. Only the runs' names and
//  states are read. Off unless you turn it on, since `gh` goes online.
//

import Foundation

/// A GitHub Actions run, as `gh run list --json` gives it.
struct CIRun: Decodable, Equatable {
    let databaseId: Int
    let status: String
    let conclusion: String?
    let workflowName: String?
    let createdAt: Date
    let url: String?

    var done: Bool { status == "completed" }
    /// Skipped and neutral runs don't make it red.
    var passed: Bool { ["success", "skipped", "neutral"].contains(conclusion ?? "") }
}

@MainActor
final class CIWatch {
    enum Event {
        case started(workflows: [String])
        case passed
        case failed(workflow: String, url: URL?)
        case cancelled
    }

    /// "owner/repo".
    let repo: String
    let branch: String
    private let pushedAt = Date()
    private let tell: (Event) -> Void
    private var timer: Timer?
    private var asking = false
    private var started = false

    /// No run for the push after this long: the repository has no Actions
    /// for it, or the push didn't go through.
    private static let firstRunWithin: TimeInterval = 3 * 60
    private static let givesUpAfter: TimeInterval = 45 * 60
    private static let every: TimeInterval = 20

    /// "owner/repo@branch", from the hook.
    init?(_ pushed: String, tell: @escaping (Event) -> Void) {
        guard let match = pushed.wholeMatch(of: #/([\w.-]{1,100})/([\w.-]{1,100})@([\w./-]{1,100})/#) else { return nil }
        repo = "\(match.1)/\(match.2)"
        branch = String(match.3)
        self.tell = tell
    }

    /// The repository's short name, for the pet to say.
    var name: String { repo.split(separator: "/").last.map(String.init) ?? repo }

    /// Where `gh` usually is; Droppy has no shell PATH.
    static var gh: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/gh", "/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.every, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let waited = Date().timeIntervalSince(pushedAt)
        guard waited < Self.givesUpAfter, let gh = Self.gh else { return stop() }
        guard !asking else { return }
        asking = true
        let arguments = ["run", "list", "--repo", repo, "--branch", branch, "--limit", "10",
                         "--json", "databaseId,status,conclusion,workflowName,createdAt,url"]
        Task { [weak self] in
            let runs = await Task.detached(priority: .utility) { Self.runs(gh, arguments) }.value
            self?.asking = false
            self?.heard(runs)
        }
    }

    private func heard(_ runs: [CIRun]?) {
        guard timer != nil else { return }
        // This push's runs: started since it, give or take a clock's minute.
        let ours = (runs ?? []).filter { $0.createdAt >= pushedAt.addingTimeInterval(-60) }
        guard !ours.isEmpty else {
            if Date().timeIntervalSince(pushedAt) > Self.firstRunWithin { stop() }
            return
        }
        if !started {
            started = true
            tell(.started(workflows: Array(Set(ours.compactMap(\.workflowName))).sorted()))
        }
        guard ours.allSatisfy(\.done) else { return }
        stop()
        if let failed = ours.first(where: { !$0.passed && $0.conclusion != "cancelled" }) {
            tell(.failed(workflow: failed.workflowName ?? "CI", url: failed.url.flatMap(URL.init(string:))))
        } else if ours.allSatisfy(\.passed) {
            tell(.passed)
        } else {
            tell(.cancelled)
        }
    }

    /// `gh run list`, given twenty seconds; nil if it couldn't say.
    private nonisolated static func runs(_ gh: URL, _ arguments: [String]) -> [CIRun]? {
        // droppykit-lint: allow process: the user's own GitHub CLI (`gh run list`, read-only) to watch the CI of a push they made, only while CI watching is on in Settings, off the main thread and ended after 20 seconds
        let process = Process()
        process.executableURL = gh
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["NO_COLOR"] = "1"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let deadline = DispatchTime.now() + 20
        DispatchQueue.global().asyncAfter(deadline: deadline) { if process.isRunning { process.terminate() } }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([CIRun].self, from: data)
    }
}
