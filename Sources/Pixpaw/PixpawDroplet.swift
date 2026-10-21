//
//  PixpawDroplet.swift
//  Pixpaw
//

import AppKit
import Combine
import DroppyKit
import SwiftUI

/// The class Droppy's loader instantiates, named in the bundle's
/// `NSPrincipalClass`. Keep it empty: it runs before the host is ready.
@objc(PixpawPrincipal)
public final class PixpawPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { PixpawDroplet() }
}

/// Pixpaw: a pixel cat that lives on your desktop.
@MainActor
public final class PixpawDroplet: NSObject, ObservableObject, Droplet {
    /// Must equal `DroppyDropletID` in the bundle's Info.plist and `id` in
    /// droplet.json. The loader refuses the bundle if the three disagree.
    public nonisolated static let id: DropletID = "pixpaw"

    private enum Key {
        static let coat = "coat"
        static let kind = "character"
        static let festivals = "festivals"
        static let festivalGreeted = "festivalGreeted"
        static let festivalsHidden = "festivalsHidden"
        static let chases = "followsCursor"
        static let visible = "visible"
        static let pets = "pets"
        static let points = "points"
        static let starDay = "starDay"
        static let hat = "hat"
        static let collar = "collar"
        static let pinned = "showsBesideNotch"
        static let roaming = "roaming"
        static let lastFed = "lastFed"
        static let pounces = "pouncesOnDrags"
        static let chatty = "chatty"
        static let tellsNotifications = "tellsNotifications"
        static let tellsCalendar = "tellsCalendar"
        static let tellsBattery = "tellsBattery"
        static let tellsDownloads = "tellsDownloads"
        static let tellsMusic = "tellsMusic"
        static let tellsAgents = "tellsAgents"
        static let tellsLevels = "tellsLevels"
        static let tellsHeadphones = "tellsHeadphones"
        static let autoQuiet = "quietDuringCalls"
        static let quietMirroring = "quietWhenMirroring"
        static let sounds = "sounds"
        static let friend = "friend"
        static let friendCoat = "friendCoat"
        static let health = "healthReminders"
        static let healthMinutes = "healthMinutes"
    }

    private var host: DropletHost?
    private(set) var cat: CatController?
    /// The optional second cat, and its coat.
    private(set) var friend: CatController?
    @Published private(set) var hasFriend = false
    @Published private(set) var friendCoat: CatCoat = .gray
    @Published private(set) var isOut = false
    /// Whether the cat and its status get a row beside the notch. Off by
    /// default: the speech bubble already says everything.
    @Published private(set) var isPinned = false

    // What the cat tells you about, and whether Droppy may read it.
    @Published private(set) var tellsNotifications = true
    @Published private(set) var tellsCalendar = true
    @Published private(set) var tellsBattery = true
    @Published private(set) var tellsDownloads = false
    @Published private(set) var tellsMusic = true
    @Published private(set) var tellsAgents = true
    @Published private(set) var tellsLevels = true
    @Published private(set) var tellsHeadphones = true
    /// Goes quiet on its own during calls, screen sharing and mirroring.
    @Published private(set) var quietsAutomatically = true
    /// Also quiet while the display is mirrored (a projector, a TV).
    @Published private(set) var quietWhenMirroring = true
    /// Stretch, water and eye-rest reminders, and how often.
    @Published private(set) var healthOn = true
    @Published private(set) var healthMinutes = 60
    private var health: HealthCoach?

    /// Meows, purrs and chewing.
    @Published private(set) var soundsOn = true
    /// Quiet because you asked, until you ask again.
    @Published private(set) var quietByHand = false
    private var autoQuietReason: QuietWatcher.Reason?
    /// Festival decorations, only ever on the festival's own days; each one
    /// can be switched off on its own.
    @Published private(set) var festivalsOn = true
    @Published private(set) var festivalsHidden: Set<Festival> = []
    private let festivals = FestivalOverlay()
    private var festivalCheck: Timer?
    private var screenWatch: NSObjectProtocol?
    private var quiet: QuietWatcher?
    private var headphones: HeadphonesWatcher?
    private var levels: LevelsWatcher?
    /// The coding agents that reported in, by name.
    @Published private(set) var agents: [String: AgentStatus] = [:]
    private var agentSweep: Timer?
    private var music: MusicWatcher?
    @Published private(set) var notificationsAllowed = false
    @Published private(set) var calendarAllowed = false
    private var battery: BatteryWatcher?
    private var downloads: DownloadsWatcher?
    private var calendar: CalendarWatcher?
    private var notifications: NotificationWatcher?

    private let activitySubject = CurrentValueSubject<LiveActivityState?, Never>(nil)
    private var moodWatch: AnyCancellable?

    public func activate(host: DropletHost) throws {
        self.host = host
        let prefs = host.preferences
        let cat = CatController(
            kind: PetKind(rawValue: prefs.value(forKey: Key.kind, default: PetKind.cat.rawValue)) ?? .cat,
            coat: CatCoat(rawValue: prefs.value(forKey: Key.coat, default: CatCoat.orange.rawValue)) ?? .orange,
            chasesPointer: prefs.value(forKey: Key.chases, default: false),
            roaming: CatRoaming(rawValue: prefs.value(forKey: Key.roaming, default: CatRoaming.floor.rawValue)) ?? .floor,
            pouncesOnDrags: prefs.value(forKey: Key.pounces, default: true),
            chatty: prefs.value(forKey: Key.chatty, default: true),
            pets: prefs.value(forKey: Key.pets, default: 0),
            points: prefs.value(forKey: Key.points, default: 0),
            hat: CatAccessory(rawValue: prefs.value(forKey: Key.hat, default: "")),
            collar: CatAccessory(rawValue: prefs.value(forKey: Key.collar, default: "")),
            starDay: prefs.value(forKey: Key.starDay, as: StarDay.self),
            // A new cat arrives fed.
            lastFed: Date(timeIntervalSince1970: prefs.value(forKey: Key.lastFed, default: Date().timeIntervalSince1970))
        )
        cat.onPersist = { [weak self] in self?.persist() }
        let logger = host.log
        cat.log = { message in logger.debug(message) }
        self.cat = cat
        isPinned = prefs.value(forKey: Key.pinned, default: false)
        tellsNotifications = prefs.value(forKey: Key.tellsNotifications, default: true)
        tellsCalendar = prefs.value(forKey: Key.tellsCalendar, default: true)
        tellsBattery = prefs.value(forKey: Key.tellsBattery, default: true)
        // Watching Downloads can make macOS ask for folder access, so it waits
        // until it is switched on in Settings.
        tellsDownloads = prefs.value(forKey: Key.tellsDownloads, default: false)
        tellsMusic = prefs.value(forKey: Key.tellsMusic, default: true)
        tellsAgents = prefs.value(forKey: Key.tellsAgents, default: true)
        tellsLevels = prefs.value(forKey: Key.tellsLevels, default: true)
        tellsHeadphones = prefs.value(forKey: Key.tellsHeadphones, default: true)
        quietsAutomatically = prefs.value(forKey: Key.autoQuiet, default: true)
        quietWhenMirroring = prefs.value(forKey: Key.quietMirroring, default: true)
        soundsOn = prefs.value(forKey: Key.sounds, default: true)
        hasFriend = prefs.value(forKey: Key.friend, default: false)
        friendCoat = CatCoat(rawValue: prefs.value(forKey: Key.friendCoat, default: CatCoat.gray.rawValue)) ?? .gray
        healthOn = prefs.value(forKey: Key.health, default: true)
        healthMinutes = prefs.value(forKey: Key.healthMinutes, default: 60)
        // Finished and failed agents fade from the list; a working one that
        // has gone quiet for half an hour is assumed gone.
        agentSweep = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sweepAgents() }
        }
        refreshPermissionState()
        applyQuiet()
        permissionWatch = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissionState() }
        }

        // The row's title follows the mood; its flags only change when the
        // user flips the pin, so the shell never resizes on its own.
        moodWatch = cat.$mood.removeDuplicates().combineLatest(cat.$isHungry.removeDuplicates()).sink { [weak self] _ in
            // Published values arrive before they are stored; read them next turn.
            DispatchQueue.main.async { self?.publishActivity() }
        }

        host.shortcuts.register(
            id: "toggle-cat",
            title: "Show or hide the cat",
            defaultShortcut: DropletKeyboardShortcut(
                keyCode: 8, // C
                modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue
            )
        ) { [weak self] in
            self?.toggle()
        }
        host.shortcuts.register(id: "call-cat", title: "Call the cat over", defaultShortcut: nil) { [weak self] in
            self?.callOver()
        }
        host.shortcuts.register(id: "quiet-cat", title: "Turn the cat's quiet mode on or off", defaultShortcut: nil) { [weak self] in
            self?.toggleQuiet()
        }
        host.shortcuts.register(id: "feed-cat", title: "Feed the cat", defaultShortcut: nil) { [weak self] in
            self?.feed()
        }
        host.shortcuts.register(id: "nap-cat", title: "Send the cat to nap in the notch", defaultShortcut: nil) { [weak self] in
            self?.cat?.goHome()
        }

        // The harness renders surfaces to pictures; a cat walking across the
        // developer's screen there would only get in the way.
        if prefs.value(forKey: Key.visible, default: true), !host.environment.isHarness {
            setOut(true)
        }
        festivalsOn = prefs.value(forKey: Key.festivals, default: true)
        festivalsHidden = Set(prefs.value(forKey: Key.festivalsHidden, default: "").split(separator: ",")
            .compactMap { Festival(rawValue: String($0)) })
        // A minute is fine-grained enough for a festival that starts at 6 pm.
        festivalCheck = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFestival() }
        }
        screenWatch = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.festivals.refit() }
        }
        refreshFestival()
        host.log.info("Pixpaw activated")
    }

    public func deactivate() {
        festivalCheck?.invalidate()
        festivalCheck = nil
        if let screenWatch { NotificationCenter.default.removeObserver(screenWatch) }
        screenWatch = nil
        festivals.hide()
        friend?.hide()
        friend = nil
        if let permissionWatch { NSWorkspace.shared.notificationCenter.removeObserver(permissionWatch) }
        permissionWatch = nil
        stopAlerts()
        agentSweep?.invalidate()
        agentSweep = nil
        moodWatch?.cancel()
        moodWatch = nil
        activitySubject.send(nil)
        cat?.hide()
        cat = nil
        host = nil
    }

    func toggle() { setOut(!isOut) }

    func setOut(_ out: Bool) {
        guard let cat else { return }
        out ? cat.show() : cat.hide()
        isOut = cat.isVisible
        updateFriend()
        host?.preferences.setValue(isOut, forKey: Key.visible)
        publishActivity()
        refreshAlerts()
    }

    func callOver() {
        if !isOut { setOut(true) }
        cat?.callOver()
    }

    func setCoat(_ coat: CatCoat) {
        cat?.coat = coat
        persist()
    }

    /// Swaps the cat for another character, or back; the friend follows.
    func setKind(_ kind: PetKind) {
        cat?.kind = kind
        friend?.kind = kind
        persist()
    }

    /// Every character in a menu at the pointer, the current one ticked.
    func chooseKind() {
        guard let cat else { return }
        let menu = NSMenu()
        for kind in PetKind.allCases {
            let item = NSMenuItem(title: kind.title, action: #selector(pickKind(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = kind.rawValue
            item.state = kind == cat.kind ? .on : .off
            item.image = CatSprites.shared.menuImage(kind, coat: cat.coat)
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func pickKind(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let kind = PetKind(rawValue: raw) else { return }
        setKind(kind)
    }

    func setChases(_ chases: Bool) {
        cat?.chasesPointer = chases
        persist()
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        host?.preferences.setValue(pinned, forKey: Key.pinned)
        publishActivity()
    }

    func setChatty(_ chatty: Bool) {
        cat?.chatty = chatty
        host?.preferences.setValue(chatty, forKey: Key.chatty)
    }

    func setTells(
        notifications: Bool? = nil, calendar: Bool? = nil, battery: Bool? = nil,
        downloads: Bool? = nil, music: Bool? = nil, agents: Bool? = nil, levels: Bool? = nil,
        headphones: Bool? = nil
    ) {
        if let headphones { tellsHeadphones = headphones; host?.preferences.setValue(headphones, forKey: Key.tellsHeadphones) }
        if let levels { tellsLevels = levels; host?.preferences.setValue(levels, forKey: Key.tellsLevels) }
        if let music { tellsMusic = music; host?.preferences.setValue(music, forKey: Key.tellsMusic) }
        if let agents { tellsAgents = agents; host?.preferences.setValue(agents, forKey: Key.tellsAgents) }
        if let notifications { tellsNotifications = notifications; host?.preferences.setValue(notifications, forKey: Key.tellsNotifications) }
        if let calendar { tellsCalendar = calendar; host?.preferences.setValue(calendar, forKey: Key.tellsCalendar) }
        if let battery { tellsBattery = battery; host?.preferences.setValue(battery, forKey: Key.tellsBattery) }
        if let downloads { tellsDownloads = downloads; host?.preferences.setValue(downloads, forKey: Key.tellsDownloads) }
        refreshAlerts()
    }

    // MARK: Quiet

    func toggleQuiet() { setQuietByHand(!quietByHand) }

    func setQuietByHand(_ on: Bool) {
        quietByHand = on
        applyQuiet()
    }

    func setQuietWhenMirroring(_ on: Bool) {
        quietWhenMirroring = on
        host?.preferences.setValue(on, forKey: Key.quietMirroring)
        quiet?.watchesMirroring = on
        quiet?.check()
    }

    func setQuietsAutomatically(_ on: Bool) {
        quietsAutomatically = on
        host?.preferences.setValue(on, forKey: Key.autoQuiet)
        refreshAlerts()
        applyQuiet()
    }

    private func applyQuiet() {
        let reason: String? = quietByHand ? "turned on by you"
            : (quietsAutomatically ? autoQuietReason?.rawValue : nil)
        cat?.setQuiet(reason)
        friend?.setQuiet(reason)
        // A quiet cat makes no sound either.
        CatSounds.shared.isEnabled = soundsOn && reason == nil
        refreshFestival()
    }

    // MARK: Festivals

    func setFestivals(_ on: Bool) {
        festivalsOn = on
        host?.preferences.setValue(on, forKey: Key.festivals)
        refreshFestival()
    }

    func setFestival(_ festival: Festival, shown: Bool) {
        if shown { festivalsHidden.remove(festival) } else { festivalsHidden.insert(festival) }
        host?.preferences.setValue(festivalsHidden.map(\.rawValue).sorted().joined(separator: ","), forKey: Key.festivalsHidden)
        refreshFestival()
    }

    /// Puts up today's festival, takes it down when it is over, and keeps the
    /// screen clear during calls and screen sharing.
    private func refreshFestival() {
        guard let host, !host.environment.isHarness else { return }
        // Only ever the real date: there is no way to call a festival early.
        guard festivalsOn, let today = Festival.current(), !festivalsHidden.contains(today),
              autoQuietReason == nil || !quietsAutomatically else {
            festivals.hide()
            return
        }
        festivals.show(today)
        // Greets it once, the first time it is up that day and the pet is
        // out to say so.
        let stamp = "\(today.rawValue) \(StarDay.today)"
        if isOut, !quietByHand, host.preferences.value(forKey: Key.festivalGreeted, default: "") != stamp {
            host.preferences.setValue(stamp, forKey: Key.festivalGreeted)
            cat?.say(today.greeting)
        }
    }

    func setHealth(on: Bool? = nil, minutes: Int? = nil) {
        if let on { healthOn = on; host?.preferences.setValue(on, forKey: Key.health) }
        if let minutes { healthMinutes = minutes; host?.preferences.setValue(minutes, forKey: Key.healthMinutes) }
        health?.interval = TimeInterval(healthMinutes * 60)
        refreshAlerts()
    }

    func setSounds(_ on: Bool) {
        soundsOn = on
        host?.preferences.setValue(on, forKey: Key.sounds)
        applyQuiet()
    }

    /// Re-reads what Droppy has been granted, for the settings pane.
    func refreshPermissionState() {
        let notifications = NotificationWatcher.isTrusted
        let hostCalendar = host?.permissions.status(for: .calendars)
        CalendarWatcher.hostGranted = hostCalendar == .granted
        let calendar = CalendarWatcher.hasAccess
        let seen = "Droppy says \(String(describing: hostCalendar)), EventKit says \(CalendarWatcher.eventKitStatus)"
        if seen != lastCalendarSeen {
            lastCalendarSeen = seen
            host?.log.info("calendar access: \(seen)")
        }
        if notifications != notificationsAllowed || calendar != calendarAllowed {
            notificationsAllowed = notifications
            calendarAllowed = calendar
            refreshAlerts()
        }
    }

    /// Asks through Droppy, which owns the system prompt.
    private var permissionWatch: NSObjectProtocol?
    private var lastCalendarSeen = ""

    func requestPermission(_ permission: DropletPermission) {
        guard let host else { return }
        Task { @MainActor [weak self] in
            let status = await host.permissions.request(permission)
            host.log.info("asked for \(String(describing: permission)): \(String(describing: status))")
            if status == .denied { host.permissions.openSystemSettings(for: permission) }
            self?.refreshPermissionState()
            // The answer can come later than the request: a system prompt
            // still up, or a switch flipped in System Settings. Look again
            // every second for two minutes, and stop as soon as it is granted.
            for _ in 0..<120 {
                guard let self, !self.isGranted(permission) else { break }
                try? await Task.sleep(for: .seconds(1))
                self.refreshPermissionState()
            }
        }
    }

    private func isGranted(_ permission: DropletPermission) -> Bool {
        switch permission {
        case .calendars: calendarAllowed
        case .accessibility: notificationsAllowed
        default: true
        }
    }

    /// Starts the sources that are on, allowed, and have a cat to talk through;
    /// stops the rest.
    private func refreshAlerts() {
        guard let cat, let host, !host.environment.isHarness else { return }
        let say: @MainActor (CatLine) -> Void = { [weak cat] line in cat?.say(line) }
        // The level you are changing yourself still shows while quiet.
        let sayEssential: @MainActor (CatLine) -> Void = { [weak cat] line in cat?.say(line, essential: true) }
        let out = isOut

        if out, quietsAutomatically {
            if quiet == nil {
                quiet = QuietWatcher { [weak self] reason in
                    self?.autoQuietReason = reason
                    self?.applyQuiet()
                }
            }
            quiet?.watchesMirroring = quietWhenMirroring
            quiet?.start()
        } else {
            quiet?.stop()
        }

        if out, tellsBattery {
            if battery == nil { battery = BatteryWatcher(onLine: say) }
            battery?.start()
        } else {
            battery?.stop()
        }
        if out, tellsDownloads {
            if downloads == nil { downloads = DownloadsWatcher(onLine: say) }
            downloads?.start()
        } else {
            downloads?.stop()
        }
        if out, healthOn {
            if health == nil {
                let coach = HealthCoach(interval: TimeInterval(healthMinutes * 60)) { [weak cat] line in
                    // Comes over to you, then says it.
                    cat?.callOver()
                    cat?.say(line)
                }
                coach.canRemind = { [weak cat] in cat?.quietReason == nil }
                health = coach
            }
            health?.start()
        } else {
            health?.stop()
        }
        if out, tellsHeadphones {
            if headphones == nil {
                headphones = HeadphonesWatcher(onLine: say, onWearing: { [weak cat] on in
                    if cat?.wearsHeadphones != on { cat?.wearsHeadphones = on }
                })
            }
            headphones?.start()
        } else {
            headphones?.stop()
        }
        if out, tellsLevels {
            if levels == nil { levels = LevelsWatcher(onLine: sayEssential) }
            levels?.start()
        } else {
            levels?.stop()
        }
        if out, tellsMusic {
            if music == nil {
                // A new song names itself and starts the cat dancing again.
                music = MusicWatcher(onLine: { [weak cat] line in say(line); cat?.dance() }, onPlaying: { [weak cat] playing in
                    if cat?.musicPlaying != playing { cat?.musicPlaying = playing }
                })
            }
            music?.start()
        } else {
            music?.stop()
        }
        if out, tellsCalendar, calendarAllowed {
            if calendar == nil { calendar = CalendarWatcher(onLine: say) }
            calendar?.start()
        } else {
            calendar?.stop()
        }
        if out, tellsNotifications, notificationsAllowed {
            if notifications == nil {
                let watcher = NotificationWatcher { line in
                    DispatchQueue.main.async { MainActor.assumeIsolated { say(line) } }
                }
                notifications = watcher
                watcher.start()
            }
        } else {
            notifications?.stop()
            notifications = nil
        }
    }

    private func stopAlerts() {
        health?.stop()
        health = nil
        quiet?.stop()
        quiet = nil
        headphones?.stop()
        headphones = nil
        levels?.stop()
        levels = nil
        music?.stop()
        music = nil
        battery?.stop()
        downloads?.stop()
        calendar?.stop()
        notifications?.stop()
        battery = nil
        downloads = nil
        calendar = nil
        notifications = nil
    }

    // MARK: Coding agents

    /// One report from a coding agent's hook: `working`, `done`, `waiting`
    /// (it needs you) or `error`, with an optional line of text.
    func agentEvent(name rawName: String, state rawState: String, text: String?, usage: String? = nil) {
        guard tellsAgents else { return }
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !name.isEmpty, let state = AgentStatus.State(rawValue: rawState.lowercased()) else { return }
        let previous = agents[name]?.state
        agents[name] = AgentStatus(name: name, state: state, at: Date())
        publishActivity()
        guard previous != state else { return }

        let detail = text.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(90)) }.flatMap { $0.isEmpty ? nil : $0 }
        switch state {
        case .working:
            cat?.say(CatLine(text: CatWords.agentWorking(name), symbol: "sparkles"))
        case .done:
            // Done, and how much of the plan is left, e.g. "5h 76% · week 59% left".
            let left = usage.map { String($0.prefix(40)) }.flatMap { $0.isEmpty ? nil : $0 }
            cat?.say(CatLine(text: left.map { "\(CatWords.agentDone(name)) \($0)" } ?? CatWords.agentDone(name), symbol: "checkmark.circle.fill"))
            cat?.celebrate()
        case .waiting:
            cat?.say(CatLine(text: detail.map { "\(CatWords.agentWaiting(name)): \($0)" } ?? CatWords.agentWaiting(name), symbol: "hand.raised.fill"))
            // Comes over to get your attention.
            cat?.callOver()
        case .error:
            cat?.say(CatLine(text: CatWords.agentFailed(name), symbol: "exclamationmark.triangle.fill"))
        }
    }

    private func sweepAgents() {
        let now = Date()
        let kept = agents.filter { _, agent in
            switch agent.state {
            case .working, .waiting: now.timeIntervalSince(agent.at) < 30 * 60
            case .done, .error: now.timeIntervalSince(agent.at) < 90
            }
        }
        if kept.count != agents.count {
            agents = kept
            publishActivity()
        }
    }

    /// "Claude Code working · Codex done", busiest first.
    var agentSummary: String? {
        let order: [AgentStatus.State] = [.waiting, .working, .error, .done]
        let sorted = agents.values.sorted {
            (order.firstIndex(of: $0.state) ?? 9, $0.name) < (order.firstIndex(of: $1.state) ?? 9, $1.name)
        }
        guard !sorted.isEmpty else { return nil }
        return sorted.prefix(3).map { "\($0.name) \($0.state.title)" }.joined(separator: " · ")
    }

    /// Short enough for the wing: the agent that most needs attention.
    var agentShortStatus: String? {
        if let waiting = agents.values.first(where: { $0.state == .waiting }) { return "\(waiting.name.prefix(8)) ✋" }
        let working = agents.values.filter { $0.state == .working }
        if working.count > 1 { return "\(working.count) AIs…" }
        if let one = working.first { return "\(one.name.prefix(8))…" }
        return nil
    }

    /// Puts on (or takes off, with nil) something already unlocked.
    func wear(_ item: CatAccessory?, in slot: CatAccessory.Slot) {
        cat?.wear(item, in: slot)
    }

    // MARK: Friend

    func setFriend(_ on: Bool) {
        hasFriend = on
        host?.preferences.setValue(on, forKey: Key.friend)
        updateFriend()
    }

    func setFriendCoat(_ coat: CatCoat) {
        friendCoat = coat
        host?.preferences.setValue(coat.rawValue, forKey: Key.friendCoat)
        friend?.coat = coat
    }

    /// Lets the friend out alongside the cat, or brings it in. It shares the
    /// cat's habits, never talks, and its happiness counts for the cat.
    private func updateFriend() {
        guard let cat, let host, !host.environment.isHarness, isOut, hasFriend else {
            friend?.hide()
            friend = nil
            cat?.buddy = nil
            return
        }
        if friend == nil {
            let friend = CatController(
                kind: cat.kind, coat: friendCoat, chasesPointer: cat.chasesPointer, roaming: cat.roaming,
                pouncesOnDrags: cat.pouncesOnDrags, chatty: false, pets: 0, lastFed: cat.lastFed
            )
            friend.isFriend = true
            friend.forwardAward = { [weak cat] source in cat?.earn(source) }
            friend.buddy = cat
            cat.buddy = friend
            self.friend = friend
        }
        friend?.show()
        friend?.setQuiet(cat.quietReason)
    }

    /// Keeps the friend's habits in step with the cat's settings.
    private func syncFriend() {
        guard let cat, let friend else { return }
        friend.roaming = cat.roaming
        friend.chasesPointer = cat.chasesPointer
        friend.pouncesOnDrags = cat.pouncesOnDrags
    }

    func setPounces(_ pounces: Bool) {
        cat?.pouncesOnDrags = pounces
        persist()
    }

    func setRoaming(_ roaming: CatRoaming) {
        cat?.roaming = roaming
        persist()
    }

    func feed() {
        if !isOut { setOut(true) }
        cat?.feed()
    }

    func napNow() {
        if !isOut { setOut(true) }
        cat?.goHome()
    }

    private func publishActivity() {
        // Indoors, or the row switched off: nothing beside the notch.
        guard isOut, isPinned, let cat else {
            activitySubject.send(nil)
            return
        }
        activitySubject.send(
            LiveActivityState(
                priority: 50,
                accessibilityTitle: "Pixpaw: \(agentSummary ?? cat.statusTitle)",
                isInteractive: false,
                joinsPersistentActivitySet: true
            )
        )
    }

    private func persist() {
        syncFriend()
        guard let cat, let prefs = host?.preferences else { return }
        prefs.setValue(cat.coat.rawValue, forKey: Key.coat)
        prefs.setValue(cat.kind.rawValue, forKey: Key.kind)
        prefs.setValue(cat.chasesPointer, forKey: Key.chases)
        prefs.setValue(cat.pets, forKey: Key.pets)
        prefs.setValue(cat.points, forKey: Key.points)
        prefs.setValue(cat.starDay, forKey: Key.starDay)
        prefs.setValue(cat.hat?.rawValue ?? "", forKey: Key.hat)
        prefs.setValue(cat.collar?.rawValue ?? "", forKey: Key.collar)
        prefs.setValue(cat.roaming.rawValue, forKey: Key.roaming)
        prefs.setValue(cat.pouncesOnDrags, forKey: Key.pounces)
        prefs.setValue(cat.lastFed.timeIntervalSince1970, forKey: Key.lastFed)
    }
}

// MARK: - Shelf widget

extension PixpawDroplet: ShelfWidgetProviding {
    public var widgetDescriptors: [ShelfWidgetDescriptor] {
        [
            ShelfWidgetDescriptor(
                id: "pixpaw",
                title: "Pixpaw",
                systemImage: "pawprint.fill",
                layoutTraits: ShelfWidgetLayoutTraits(
                    preferredSoloWidth: 420,
                    preferredPairedWidth: 210,
                    contentHeight: .fixed(140)
                )
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        guard let cat else { return AnyView(EmptyView()) }
        return AnyView(PixpawWidget(droplet: self, cat: cat, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? { nil }
}

private struct PixpawWidget: View {
    @ObservedObject var droplet: PixpawDroplet
    @ObservedObject var cat: CatController
    let context: ShelfWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            header
            HStack(alignment: .center, spacing: DroppySpacing.md) {
                portrait
                VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                    Text(droplet.isOut ? cat.statusTitle : "Indoors")
                        .font(.system(size: context.isCompact ? 15 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                        .lineLimit(1)
                    Text(cat.quietReason.map { "\(Image(systemName: "bell.slash.fill")) Quiet, \($0)" } ?? pointsLine)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    fullnessBar
                    if let summary = droplet.agentSummary {
                        Text("\(Image(systemName: "sparkles")) \(summary)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            if !context.isCompact {
                controls
            }
            Spacer(minLength: 0)
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 12, weight: .medium))
            Text("Pixpaw")
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Button {
                droplet.chooseKind()
            } label: {
                if let face = CatSprites.shared.image(.sit, coat: cat.coat, kind: cat.kind) {
                    Image(decorative: face, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 12)
                } else {
                    Image(systemName: "pawprint")
                }
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 20))
            .help("Character: \(cat.kind.title). Click to change.")
            .accessibilityLabel("Change character, now \(cat.kind.title)")
            Button {
                droplet.toggleQuiet()
            } label: {
                Image(systemName: cat.quietReason == nil ? "bell" : "bell.slash.fill")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 20))
            .help(droplet.quietByHand ? "Let the cat talk again" : "Quiet: no speech bubbles")
            .accessibilityLabel(droplet.quietByHand ? "Turn quiet mode off" : "Turn quiet mode on")
            Button {
                droplet.toggle()
            } label: {
                Image(systemName: droplet.isOut ? "eye.slash" : "eye")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 20))
            .help(droplet.isOut ? "Bring the cat inside" : "Let the cat out")
            .accessibilityLabel(droplet.isOut ? "Hide the cat" : "Show the cat")
        }
        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
    }

    private var portrait: some View {
        let frame: CatFrame = droplet.isOut ? cat.frame : .sleep1
        return Group {
            if let image = CatSprites.shared.image(frame, coat: cat.coat, hat: cat.hat, collar: cat.collar,
                                                   headphones: droplet.isOut && cat.wearsHeadphones, kind: cat.kind) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: cat.facesRight ? 1 : -1, y: 1)
            }
        }
        .frame(width: CatSprites.catSize.width, height: CatSprites.catSize.height)
        .accessibilityHidden(true)
    }

    /// "★ 37 · next: Bow at 45"
    private var pointsLine: String {
        let today = cat.starDay.day == StarDay.today ? cat.starDay.stars : 0
        guard let next = CatAccessory.next(after: cat.points) else { return "★ \(cat.points) · \(today)/\(StarSource.dailyTotal) today" }
        return "★ \(cat.points) · \(today)/\(StarSource.dailyTotal) today · \(next.title) at \(next.unlockAt)"
    }

    /// How full the cat is; amber once it is hungry.
    private var fullnessBar: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: "fork.knife")
                .font(.system(size: 10, weight: .semibold))
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AdaptiveColors.notchSurfaceCardFill)
                Capsule(style: .continuous)
                    .fill(cat.isHungry ? Color.orange : Color.green.opacity(0.85))
                    .frame(width: 72 * max(0.06, cat.fullness))
            }
            .frame(width: 72, height: 5)
        }
        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
        .accessibilityElement()
        .accessibilityLabel("Fullness \(Int(cat.fullness * 100)) percent")
    }

    private var controls: some View {
        HStack(spacing: DroppySpacing.sm) {
            ForEach(cat.kind.hasCoats ? CatCoat.allCases : []) { coat in
                Button {
                    droplet.setCoat(coat)
                } label: {
                    Circle()
                        .fill(Color(nsColor: coat.swatch))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if coat == cat.coat {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(coat == .black ? Color.white : Color.black.opacity(0.7))
                            }
                        }
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 24))
                .help(coat.title)
                .accessibilityLabel(coat.title)
            }
            Spacer(minLength: 0)
            Button {
                droplet.feed()
            } label: {
                Image(systemName: "fork.knife")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 24))
            .help("Feed the cat")
            .accessibilityLabel("Feed the cat")
            Button {
                droplet.napNow()
            } label: {
                Image(systemName: "moon.zzz.fill")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 24))
            .disabled(cat.mood == .sleeping)
            .help("Nap now")
            .accessibilityLabel("Nap now")
            Button(cat.mood == .sleeping ? "Wake up" : "Come here") {
                droplet.callOver()
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
        }
        .droppyFlatGlassControls()
    }
}

// MARK: - Live activity

extension PixpawDroplet: LiveActivityProviding {
    public var liveActivityState: AnyPublisher<LiveActivityState?, Never> {
        activitySubject.eraseToAnyPublisher()
    }

    /// The cat itself, at wing size: curled up asleep while it is home in the
    /// notch, otherwise doing whatever it is doing on the desktop.
    public func makeCompactLeading() -> AnyView {
        guard let cat else { return AnyView(EmptyView()) }
        return AnyView(CatWingPortrait(cat: cat))
    }

    public func makeCompactTrailing() -> AnyView {
        guard let cat else { return AnyView(EmptyView()) }
        return AnyView(CatWingMood(droplet: self, cat: cat))
    }

    /// Not mounted by Droppy; hovering the row opens the shelf widget instead.
    public func makeExpanded(context: LiveActivityContext) -> AnyView {
        AnyView(EmptyView())
    }

    public func makeCompanionCompact(context: CompactLiveActivityContext) -> AnyView {
        guard let cat else { return AnyView(EmptyView()) }
        return AnyView(CatWingPortrait(cat: cat))
    }
}

private struct CatWingPortrait: View {
    @ObservedObject var cat: CatController

    var body: some View {
        Group {
            if let image = CatSprites.shared.image(cat.frame, coat: cat.coat, hat: cat.hat, collar: cat.collar,
                                                   headphones: cat.wearsHeadphones, kind: cat.kind) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: cat.facesRight ? 1 : -1, y: 1)
            }
        }
        // 20 × 16 art at 1.25 points a pixel fits the 37pt row with room above and below.
        .frame(width: 25, height: 20)
        .accessibilityHidden(true)
    }
}

private struct CatWingMood: View {
    @ObservedObject var droplet: PixpawDroplet
    @ObservedObject var cat: CatController

    private var label: String { droplet.agentShortStatus ?? cat.statusShortTitle }

    var body: some View {
        Text(label)
            .id(label)
            .transition(DroppyTransition.compactContent)
            .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .medium, design: .rounded))
            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            .lineLimit(1)
            .accessibilityLabel(cat.statusTitle)
    }
}

// MARK: - Settings pane

extension PixpawDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        guard let cat else { return AnyView(EmptyView()) }
        return AnyView(PixpawSettings(droplet: self, cat: cat))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: "A second cat", keywords: ["cat", "friend", "two", "companion"]),
            SettingsSearchEntry(title: "Wardrobe", keywords: ["cat", "hat", "collar", "points", "happiness", "unlock"]),
            SettingsSearchEntry(title: "Festival decorations", keywords: ["festival", "halloween", "new year", "christmas", "songkran", "valentine", "fireworks", "ghost", "snow"]),
            SettingsSearchEntry(title: "Break reminders", keywords: ["cat", "health", "stretch", "water", "eyes", "break"]),
            SettingsSearchEntry(title: "Sounds", keywords: ["cat", "meow", "purr", "sound", "mute"]),
            SettingsSearchEntry(title: "Character", keywords: ["cat", "bee", "parrot", "bird", "dinosaur", "dino", "dog", "puppy", "hamster", "chicken", "hen", "pet", "character", "animal"]),
            SettingsSearchEntry(title: "Where the cat walks", keywords: ["cat", "roam", "windows", "bottom", "screen"]),
            SettingsSearchEntry(title: "Follow the cursor", keywords: ["cat", "chase", "pointer", "mouse"]),
            SettingsSearchEntry(title: "Pounce on dragged files", keywords: ["cat", "drag", "file", "pounce", "play"]),
            SettingsSearchEntry(title: "Quiet during calls and screen sharing", keywords: ["cat", "quiet", "meeting", "privacy", "share", "zoom"]),
            SettingsSearchEntry(title: "Mac notifications", keywords: ["cat", "speech", "bubble", "alert", "banner"]),
            SettingsSearchEntry(title: "Calendar events", keywords: ["cat", "meeting", "reminder"]),
            SettingsSearchEntry(title: "Volume and brightness", keywords: ["cat", "sound", "volume", "mute", "brightness", "screen"]),
            SettingsSearchEntry(title: "Headphones", keywords: ["cat", "airpods", "bluetooth", "headset", "connect"]),
            SettingsSearchEntry(title: "Song changes", keywords: ["cat", "music", "spotify", "now playing"]),
            SettingsSearchEntry(title: "AI agents", keywords: ["cat", "claude", "codex", "cursor", "agent"]),
            SettingsSearchEntry(title: "Show beside the notch", keywords: ["cat", "live activity", "status", "notch"]),
        ]
    }
}

private struct PixpawSettings: View {
    @ObservedObject var droplet: PixpawDroplet
    @ObservedObject var cat: CatController
    /// Access granted in System Settings shows up here without reopening.
    private let recheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        pane
            .onAppear { droplet.refreshPermissionState() }
            .onReceive(recheck) { _ in droplet.refreshPermissionState() }
    }

    private var pane: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Show the cat",
                    subtitle: "Lets the cat out onto your desktop. Control-Option-C does the same.",
                    isOn: Binding(get: { droplet.isOut }, set: { droplet.setOut($0) })
                )
                DropletGroupedPickerRow(
                    title: "Character",
                    subtitle: "Who lives on your desktop. More friends are on the way."
                ) {
                    Picker("Character", selection: Binding(get: { cat.kind }, set: { droplet.setKind($0) })) {
                        ForEach(PetKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletGroupedPickerRow(
                    title: "Where the cat walks",
                    subtitle: "Bottom and on windows lets it jump onto the top edges of the windows you have open, and ride along when you move one. The bee flies anywhere; the parrot perches here and flies between perches."
                ) {
                    Picker("Where the cat walks", selection: Binding(get: { cat.roaming }, set: { droplet.setRoaming($0) })) {
                        ForEach(CatRoaming.allCases) { roaming in
                            Text(roaming.title).tag(roaming)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletToggleRow(
                    title: "Sounds",
                    subtitle: "A meow when the cat talks, a purr when you pet it, crunching while it eats. Silent while quiet.",
                    isOn: Binding(get: { droplet.soundsOn }, set: { droplet.setSounds($0) })
                )
                DropletToggleRow(
                    title: "Follow the cursor",
                    subtitle: "The cat runs after your pointer whenever it moves far away. Off, it just wanders.",
                    isOn: Binding(get: { cat.chasesPointer }, set: { droplet.setChases($0) })
                )
                DropletToggleRow(
                    title: "Pounce on dragged files",
                    subtitle: "Drag a file anywhere and the cat stalks it, crouches and pounces. Dropping still works: the cat never gets in the way.",
                    isOn: Binding(get: { cat.pouncesOnDrags }, set: { droplet.setPounces($0) })
                )
            }

            DropletSettingsSection {
                VStack(alignment: .leading, spacing: 2) {
                    settingsSectionHeader("Speech bubble")
                    Text("The cat says it in a bubble over its head, or under the notch while it naps.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } content: {
                DropletSettingsCard {
                    DropletToggleRow(
                        title: "Quiet during calls and screen sharing",
                        subtitle: "No bubbles while a microphone or camera is in use or a screen is shared, so private messages never show up in a meeting. Volume and brightness still show.",
                        isOn: Binding(get: { droplet.quietsAutomatically }, set: { droplet.setQuietsAutomatically($0) })
                    )
                    if droplet.quietsAutomatically {
                        DropletToggleRow(
                            title: "Also quiet while mirroring",
                            subtitle: "When the display is mirrored to a projector or a TV. Turn off if you mirror to a TV at home and want the cat to keep talking.",
                            isOn: Binding(get: { droplet.quietWhenMirroring }, set: { droplet.setQuietWhenMirroring($0) })
                        )
                    }
                    DropletToggleRow(
                        title: "Talks about itself",
                        subtitle: "Hungry, full, sleepy, awake, and a word when it catches a file.",
                        isOn: Binding(get: { cat.chatty }, set: { droplet.setChatty($0) })
                    )
                    DropletToggleRow(
                        title: "Mac notifications",
                        subtitle: "Reads out the banners other apps show. Droppy reads them with Accessibility; nothing is kept.",
                        isOn: Binding(get: { droplet.tellsNotifications }, set: { droplet.setTells(notifications: $0) })
                    )
                    if droplet.tellsNotifications, !droplet.notificationsAllowed {
                        DropletControlRow(title: "Accessibility access") {
                            Button("Allow…") { droplet.requestPermission(.accessibility) }
                        }
                    }
                    DropletToggleRow(
                        title: "Calendar events",
                        subtitle: "A heads-up five minutes before each event.",
                        isOn: Binding(get: { droplet.tellsCalendar }, set: { droplet.setTells(calendar: $0) })
                    )
                    if droplet.tellsCalendar, !droplet.calendarAllowed {
                        DropletControlRow(title: "Calendar access") {
                            Button("Allow…") { droplet.requestPermission(.calendars) }
                        }
                    }
                    DropletToggleRow(
                        title: "Battery",
                        subtitle: "Low battery at 20% and 10%, plugging in, and a full charge.",
                        isOn: Binding(get: { droplet.tellsBattery }, set: { droplet.setTells(battery: $0) })
                    )
                    DropletToggleRow(
                        title: "Volume and brightness",
                        subtitle: "Says the new level when you turn the sound or the screen up or down, in one bubble that updates as you hold the key.",
                        isOn: Binding(get: { droplet.tellsLevels }, set: { droplet.setTells(levels: $0) })
                    )
                    DropletToggleRow(
                        title: "Headphones",
                        subtitle: "When AirPods or other headphones connect or disconnect. The cat wears a pair while yours are on.",
                        isOn: Binding(get: { droplet.tellsHeadphones }, set: { droplet.setTells(headphones: $0) })
                    )
                    DropletToggleRow(
                        title: "Song changes",
                        subtitle: "Names each new song in Apple Music or Spotify, and dances while it plays.",
                        isOn: Binding(get: { droplet.tellsMusic }, set: { droplet.setTells(music: $0) })
                    )
                    DropletToggleRow(
                        title: "AI agents",
                        subtitle: "Claude Code, Codex, Cursor and others report through hooks that open droppy://droplet/pixpaw/agent?name=…&state=working|done|waiting|error.",
                        isOn: Binding(get: { droplet.tellsAgents }, set: { droplet.setTells(agents: $0) })
                    )
                    DropletToggleRow(
                        title: "Finished downloads",
                        subtitle: "When a file lands in Downloads. macOS may ask Droppy for access to the folder.",
                        isOn: Binding(get: { droplet.tellsDownloads }, set: { droplet.setTells(downloads: $0) })
                    )
                }
            }

            DropletSettingsSection {
                VStack(alignment: .leading, spacing: 2) {
                    settingsSectionHeader("Wardrobe")
                    Text("Petting (+1, up to 10 a day), meals (+3, +5 when hungry, 3 a day), play (+5, 3 a day) and catches (+2, 5 a day) earn up to 30 happiness points a day, which unlock things to wear.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } content: {
                DropletSettingsCard {
                    DropletControlRow(title: "Happiness") {
                        DropletValuePill(text: "\(cat.points) ★")
                    }
                    DropletControlRow(title: "Earned today") {
                        DropletValuePill(text: "\(cat.starDay.day == StarDay.today ? cat.starDay.stars : 0) / \(StarSource.dailyTotal)")
                    }
                    DropletGroupedPickerRow(title: "Hat") {
                        Picker("Hat", selection: Binding(get: { cat.hat }, set: { droplet.wear($0, in: .hat) })) {
                            Text("None").tag(CatAccessory?.none)
                            ForEach(CatAccessory.unlocked(at: cat.points).filter { $0.slot == .hat }) { item in
                                Text(item.title).tag(CatAccessory?.some(item))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    if cat.kind.wearsCollars {
                        DropletGroupedPickerRow(title: "Collar") {
                            Picker("Collar", selection: Binding(get: { cat.collar }, set: { droplet.wear($0, in: .collar) })) {
                                Text("None").tag(CatAccessory?.none)
                                ForEach(CatAccessory.unlocked(at: cat.points).filter { $0.slot == .collar }) { item in
                                    Text(item.title).tag(CatAccessory?.some(item))
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                    if let next = CatAccessory.next(after: cat.points) {
                        DropletControlRow(title: "Next: \(next.title)") {
                            DropletValuePill(text: "\(next.unlockAt - cat.points) ★ to go")
                        }
                    }
                }
            }

            DropletSettingsSection {
                settingsSectionHeader("Friend")
            } content: {
                DropletSettingsCard {
                    DropletToggleRow(
                        title: "A second cat",
                        subtitle: "A friend that roams with your cat, sits with it and plays tag. It never talks, and its happiness counts for your cat.",
                        isOn: Binding(get: { droplet.hasFriend }, set: { droplet.setFriend($0) })
                    )
                    if cat.kind.hasCoats {
                        DropletGroupedPickerRow(title: "Friend's coat") {
                            Picker("Friend's coat", selection: Binding(get: { droplet.friendCoat }, set: { droplet.setFriendCoat($0) })) {
                                ForEach(CatCoat.allCases) { coat in
                                    Text(coat.title).tag(coat)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }
            }

            DropletSettingsSection {
                settingsSectionHeader("Health")
            } content: {
                DropletSettingsCard {
                    DropletToggleRow(
                        title: "Break reminders",
                        subtitle: "After a stretch at the Mac without a break, the cat comes over to remind you to stand up, drink some water or rest your eyes. Five minutes away counts as a break; never during a call.",
                        isOn: Binding(get: { droplet.healthOn }, set: { droplet.setHealth(on: $0) })
                    )
                    DropletGroupedPickerRow(title: "Remind me every") {
                        Picker("Remind me every", selection: Binding(get: { droplet.healthMinutes }, set: { droplet.setHealth(minutes: $0) })) {
                            ForEach([30, 45, 60, 90], id: \.self) { minutes in
                                Text("\(minutes) minutes").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }

            DropletSettingsSection {
                settingsSectionHeader("Festivals")
            } content: {
                DropletSettingsCard {
                    DropletToggleRow(
                        title: "Festival decorations",
                        subtitle: "On a festival's own days the screen joins in, then clears when the day is over. Never during calls or screen sharing.",
                        isOn: Binding(get: { droplet.festivalsOn }, set: { droplet.setFestivals($0) })
                    )
                    ForEach(Festival.allCases) { festival in
                        DropletToggleRow(
                            title: festival.title,
                            subtitle: "\(festival.when): \(festival.decoration).",
                            isOn: Binding(get: { !droplet.festivalsHidden.contains(festival) },
                                          set: { droplet.setFestival(festival, shown: $0) })
                        )
                        .disabled(!droplet.festivalsOn)
                    }
                }
            }

            DropletSettingsSection {
                settingsSectionHeader("Notch")
            } content: {
                DropletSettingsCard {
                    DropletToggleRow(
                        title: "Show beside the notch",
                        subtitle: "A row beside the notch with a little cat and what it, or your AI agents, are up to.",
                        isOn: Binding(get: { droplet.isPinned }, set: { droplet.setPinned($0) })
                    )
                }
            }
        }
    }
}

// MARK: - URLs

/// `droppy://droplet/pixpaw/<action>` (or `droppy-playground://…` in the
/// Playground), for Shortcuts and scripts: show, hide, come, nap, feed,
/// play?toy=yarn|teaser|stop, wear?hat=…&collar=…, quiet?on=1|0, say?text=…,
/// agent?name=…&state=working|done|waiting|error&text=…&usage=…, and
/// roam?mode=anywhere|floor|windows.
extension PixpawDroplet: DropletURLHandling {
    public func handle(_ request: DropletURLRequest) {
        switch request.path.lowercased() {
        case "show": setOut(true)
        case "hide": setOut(false)
        case "come": callOver()
        case "nap": napNow()
        case "feed": feed()
        case "play":
            if !isOut { setOut(true) }
            switch request.query["toy"]?.lowercased() {
            case "teaser": cat?.play(.teaser)
            case "stop": cat?.stopPlaying()
            default: cat?.play(.yarn)
            }
        case "wear":
            // wear?hat=crown&collar= ; an empty value takes it off.
            if let hat = request.query["hat"] { wear(CatAccessory(rawValue: hat), in: .hat) }
            if let collar = request.query["collar"] { wear(CatAccessory(rawValue: collar), in: .collar) }
        case "quiet":
            setQuietByHand(["1", "on", "true"].contains(request.query["on"]?.lowercased() ?? "1"))
        case "agent":
            agentEvent(name: request.query["name"] ?? "", state: request.query["state"] ?? "", text: request.query["text"], usage: request.query["usage"])
        case "say":
            // Bounded, and shown as plain text only.
            if let text = request.query["text"]?.prefix(140), !text.isEmpty { cat?.say(CatLine(text: String(text), symbol: "bubble.left.fill")) }
        case "roam":
            if let mode = request.query["mode"].flatMap(CatRoaming.init(rawValue:)) { setRoaming(mode) }
        case "character":
            // character?name=cat|bee
            if let kind = request.query["name"].flatMap({ PetKind(rawValue: $0.lowercased()) }) { setKind(kind) }
        default: host?.log.info("ignored URL path \(request.path)")
        }
    }
}

// MARK: - Agent status

struct AgentStatus: Equatable {
    enum State: String {
        case working, done, waiting, error

        var title: String {
            switch self {
            case .working: "working"
            case .done: "done"
            case .waiting: "needs you"
            case .error: "hit a snag"
            }
        }
    }

    var name: String
    var state: State
    var at: Date
}
