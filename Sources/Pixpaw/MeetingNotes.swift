//
//  MeetingNotes.swift
//  Pixpaw
//
//  Meeting notes: your pet listens to a call with you and writes it down.
//  Your side comes from the microphone and, if you like, the others' from
//  the Mac's own sound (ScreenCaptureKit, audio only), each turned into
//  words on the Mac by Apple's speech recognition, in Thai or English. The
//  sound is never kept. When you stop, the model you picked sums it up
//  (Apple's own on the Mac, or Claude through its command with its tools
//  off, signed in as you), and the notes are saved as a Markdown file
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
    // Codex and Antigravity are left out: neither can be run with its tools
    // off, and a summary must not be able to act on what was said in a call.
    case apple, claude, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: "Apple Intelligence (on this Mac)"
        case .claude: "Claude (claude command)"
        case .none: "None, just the transcript"
        }
    }

    /// The command it runs, if it runs one, where it's installed.
    var command: URL? {
        let name: String
        switch self {
        case .claude: name = "claude"
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
        case .appleNoLanguage(let language): "Apple's model doesn't write \(language) yet. Pick Claude for the summary."
        case .noCommand(let name): "The \(name) command isn't installed."
        case .modelFailed(let why): "The summary didn't come back: \(why)"
        }
    }
}

// MARK: - Listening

/// Speech to words for one voice, as long as the meeting runs. Apple's
/// recognizer takes about a minute at a time, so a new request starts at
/// each pause in the talk (or every 50 seconds), and each one's last words
/// are kept as a line. The audio goes straight on into the new request; the
/// old one is only told the audio has ended, and its line is kept when its
/// final words come back, so nothing said at the cut is lost. Stop does the
/// same (`finish`): the last request is ended, not cancelled, and its words
/// are waited for, up to `SpeechWords.wait`.
@MainActor
final class RollingTranscriber {
    let you: Bool
    private let recognizer: SFSpeechRecognizer
    private let feed = AudioFeed()
    /// One request and what it has made out so far.
    @MainActor private final class Segment {
        let started = Date()
        var text = ""
        var task: SFSpeechRecognitionTask?
        var done = false
        /// When a cut segment stops waiting for its final words.
        var giveUpAt: Date?
    }
    private var current: Segment?
    private var closing: [Segment] = []
    private var heardAt: Date?
    private let startedAt: Date
    private var timer: Timer?
    /// Stopping: when it began, and who gets the lines once the last words are in.
    private var draining: (since: Date, done: ([MeetingLine]) -> Void)?
    private(set) var lines: [MeetingLine] = []
    /// Words the recognizer should expect (the meeting's title), read at each new request.
    var expecting: (() -> [String])?
    /// What it's making out now, for the pet to show.
    var hearing: ((String) -> Void)?
    /// Each line as it's kept, for the live transcript.
    var kept: ((MeetingLine) -> Void)?

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

    /// Anything heard yet: a line kept, or words still being made out.
    var heardAnything: Bool {
        !lines.isEmpty || ([current].compactMap { $0 } + closing).contains { !$0.text.isEmpty }
    }

    /// Stop, keeping the last words: no more audio goes in, the request
    /// still open is ended (`endAudio`, not cancelled) like a cut one, and
    /// `done` gets every line on main once each has sent its final words,
    /// or `SpeechWords.wait` seconds on, whichever is first. Nothing waits
    /// on main meanwhile; `cancel` still ends it at once.
    func finish(_ done: @escaping ([MeetingLine]) -> Void) {
        guard draining == nil else { return }
        hearing = nil
        feed.swap(nil)?.endAudio()
        if let current, !current.done { closing.append(current) }
        current = nil
        let now = Date()
        let latest = now.addingTimeInterval(SpeechWords.wait)
        for segment in closing { segment.giveUpAt = min(segment.giveUpAt ?? latest, latest) }
        draining = (now, done)
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
        drainIfDone()
    }

    /// Stops at once: what each request made out so far is kept, nothing
    /// waits (`deactivate`). A `finish` under way gets its lines now.
    func cancel() {
        timer?.invalidate()
        timer = nil
        feed.swap(nil)?.endAudio()
        for segment in closing + [current].compactMap({ $0 }) {
            finish(segment)
            segment.task?.cancel()
            segment.task = nil
        }
        closing = []
        current = nil
        if let done = draining?.done {
            draining = nil
            done(lines)
        }
    }

    /// A `finish` is over once no request is left open, or time is up.
    private func drainIfDone() {
        guard let draining else { return }
        let now = Date()
        guard SpeechWords.doneWaiting(open: closing.count, stoppedAt: draining.since.timeIntervalSinceReferenceDate,
                                      now: now.timeIntervalSinceReferenceDate) else { return }
        for segment in closing {
            finish(segment)
            segment.task?.cancel()
            segment.task = nil
        }
        closing = []
        timer?.invalidate()
        timer = nil
        self.draining = nil
        draining.done(lines)
    }

    /// A new request takes the audio from here on; the one before is ended,
    /// not cancelled, and waits a few seconds for its last words.
    private func next() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        if let words = expecting?(), !words.isEmpty { request.contextualStrings = words }
        let segment = Segment()
        feed.swap(request)?.endAudio()
        if let old = current, !old.done {
            old.giveUpAt = Date().addingTimeInterval(SpeechWords.wait)
            closing.append(old)
        }
        current = segment
        heardAt = nil
        segment.task = recognizer.recognitionTask(with: request) { @Sendable [weak self, weak segment] result, error in
            let text = result?.bestTranscription.formattedString
            let ended = error != nil || result?.isFinal == true
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, let segment, !segment.done else { return }
                    if let text, case let words = SpeechWords.after(segment.text, text), words != segment.text {
                        segment.text = words
                        if segment === self.current {
                            self.heardAt = Date()
                            self.hearing?(text)
                        }
                    }
                    if ended { self.ended(segment) }
                }
            }
        }
    }

    /// The recognizer finished a request: a cut one's line is kept; the
    /// current one has stopped listening, so a new request takes over
    /// (straight away, or by `tick` if it ended within two seconds, so a
    /// recognizer that keeps failing isn't restarted in a loop).
    private func ended(_ segment: Segment) {
        finish(segment)
        segment.task = nil
        closing.removeAll { $0 === segment }
        if segment === current, Date().timeIntervalSince(segment.started) >= 2 { next() }
        drainIfDone()
    }

    private func finish(_ segment: Segment) {
        guard !segment.done else { return }
        segment.done = true
        let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let line = MeetingLine(at: segment.started.timeIntervalSince(startedAt), you: you, text: text)
        lines.append(line)
        kept?(line)
    }

    /// A pause of a second and a half ends the line; so does a long one.
    private func tick() {
        let now = Date()
        for segment in closing where (segment.giveUpAt ?? now) <= now {
            finish(segment)
            segment.task?.cancel()
            segment.task = nil
        }
        closing.removeAll { $0.done }
        guard let current else { return drainIfDone() }
        let age = now.timeIntervalSince(current.started)
        if current.done {
            if age >= 2 { next() }
            return
        }
        let paused = heardAt.map { now.timeIntervalSince($0) >= 1.5 } ?? false
        guard (paused && !current.text.isEmpty) || age >= 50 else { return }
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

    private var level = SpeechLevel()
    private var mono: AVAudioFormat?

    /// Speech as the recognizer hears it best: the first channel only (a
    /// voice-processed or many-channel microphone puts the voice there, and
    /// a mix with silent channels would make it quieter), lifted by
    /// `SpeechLevel`. Anything that isn't plain float audio goes in as it is.
    func appendSpeech(_ buffer: AVAudioPCMBuffer) {
        let format = buffer.format
        let count = Int(buffer.frameLength)
        guard format.commonFormat == .pcmFormatFloat32, !format.isInterleaved, count > 0,
              let source = buffer.floatChannelData else { return append(buffer) }
        lock.lock()
        defer { lock.unlock() }
        if mono?.sampleRate != format.sampleRate {
            mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: 1, interleaved: false)
        }
        guard let mono, let out = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buffer.frameLength),
              let target = out.floatChannelData else {
            request?.append(buffer)
            return
        }
        out.frameLength = buffer.frameLength
        target[0].update(from: source[0], count: count)
        level.apply(target[0], count: count, sampleRate: format.sampleRate)
        request?.append(out)
    }

    /// The Mac's sound, the same way.
    func appendSpeech(_ sample: CMSampleBuffer) {
        let frames = sample.numSamples
        guard frames > 0, let description = sample.formatDescription,
              case let format = AVAudioFormat(cmAudioFormatDescription: description),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(frames),
                                                           into: buffer.mutableAudioBufferList) == noErr
        else { return append(sample) }
        buffer.frameLength = AVAudioFrameCount(frames)
        appendSpeech(buffer)
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
        feed.appendSpeech(sampleBuffer)
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
    /// Filled in after the start when it comes from the calendar.
    var title: String?
    private let engine = AVAudioEngine()
    private var mine: RollingTranscriber?
    private var theirs: RollingTranscriber?
    private var system: SystemAudio?
    /// What is being heard: the microphone, the Mac's sound, or both.
    private(set) var hearsMicrophone = false
    private(set) var hearsOthers = false
    /// For the live transcript, on main: what a side is making out now
    /// (`you`, the words), and each line as it ends.
    var onHearing: ((Bool, String) -> Void)?
    var onLine: ((MeetingLine) -> Void)?

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
            // Voice processing: Apple's gain control and noise suppression, and
            // the call's own sound taken out of the microphone so it isn't
            // written down as you. Other sound is ducked as little as it can be.
            // If the microphone can't do it, it listens as before.
            do {
                try input.setVoiceProcessingEnabled(true)
                input.voiceProcessingOtherAudioDuckingConfiguration =
                    AVAudioVoiceProcessingOtherAudioDuckingConfiguration(enableAdvancedDucking: false, duckingLevel: .min)
            } catch {
                try? input.setVoiceProcessingEnabled(false)
            }
            let feed = mine.input
            do { try listen(input, into: feed) } catch {
                // Not with voice processing: once more without it.
                guard input.isVoiceProcessingEnabled else { throw MeetingProblem.noMicrophone }
                if engine.isRunning { engine.stop() }
                try? input.setVoiceProcessingEnabled(false)
                try listen(input, into: feed)
            }
            listen(to: mine)
            mine.start()
            self.mine = mine
            hearsMicrophone = true
        }
        guard source.hearsMac else { return }
        let theirs = try RollingTranscriber(language: language, you: false, startedAt: startedAt)
        let system = SystemAudio(feed: theirs.input)
        do {
            try await system.start()
            listen(to: theirs)
            theirs.start()
            self.theirs = theirs
            self.system = system
            hearsOthers = true
        } catch {
            hearsOthers = false
            guard hearsMicrophone else { throw MeetingProblem.noMacSound }
        }
    }

    /// Taps the microphone in the format it has now (voice processing
    /// changes it) and starts the engine; undone if it doesn't start.
    private func listen(_ input: AVAudioInputNode, into feed: AudioFeed) throws {
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw MeetingProblem.noMicrophone }
        // Called on the audio threads: @Sendable, so not tied to the main actor
        // (Swift checks, and stops Droppy, when a main-actor closure runs there).
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable buffer, _ in feed.appendSpeech(buffer) }
        engine.prepare()
        do { try engine.start() } catch {
            input.removeTap(onBus: 0)
            throw MeetingProblem.noMicrophone
        }
    }

    private func listen(to transcriber: RollingTranscriber) {
        let you = transcriber.you
        transcriber.expecting = { [weak self] in Self.expected(in: self?.title) }
        transcriber.hearing = { [weak self] text in self?.onHearing?(you, text) }
        transcriber.kept = { [weak self] line in self?.onLine?(line) }
    }

    /// Anything heard yet, on either side.
    var heardAnything: Bool { (mine?.heardAnything ?? false) || (theirs?.heardAnything ?? false) }

    /// Stops listening and keeps the last words: the microphone and the
    /// Mac's sound stop at once, then both sides' last requests are ended
    /// together and waited for (up to `SpeechWords.wait`). Everything said,
    /// in order. Main is never blocked; the live transcript hears no more.
    func finish() async -> [MeetingLine] {
        onHearing = nil
        onLine = nil
        stopListening()
        let sides = [mine, theirs].compactMap { $0 }
        var lines: [MeetingLine] = []
        var left = sides.count
        if left > 0 {
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                for side in sides {
                    side.finish { got in
                        lines += got
                        left -= 1
                        if left == 0 { done.resume() }
                    }
                }
            }
        }
        return lines.sorted { $0.at < $1.at }
    }

    /// Stops at once, nothing waited for (`deactivate`); everything said so
    /// far, in order. A `finish` under way returns now too.
    func cancel() -> [MeetingLine] {
        stopListening()
        mine?.cancel()
        theirs?.cancel()
        return ((mine?.lines ?? []) + (theirs?.lines ?? [])).sorted { $0.at < $1.at }
    }

    /// The microphone and the Mac's sound stop; the Mac's sound a moment
    /// later: wait for `stopped` before relying on it.
    private func stopListening() {
        if hearsMicrophone, engine.isRunning || engine.inputNode.isVoiceProcessingEnabled {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
            if engine.inputNode.isVoiceProcessingEnabled { try? engine.inputNode.setVoiceProcessingEnabled(false) }
        }
        if let system {
            self.system = nil
            stopped = Task { await system.stop() }
        }
    }

    /// The meeting's title and its longer words (names, product words) for
    /// the recognizer to expect.
    nonisolated static func expected(in title: String?) -> [String] {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return [] }
        let words = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 }
        return Array(([title] + words).prefix(20))
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

    static func prompt(_ transcript: String, language: MeetingLanguage, angle: String? = nil) -> String {
        let angle = angle?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ?? ""
        let shaped = angle.isEmpty ? "" : " The reader asked for these notes to be shaped this way: \"\(angle)\". "
            + "Follow it, including any different language, length or format it asks for, but still use only what is in the transcript."
        return """
        Below is the transcript of a meeting, made by speech recognition, so some words may be misheard. \
        Lines marked "You" are the person taking the notes; "Others" are the rest of the call. \
        Write meeting notes in \(language == .thai ? "Thai" : "English"), in Markdown, with these second-level (##) headings: \
        Summary (three to five sentences), Decisions, Action items (who does what, by when if said), Open questions. \
        Leave out a heading with nothing under it. Use only what is in the transcript; don't make anything up. \
        Reply with the notes only.\(shaped)

        Transcript:
        \(transcript)
        """
    }

    /// The summary from the model you picked. Slow: minutes for a long meeting.
    static func summarize(_ transcript: String, language: MeetingLanguage, model: NoteModel, name: String,
                          angle: String? = nil) async throws -> String {
        switch model {
        case .none:
            return ""
        case .apple:
            guard #available(macOS 26, *) else { throw MeetingProblem.noCommand(model.title) }
            return try await apple(transcript, language: language, angle: angle)
        case .claude:
            guard let command = model.command else { throw MeetingProblem.noCommand(model.title) }
            let prompt = prompt(transcript, language: language, angle: angle)
            // Cancelled (deactivate): the command is ended, not left to finish.
            let running = RunningProcess()
            return try await withTaskCancellationHandler {
                try await Task.detached(priority: .utility) {
                    try run(model, command: command, model: name, prompt: prompt, running: running)
                }.value
            } onCancel: { running.cancel() }
        }
    }

    /// Apple's model on the Mac: it reads only a few pages at a time, so a
    /// long meeting is summed up a part at a time and the parts together.
    @available(macOS 26, *)
    private static func apple(_ transcript: String, language: MeetingLanguage, angle: String?) async throws -> String {
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
            return try await LanguageModelSession().respond(to: prompt(transcript, language: language, angle: angle)).content
        }
        var notes: [String] = []
        for (index, part) in parts.enumerated() {
            try Task.checkCancellation()
            let session = LanguageModelSession()
            let asked = "This is part \(index + 1) of \(parts.count) of a meeting transcript. In a few bullet points, note what was said, decided and who will do what.\n\n\(part)"
            notes.append(try await session.respond(to: asked).content)
        }
        return try await LanguageModelSession().respond(to: prompt(notes.joined(separator: "\n\n"), language: language, angle: angle)
            .replacingOccurrences(of: "Below is the transcript of a meeting", with: "Below are notes on each part of a meeting")).content
    }

    /// Claude's command, run in an empty folder with no tools (`--tools ""`)
    /// and no settings, hooks or MCP servers: it reads the prompt and
    /// answers, and nothing else.
    private nonisolated static func run(_ which: NoteModel, command: URL, model: String, prompt: String,
                                          running: RunningProcess) throws -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pixpaw-notes-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var arguments = ["-p", "--tools", "", "--no-session-persistence", "--setting-sources", "", "--strict-mcp-config"]
        let input: String? = prompt
        if !model.isEmpty { arguments += ["--model", model] }

        // droppykit-lint: allow process: the user's own claude command, chosen by them for meeting notes, given the transcript to summarize with its tools off (--tools "", no settings, hooks or MCP) in an empty temporary folder, only after a meeting they recorded, off the main thread and ended after 15 minutes
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
        try running.start(process)
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
        answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !answer.isEmpty else {
            let errors = said.text
            if errors.range(of: #"(?i)refresh token|not logged in|log ?in again|unauthori[sz]ed|authenticat"#, options: .regularExpression) != nil {
                throw MeetingProblem.modelFailed("its command isn't signed in. Sign in again and try once more.")
            }
            let why = errors.split(separator: "\n").last.map(String.init) ?? "it stopped (\(process.terminationStatus))"
            throw MeetingProblem.modelFailed(String(why.prefix(160)))
        }
        return answer
    }

    /// The notes as a Markdown file in `folder`; its address.
    static func save(title: String?, startedAt: Date, minutes: Int, summary: String, by: String?, transcript: String,
                     angle: String? = nil) throws -> URL {
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
        if !summary.isEmpty {
            text += summary + "\n\n" + (by.map { "_Summed up by \($0)._\n\n" } ?? "")
            if let angle, !angle.isEmpty { text += "_Angle: \(angle)_\n\n" }
        }
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

/// The summary's command, so cancelling the summary can end it.
final class RunningProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    /// Runs it, unless the summary was already cancelled.
    func start(_ process: Process) throws {
        try lock.withLock {
            guard !cancelled else { throw CancellationError() }
            try process.run()
            self.process = process
        }
    }

    func cancel() {
        let process = lock.withLock { cancelled = true; return self.process }
        if let process, process.isRunning { process.terminate() }
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
