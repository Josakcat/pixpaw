//
//  PetVoice.swift
//  Pixpaw
//
//  Talk to your pet: press its shortcut (or Talk to me in its menu), say
//  what you'd like, "come here", "focus for 25 minutes", "note buy milk",
//  and it does it. Apple's speech recognition runs on the Mac
//  (`requiresOnDeviceRecognition`), only while you talk to it and for a few
//  seconds at most; the sound isn't kept or sent, and the words only long
//  enough to do what they say.
//

import AVFoundation
import Foundation
import Speech

/// What you can ask your pet out loud.
enum PetCommand: Equatable {
    case come, feed, treat, nap, stretch, photo, gif, join
    /// One of Droppy's own tools (DroppyTools.swift).
    case droppy(DroppyTool)
    case focus(minutes: Int?)
    case stopFocus
    case lofi, pauseLofi
    case play(PetGame?)
    case note(String)
    case usage
    case quiet(Bool)
    case praise

    /// Words it listens out for, so they're heard right.
    static let words = ["come here", "feed", "treat", "nap", "stretch", "take a photo", "record a GIF", "join the call",
                        "focus", "stop focus", "play lofi", "pause lofi", "play", "fetch", "note", "remind me to",
                        "usage left", "be quiet", "good kitty", "my notes", "new note", "tasks", "clipboard", "meetings today", "capture the page", "agents", "next song", "previous song", "pause the song"]

    /// The first thing it knows in what was said, or nil.
    static func parse(_ said: String) -> PetCommand? {
        let text = said.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !text.isEmpty else { return nil }
        // A note keeps your words as you said them, whatever is in them.
        for opener in ["remind me to ", "remember to ", "make a note to ", "make a note ", "add a note ", "write down ", "note that ", "note "]
        where text.hasPrefix(opener) {
            let rest = String(said.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst(opener.count))
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return rest.isEmpty ? nil : .note(rest.prefix(1).uppercased() + rest.dropFirst())
        }
        // Whole words only: "here" isn't in "where", nor "eat" in "great".
        func has(_ words: String...) -> Bool {
            words.contains { text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b", options: .regularExpression) != nil }
        }
        // Droppy's own tools: what Droppy already has, the pet asks it for.
        if has("new note") { return .droppy(.newNote) }
        if has("my notes", "show notes", "open notes", "the notes") { return .droppy(.notes) }
        if has("tasks", "my tasks", "to-do list", "todo list") { return .droppy(.tasks) }
        if has("clipboard") { return .droppy(.clipboard) }
        if has("meetings today", "today's meetings", "my meetings") { return .droppy(.todaysMeetings) }
        if has("capture the page", "capture this page", "whole page", "scrolling capture") { return .droppy(.captureScrolling) }
        if has("agents", "my agents") { return .droppy(.agents) }
        // Whatever is playing, through Droppy (lofi keeps its own words below).
        if has("next song", "next track", "skip this song", "skip the song") { return .droppy(.nextTrack) }
        if has("previous song", "previous track", "last song", "go back a song") { return .droppy(.previousTrack) }
        if has("pause the song", "play the song", "resume the song") { return .droppy(.playPause) }
        if has("stop focus", "end focus", "stop the focus", "done focusing") { return .stopFocus }
        if has("focus", "pomodoro") {
            let minutes = text.firstMatch(of: #/(\d{1,3})\s*(min|minute)/#).flatMap { Int($0.1) }
                ?? text.firstMatch(of: #/(\d{1,2})\s*hour/#).flatMap { Int($0.1) }.map { $0 * 60 }
            return .focus(minutes: minutes.map { min(180, max(1, $0)) })
        }
        if has("pause", "stop the music", "stop music", "stop lofi", "stop the lofi") { return .pauseLofi }
        if has("lofi", "lo-fi", "lo fi", "low fi", "music", "beats") { return .lofi }
        if has("photo", "picture", "selfie") { return .photo }
        if has("gif") { return .gif }
        if has("meeting", "join the call", "join call", "video call") { return .join }
        if has("usage", "quota", "how much is left", "what's left", "limit") { return .usage }
        if has("be quiet", "quiet", "shh", "hush", "silent") { return .quiet(true) }
        if has("you can talk", "talk again", "speak again") { return .quiet(false) }
        if has("treat", "snack") { return .treat }
        if has("feed", "food", "dinner", "breakfast", "lunch", "hungry", "eat") { return .feed }
        if has("stretch") { return .stretch }
        if has("nap", "sleep", "go home", "bed time", "bedtime") { return .nap }
        if has("fetch", "ball") { return .play(.fetch) }
        if let game = PetGame.allCases.first(where: { has($0.rawValue.lowercased()) }) { return .play(game) }
        if has("play") { return .play(nil) }
        if has("come", "here", "over here") { return .come }
        if has("good", "great", "thank you", "thanks", "love you", "cute", "clever") { return .praise }
        return nil
    }
}

enum PetListenProblem: LocalizedError {
    case notOnDevice, noMicrophone

    var errorDescription: String? {
        switch self {
        case .notOnDevice: "Your Mac can't recognize English speech on its own yet. Download it under System Settings → Keyboard → Dictation."
        case .noMicrophone: "The microphone isn't available."
        }
    }
}

/// Listens once: until you stop talking for a moment, or seven seconds.
@MainActor
final class PetListener {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var startedAt = Date()
    private var heardAt: Date?
    private var said = ""
    private var done: ((String) -> Void)?
    /// What it has made out so far, as you talk.
    var hearing: ((String) -> Void)?

    var listening: Bool { request != nil }

    private static let longest: TimeInterval = 7
    private static let pause: TimeInterval = 1.3

    func listen(then done: @escaping (String) -> Void) throws {
        stop()
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { throw PetListenProblem.notOnDevice }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = PetCommand.words
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw PetListenProblem.noMicrophone }
        nonisolated(unsafe) let feed = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in feed.append(buffer) }
        engine.prepare()
        do { try engine.start() } catch {
            input.removeTap(onBus: 0)
            throw PetListenProblem.noMicrophone
        }
        self.request = request
        self.done = done
        said = ""
        heardAt = nil
        startedAt = Date()
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true || error != nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.heard(text, final: final) }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Done talking: what was said so far is what it goes by.
    func finish() {
        guard listening else { return }
        let done = self.done
        let said = self.said
        stop()
        done?(said)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        done = nil
    }

    private func heard(_ text: String?, final: Bool) {
        guard listening else { return }
        if let text, !text.isEmpty, text != said {
            said = text
            heardAt = Date()
            hearing?(text)
        }
        if final { finish() }
    }

    private func tick() {
        let now = Date()
        if let heardAt, now.timeIntervalSince(heardAt) >= Self.pause { return finish() }
        if now.timeIntervalSince(startedAt) >= Self.longest { finish() }
    }
}
