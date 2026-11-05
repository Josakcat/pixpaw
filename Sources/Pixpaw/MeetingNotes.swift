//
//  MeetingNotes.swift
//  Pixpaw
//
//  Meeting notes: your pet listens to a call with you and writes it down.
//  Your side comes from the microphone and, if you like, the others' from
//  the Mac's own sound (ScreenCaptureKit, audio only), each turned into
//  words on the Mac by Apple's speech recognition, in Thai or English. The
//  sound is never kept. When you stop, the model you picked sums it up
//  (Apple's own on the Mac, or Claude, Codex or Antigravity through their
//  commands, signed in as you), and the notes are saved as a Markdown file
//  and put on Droppy's shelf.
//

import AVFoundation
import FoundationModels
import ScreenCaptureKit
import Speech

/// One thing said: when, and by you or the others.
struct MeetingLine: Equatable {
    let at: TimeInterval
    let you: Bool
    let text: String
}

/// Who sums the meeting up.
enum NoteModel: String, CaseIterable, Identifiable {
    case apple, claude, codex, antigravity, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: "Apple Intelligence (on this Mac)"
        case .claude: "Claude (claude command)"
        case .codex: "Codex (codex command)"
        case .antigravity: "Antigravity (agy command)"
        case .none: "None, just the transcript"
        }
    }

    /// The command it runs, if it runs one, where it's installed.
    var command: URL? {
        let name: String
        switch self {
        case .claude: name = "claude"
        case .codex: name = "codex"
        case .antigravity: name = "agy"
        case .apple, .none: return nil
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/\(name)", "\(home)/.claude/local/\(name)", "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    /// Whether it can sum up here: its command is installed, or Apple's model is ready.
    var available: Bool {
        switch self {
        case .apple:
            if #available(macOS 26, *) { SystemLanguageModel.default.isAvailable } else { false }
        case .none: true
        default: command != nil
        }
    }

    /// Whether the transcript leaves the Mac for the model's company.
    var online: Bool { ![.apple, .none].contains(self) }

    /// Models to pick from; "" is the command's own default.
    var presets: [String] {
        switch self {
        case .claude: ["", "haiku", "sonnet", "opus"]
        default: [""]
        }
    }
}

/// What a meeting is heard from.
enum MeetingSource: String, CaseIterable, Identifiable {
    case both, microphone, mac

    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Microphone and the Mac's sound"
        case .microphone: "Microphone only"
        case .mac: "The Mac's sound only"
        }
    }
    var detail: String {
        switch self {
        case .both: "Your microphone, and the call's own sound from your Mac, so their side is in the notes, marked apart from yours. The Mac's sound needs Screen Recording for Droppy; without it, only your microphone. With speakers rather than headphones, their words can come twice."
        case .microphone: "Only your microphone: you, and the room if the call is on speakers."
        case .mac: "Only what your Mac plays: the call, a video or a webinar, not your microphone. Needs Screen Recording for Droppy."
        }
    }
    var hearsMicrophone: Bool { self != .mac }
    var hearsMac: Bool { self != .microphone }
}

/// The languages a meeting can be in.
enum MeetingLanguage: String, CaseIterable, Identifiable {
    case thai = "th-TH", english = "en-US"

    var id: String { rawValue }
    var title: String { self == .thai ? "Thai" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }

    /// Thai if it's among your Mac's languages, else English.
    static var likely: MeetingLanguage {
        Locale.preferredLanguages.contains { $0.hasPrefix("th") } ? .thai : .english
    }
}

enum MeetingProblem: LocalizedError {
    case notOnDevice(String), noMicrophone, noMacSound, appleNoLanguage(String), noCommand(String), modelFailed(String)

    var errorDescription: String? {
        switch self {
        case .notOnDevice(let language): "Your Mac can't turn \(language) speech into words on its own yet. Add \(language) under System Settings → Keyboard → Dictation."
        case .noMicrophone: "The microphone isn't available."
        case .noMacSound: "Droppy needs Screen Recording to hear the Mac's sound: System Settings → Privacy & Security → Screen & System Audio Recording."
        case .appleNoLanguage(let language): "Apple's model doesn't write \(language) yet. Pick Claude, Codex or Antigravity for the summary."
        case .noCommand(let name): "The \(name) command isn't installed."
        case .modelFailed(let why): "The summary didn't come back: \(why)"
        }
    }
}

// MARK: - Listening

/// Speech to words for one voice, as long as the meeting runs. Apple's
/// recognizer takes about a minute at a time, so a new request starts at
/// each pause in the talk (or every 50 seconds), and each one's last words
/// are kept as a line.
@MainActor
final class RollingTranscriber {
    let you: Bool
    private let recognizer: SFSpeechRecognizer
    private let feed = AudioFeed()
    private var task: SFSpeechRecognitionTask?
    private var partial = ""
    private var segmentStarted = Date()
    private var heardAt: Date?
    private let startedAt: Date
    private var timer: Timer?
    private(set) var lines: [MeetingLine] = []
    /// What it's making out now, for the pet to show.
    var hearing: ((String) -> Void)?

    init(language: MeetingLanguage, you: Bool, startedAt: Date) throws {
        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.supportsOnDeviceRecognition else {
            throw MeetingProblem.notOnDevice(language.title)
        }
        self.recognizer = recognizer
        self.you = you
        self.startedAt = startedAt
    }

    /// Where the audio goes: from any thread.
    nonisolated var input: AudioFeed { feed }

    func start() {
        next()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        keep()
        feed.swap(nil)?.endAudio()
        task?.cancel()
        task = nil
    }

    private func next() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        feed.swap(request)?.endAudio()
        task?.cancel()
        partial = ""
        heardAt = nil
        segmentStarted = Date()
        let started = segmentStarted
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.segmentStarted == started, text != self.partial else { return }
                    self.partial = text
                    self.heardAt = Date()
                    self.hearing?(text)
                }
            }
        }
    }

    private func keep() {
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        lines.append(MeetingLine(at: segmentStarted.timeIntervalSince(startedAt), you: you, text: text))
        partial = ""
    }

    /// A pause of a second and a half ends the line; so does a long one.
    private func tick() {
        let now = Date()
        let paused = heardAt.map { now.timeIntervalSince($0) >= 1.5 } ?? false
        guard (paused && !partial.isEmpty) || now.timeIntervalSince(segmentStarted) >= 50 else { return }
        keep()
        next()
    }
}

/// The request audio is fed into, swapped as lines end; safe to append to
/// from the audio threads.
final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    /// Puts a new request in and hands back the old one.
    func swap(_ new: SFSpeechAudioBufferRecognitionRequest?) -> SFSpeechAudioBufferRecognitionRequest? {
        lock.lock()
        defer { lock.unlock() }
        let old = request
        request = new
        return old
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        request?.append(buffer)
    }

    func append(_ sample: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        request?.appendAudioSampleBuffer(sample)
    }
}

/// The others in the call: the Mac's own sound, without Droppy's.
final class SystemAudio: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var stream: SCStream?
    private let feed: AudioFeed
    private let queue = DispatchQueue(label: "pixpaw.meeting.audio")

    init(feed: AudioFeed) {
        self.feed = feed
    }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw MeetingProblem.noMicrophone }
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 16_000
        configuration.channelCount = 1
        // Audio is all it's for: the smallest picture, as seldom as it can.
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        lock.withLock { self.stream = stream }
    }

    /// Stops the capture, and with it the Mac's "Currently Sharing" in the
    /// menu bar. Done when it returns: the stream is told twice if the first
    /// time fails, and kept until it has stopped.
    func stop() async {
        guard let stream = lock.withLock({ () -> SCStream? in
            defer { self.stream = nil }
            return self.stream
        }) else { return }
        try? stream.removeStreamOutput(self, type: .audio)
        do { try await stream.stopCapture() } catch { try? await stream.stopCapture() }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        feed.append(sampleBuffer)
    }

    /// Stopped from outside: Stop Sharing in the menu bar, or the system.
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        lock.withLock { self.stream = nil }
    }
}

/// A meeting being written down.
@MainActor
final class MeetingRecorder {
    let startedAt = Date()
    let language: MeetingLanguage
    let title: String?
    private let engine = AVAudioEngine()
    private var mine: RollingTranscriber?
    private var theirs: RollingTranscriber?
    private var system: SystemAudio?
    /// What is being heard: the microphone, the Mac's sound, or both.
    private(set) var hearsMicrophone = false
    private(set) var hearsOthers = false

    init(language: MeetingLanguage, title: String?) throws {
        self.language = language
        self.title = title
        // Fails here, before anything starts, if the Mac can't do the language.
        _ = try RollingTranscriber(language: language, you: true, startedAt: startedAt)
    }

    /// Starts with what `source` says. With both, if the Mac's sound isn't
    /// allowed, the microphone alone; with one, that one or an error.
    func start(_ source: MeetingSource) async throws {
        if source.hearsMicrophone {
            let mine = try RollingTranscriber(language: language, you: true, startedAt: startedAt)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw MeetingProblem.noMicrophone }
            let feed = mine.input
            // Called on the audio threads: @Sendable, so not tied to the main actor
            // (Swift checks, and stops Droppy, when a main-actor closure runs there).
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable buffer, _ in feed.append(buffer) }
            engine.prepare()
            do { try engine.start() } catch {
                input.removeTap(onBus: 0)
                throw MeetingProblem.noMicrophone
            }
            mine.start()
            self.mine = mine
            hearsMicrophone = true
        }
        guard source.hearsMac else { return }
        let theirs = try RollingTranscriber(language: language, you: false, startedAt: startedAt)
        let system = SystemAudio(feed: theirs.input)
        do {
            try await system.start()
            theirs.start()
            self.theirs = theirs
            self.system = system
            hearsOthers = true
        } catch {
            hearsOthers = false
            guard hearsMicrophone else { throw MeetingProblem.noMacSound }
        }
    }

    /// Stops listening; everything said, in order. The Mac's sound stops
    /// a moment later: wait for `stopped` before relying on it.
    func stop() -> [MeetingLine] {
        if hearsMicrophone {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
        }
        mine?.stop()
        theirs?.stop()
        if let system {
            self.system = nil
            stopped = Task { await system.stop() }
        }
        return ((mine?.lines ?? []) + (theirs?.lines ?? [])).sorted { $0.at < $1.at }
    }

    /// The Mac's sound being stopped, if it was heard.
    private(set) var stopped: Task<Void, Never>?

    var minutes: Int { Int(Date().timeIntervalSince(startedAt) / 60) }
}

// MARK: - Notes

enum MeetingNotes {
    /// ~/Documents/Pixpaw Meetings.
    static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pixpaw Meetings", isDirectory: true)
    }

    /// With both sides heard, "You" and "Others"; with one, "Room" for the
    /// microphone and "Call" for the Mac's sound.
    static func transcript(_ lines: [MeetingLine], bothSides: Bool) -> String {
        lines.map { line in
            let at = Int(line.at)
            let who = bothSides ? (line.you ? "You" : "Others") : (line.you ? "Room" : "Call")
            return String(format: "[%02d:%02d] ", at / 60, at % 60) + "\(who): \(line.text)"
        }.joined(separator: "\n")
    }

    static func prompt(_ transcript: String, language: MeetingLanguage) -> String {
        """
        Below is the transcript of a meeting, made by speech recognition, so some words may be misheard. \
        Lines marked "You" are the person taking the notes; "Others" are the rest of the call. \
        Write meeting notes in \(language == .thai ? "Thai" : "English"), in Markdown, with these second-level (##) headings: \
        Summary (three to five sentences), Decisions, Action items (who does what, by when if said), Open questions. \
        Leave out a heading with nothing under it. Use only what is in the transcript; don't make anything up. \
        Reply with the notes only.

        Transcript:
        \(transcript)
        """
    }

    /// The summary from the model you picked. Slow: minutes for a long meeting.
    static func summarize(_ transcript: String, language: MeetingLanguage, model: NoteModel, name: String) async throws -> String {
        switch model {
        case .none:
            return ""
        case .apple:
            guard #available(macOS 26, *) else { throw MeetingProblem.noCommand(model.title) }
            return try await apple(transcript, language: language)
        case .claude, .codex, .antigravity:
            guard let command = model.command else { throw MeetingProblem.noCommand(model.title) }
            let prompt = prompt(transcript, language: language)
            return try await Task.detached(priority: .utility) {
                try run(model, command: command, model: name, prompt: prompt)
            }.value
        }
    }

    /// Apple's model on the Mac: it reads only a few pages at a time, so a
    /// long meeting is summed up a part at a time and the parts together.
    @available(macOS 26, *)
    private static func apple(_ transcript: String, language: MeetingLanguage) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.supportsLocale(language.locale) else { throw MeetingProblem.appleNoLanguage(language.title) }
        var parts: [String] = []
        var part = ""
        for line in transcript.split(separator: "\n") {
            if part.count + line.count > 6000, !part.isEmpty {
                parts.append(part)
                part = ""
            }
            part += line + "\n"
        }
        if !part.isEmpty { parts.append(part) }
        guard parts.count > 1 else {
            return try await LanguageModelSession().respond(to: prompt(transcript, language: language)).content
        }
        var notes: [String] = []
        for (index, part) in parts.enumerated() {
            let session = LanguageModelSession()
            let asked = "This is part \(index + 1) of \(parts.count) of a meeting transcript. In a few bullet points, note what was said, decided and who will do what.\n\n\(part)"
            notes.append(try await session.respond(to: asked).content)
        }
        return try await LanguageModelSession().respond(to: prompt(notes.joined(separator: "\n\n"), language: language)
            .replacingOccurrences(of: "Below is the transcript of a meeting", with: "Below are notes on each part of a meeting")).content
    }

    /// The model's command, run in an empty folder with no tools: it reads
    /// the prompt and answers, and nothing else.
    private nonisolated static func run(_ which: NoteModel, command: URL, model: String, prompt: String) throws -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pixpaw-notes-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let answerFile = folder.appendingPathComponent("answer.md")
        var arguments: [String]
        var input: String? = prompt
        switch which {
        case .claude:
            arguments = ["-p", "--tools", "", "--no-session-persistence", "--setting-sources", "", "--strict-mcp-config"]
        case .codex:
            arguments = ["exec", "--skip-git-repo-check", "--ephemeral", "--sandbox", "read-only", "-o", answerFile.path]
        default:
            arguments = ["-p", prompt, "--mode", "plan", "--print-timeout", "600s"]
            input = nil
        }
        if !model.isEmpty { arguments += which == .codex ? ["-m", model] : ["--model", model] }
        if which == .codex { arguments.append("-") }

        // droppykit-lint: allow process: the AI command the user picked for meeting notes (Claude, Codex or Antigravity), given the transcript to summarize with no tools in an empty temporary folder, only after a meeting they recorded, off the main thread and ended after 15 minutes
        let process = Process()
        process.executableURL = command
        process.arguments = arguments
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        environment["PIXPAW_ASKING_USAGE"] = "1"
        process.environment = environment
        let output = Pipe(), errors = Pipe(), stdin = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = input == nil ? FileHandle.nullDevice : stdin
        try process.run()
        if let input {
            try? stdin.fileHandleForWriting.write(contentsOf: Data(input.utf8))
            try? stdin.fileHandleForWriting.close()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 15 * 60) { if process.isRunning { process.terminate() } }
        // Both pipes drained at once, so a chatty one never fills and stalls it.
        let said = Drain(errors.fileHandleForReading)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        var answer = String(decoding: data, as: UTF8.self)
        if which == .codex { answer = (try? String(contentsOf: answerFile, encoding: .utf8)) ?? "" }
        answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !answer.isEmpty else {
            let errors = said.text
            if errors.range(of: #"(?i)refresh token|not logged in|log ?in again|unauthori[sz]ed|authenticat"#, options: .regularExpression) != nil {
                throw MeetingProblem.modelFailed("its command isn't signed in. Sign in again (for Codex, codex login) and try once more.")
            }
            let why = errors.split(separator: "\n").last.map(String.init) ?? "it stopped (\(process.terminationStatus))"
            throw MeetingProblem.modelFailed(String(why.prefix(160)))
        }
        return answer
    }

    /// The notes as a Markdown file in `folder`; its address.
    static func save(title: String?, startedAt: Date, minutes: Int, summary: String, by: String?, transcript: String) throws -> URL {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startedAt)
        let stamp = String(format: "%04d-%02d-%02d %02d.%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0, day.hour ?? 0, day.minute ?? 0)
        let name = (title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Meeting"
        let safe = String(name.map { "/:\\".contains($0) ? "-" : $0 }.prefix(60))
        let format = DateFormatter()
        format.calendar = calendar
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "d MMM yyyy, HH:mm"
        var text = "# \(name)\n\n\(format.string(from: startedAt)) · \(max(1, minutes)) min\n\n"
        if !summary.isEmpty { text += summary + "\n\n" + (by.map { "_Summed up by \($0)._\n\n" } ?? "") }
        text += "## Transcript\n\n" + (transcript.isEmpty ? "_Nothing was heard._" : transcript) + "\n"
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var file = folder.appendingPathComponent("\(stamp) \(safe).md")
        var n = 2
        while FileManager.default.fileExists(atPath: file.path) {
            file = folder.appendingPathComponent("\(stamp) \(safe) \(n).md")
            n += 1
        }
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}

/// Reads a pipe to its end on its own thread.
private final class Drain: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    init(_ handle: FileHandle) {
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty { handle.readabilityHandler = nil }
            self?.lock.lock()
            self?.data.append(chunk)
            self?.lock.unlock()
        }
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
