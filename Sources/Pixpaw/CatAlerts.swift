//
//  CatAlerts.swift
//  Pixpaw
//
//  The things the cat tells you about: Mac notifications from other apps,
//  calendar events about to start, the battery, and finished downloads. Each
//  source is its own small watcher that hands a line to `onLine` on the main
//  actor. Nothing is stored or sent anywhere; a line is shown and forgotten.
//

import AppKit
import ApplicationServices
import AudioToolbox
import CoreAudio
import CoreMediaIO
import EventKit
import IOKit.ps
import IOKit.pwr_mgt

/// The words the cat uses. English, short enough for the bubble.
enum CatWords {
    static let hungry = "I'm hungry!"
    static let full = "So full. Thanks!"
    static let caught = "Got it!"
    static func focusing(until end: Date) -> CatLine {
        CatLine(text: "Focus time · ", symbol: "timer", until: end)
    }
    static func focusDone(minutes: Int) -> CatLine {
        CatLine(text: "Time for a break! \(minutes) minutes of focus done.", symbol: "cup.and.saucer.fill", seconds: 5)
    }
    static let treat = ["Yum!", "Crunchy!", "More, please?"]
    static let gift = "I brought you something!"
    static let giftTaken = ["You like it?", "It's for you!", "I found it myself!"]
    /// Shaken about while carried.
    static let dizzy = ["Whoa…", "The room is spinning!", "Everything's wobbly…"]
    /// You just took a screenshot.
    static func screenshot() -> CatLine {
        CatLine(text: ["Did you get my good side?", "Cheese!", "Ooh, a photo!", "Was I in it?"].randomElement()!, symbol: "camera.fill")
    }
    /// The first time it sees you on a morning, with the day's first event
    /// when it can read your calendar.
    static func goodMorning(first: (title: String, start: Date)?, calendar: Bool) -> CatLine {
        guard calendar else { return CatLine(text: "Good morning!", symbol: "sun.max.fill", seconds: 3) }
        guard let first else { return CatLine(text: "Good morning! Your calendar's clear today.", symbol: "sun.max.fill", seconds: 4) }
        let time = first.start.formatted(date: .omitted, time: .shortened)
        return CatLine(text: "Good morning! First up: \(first.title.prefix(40)) at \(time).", symbol: "sun.max.fill", seconds: 5)
    }
    /// Once a night, the first time it sees you up after midnight.
    static let lateNight = CatLine(text: "It's late. Bed soon?", symbol: "moon.zzz.fill", seconds: 3)
    /// After a leap at the laser dot, which it never catches.
    static let missedLaser = ["Huh?", "Where did it go?", "So close!", "I almost had it!"]
    static let sleepy = "Sleepy. Off to the notch…"
    static func awake(_ kind: PetKind) -> String {
        switch kind {
        case .cat: "Meow! I'm up."
        case .bee: "Bzzz! I'm up."
        case .parrot: "Squawk! I'm up."
        case .dino: "Rawr! I'm up."
        case .dog: "Woof! I'm up."
        case .hamster: "Squeak! I'm up."
        case .chicken: "Bawk! I'm up."
        }
    }
    static func purr(_ kind: PetKind) -> String {
        switch kind {
        case .cat: "Purrrr…"
        case .bee: "Bzzzz…"
        case .parrot: "Pretty bird!"
        case .dino: "Rrrrr…"
        case .dog: "Wag wag wag!"
        case .hamster: "Squee…"
        case .chicken: "Bok bok bok…"
        }
    }

    static func batteryLow(_ percent: Int) -> String { "Battery at \(percent)%. Plug me in?" }
    static let charging = "Yum, power!"
    static let fullyCharged = "Battery's full."

    static func downloaded(_ name: String) -> String { "Downloaded \(name)" }

    static func eventSoon(_ title: String, minutes: Int) -> String {
        minutes <= 0 ? "\(title) is starting!" : "\(title) in \(minutes) min"
    }

    static func nowPlaying(_ song: String, _ artist: String) -> String {
        // The bubble already shows a music note.
        artist.isEmpty ? song : "\(song) — \(artist)"
    }

    static func volume(_ percent: Int) -> String { "Volume \(percent)%" }
    static let muted = "Muted"
    static func brightness(_ percent: Int) -> String { "Brightness \(percent)%" }

    static func connected(_ name: String) -> String { "\(name) connected" }
    static func disconnected(_ name: String) -> String { "\(name) disconnected" }

    static func agentWorking(_ name: String) -> String { "\(name) is on it…" }
    static func agentDone(_ name: String) -> String { "\(name) is done!" }
    static func agentWaiting(_ name: String) -> String { "\(name) needs you" }
    static func agentFailed(_ name: String) -> String { "\(name) hit a snag" }
}

// MARK: - Battery

/// Low battery at 20% and 10% (once each per discharge), plugging in, and a
/// full charge. Uses the power-source change callback, so it costs nothing
/// between changes and needs no permission.
@MainActor
final class BatteryWatcher {
    private var source: CFRunLoopSource?
    private var lastCharging: Bool?
    private var warned: Set<Int> = []
    private var wasFull = false
    private let onLine: (CatLine) -> Void

    init(onLine: @escaping (CatLine) -> Void) {
        self.onLine = onLine
    }

    func start() {
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let made = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let watcher = Unmanaged<BatteryWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.check() }
        }, context)?.takeRetainedValue() else { return }
        source = made
        CFRunLoopAddSource(CFRunLoopGetMain(), made, .defaultMode)
        check(announce: false)
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        source = nil
        lastCharging = nil
    }

    private func check(announce: Bool = true) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let details = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any],
              let current = details[kIOPSCurrentCapacityKey] as? Int,
              let max = details[kIOPSMaxCapacityKey] as? Int, max > 0
        else { return }
        let percent = current * 100 / max
        let charging = (details[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue

        defer { lastCharging = charging }
        if charging {
            warned = []
            if announce, lastCharging == false { onLine(CatLine(text: CatWords.charging, symbol: "bolt.fill")) }
            if percent >= 100, !wasFull {
                wasFull = true
                if announce, lastCharging != nil { onLine(CatLine(text: CatWords.fullyCharged, symbol: "battery.100")) }
            }
            return
        }
        wasFull = false
        // Crossing 20% and then 10% each speak once; already below one when
        // the watch starts counts as told.
        let threshold = percent <= 10 ? 10 : (percent <= 20 ? 20 : nil)
        guard let threshold, !warned.contains(threshold) else { return }
        warned.formUnion(threshold == 10 ? [10, 20] : [20])
        if announce {
            onLine(CatLine(text: CatWords.batteryLow(percent), symbol: threshold == 10 ? "battery.0" : "battery.25"))
        }
    }
}

// MARK: - Downloads

/// A new file landing in ~/Downloads, once its partial-download name is gone.
/// The folder is listed on a queue of its own, only when it changes.
@MainActor
final class DownloadsWatcher {
    private let queue = DispatchQueue(label: "pixpaw.downloads", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var running = false
    private let onLine: (CatLine) -> Void

    init(onLine: @escaping (CatLine) -> Void) {
        self.onLine = onLine
    }

    func start() {
        guard !running else { return }
        running = true
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let queue = self.queue
        queue.async { [weak self] in
            let fd = open(folder.path, O_EVTONLY)
            guard fd >= 0 else { return }
            let initial = Self.finishedFiles(in: folder)
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: queue)
            source.setEventHandler { [weak self] in
                let now = Self.finishedFiles(in: folder)
                Task { @MainActor in self?.changed(now) }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            Task { @MainActor in
                // Stopped (or gone) while the watch was being set up.
                guard let self, self.running else { return source.cancel() }
                self.known = initial
                self.source = source
            }
        }
    }

    func stop() {
        running = false
        source?.cancel()
        source = nil
        known = []
    }

    private func changed(_ now: Set<String>) {
        let fresh = now.subtracting(known)
        known = now
        // A burst (unzipping, a sync) is not a download; name one at most.
        guard fresh.count <= 3, let name = fresh.sorted().first else { return }
        onLine(CatLine(text: CatWords.downloaded(Self.shortened(name)), symbol: "arrow.down.circle.fill"))
    }

    nonisolated private static func finishedFiles(in folder: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let partial = ["download", "crdownload", "part", "partial", "opdownload", "tmp"]
        return Set(names.filter { name in
            !name.hasPrefix(".") && !partial.contains((name as NSString).pathExtension.lowercased())
        })
    }

    private static func shortened(_ name: String) -> String {
        name.count <= 32 ? name : String(name.prefix(22)) + "…" + String(name.suffix(8))
    }
}

// MARK: - Calendar

/// Events about to start: five minutes before, once per event. Checks once a
/// minute, only while calendar access is granted.
@MainActor
final class CalendarWatcher {
    private let store = EKEventStore()
    private var timer: Timer?
    private var announced: Set<String> = []
    private let onLine: (CatLine) -> Void

    init(onLine: @escaping (CatLine) -> Void) {
        self.onLine = onLine
    }

    /// Droppy's own answer, which is the one that counts: Droppy owns the
    /// calendar prompt, and can know it is granted before EventKit in this
    /// process says so.
    static var hostGranted = false

    static var hasAccess: Bool {
        if hostGranted { return true }
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    /// EventKit's status by name, for the log.
    static var eventKitStatus: String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: "not determined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .fullAccess: "full access"
        case .writeOnly: "write only"
        @unknown default: "unknown"
        }
    }

    /// Today's first event still to come, or begun in the last half hour;
    /// all-day ones left out.
    static func firstEventToday() -> (title: String, start: Date)? {
        guard hasAccess else { return nil }
        let store = EKEventStore()
        let now = Date()
        guard let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return nil }
        let events = store.events(matching: store.predicateForEvents(withStart: now.addingTimeInterval(-30 * 60), end: end, calendars: nil))
        return events.filter { !$0.isAllDay }.compactMap { event in event.startDate.map { (event.title ?? "An event", $0) } }
            .min { $0.1 < $1.1 }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer?.tolerance = 10
        check()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        guard Self.hasAccess else { return }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-60), end: now.addingTimeInterval(6 * 60), calendars: nil)
        for event in store.events(matching: predicate) where !event.isAllDay {
            guard let start = event.startDate, let id = event.eventIdentifier, !announced.contains(id) else { continue }
            let minutes = Int((start.timeIntervalSince(now) / 60).rounded())
            guard minutes <= 5, minutes >= -1 else { continue }
            announced.insert(id)
            onLine(CatLine(text: CatWords.eventSoon(event.title ?? "Event", minutes: max(0, minutes)), symbol: "calendar"))
        }
        if announced.count > 200 { announced = [] }
    }
}

// MARK: - Mac notifications

/// Notification banners from other apps, read through the Accessibility API:
/// when Notification Center opens a banner window, its text is read and
/// handed on. Runs on a thread and run loop of its own, with a short AX
/// timeout, so a busy Notification Center never stalls the notch.
final class NotificationWatcher: @unchecked Sendable {
    private let onLine: @Sendable (CatLine) -> Void
    private let lock = NSLock()
    private var runLoop: CFRunLoop?
    private var observer: AXObserver?
    private var stopped = false

    init(onLine: @escaping @Sendable (CatLine) -> Void) {
        self.onLine = onLine
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    func start() {
        lock.lock()
        stopped = false
        lock.unlock()
        let thread = Thread { [weak self] in self?.run() }
        thread.name = "Pixpaw notifications"
        thread.qualityOfService = .utility
        thread.start()
    }

    func stop() {
        lock.lock()
        stopped = true
        let loop = runLoop
        lock.unlock()
        if let loop {
            CFRunLoopStop(loop)
        }
    }

    private func run() {
        guard Self.isTrusted,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first
        else { return }
        let pid = app.processIdentifier
        var made: AXObserver?
        let callback: AXObserverCallback = { _, element, _, context in
            guard let context else { return }
            let watcher = Unmanaged<NotificationWatcher>.fromOpaque(context).takeUnretainedValue()
            // The banner fills in a moment after its window appears.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) {
                watcher.read(element)
            }
        }
        guard AXObserverCreate(pid, callback, &made) == .success, let observer = made else { return }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.5)
        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, context)
        AXObserverAddNotification(observer, appElement, kAXCreatedNotification as CFString, context)

        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        self.observer = observer
        runLoop = CFRunLoopGetCurrent()
        lock.unlock()

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        CFRunLoopRun()

        lock.lock()
        self.observer = nil
        runLoop = nil
        lock.unlock()
    }

    private var lastText = ""
    private var lastAt = Date.distantPast

    /// Collects the banner's text: the first piece is usually the app or the
    /// sender, the rest the message.
    private func read(_ element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, 0.5)
        var texts: [String] = []
        collect(element, into: &texts, depth: 0)
        let cleaned = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        let title = cleaned[0]
        let body = cleaned.dropFirst().prefix(2).joined(separator: " ")
        var text = body.isEmpty ? title : "\(title): \(body)"
        if text.count > 110 { text = String(text.prefix(108)) + "…" }

        lock.lock()
        let duplicate = text == lastText && Date().timeIntervalSince(lastAt) < 5
        lastText = text
        lastAt = Date()
        lock.unlock()
        guard !duplicate else { return }
        onLine(CatLine(text: text, symbol: "bell.fill"))
    }

    private func collect(_ element: AXUIElement, into texts: inout [String], depth: Int) {
        guard depth < 12, texts.count < 6 else { return }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if (role as? String) == (kAXStaticTextRole as String) {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
            if let string = value as? String, !texts.contains(string) { texts.append(string) }
        }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement] else { return }
        for child in list { collect(child, into: &texts, depth: depth + 1) }
    }
}

// MARK: - Music

/// Track changes in Apple Music and Spotify, from the distributed
/// notifications both apps post on every change, and notice anything else
/// playing: a video in a browser, another player. No permission needed.
@MainActor
final class MusicWatcher {
    private var observers: [NSObjectProtocol] = []
    private var lastTrack = ""
    private var playerPlaying = false
    private let playback = PlaybackWatcher()
    private let onLine: (CatLine) -> Void
    private let onPlaying: (Bool) -> Void

    init(onLine: @escaping (CatLine) -> Void, onPlaying: @escaping (Bool) -> Void, log: ((String) -> Void)? = nil) {
        self.onLine = onLine
        self.onPlaying = onPlaying
        playback.log = log
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            observers.append(center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] note in
                let info = note.userInfo ?? [:]
                let state = info["Player State"] as? String ?? ""
                let song = info["Name"] as? String ?? ""
                let artist = info["Artist"] as? String ?? ""
                MainActor.assumeIsolated { self?.changed(state: state, song: song, artist: artist) }
            })
        }
        playback.start { [weak self] in self?.report() }
    }

    func stop() {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        playback.stop()
        lastTrack = ""
        playerPlaying = false
        onPlaying(false)
    }

    private func changed(state: String, song: String, artist: String) {
        playerPlaying = state == "Playing"
        report()
        guard playerPlaying, !song.isEmpty else { return }
        let track = song + "\u{1}" + artist
        guard track != lastTrack else { return }
        lastTrack = track
        onLine(CatLine(text: CatWords.nowPlaying(song, artist), symbol: "music.note"))
    }

    private func report() {
        onPlaying(playerPlaying || playback.isPlaying)
    }
}

/// Whether some app is playing, from the power assertions players take to
/// keep the Mac awake while they play: "Playing audio" in Chrome and other
/// Chromium browsers, "WebKit Media Playback" in Safari, and the like in
/// other players. A browser holding the speakers open in silence, or an
/// app making keyboard clicks, takes none, so neither counts. Asked every
/// two seconds; a change has to show twice running, so a blip does nothing.
@MainActor
final class PlaybackWatcher {
    private(set) var isPlaying = false
    var log: ((String) -> Void)?
    private var timer: Timer?
    private var streak = 0
    private var onChange: (() -> Void)?

    func start(onChange: @escaping () -> Void) {
        guard timer == nil else { return }
        self.onChange = onChange
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer?.tolerance = 0.5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
        streak = 0
        isPlaying = false
    }

    private func check() {
        let player = Self.player()
        guard (player != nil) != isPlaying else { streak = 0; return }
        streak += 1
        guard streak >= 2 else { return }
        streak = 0
        isPlaying = player != nil
        log?(player.map { "playback started: \($0)" } ?? "playback stopped")
        onChange?()
    }

    /// The name of an assertion some other app holds while playing; nil
    /// when nothing is.
    private static func player() -> String? {
        var list: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&list) == kIOReturnSuccess,
              let byProcess = list?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return nil }
        let me = getpid()
        for (pid, assertions) in byProcess where pid.int32Value != me {
            for assertion in assertions {
                guard let name = assertion["AssertName"] as? String,
                      name.range(of: "playing|playback", options: [.regularExpression, .caseInsensitive]) != nil else { continue }
                // WebKit's names start with the whole service description.
                return name.split(separator: ":").last.map(String.init) ?? name
            }
        }
        return nil
    }
}

// MARK: - Screenshots

/// New screenshots, from Spotlight, which marks every one macOS saves,
/// wherever it saves them. No permission needed; a screenshot copied only to
/// the clipboard leaves no file, so it goes unnoticed.
@MainActor
final class ScreenshotWatcher {
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var lastShot = Date.distantPast
    private let onShot: () -> Void

    init(onShot: @escaping () -> Void) {
        self.onShot = onShot
    }

    func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        // Only ones taken from now on.
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 AND kMDItemContentCreationDate > %@", Date() as NSDate)
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] note in
            let added = (note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [Any])?.isEmpty == false
            guard added else { return }
            MainActor.assumeIsolated { self?.shot() }
        }
        query.start()
        self.query = query
    }

    func stop() {
        query?.stop()
        query = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func shot() {
        // A burst of them is one photo shoot.
        guard Date().timeIntervalSince(lastShot) > 10 else { return }
        lastShot = Date()
        onShot()
    }
}

// MARK: - Volume and brightness

/// The output volume (and mute) of the current speakers, from CoreAudio's
/// property listeners, and the built-in display's brightness. Each says its
/// level in one bubble that updates in place while a key is held.
@MainActor
final class LevelsWatcher {
    private let onLine: (CatLine) -> Void
    private var device = AudioObjectID(kAudioObjectUnknown)
    private var lastVolume: Int?
    private var lastMuted: Bool?
    private var brightnessTimer: Timer?
    private var lastBrightness: Float?
    private var running = false

    private let volumeListener: AudioObjectPropertyListenerBlock
    private let muteListener: AudioObjectPropertyListenerBlock
    private let deviceListener: AudioObjectPropertyListenerBlock

    init(onLine: @escaping (CatLine) -> Void) {
        self.onLine = onLine
        // Filled in below once `self` exists; CoreAudio needs the same block
        // objects to remove them later.
        var volume: AudioObjectPropertyListenerBlock = { _, _ in }
        var mute: AudioObjectPropertyListenerBlock = { _, _ in }
        var device: AudioObjectPropertyListenerBlock = { _, _ in }
        volumeListener = { a, b in volume(a, b) }
        muteListener = { a, b in mute(a, b) }
        deviceListener = { a, b in device(a, b) }
        volume = { [weak self] _, _ in MainActor.assumeIsolated { self?.readVolume(announce: true) } }
        mute = { [weak self] _, _ in MainActor.assumeIsolated { self?.readVolume(announce: true) } }
        device = { [weak self] _, _ in MainActor.assumeIsolated { self?.attachToDefaultDevice() } }
    }

    func start() {
        guard !running else { return }
        running = true
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, deviceListener)
        attachToDefaultDevice()

        // Brightness has no public change notification; a cheap read a few
        // times a second, and only a key-sized step speaks, so auto-brightness
        // drifting never does.
        lastBrightness = Self.brightness()
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.readBrightness() }
        }
        brightnessTimer?.tolerance = 0.1
    }

    func stop() {
        guard running else { return }
        running = false
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, deviceListener)
        detachFromDevice()
        brightnessTimer?.invalidate()
        brightnessTimer = nil
    }

    // MARK: Volume

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func attachToDefaultDevice() {
        detachFromDevice()
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return }
        device = id
        var volume = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(id, &volume, .main, volumeListener)
        var mute = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(id, &mute, .main, muteListener)
        // A new device has its own level; take it quietly.
        readVolume(announce: false)
    }

    private func detachFromDevice() {
        guard device != kAudioObjectUnknown else { return }
        var volume = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectRemovePropertyListenerBlock(device, &volume, .main, volumeListener)
        var mute = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectRemovePropertyListenerBlock(device, &mute, .main, muteListener)
        device = AudioObjectID(kAudioObjectUnknown)
    }

    private func readVolume(announce: Bool) {
        guard device != kAudioObjectUnknown else { return }
        var scalar = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &scalar) == noErr else { return }
        var mutedValue = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        let hasMute = AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &mutedValue) == noErr
        let muted = hasMute && mutedValue != 0
        let percent = Int((scalar * 100).rounded())

        defer {
            lastVolume = percent
            lastMuted = muted
        }
        guard announce, percent != lastVolume || muted != lastMuted else { return }
        if muted {
            onLine(CatLine(text: CatWords.muted, symbol: "speaker.slash.fill", key: "volume"))
        } else {
            let symbol = percent == 0 ? "speaker.fill" : (percent < 34 ? "speaker.wave.1.fill" : (percent < 67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"))
            onLine(CatLine(text: CatWords.volume(percent), symbol: symbol, key: "volume"))
        }
    }

    // MARK: Brightness

    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32

    /// DisplayServices is the framework the brightness keys go through; looked
    /// up at runtime, and quietly absent if a future macOS removes it.
    private static let getBrightness: GetBrightness? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    private static func brightness() -> Float? {
        guard let getBrightness else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(8, &displays, &count)
        let builtIn = displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
        var value: Float = 0
        return getBrightness(builtIn, &value) == 0 ? value : nil
    }

    private func readBrightness() {
        guard let value = Self.brightness() else { return }
        defer { lastBrightness = value }
        guard let last = lastBrightness, abs(value - last) >= 0.03 else { return }
        let percent = Int((value * 100).rounded())
        onLine(CatLine(text: CatWords.brightness(percent), symbol: value < 0.5 ? "sun.min.fill" : "sun.max.fill", key: "brightness"))
    }
}

// MARK: - Headphones

/// Headphones coming and going: AirPods and other Bluetooth or USB audio,
/// and the "External Headphones" output a MacBook adds when a cable goes in.
/// Watches CoreAudio's device list, so it needs no Bluetooth permission.
@MainActor
final class HeadphonesWatcher {
    private struct Output: Equatable {
        var name: String
        var symbol: String
    }

    private let onLine: (CatLine) -> Void
    /// Whether any headphones are connected, on start and on every change.
    private let onWearing: (Bool) -> Void
    private var known: [AudioObjectID: Output] = [:]
    private var running = false
    private let listener: AudioObjectPropertyListenerBlock

    init(onLine: @escaping (CatLine) -> Void, onWearing: @escaping (Bool) -> Void = { _ in }) {
        self.onLine = onLine
        self.onWearing = onWearing
        var changed: AudioObjectPropertyListenerBlock = { _, _ in }
        listener = { a, b in changed(a, b) }
        changed = { [weak self] _, _ in MainActor.assumeIsolated { self?.devicesChanged() } }
    }

    func start() {
        guard !running else { return }
        running = true
        known = Self.headphones()
        onWearing(!known.isEmpty)
        var address = Self.devicesAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }

    func stop() {
        guard running else { return }
        running = false
        var address = Self.devicesAddress
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        known = [:]
        onWearing(false)
    }

    private static var devicesAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func devicesChanged() {
        let now = Self.headphones()
        // A Bluetooth headset can briefly appear twice while it settles; one
        // line per name is plenty.
        let added = Set(now.filter { known[$0.key] == nil }.map(\.value.name))
        let removed = Set(known.filter { now[$0.key] == nil }.map(\.value.name)).subtracting(now.values.map(\.name))
        for name in added.sorted() {
            let symbol = now.values.first { $0.name == name }?.symbol ?? "headphones"
            onLine(CatLine(text: CatWords.connected(name), symbol: symbol))
        }
        for name in removed.sorted() {
            onLine(CatLine(text: CatWords.disconnected(name), symbol: "headphones"))
        }
        known = now
        onWearing(!now.isEmpty)
    }

    /// Output devices that are headphones of some kind, by id.
    private static func headphones() -> [AudioObjectID: Output] {
        var address = devicesAddress
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [:] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [:] }

        var result: [AudioObjectID: Output] = [:]
        for id in ids where hasOutput(id) {
            let name = string(id, kAudioObjectPropertyName) ?? "Headphones"
            let transport = uint(id, kAudioDevicePropertyTransportType)
            let lowered = name.lowercased()
            let isHeadphones: Bool
            switch transport {
            case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                isHeadphones = true
            case kAudioDeviceTransportTypeUSB:
                isHeadphones = ["headphone", "headset", "earbud", "airpods", "buds"].contains { lowered.contains($0) }
            case kAudioDeviceTransportTypeBuiltIn:
                isHeadphones = lowered.contains("headphone")
            default:
                isHeadphones = false
            }
            guard isHeadphones else { continue }
            let symbol = lowered.contains("airpods max") ? "airpodsmax"
                : lowered.contains("airpods pro") ? "airpodspro"
                : lowered.contains("airpods") ? "airpods"
                : "headphones"
            result[id] = Output(name: String(name.prefix(32)), symbol: symbol)
        }
        return result
    }

    private static func hasOutput(_ id: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func uint(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return value
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

// MARK: - Quiet

/// Notices when the cat should keep its mouth shut: a call (a microphone or
/// camera in use by any app), a screen being shared, or a display mirrored to
/// a projector. Reads device and window state every two seconds; none of it
/// needs a permission, and nothing is recorded.
@MainActor
final class QuietWatcher {
    enum Reason: String {
        case call = "in a call"
        case sharing = "sharing the screen"
        case mirroring = "mirroring the display"
    }

    private var timer: Timer?
    private let onChange: (Reason?) -> Void
    private var last: Reason?
    /// Zoom's CptHost, tracked from launch and quit notifications rather than
    /// by listing every app (each name lookup is a round trip to LaunchServices).
    private var zoomSharing = false
    private var appObservers: [NSObjectProtocol] = []
    /// Whether window titles are readable at all; without Screen Recording
    /// access they never are, so there is no point listing windows.
    private var titlesReadable: Bool?

    init(onChange: @escaping (Reason?) -> Void) {
        self.onChange = onChange
    }

    private static func isZoomShare(_ app: NSRunningApplication?) -> Bool {
        app?.bundleIdentifier?.lowercased().contains("cpthost") == true
    }

    func start() {
        guard timer == nil else { return }
        zoomSharing = NSWorkspace.shared.runningApplications.contains { Self.isZoomShare($0) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            appObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard Self.isZoomShare(app) else { return }
                let launched = note.name == NSWorkspace.didLaunchApplicationNotification
                MainActor.assumeIsolated {
                    self?.zoomSharing = launched
                    self?.check()
                }
            })
        }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer?.tolerance = 0.5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        appObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        appObservers = []
        if last != nil {
            last = nil
            onChange(nil)
        }
    }

    /// Mirroring counts only when this is on: a TV at home is not a meeting.
    var watchesMirroring = true

    func check() {
        let reason: Reason? = (zoomSharing || sharingBarIsUp()) ? .sharing
            : (Self.isMicrophoneInUse() || Self.isCameraInUse()) ? .call
            : (watchesMirroring && Self.isMirroring()) ? .mirroring
            : nil
        guard reason != last else { return }
        last = reason
        onChange(reason)
    }

    /// Any real microphone running for any app: a call, a recording,
    /// dictation. Aggregate and virtual devices are skipped: Droppy's own
    /// audio tap for the visualiser is a private aggregate that runs whenever
    /// music plays, and it is not a call.
    static func isMicrophoneInUse() -> Bool { !microphonesInUse().isEmpty }

    static func microphonesInUse() -> [String] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        var found: [String] = []
        for id in ids {
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var streamsSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamsSize) == noErr, streamsSize > 0 else { continue }
            var transportAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(id, &transportAddress, 0, nil, &transportSize, &transport)
            guard transport != kAudioDeviceTransportTypeAggregate, transport != kAudioDeviceTransportTypeVirtual,
                  transport != kAudioDeviceTransportTypeAutoAggregate, transport != 0 else { continue }
            var running = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var value: UInt32 = 0
            var valueSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &running, 0, nil, &valueSize, &value) == noErr, value != 0 {
                var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                var name: Unmanaged<CFString>?
                var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name)
                found.append((name?.takeRetainedValue() as String?) ?? "device \(id)")
            }
        }
        return found
    }

    private static func isCameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &ids) == noErr else { return false }
        for id in ids {
            var running = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            var value: UInt32 = 0
            var valueUsed: UInt32 = 0
            if CMIOObjectGetPropertyData(id, &running, 0, nil, UInt32(MemoryLayout<UInt32>.size), &valueUsed, &value) == noErr, value != 0 {
                return true
            }
        }
        return false
    }

    /// Zoom runs CptHost only while sharing; Chrome (Meet), Teams and others
    /// put up a small "is sharing your screen" bar. Window titles are only
    /// visible with Screen Recording access, so without it only Zoom counts.
    private static let sharingTitles = ["is sharing your screen", "is sharing a window", "is sharing this tab",
                                        "sharing control bar", "you're sharing", "you are sharing", "stop sharing"]

    private func sharingBarIsUp() -> Bool {
        if titlesReadable == false { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        if titlesReadable == nil {
            // Any other app's window with a title means titles come through.
            titlesReadable = info.contains {
                ($0[kCGWindowOwnerPID as String] as? Int32) != ownPID && !(($0[kCGWindowName as String] as? String) ?? "").isEmpty
            }
            if titlesReadable == false { return false }
        }
        return info.contains { window in
            guard let title = (window[kCGWindowName as String] as? String)?.lowercased(), !title.isEmpty else { return false }
            return Self.sharingTitles.contains { title.contains($0) }
        }
    }

    private static func isMirroring() -> Bool {
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(8, &displays, &count)
        return displays.prefix(Int(count)).contains { CGDisplayIsInMirrorSet($0) != 0 }
    }
}

// MARK: - Health

/// Counts the time you spend at the Mac without a break, and when it reaches
/// the interval, has the cat come over with a reminder: stretch, drink some
/// water, rest your eyes, in turn. Five minutes away counts as a break and
/// starts the count again. A reminder that falls due during a call waits
/// until the call is over.
@MainActor
final class HealthCoach {
    private static let tick: TimeInterval = 30
    private static let breakAfter: TimeInterval = 5 * 60

    var interval: TimeInterval
    /// Whether the cat may talk right now (not quiet).
    var canRemind: () -> Bool = { true }
    private let onRemind: (CatLine) -> Void
    private var timer: Timer?
    private var active: TimeInterval = 0
    private var due = false
    private var next = 0

    private static let reminders: [(String, String)] = [
        ("Time to stretch! Stand up for a minute.", "figure.cooldown"),
        ("Drink some water.", "drop.fill"),
        ("Rest your eyes: look far away for 20 seconds.", "eye"),
    ]

    init(interval: TimeInterval, onRemind: @escaping (CatLine) -> Void) {
        self.interval = interval
        self.onRemind = onRemind
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer?.tolerance = 5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        active = 0
        due = false
    }

    private func check() {
        guard let anyInput = CGEventType(rawValue: ~0) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if idle >= Self.breakAfter {
            active = 0
            due = false
        } else if idle < 120 {
            active += Self.tick
        }
        if active >= interval { due = true }
        guard due, canRemind() else { return }
        due = false
        active = 0
        let (text, symbol) = Self.reminders[next % Self.reminders.count]
        next += 1
        onRemind(CatLine(text: text, symbol: symbol, seconds: 5))
    }
}
