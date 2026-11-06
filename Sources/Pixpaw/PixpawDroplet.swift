//
//  PixpawDroplet.swift
//  Pixpaw
//

import AppKit
import AVFoundation
import Combine
import DroppyKit
import IOKit.pwr_mgt
import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers

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
        static let photoCoat = "photoCoat"
        static let talks = "talks"
        static let notesModel = "meetingNotesModel"
        static let notesModelName = "meetingNotesModelName"
        static let notesLanguage = "meetingNotesLanguage"
        static let notesHearOthers = "meetingNotesHearOthers"
        static let notesSource = "meetingNotesSource"
        static let hooksHeard = "hooksHeard"
        static let foldedEars = "foldedEars"
        static let kind = "character"
        static let festivals = "festivals"
        static let festivalGreeted = "festivalGreeted"
        static let festivalsHidden = "festivalsHidden"
        static let birthdayOn = "birthdayOn"
        static let birthdayMonth = "birthdayMonth"
        static let birthdayDay = "birthdayDay"
        static let morning = "goodMorning"
        static let morningGreeted = "goodMorningGreeted"
        static let welcomeBack = "welcomeBack"
        static let lateNights = "lateNights"
        static let lateNightTold = "lateNightTold"
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
        static let tellsHeat = "tellsHeat"
        static let typesAlong = "typesAlong"
        static let carriesFiles = "carriesFiles"
        /// Before the to-do list: the one note on its sign, if any.
        static let sign = "sign"
        static let notes = "notes"
        static let countdowns = "countdowns"
        static let noteStreak = "noteStreak"
        static let nudges = "nudges"
        static let distractions = "distractions"
        static let pomodoro = "pomodoro"
        static let tellsDownloads = "tellsDownloads"
        static let tellsScreenshots = "tellsScreenshots"
        static let meals = "meals"
        static let giftDay = "giftDay"
        static let plays = "plays"
        static let firstMet = "firstMet"
        static let tellsMusic = "tellsMusic"
        static let tellsAgents = "tellsAgents"
        static let awakeForAgents = "awakeForAgents"
        static let answersAsks = "agentAsks"
        static let tellsScheduled = "tellsScheduled"
        static let scheduledOnSign = "scheduledOnSign"
        static let readsAsksAloud = "agentAsksAloud"
        static let touchIDForRisky = "touchIDForRisky"
        static let showsAgentTools = "agentTools"
        static let lofiSource = "lofiSource"
        static let lofiLink = "lofiLink"
        static let lofiWithFocus = "lofiWithFocus"
        /// Waits on long commands, and helpers out on errands.
        static let showsWaits = "agentWaits"
        static let watchesCI = "watchesCI"
        static let menuBarUsage = "menuBarUsage"
        static let usesDroppyTools = "usesDroppyTools"
        static let toldDroppyTools = "toldDroppyTools"
        static let cardOpening = "cardOpening"
        static let cardLook = "cardLook"
        static let cardGlass = "cardGlass"
        static let agentFiles = "agentFiles"
        static let asksClaudeUsage = "asksClaudeUsage"
        /// The pets' characters, coins and score at rock, paper, scissors.
        static let social = "social"
        static let stats = "stats"
        static let tellsLevels = "tellsLevels"
        static let tellsHeadphones = "tellsHeadphones"
        static let autoQuiet = "quietDuringCalls"
        static let quietMirroring = "quietWhenMirroring"
        static let sounds = "sounds"
        static let friend = "friend"
        static let friendCoat = "friendCoat"
        /// The friend's character; unset, the same as the pet's.
        static let friendKind = "friendKind"
        /// What the friend wears, chosen from its own menu.
        static let friendHat = "friendHat"
        static let friendCollar = "friendCollar"
        static let health = "healthReminders"
        /// Before reminders had their own times: the stretch one's to begin with.
        static let healthMinutes = "healthMinutes"
        static let reminders = "reminders"
        static let stretches = "stretches"
        static let homeOn = "homeOn"
        /// The house's left edge on the floor; below zero until it has one.
        static let homeX = "homeX"
        static let focusMinutes = "focusMinutes"
        static let ownPets = "ownPets"
    }

    private var host: DropletHost?
    private(set) var cat: CatController?
    /// The optional second cat, and its coat.
    private(set) var friend: CatController?
    @Published private(set) var hasFriend = false
    @Published private(set) var friendCoat: CatCoat = .gray
    /// Who the friend is: nil for the same character as your pet.
    @Published private(set) var friendKind: PetKind?
    @Published private(set) var isOut = false
    /// Whether the cat and its status get a row beside the notch. Off by
    /// default: the speech bubble already says everything.
    @Published private(set) var isPinned = false

    // What the cat tells you about, and whether Droppy may read it.
    @Published private(set) var tellsNotifications = true
    @Published private(set) var tellsCalendar = true
    @Published private(set) var tellsBattery = true
    @Published private(set) var tellsHeat = true
    @Published private(set) var typesAlong = true
    @Published private(set) var carriesFiles = true
    /// Your to-do list: it holds the first note up on a sign until you
    /// click it done, then the next.
    @Published private(set) var notes: [PetNote] = []
    @Published private(set) var noteStreak = NoteStreak()
    /// Days it counts down to, the nearest under the note on its sign.
    @Published private(set) var countdowns: [Countdown] = []
    /// During a focus session, comes over when you wander off somewhere distracting.
    @Published private(set) var nudgesOn = true
    @Published private(set) var distractionWords = DistractionWatcher.defaultWords
    private let distractions = DistractionWatcher()
    @Published private(set) var tellsDownloads = false
    @Published private(set) var tellsScreenshots = true
    /// The day you first let the pet out, for the shelf's tally.
    @Published private(set) var firstMet = Date()
    @Published private(set) var tellsMusic = true
    @Published private(set) var tellsAgents = true
    /// Keep the Mac from sleeping while a coding agent works.
    @Published private(set) var awakeForAgents = false
    /// Scheduled runs (Desktop scheduled tasks, /loop): said when they
    /// start, brought over with the result when they finish.
    @Published private(set) var tellsScheduled = true
    /// And the result kept on its sign as a note until you click it done.
    @Published private(set) var scheduledOnSign = true
    /// An agent's questions come to the pet, with buttons to answer.
    @Published private(set) var answersAsks = true
    /// And it reads them out.
    @Published private(set) var readsAsksAloud = true
    @Published private(set) var touchIDForRisky = true
    /// Touch ID is up for a risky one: no second prompt over it.
    private var confirmingRisky = false
    /// What a coding agent is doing ("Editing CatController.swift"), on a
    /// tag at the pet's side.
    @Published private(set) var showsAgentTools = true
    @Published private(set) var showsWaits = true
    @Published private(set) var watchesCI = false
    /// CI being waited for after a push, by "owner/repo@branch".
    private var ciWatches: [String: CIWatch] = [:]
    /// The run that failed last, for the pet's menu, until opened or green.
    private var ciFailedURL: URL?
    private var ciFailedRepo: String?
    /// The paw in the menu bar with what's left of each agent's plan.
    @Published private(set) var showsMenuBar = true
    /// What's left of each agent's plan, re-read once a minute.
    @Published private(set) var planUsage: [PlanUsage] = []
    /// "5h 77% · week 59% left" as an agent's hook last sent it, for the
    /// agents with no file of their own (Codex, others).
    private var reportedUsage: [String: (usage: String, at: Date)] = [:]
    @Published private(set) var lofiSource = LofiSource.youtube
    @Published private(set) var lofiLink = ""
    @Published private(set) var lofiWithFocus = false
    /// Lofi the pet started: until the music has been off for a while,
    /// whatever plays is taken for it, since Lofi Girl's tracks don't say
    /// "lofi" in their names.
    private var lofiStartedAt: Date?
    private var musicStoppedAt: Date?
    /// Started for a focus session, so a break pauses it.
    private var lofiForFocus = false
    /// When the pet paused it for a break: the next round within half an
    /// hour picks it up again rather than opening it a second time.
    private var lofiPausedAt: Date?
    private var lofiPaused: Bool { lofiPausedAt.map { Date().timeIntervalSince($0) < 30 * 60 } ?? false }
    /// When the tool's tag comes down, unless the agent says more.
    private var toolAt = Date.distantPast
    /// Commands agents are running, oldest first: past a little while, the
    /// pet sits and waits on the oldest with it.
    private var commands: [RunningCommand] = []
    /// Ports a dev server an agent just started may come up on, and since
    /// when; then the one that came up, for the menu.
    private var serverWatch: (ports: [Int], since: Date)?
    @Published private(set) var localServer: Int?
    private var serverCheckedAt = Date.distantPast
    /// The little helpers out on an agent's errand, by the agent's own id.
    private var helpers: [String: HelperPet] = [:]
    /// Bugs from failed tests and builds, by the command ("npm test").
    private var bugs: [String: PixelBug] = [:]
    /// Bugs the pet is on its way to catch, out of `bugs` until gone.
    private var catching: [PixelBug] = []
    /// Plan usage already warned about, by agent and window ("Claude 5h"),
    /// with how low it was: once at 10% left, once more at 3%.
    private var usageWarned: [String: Int] = [:]
    private var usageCheckedAt = Date.distantPast
    /// How fast each plan has gone down lately.
    private var planPace = PlanPace()
    /// Without the hooks: what Claude Code, Codex and Antigravity's own logs
    /// say (AgentFiles.swift).
    @Published private(set) var readsAgentFiles = false
    private let claudeFiles = ClaudeSessions()
    private let codexFiles = CodexRollouts()
    private let antigravityFiles = AntigravityBrains()
    private let geminiFiles = GeminiChats()
    private var filesReadAt = Date.distantPast
    private var filesReading = false
    /// Droppy's own tools, which the pet runs instead of doing the same itself.
    let tools = DroppyTools()
    @Published private(set) var usesDroppyTools = true
    /// The pet's card: how it opens, how it looks, how much glass.
    @Published private(set) var cardOpening = PetCardOpening.hold
    @Published private(set) var cardLook = PetCardLook.droppy
    @Published private(set) var cardGlass = 0.5
    @Published private(set) var droppyToolsFound: [DroppyTool] = []
    /// While Droppy's Pomodoro runs: the pet just sits at its laptop this long.
    private var droppyFocusTimer: Timer?
    private static let filesQueue = DispatchQueue(label: "app.pixpaw.agent-files", qos: .utility)
    /// When each agent's hook last spoke: while they do, the logs keep quiet.
    private var hookHeardAt: [String: Date] = [:]
    /// What the logs said, held a moment for a hook saying the same.
    private var fileEvents: [(at: Date, agent: String, event: AgentFileEvent)] = []
    /// Asking the `claude` command for the plan left.
    @Published private(set) var asksClaudeUsage = false
    private var claudeUsageAskedAt = Date.distantPast
    private var claudeUsageTask: Task<Void, Never>?
    /// Codex's plan as its log has it, with when each window resets.
    private var fileUsage: [String: (text: String, plan: PlanUsage)] = [:]
    /// The pets' characters, purses and score.
    @Published private(set) var social = PetSocial.fresh()
    /// This year's tally, for a card at its end.
    @Published private(set) var stats = PetStats()
    private var askTimer: Timer?
    private var askQueue: [AgentAsk] = []
    /// The question up on the pet's card, also in the menu bar's menu.
    @Published private(set) var openAsk: AgentAsk?
    /// The shelf widget on its plan-left page instead of the pet's.
    @Published private(set) var widgetShowsPlans = false

    func toggleWidgetPlans() { widgetShowsPlans.toggle() }
    private var askShownAt = Date.distantPast
    private var aliveAt = Date.distantPast
    private let voice = AVSpeechSynthesizer()
    private let notePrompt = NotePrompt()
    private var awakeAssertion: IOPMAssertionID?
    @Published private(set) var tellsLevels = true
    @Published private(set) var tellsHeadphones = true
    /// Goes quiet on its own during calls, screen sharing and mirroring.
    @Published private(set) var quietsAutomatically = true
    /// Also quiet while the display is mirrored (a projector, a TV).
    @Published private(set) var quietWhenMirroring = true
    /// Stretch, water and eye-rest reminders and your own, each with its time.
    @Published private(set) var healthOn = true
    @Published private(set) var reminders = Reminder.builtIn
    /// A focus session: when it began and ends, and how long one lasts.
    @Published private(set) var focusStartedAt: Date?
    @Published private(set) var focusEndsAt: Date?
    @Published private(set) var focusMinutes = 25
    /// Pomodoro: four focus sessions with a break after each, the fourth a long one.
    @Published private(set) var pomodoroOn = false
    @Published private(set) var pomodoroRound = 1
    @Published private(set) var breakStartedAt: Date?
    @Published private(set) var breakEndsAt: Date?
    private var breakTimer: Timer?
    /// Focusing or on a break between rounds.
    var inSession: Bool { focusEndsAt != nil || breakEndsAt != nil }
    /// The pets you drew, and what went wrong bringing the last one in.
    @Published private(set) var ownPets: [OwnPet] = []
    @Published private(set) var ownPetProblem: String?
    @Published private(set) var photoCoatProblem: String?
    @Published private(set) var readingPhoto = false
    @Published private(set) var hasPhotoCoat = false
    @Published private(set) var foldedEars = false
    /// Talk to your pet: on once the microphone and speech recognition are allowed.
    @Published private(set) var talks = false
    @Published private(set) var talkProblem: String?
    private let listener = PetListener()
    /// Meeting notes: the meeting being written down, and how it's summed up.
    private var meeting: MeetingRecorder?
    private var meetingTimer: Timer?
    @Published private(set) var takingNotes = false
    @Published private(set) var summingUp = false
    @Published private(set) var notesProblem: String?
    @Published private(set) var lastNotes: URL?
    @Published private(set) var notesModel = NoteModel.apple
    @Published private(set) var notesModelName = ""
    @Published private(set) var notesLanguage = MeetingLanguage.likely
    @Published private(set) var notesSource = MeetingSource.both
    /// Antigravity's models, once asked (`agy models`).
    private var focusTimer: Timer?
    private var health: ReminderCoach?

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
    /// Your birthday, for confetti and a party hat on the day.
    @Published private(set) var birthdayOn = false
    @Published private(set) var birthdayMonth = 1
    @Published private(set) var birthdayDay = 1
    /// A stretch and a good morning the first time it sees you each morning.
    @Published private(set) var morningOn = true
    @Published private(set) var welcomeBackOn = true
    /// A nightcap and a word about bedtime after midnight.
    @Published private(set) var lateNightsOn = true
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
    /// What Droppy is allowed, for Settings → Permissions.
    @Published private(set) var permissionStatus: [DropletPermission: DropletPermissionStatus] = [:]
    /// When each hook last spoke, kept across launches for Settings → Permissions
    /// (agent names, and "pixpaw-ask" for the question hook).
    @Published private(set) var hooksHeard: [String: Date] = [:]
    private var battery: BatteryWatcher?
    private var heat: HeatWatcher?
    /// When it last said the Mac was working hard, so it says so now and then, not every time.
    private var heatToldAt = Date.distantPast
    private var returns: ReturnWatcher?
    private var downloads: DownloadsWatcher?
    private var screenshots: ScreenshotWatcher?
    private var capturingPage = false
    private var gif: PetGIF?
    private var calendar: CalendarWatcher?
    private var notifications: NotificationWatcher?

    private let activitySubject = CurrentValueSubject<LiveActivityState?, Never>(nil)
    private let lockSubject = CurrentValueSubject<LockScreenStatusEntry?, Never>(nil)
    private var moodWatch: AnyCancellable?

    public func activate(host: DropletHost) throws {
        self.host = host
        usesDroppyTools = host.preferences.value(forKey: Key.usesDroppyTools, default: true)
        cardOpening = PetCardOpening(rawValue: host.preferences.value(forKey: Key.cardOpening, default: "hold")) ?? .hold
        cardLook = PetCardLook(rawValue: host.preferences.value(forKey: Key.cardLook, default: "droppy")) ?? .droppy
        cardGlass = host.preferences.value(forKey: Key.cardGlass, default: 0.5)
        tools.changed = { [weak self] in self?.droppyToolsChanged() }
        tools.start(host.launcher)
        droppyToolsFound = DroppyTool.allCases.filter(tools.has)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.tellDroppyToolsOnce() }
        let prefs = host.preferences
        ownPets = prefs.value(forKey: Key.ownPets, as: [OwnPet].self) ?? []
        OwnPets.soundFolder = host.environment.containerDirectory.appendingPathComponent("Own pet sounds", isDirectory: true)
        OwnPets.use(ownPets)
        PhotoCoat.use(prefs.value(forKey: Key.photoCoat, as: [String: UInt32].self))
        hasPhotoCoat = PhotoCoat.palette != nil
        foldedEars = prefs.value(forKey: Key.foldedEars, default: false)
        CatSprites.shared.foldedEars = foldedEars
        talks = prefs.value(forKey: Key.talks, default: false)
        notesModel = NoteModel(rawValue: prefs.value(forKey: Key.notesModel, default: "")) ?? (NoteModel.apple.available ? .apple : .none)
        notesModelName = prefs.value(forKey: Key.notesModelName, default: "")
        notesLanguage = MeetingLanguage(rawValue: prefs.value(forKey: Key.notesLanguage, default: "")) ?? .likely
        // Before the choice of three, a switch for hearing the others too.
        notesSource = MeetingSource(rawValue: prefs.value(forKey: Key.notesSource, default: ""))
            ?? (prefs.value(forKey: Key.notesHearOthers, default: true) ? .both : .microphone)
        hooksHeard = (prefs.value(forKey: Key.hooksHeard, as: [String: Double].self) ?? [:]).mapValues(Date.init(timeIntervalSince1970:))
        let kind = PetKind(rawValue: prefs.value(forKey: Key.kind, default: PetKind.cat.rawValue)) ?? .cat
        let cat = CatController(
            kind: kind.isOwn && OwnPets.pet(kind) == nil ? .cat : kind,
            coat: CatCoat(rawValue: prefs.value(forKey: Key.coat, default: CatCoat.orange.rawValue)) ?? .orange,
            chasesPointer: prefs.value(forKey: Key.chases, default: false),
            roaming: CatRoaming(rawValue: prefs.value(forKey: Key.roaming, default: CatRoaming.floor.rawValue)) ?? .floor,
            pouncesOnDrags: prefs.value(forKey: Key.pounces, default: true),
            chatty: prefs.value(forKey: Key.chatty, default: true),
            pets: prefs.value(forKey: Key.pets, default: 0),
            meals: prefs.value(forKey: Key.meals, default: 0),
            plays: prefs.value(forKey: Key.plays, default: 0),
            points: prefs.value(forKey: Key.points, default: 0),
            hat: CatAccessory(rawValue: prefs.value(forKey: Key.hat, default: "")),
            collar: CatAccessory(rawValue: prefs.value(forKey: Key.collar, default: "")),
            starDay: prefs.value(forKey: Key.starDay, as: StarDay.self),
            giftDay: prefs.value(forKey: Key.giftDay, default: ""),
            stretches: prefs.value(forKey: Key.stretches, default: 0),
            homeX: { let x: Double = prefs.value(forKey: Key.homeX, default: -1); return x < 0 ? nil : CGFloat(x) }(),
            // A new cat arrives fed.
            lastFed: Date(timeIntervalSince1970: prefs.value(forKey: Key.lastFed, default: Date().timeIntervalSince1970))
        )
        cat.homeOn = prefs.value(forKey: Key.homeOn, default: true)
        cat.onPersist = { [weak self] in self?.persist() }
        cat.onPhoto = { [weak self] in self?.takePhoto() }
        cat.onCapturePage = { [weak self] in self?.captureByHand() }
        cat.droppyTools = { [weak self] in self?.droppyMenuTools ?? [] }
        cat.onDroppyTool = { [weak self] tool in self?.runDroppyTool(tool) }
        cat.droppyFocusing = { [weak self] in self?.droppyFocusing ?? false }
        cat.cardStyle = { [weak self] in (self?.cardLook ?? .droppy, self?.cardGlass ?? 0.5) }
        cat.cardOpensOnClick = { [weak self] in self?.cardOpening == .click }
        cat.onRecordGIF = { [weak self] in self?.recordGIF() }
        cat.onLofi = { [weak self] in self?.playLofi() }
        cat.onPauseLofi = { [weak self] in self?.pauseLofi() }
        cat.lofiLabel = { [weak self] in self?.lofiSource.short }
        cat.localServer = { [weak self] in self?.localServer }
        cat.onOpenServer = { [weak self] in self?.openLocalServer() }
        cat.canTalk = { [weak self] in self?.talks == true }
        cat.notesLabel = { [weak self] in
            guard let self, let meeting = self.meeting else { return nil }
            return "\(meeting.minutes) min"
        }
        cat.hasNotes = { [weak self] in self?.lastNotes != nil }
        cat.onNotes = { [weak self] in self?.toggleMeetingNotes() }
        cat.onOpenNotes = { [weak self] in
            if let notes = self?.lastNotes { self?.host?.workspace.open(notes) }
        }
        cat.onTalk = { [weak self] in self?.talkToPet() }
        cat.failedCI = { [weak self] in self?.ciFailedURL == nil ? nil : self?.ciFailedRepo }
        cat.onOpenFailedCI = { [weak self] in
            guard let self, let url = self.ciFailedURL else { return }
            self.host?.workspace.open(url)
            self.ciFailedURL = nil
        }
        cat.focusLabel = { [weak self] in self?.focusLabel }
        cat.onFocus = { [weak self] in self?.toggleFocus() }
        // Counted from the first time the droplet ran, which its folder
        // remembers for anyone who had it before the tally existed.
        let created = (try? host.environment.containerDirectory.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        let stored = prefs.value(forKey: Key.firstMet, as: Double.self).map(Date.init(timeIntervalSince1970:))
        firstMet = [stored, created, Date()].compactMap { $0 }.min() ?? Date()
        prefs.setValue(firstMet.timeIntervalSince1970, forKey: Key.firstMet)
        let logger = host.log
        cat.log = { message in logger.debug(message) }
        self.cat = cat
        if let kept = prefs.value(forKey: Key.social, as: PetSocial.self) { social = kept } else { prefs.setValue(social, forKey: Key.social) }
        stats = prefs.value(forKey: Key.stats, as: PetStats.self) ?? PetStats()
        cat.traits = social.petTraits
        cat.canPlayHands = { [weak self] asked in self?.canPlayHands(asked: asked) ?? false }
        cat.onHandsPlayed = { [weak self] won, how in self?.handsPlayed(won, how: how) }
        cat.bugSpot = { [weak self] in self?.bugs.values.first { !$0.caught }?.spot }
        isPinned = prefs.value(forKey: Key.pinned, default: false)
        tellsNotifications = prefs.value(forKey: Key.tellsNotifications, default: true)
        tellsCalendar = prefs.value(forKey: Key.tellsCalendar, default: true)
        tellsBattery = prefs.value(forKey: Key.tellsBattery, default: true)
        tellsHeat = prefs.value(forKey: Key.tellsHeat, default: true)
        typesAlong = prefs.value(forKey: Key.typesAlong, default: true)
        cat.typesAlong = typesAlong
        carriesFiles = prefs.value(forKey: Key.carriesFiles, default: true)
        cat.carriesFiles = carriesFiles
        cat.onDeliver = { [weak self] urls in self?.addToShelf(urls) }
        notes = prefs.value(forKey: Key.notes, as: [PetNote].self)
            ?? prefs.value(forKey: Key.sign, as: String.self).map { [PetNote(text: $0)] } ?? []
        noteStreak = prefs.value(forKey: Key.noteStreak, as: NoteStreak.self) ?? NoteStreak()
        countdowns = (prefs.value(forKey: Key.countdowns, as: [Countdown].self) ?? []).filter { $0.daysLeft >= 0 }
        showTopNote()
        cat.onSignDone = { [weak self] in self?.completeNote() ?? false }
        cat.onAskSign = { [weak self] in self?.askForNote() }
        nudgesOn = prefs.value(forKey: Key.nudges, default: true)
        distractionWords = prefs.value(forKey: Key.distractions, as: [String].self) ?? DistractionWatcher.defaultWords
        distractions.words = distractionWords
        distractions.onNudge = { [weak self] _ in self?.nudgeBackToWork() }
        pomodoroOn = prefs.value(forKey: Key.pomodoro, default: false)
        // Watching Downloads can make macOS ask for folder access, so it waits
        // until it is switched on in Settings.
        tellsDownloads = prefs.value(forKey: Key.tellsDownloads, default: false)
        tellsScreenshots = prefs.value(forKey: Key.tellsScreenshots, default: true)
        tellsMusic = prefs.value(forKey: Key.tellsMusic, default: true)
        tellsAgents = prefs.value(forKey: Key.tellsAgents, default: true)
        awakeForAgents = prefs.value(forKey: Key.awakeForAgents, default: false)
        answersAsks = prefs.value(forKey: Key.answersAsks, default: true)
        tellsScheduled = prefs.value(forKey: Key.tellsScheduled, default: true)
        scheduledOnSign = prefs.value(forKey: Key.scheduledOnSign, default: true)
        readsAsksAloud = prefs.value(forKey: Key.readsAsksAloud, default: true)
        touchIDForRisky = prefs.value(forKey: Key.touchIDForRisky, default: true)
        showsAgentTools = prefs.value(forKey: Key.showsAgentTools, default: true)
        showsWaits = prefs.value(forKey: Key.showsWaits, default: true)
        watchesCI = prefs.value(forKey: Key.watchesCI, default: false)
        showsMenuBar = prefs.value(forKey: Key.menuBarUsage, default: true)
        // Both off until you turn them on: they read your agents' logs and run your claude command.
        readsAgentFiles = prefs.value(forKey: Key.agentFiles, default: false)
        asksClaudeUsage = prefs.value(forKey: Key.asksClaudeUsage, default: false)
        lofiSource = LofiSource(rawValue: prefs.value(forKey: Key.lofiSource, default: LofiSource.youtube.rawValue)) ?? .youtube
        lofiLink = prefs.value(forKey: Key.lofiLink, default: "")
        lofiWithFocus = prefs.value(forKey: Key.lofiWithFocus, default: false)
        tellsLevels = prefs.value(forKey: Key.tellsLevels, default: true)
        tellsHeadphones = prefs.value(forKey: Key.tellsHeadphones, default: true)
        quietsAutomatically = prefs.value(forKey: Key.autoQuiet, default: true)
        quietWhenMirroring = prefs.value(forKey: Key.quietMirroring, default: true)
        soundsOn = prefs.value(forKey: Key.sounds, default: true)
        hasFriend = prefs.value(forKey: Key.friend, default: false)
        friendCoat = CatCoat(rawValue: prefs.value(forKey: Key.friendCoat, default: CatCoat.gray.rawValue)) ?? .gray
        friendKind = PetKind(rawValue: prefs.value(forKey: Key.friendKind, default: ""))
        healthOn = prefs.value(forKey: Key.health, default: true)
        reminders = Self.loadReminders(prefs)
        focusMinutes = prefs.value(forKey: Key.focusMinutes, default: 25)
        // Finished and failed agents fade from the list; one waiting on you
        // that has gone quiet for half an hour, or a working one after four
        // hours (agents only say so when a run starts), is assumed gone.
        agentSweep = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sweepAgents() }
        }
        askTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickAsks() }
        }
        publishLockScreen()
        refreshPlanUsage()
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
            title: "Show or hide your pet",
            defaultShortcut: DropletKeyboardShortcut(
                keyCode: 8, // C
                modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue
            )
        ) { [weak self] in
            self?.toggle()
        }
        host.shortcuts.register(
            id: "add-note",
            title: "Give your pet a note",
            defaultShortcut: DropletKeyboardShortcut(
                keyCode: 45, // N
                modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue
            )
        ) { [weak self] in
            self?.askForNote()
        }
        host.shortcuts.register(
            id: "talk",
            title: "Talk to your pet",
            defaultShortcut: DropletKeyboardShortcut(
                keyCode: 17, // T
                modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue
            )
        ) { [weak self] in
            self?.talkToPet()
        }
        host.shortcuts.register(id: "meeting-notes", title: "Start or stop meeting notes", defaultShortcut: nil) { [weak self] in
            self?.toggleMeetingNotes()
        }
        host.shortcuts.register(id: "record-gif", title: "Record a GIF of your pet", defaultShortcut: nil) { [weak self] in
            self?.recordGIF()
        }
        host.shortcuts.register(id: "play-lofi", title: "Play lofi", defaultShortcut: nil) { [weak self] in
            self?.playLofi()
        }
        host.shortcuts.register(id: "capture-page", title: "Capture the whole page in your browser", defaultShortcut: nil) { [weak self] in
            self?.capturePage()
        }
        host.shortcuts.register(id: "join-meeting", title: "Join your next video call", defaultShortcut: nil) { [weak self] in
            self?.joinNextMeeting()
        }
        host.shortcuts.register(id: "call-cat", title: "Call your pet over", defaultShortcut: nil) { [weak self] in
            self?.callOver()
        }
        host.shortcuts.register(id: "quiet-cat", title: "Turn your pet's quiet mode on or off", defaultShortcut: nil) { [weak self] in
            self?.toggleQuiet()
        }
        host.shortcuts.register(id: "feed-cat", title: "Feed your pet", defaultShortcut: nil) { [weak self] in
            self?.feed()
        }
        host.shortcuts.register(id: "nap-cat", title: "Send your pet to nap in the notch", defaultShortcut: nil) { [weak self] in
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
        lateNightsOn = prefs.value(forKey: Key.lateNights, default: true)
        morningOn = prefs.value(forKey: Key.morning, default: true)
        welcomeBackOn = prefs.value(forKey: Key.welcomeBack, default: true)
        birthdayOn = prefs.value(forKey: Key.birthdayOn, default: false)
        birthdayMonth = prefs.value(forKey: Key.birthdayMonth, default: 1)
        birthdayDay = prefs.value(forKey: Key.birthdayDay, default: 1)
        // A minute is fine-grained enough for a festival that starts at 6 pm,
        // or for midnight.
        festivalCheck = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshFestival()
                self?.refreshLateNight()
                self?.refreshMorning()
                self?.remindDueNotes()
                self?.refreshCountdowns()
            }
        }
        screenWatch = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.festivals.refit() }
        }
        refreshFestival()
        refreshLateNight()
        host.log.info("Pixpaw activated")
    }

    public func deactivate() {
        PetCard.shared.close()
        stopCIWatches()
        listener.stop()
        meetingTimer?.invalidate()
        meetingTimer = nil
        _ = meeting?.stop()
        meeting = nil
        notePrompt.close()
        gif?.cancel()
        gif = nil
        claudeUsageTask?.cancel()
        claudeUsageTask = nil
        ClaudeUsage.stop()
        tools.stop()
        droppyFocusTimer?.invalidate()
        droppyFocusTimer = nil
        festivalCheck?.invalidate()
        focusTimer?.invalidate()
        focusTimer = nil
        focusStartedAt = nil
        focusEndsAt = nil
        breakTimer?.invalidate()
        breakTimer = nil
        breakStartedAt = nil
        breakEndsAt = nil
        distractions.stop()
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
        askTimer?.invalidate()
        askTimer = nil
        skipAllAsks()
        sendHelpersHome(now: true)
        clearBugs()
        commands = []
        serverWatch = nil
        localServer = nil
        voice.stopSpeaking(at: .immediate)
        agents = [:]
        refreshKeepAwake()
        moodWatch?.cancel()
        moodWatch = nil
        activitySubject.send(nil)
        lockSubject.send(nil)
        cat?.hide()
        cat = nil
        host = nil
    }

    func toggle() { setOut(!isOut) }

    func setOut(_ out: Bool) {
        guard let cat else { return }
        out ? cat.show() : cat.hide()
        isOut = cat.isVisible
        if !isOut {
            sendHelpersHome(now: true)
            clearBugs()
        }
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

    /// Reads a photo of your own cat into a coat and puts it on. Vision does
    /// it on the Mac; only the colours are kept.
    func coatFromPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a photo of your cat: clearly in view, in good light, on a plain background."
        NSApp.activate()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.readPhoto(url) }
        }
    }

    private func readPhoto(_ url: URL) {
        readingPhoto = true
        photoCoatProblem = nil
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { Result { try PhotoCoat.read(url) } }.value
            guard let self else { return }
            readingPhoto = false
            switch result {
            case .success(let palette):
                PhotoCoat.use(palette)
                hasPhotoCoat = true
                host?.preferences.setValue(palette, forKey: Key.photoCoat)
                if cat?.kind.hasCoats == false { setKind(.cat) }
                setCoat(.photo)
                cat?.celebrate()
            case .failure(let error):
                photoCoatProblem = error.localizedDescription
            }
        }
    }

    func forgetPhotoCoat() {
        PhotoCoat.use(nil)
        hasPhotoCoat = false
        host?.preferences.setValue([String: UInt32]?.none, forKey: Key.photoCoat)
        if cat?.coat == .photo { setCoat(.gray) }
        if friendCoat == .photo { setFriendCoat(.gray) }
    }

    /// Turning it on asks for the microphone and speech recognition,
    /// through Droppy, which owns the prompts.
    func setTalks(_ on: Bool) {
        talkProblem = nil
        guard on else {
            listener.stop()
            talks = false
            host?.preferences.setValue(false, forKey: Key.talks)
            return
        }
        guard let host else { return }
        Task { @MainActor [weak self] in
            var allowed = true
            for permission in [DropletPermission.microphone, .speechRecognition] where host.permissions.status(for: permission) != .granted {
                let status = await host.permissions.request(permission)
                if status == .denied { host.permissions.openSystemSettings(for: permission) }
                if status != .granted { allowed = false }
            }
            guard let self else { return }
            self.talks = allowed
            host.preferences.setValue(allowed, forKey: Key.talks)
            if !allowed { self.talkProblem = "Droppy needs the microphone and speech recognition, in System Settings → Privacy & Security." }
        }
    }

    /// Listens for a few seconds and does what you say; again while it
    /// listens, it stops and goes by what it heard.
    func talkToPet() {
        guard talks else { return }
        if listener.listening { return listener.finish() }
        if !isOut { setOut(true) }
        guard let cat else { return }
        listener.hearing = { [weak cat] text in
            cat?.say(CatLine(text: "“\(text.count > 60 ? "…" + text.suffix(59) : Substring(text))”", symbol: "ear", key: "listen", seconds: 2))
        }
        do {
            try listener.listen { [weak self] said in self?.heard(said) }
            cat.callOver()
            cat.say(CatWords.listening)
        } catch {
            cat.say(CatLine(text: error.localizedDescription, symbol: "mic.slash", seconds: 6))
        }
    }

    private func heard(_ said: String) {
        guard let cat else { return }
        guard let command = PetCommand.parse(said) else {
            return cat.say(said.isEmpty ? CatWords.heardNothing : CatWords.didntUnderstand)
        }
        switch command {
        case .come: callOver()
        case .feed: feed()
        case .treat: cat.giveTreat()
        case .nap: napNow()
        case .stretch: cat.stretchWithMe()
        case .photo: takePhoto()
        case .gif: recordGIF()
        case .join: joinByHand()
        case .droppy(.captureScrolling): captureByHand()
        case let .droppy(tool):
            if usesDroppy(tool) { runDroppyTool(tool) }
            else { cat.say(CatLine(text: usesDroppyTools ? "Droppy doesn't have \(tool.title.lowercased()) here" : "Turn on Use Droppy's own tools first", symbol: tool.symbol)) }
        case let .focus(minutes): focusByHand(minutes: minutes)
        case .stopFocus: stopFocus()
        case .lofi: playLofi()
        case .pauseLofi: pauseLofi()
        case let .play(game): cat.play(game ?? cat.kind.actsLike.games.first ?? .yarn)
        case let .note(text): addNote(text)
        case .usage: cat.say(usageSaid)
        case let .quiet(on): setQuietByHand(on)
        case .praise:
            cat.earn(.pet)
            cat.celebrate()
        }
    }

    // MARK: Meeting notes

    func setNotesModel(_ model: NoteModel) {
        notesModel = model
        notesModelName = ""
        host?.preferences.setValue(model.rawValue, forKey: Key.notesModel)
        host?.preferences.setValue("", forKey: Key.notesModelName)
    }

    func setNotesModelName(_ name: String) {
        notesModelName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        host?.preferences.setValue(notesModelName, forKey: Key.notesModelName)
    }

    func setNotesLanguage(_ language: MeetingLanguage) {
        notesLanguage = language
        host?.preferences.setValue(language.rawValue, forKey: Key.notesLanguage)
    }

    func setNotesSource(_ source: MeetingSource) {
        notesSource = source
        host?.preferences.setValue(source.rawValue, forKey: Key.notesSource)
    }

    func openNotesFolder() {
        try? FileManager.default.createDirectory(at: MeetingNotes.folder, withIntermediateDirectories: true)
        host?.workspace.open(MeetingNotes.folder)
    }

    // MARK: Droppy's tools

    /// Whether to ask Droppy for this rather than do it ourselves.
    func usesDroppy(_ tool: DroppyTool) -> Bool { usesDroppyTools && tools.has(tool) }

    /// The tools Droppy has, while the pet uses them, for its menu.
    var droppyMenuTools: [DroppyTool] { usesDroppyTools ? droppyToolsFound : [] }

    /// Runs one of Droppy's tools for you, from a click, a shortcut or your
    /// words; the pet says how it went.
    @discardableResult
    func runDroppyTool(_ tool: DroppyTool, said: String? = nil) -> Bool {
        if !isOut { setOut(true) }
        if let why = tools.run(tool) {
            cat?.say(CatLine(text: String(why.prefix(120)), symbol: "exclamationmark.triangle.fill"))
            return false
        }
        cat?.say(CatLine(text: said ?? "On it: \(tool.title)", symbol: tool.symbol, seconds: said == nil ? nil : 6))
        return true
    }

    /// Once, after an update: what the pet leaves to Droppy now, so nothing
    /// seems to have gone missing.
    private func tellDroppyToolsOnce() {
        guard usesDroppyTools, tools.isAvailable, isOut, droppyAnnouncesMeetings || droppyShowsUsage,
              host?.preferences.value(forKey: Key.toldDroppyTools, default: false) == false else { return }
        host?.preferences.setValue(true, forKey: Key.toldDroppyTools)
        cat?.say(CatLine(text: "Droppy shows your meetings and agents now, so I'll leave those to it", symbol: "drop.fill", seconds: 8))
    }

    /// Droppy's Agents has its own gauge and lock screen, so the pet's step aside.
    var droppyShowsUsage: Bool { usesDroppyTools && tools.isOn("agents") }

    /// The pet sitting at its laptop while Droppy's Pomodoro runs.
    var droppyFocusing: Bool { droppyFocusTimer != nil }

    func setCardOpening(_ opening: PetCardOpening) {
        cardOpening = opening
        host?.preferences.setValue(opening.rawValue, forKey: Key.cardOpening)
    }

    func setCardLook(_ look: PetCardLook) {
        cardLook = look
        host?.preferences.setValue(look.rawValue, forKey: Key.cardLook)
    }

    func setCardGlass(_ level: Double) {
        cardGlass = level
        host?.preferences.setValue(level, forKey: Key.cardGlass)
    }

    func setUsesDroppyTools(_ on: Bool) {
        usesDroppyTools = on
        host?.preferences.setValue(on, forKey: Key.usesDroppyTools)
        droppyToolsChanged()
    }

    /// A tool came or went, or the switch moved: what the pet hides follows.
    private func droppyToolsChanged() {
        droppyToolsFound = DroppyTool.allCases.filter(tools.has)
        refreshAlerts()
        publishLockScreen()
        tellDroppyToolsOnce()
    }

    /// Droppy shows meetings itself, so the pet doesn't announce them too.
    var droppyAnnouncesMeetings: Bool { usesDroppyTools && (tools.isOn("meetings") || tools.isOn("calendar")) }

    /// Focus from your menu, shortcut or words: Droppy's Pomodoro when there
    /// is one, the pet sitting at its laptop meanwhile (it can't tell when
    /// Droppy's timer ends), else the pet's own session.
    func focusByHand(minutes: Int? = nil) {
        guard usesDroppy(.pomodoro), runDroppyTool(.pomodoro, said: "Pomodoro's on in Droppy. Pause or stop it there.") else {
            return startFocus(minutes: minutes)
        }
        cat?.focusing = true
        droppyFocusTimer?.invalidate()
        droppyFocusTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval((minutes ?? focusMinutes) * 60), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.endDroppyFocus() }
        }
    }

    private func endDroppyFocus() {
        droppyFocusTimer?.invalidate()
        droppyFocusTimer = nil
        cat?.focusing = false
    }

    /// Join the next meeting: through Droppy when it has meetings.
    func joinByHand() {
        if usesDroppy(.joinMeeting) { runDroppyTool(.joinMeeting) } else { joinNextMeeting() }
    }

    /// The whole page: Droppy's scrolling capture when it has one.
    func captureByHand() {
        if usesDroppy(.captureScrolling) { runDroppyTool(.captureScrolling) } else { capturePage() }
    }

    /// Starts listening to the meeting, or stops and writes it up.
    func toggleMeetingNotes() {
        if meeting != nil { return stopMeetingNotes() }
        guard !summingUp, let host else { return }
        notesProblem = nil
        // The Mac's sound alone needs no microphone.
        let needed: [DropletPermission] = notesSource.hearsMicrophone ? [.microphone, .speechRecognition] : [.speechRecognition]
        Task { @MainActor [weak self] in
            for permission in needed where host.permissions.status(for: permission) != .granted {
                let status = await host.permissions.request(permission)
                if status == .denied { host.permissions.openSystemSettings(for: permission) }
                guard status == .granted else {
                    let what = needed.count > 1 ? "the microphone and speech recognition" : "speech recognition"
                    self?.notesProblem = "Droppy needs \(what), in System Settings → Privacy & Security."
                    self?.cat?.say(CatLine(text: "I need \(what) for that.", symbol: "mic.slash", seconds: 5))
                    return
                }
            }
            await self?.startMeetingNotes()
        }
    }

    private func startMeetingNotes() async {
        guard meeting == nil else { return }
        if !isOut { setOut(true) }
        do {
            let recorder = try MeetingRecorder(language: notesLanguage, title: cat?.joinTitle ?? MeetingLink.next()?.title)
            meeting = recorder
            takingNotes = true
            try await recorder.start(notesSource)
            cat?.say(CatWords.notesStarted(hearsOthers: recorder.hearsOthers, wanted: notesSource))
            showNotesTag()
            meetingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let meeting = self.meeting else { return }
                    // Three hours at most: it was forgotten.
                    if meeting.minutes >= 180 { return self.stopMeetingNotes() }
                    self.showNotesTag()
                }
            }
        } catch {
            _ = meeting?.stop()
            meeting = nil
            takingNotes = false
            notesProblem = error.localizedDescription
            cat?.say(CatLine(text: error.localizedDescription, symbol: "mic.slash", seconds: 6))
        }
    }

    private func showNotesTag() {
        guard let meeting else { return }
        let tag = AgentTool(agent: "Notes", symbol: "waveform.badge.mic", text: "Taking notes · \(meeting.minutes) min", lasts: 40)
        toolAt = Date().addingTimeInterval(tag.lasts)
        cat?.showTool(tag)
    }

    private func stopMeetingNotes() {
        guard let meeting else { return }
        meetingTimer?.invalidate()
        meetingTimer = nil
        let lines = meeting.stop()
        self.meeting = nil
        takingNotes = false
        let transcript = MeetingNotes.transcript(lines, bothSides: meeting.hearsMicrophone && meeting.hearsOthers)
        let model = lines.isEmpty ? .none : notesModel
        let name = notesModelName
        let language = notesLanguage
        let by = model == .none ? nil : model == .apple ? "Apple Intelligence" : [model.title.components(separatedBy: " (").first ?? "", name].filter { !$0.isEmpty }.joined(separator: " ")
        summingUp = model != .none
        if model != .none {
            cat?.say(CatWords.summingUp(by ?? ""))
            let tag = AgentTool(agent: "Notes", symbol: "text.append", text: "Writing it up", lasts: 900)
            toolAt = Date().addingTimeInterval(tag.lasts)
            cat?.showTool(tag)
        }
        Task { [weak self] in
            await meeting.stopped?.value
            var summary = ""
            var failed: String?
            if model != .none {
                do { summary = try await MeetingNotes.summarize(transcript, language: language, model: model, name: name) }
                catch { failed = error.localizedDescription }
            }
            guard let self else { return }
            self.summingUp = false
            self.cat?.showTool(nil)
            if let failed { summary = "_\(failed)_" }
            do {
                let file = try MeetingNotes.save(title: meeting.title, startedAt: meeting.startedAt, minutes: meeting.minutes,
                                                 summary: summary, by: failed == nil ? by : nil, transcript: transcript)
                self.lastNotes = file
                self.addToShelf([file])
                self.cat?.say(failed == nil ? CatWords.notesReady : CatWords.notesWithoutSummary)
                if failed == nil { self.cat?.celebrate() }
            } catch {
                self.notesProblem = error.localizedDescription
                self.cat?.say(CatLine(text: "I couldn't save the notes: \(error.localizedDescription)", symbol: "exclamationmark.triangle", seconds: 6))
            }
        }
    }

    /// What's left of each plan, in a line.
    private var usageSaid: CatLine {
        let left = planUsage.compactMap { plan in plan.lowest.map { "\(AgentLook.name(plan)) \($0)%" } }
        return CatLine(text: left.isEmpty ? "No plan usage yet." : left.joined(separator: " · ") + " left",
                       symbol: "gauge.with.dots.needle.67percent", seconds: 5)
    }

    func setFoldedEars(_ on: Bool) {
        foldedEars = on
        CatSprites.shared.foldedEars = on
        host?.preferences.setValue(on, forKey: Key.foldedEars)
    }

    /// Swaps the cat for another character, or back; the friend follows.
    func setKind(_ kind: PetKind) {
        cat?.kind = kind
        friend?.kind = friendsKind
        persist()
    }

    /// Every character in a menu at the pointer, the current one ticked.
    func chooseKind() {
        guard let cat else { return }
        let menu = NSMenu()
        for kind in PetKind.alphabetical {
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

    // MARK: Notes

    /// Adds a note to the end of the list; a time in it ("in 10 min",
    /// "at 5pm") is when the pet comes to remind you.
    /// `timed`: read a time in it ("at 5") as when to remind you.
    func addNote(_ raw: String, timed: Bool = true) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > CatSign.maxLength { text = String(text.prefix(CatSign.maxLength - 1)) + "…" }
        guard !text.isEmpty, notes.count < PetNote.limit else { return }
        notes.append(PetNote(text: text, due: timed ? NoteTime.due(in: text) : nil))
        saveNotes()
    }

    /// Done: the first note, or the one named, off the list for a star, and
    /// a day on the streak.
    @discardableResult
    func completeNote(_ id: UUID? = nil) -> Bool {
        guard let index = id.map({ id in notes.firstIndex { $0.id == id } }) ?? (notes.isEmpty ? nil : 0) else { return false }
        notes.remove(at: index)
        saveNotes()
        countStat(.notesDone)
        cat?.earn(.note)
        if noteStreak.countToday() {
            host?.preferences.setValue(noteStreak, forKey: Key.noteStreak)
            if noteStreak.days >= 2 { cat?.say(CatWords.noteStreak(noteStreak.days)) }
        }
        return true
    }

    /// Off the list without counting as done.
    func removeNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        saveNotes()
    }

    /// Up to the sign, ahead of the rest.
    func moveNoteToTop(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), index > 0 else { return }
        notes.insert(notes.remove(at: index), at: 0)
        saveNotes()
    }

    private func saveNotes() {
        host?.preferences.setValue(notes, forKey: Key.notes)
        showTopNote()
    }

    /// The first note, the nearest countdown under it; or the countdown alone.
    private func showTopNote() {
        let next = countdowns.filter { $0.daysLeft >= 0 }.min { $0.day < $1.day }
        cat?.signIsNote = !notes.isEmpty
        if let note = notes.first {
            cat?.holdSign(note.text, more: notes.count - 1, footer: next.map { "\($0.title) · \($0.whenText)" })
        } else if let next {
            cat?.holdSign(next.title, footer: next.daysLeft == 0 ? "Today!" : "In \(next.whenText)")
        } else {
            cat?.holdSign(nil)
        }
    }

    // MARK: Countdowns

    func addCountdown(_ raw: String, day: Date) {
        let title = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CatSign.maxLength))
        guard !title.isEmpty, countdowns.count < Countdown.limit else { return }
        countdowns.append(Countdown(title: title, day: Calendar.current.startOfDay(for: day)))
        countdowns.sort { $0.day < $1.day }
        saveCountdowns()
    }

    func removeCountdown(_ id: UUID) {
        countdowns.removeAll { $0.id == id }
        saveCountdowns()
    }

    private func saveCountdowns() {
        host?.preferences.setValue(countdowns, forKey: Key.countdowns)
        showTopNote()
    }

    /// A new day: past ones off, the day itself celebrated once, the sign's
    /// count brought up to date.
    private func refreshCountdowns() {
        var changed = false
        if countdowns.contains(where: { $0.daysLeft < 0 }) {
            countdowns.removeAll { $0.daysLeft < 0 }
            changed = true
        }
        if let cat, isOut, cat.quietReason == nil,
           let index = countdowns.firstIndex(where: { $0.daysLeft == 0 && !$0.celebrated }) {
            countdowns[index].celebrated = true
            changed = true
            cat.callOver()
            cat.say(CatWords.countdownDay(countdowns[index].title), essential: true)
        }
        if changed { saveCountdowns() } else { showTopNote() }
    }

    // MARK: Meetings

    /// A video call it just announced: a click on it joins, until the call
    /// has been on for ten minutes.
    private func offerJoin(_ meeting: Meeting) {
        cat?.offerJoin(meeting.title, until: meeting.start.addingTimeInterval(10 * 60)) { [weak self] in
            self?.join(meeting)
        }
    }

    /// The call under way or about to start, from a shortcut or a link.
    func joinNextMeeting() {
        guard let meeting = MeetingLink.next() else {
            cat?.say(CatWords.noMeeting)
            return
        }
        join(meeting)
    }

    private func join(_ meeting: Meeting) {
        cat?.clearJoinOffer()
        NSWorkspace.shared.open(meeting.link)
        cat?.say(CatWords.joining(meeting.title))
    }

    /// A note whose time is up: up onto the sign, and the pet comes to say
    /// it. One at a time, and not while it's quiet.
    private func remindDueNotes() {
        guard let cat, isOut, cat.quietReason == nil,
              let index = notes.firstIndex(where: { !$0.told && ($0.due ?? .distantFuture) <= Date() }) else { return }
        notes[index].told = true
        let note = notes.remove(at: index)
        notes.insert(note, at: 0)
        saveNotes()
        cat.callOver()
        cat.say(CatWords.noteDue(note.text), essential: true)
    }

    /// Asks for a note to add, in a panel that never stops Droppy while it
    /// waits (a modal alert would hold Droppy's main thread until answered).
    func askForNote() {
        if !isOut { setOut(true) }
        notePrompt.show(full: notes.count >= PetNote.limit, limit: PetNote.limit) { [weak self] text in
            self?.addNote(text)
        }
    }

    // MARK: Nudges

    func setNudges(_ on: Bool) {
        nudgesOn = on
        host?.preferences.setValue(on, forKey: Key.nudges)
        if on, focusEndsAt != nil { distractions.start() } else if !on { distractions.stop() }
    }

    /// Your words, comma-separated: app names and words in window titles.
    func setDistractions(_ raw: String) {
        let words = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        distractionWords = words
        distractions.words = words
        host?.preferences.setValue(words, forKey: Key.distractions)
    }

    /// Two minutes somewhere distracting in a focus session: it comes to ask.
    private func nudgeBackToWork() {
        guard let cat, let end = focusEndsAt, cat.quietReason == nil else { return }
        cat.callOver()
        cat.say(CatWords.backToWork(minutesLeft: Int((end.timeIntervalSinceNow / 60).rounded())))
    }

    func setCarriesFiles(_ on: Bool) {
        carriesFiles = on
        cat?.carriesFiles = on
        friend?.carriesFiles = on
        host?.preferences.setValue(on, forKey: Key.carriesFiles)
    }

    /// Puts files on Droppy's shelf the way its Services menu item, Add to
    /// Droppy Shelf, does. Inside Droppy that is its own services provider,
    /// called directly (asking the services server would wait on itself);
    /// anywhere else, the service by name. All of it on the main thread:
    /// pasteboards and services are AppKit.
    private func addToShelf(_ urls: [URL]) {
        let board = NSPasteboard.withUniqueName()
        board.clearContents()
        board.writeObjects(urls as [NSURL])
        // droppykit-lint: allow dynamic-lookup: Droppy's own Add to Droppy Shelf service (its public Services menu item), called in process because DroppyKit has no shelf-add API and asking the services server from inside Droppy would wait on itself; the selector is the fixed NSServices signature
        let selector = NSSelectorFromString("addToShelf:userData:error:")
        if let provider = NSApp.servicesProvider as? NSObject, provider.responds(to: selector),
           let method = class_getInstanceMethod(type(of: provider), selector) {
            typealias Service = @convention(c) (AnyObject, Selector, NSPasteboard, NSString, AutoreleasingUnsafeMutablePointer<NSString?>) -> Void
            var problem: NSString?
            unsafeBitCast(method_getImplementation(method), to: Service.self)(provider, selector, board, "" as NSString, &problem)
            board.releaseGlobally()
            cat?.say(problem == nil ? CatWords.shelved : CatWords.noShelf)
            return
        }
        // A host with services of its own but not this one would be asking
        // itself, and NSPerformService waits for the answer: say so instead.
        guard NSApp.servicesProvider == nil else {
            board.releaseGlobally()
            cat?.say(CatWords.noShelf)
            return
        }
        // The service by name, on the main thread, once the drop that
        // brought the files has finished.
        let name = board.name
        DispatchQueue.main.async { [weak self] in
            let board = NSPasteboard(name: name)
            let done = NSPerformService("Add to Droppy Shelf", board)
            board.releaseGlobally()
            self?.cat?.say(done ? CatWords.shelved : CatWords.noShelf)
        }
    }

    func setTypesAlong(_ on: Bool) {
        typesAlong = on
        cat?.typesAlong = on
        friend?.typesAlong = on
        host?.preferences.setValue(on, forKey: Key.typesAlong)
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
        headphones: Bool? = nil, screenshots: Bool? = nil, heat: Bool? = nil
    ) {
        if let heat { tellsHeat = heat; host?.preferences.setValue(heat, forKey: Key.tellsHeat) }
        if let screenshots { tellsScreenshots = screenshots; host?.preferences.setValue(screenshots, forKey: Key.tellsScreenshots) }
        if let headphones { tellsHeadphones = headphones; host?.preferences.setValue(headphones, forKey: Key.tellsHeadphones) }
        if let levels { tellsLevels = levels; host?.preferences.setValue(levels, forKey: Key.tellsLevels) }
        if let music { tellsMusic = music; host?.preferences.setValue(music, forKey: Key.tellsMusic) }
        if let agents {
            tellsAgents = agents
            host?.preferences.setValue(agents, forKey: Key.tellsAgents)
            if !agents { self.agents = [:]; refreshKeepAwake() }
        }
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
        // A quiet cat makes no sound either, and nor does one keeping you
        // company while you focus: its news still shows, then the clock.
        CatSounds.shared.isEnabled = soundsOn && reason == nil && focusEndsAt == nil
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

    /// Days since you first let it out, counted in calendar days.
    var daysTogether: Int {
        let calendar = Calendar.current
        let between = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstMet),
                                               to: calendar.startOfDay(for: Date())).day ?? 0
        return max(1, between + 1)
    }

    /// A portrait of the pet as it is now, saved where you choose.
    func takePhoto() {
        guard let cat, let data = PetPhoto.render(cat, days: daysTogether) else { return }
        PetPhoto.save(data, named: "\(cat.kind.title) by Pixpaw.png")
    }

    /// Five seconds of the pet as a looping GIF, saved where your screenshots
    /// go; the pet takes it to the shelf, ready to drop into a chat.
    func recordGIF() {
        guard gif == nil, let cat, isOut else { return }
        cat.say(CatWords.recordingGIF)
        gif = PetGIF(cat) { [weak self] file in
            guard let self else { return }
            self.gif = nil
            guard let file else { return }
            if let cat = self.cat, self.isOut {
                cat.carry([file])
                cat.say(CatWords.gifDone)
            } else {
                self.addToShelf([file])
            }
        }
    }

    /// The whole page in the front browser window, top to bottom, saved where
    /// your screenshots go; the pet takes it to the shelf.
    func capturePage() {
        guard !capturingPage else { return }
        capturingPage = true
        cat?.say(CatWords.capturingPage)
        Task { @MainActor [weak self] in
            do {
                let file = try await PageCapture.capture()
                guard let self else { return }
                self.capturingPage = false
                if let cat = self.cat, self.isOut { cat.carry([file]) } else { self.addToShelf([file]) }
            } catch {
                self?.capturingPage = false
                self?.cat?.say(CatWords.pageProblem(error as? PageCaptureProblem ?? .failed))
            }
        }
    }

    func setBirthday(on: Bool? = nil, month: Int? = nil, day: Int? = nil) {
        if let on { birthdayOn = on; host?.preferences.setValue(on, forKey: Key.birthdayOn) }
        if let month { birthdayMonth = month; host?.preferences.setValue(month, forKey: Key.birthdayMonth) }
        if let day { birthdayDay = day; host?.preferences.setValue(day, forKey: Key.birthdayDay) }
        // A day the month does not have becomes its last.
        let last = Self.days(in: birthdayMonth)
        if birthdayDay > last { birthdayDay = last; host?.preferences.setValue(last, forKey: Key.birthdayDay) }
        refreshFestival()
    }

    /// Days in a month, counting 29 February.
    static func days(in month: Int) -> Int { [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][max(0, min(11, month - 1))] }

    /// Puts up today's festival, takes it down when it is over, and keeps the
    /// screen clear during calls and screen sharing. Your birthday has its
    /// own switch, apart from the festivals'.
    private func refreshFestival() {
        guard let host, !host.environment.isHarness else { return }
        // Only ever the real date: there is no way to call a festival early.
        let found = Festival.current(birthday: birthdayOn ? (birthdayMonth, birthdayDay) : nil)
        let shown = found.flatMap { $0 == .birthday || (festivalsOn && !festivalsHidden.contains($0)) ? $0 : nil }
        if cat?.festivalHat != shown?.hat { cat?.festivalHat = shown?.hat }
        guard let today = shown, autoQuietReason == nil || !quietsAutomatically else {
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

    // MARK: Good morning

    func setMorning(_ on: Bool) {
        morningOn = on
        host?.preferences.setValue(on, forKey: Key.morning)
    }

    /// The first time it sees you at the Mac on a morning (5 am to noon), it
    /// stretches and says good morning, with your first event of the day.
    /// True when it did.
    @discardableResult
    private func refreshMorning() -> Bool {
        guard let host, !host.environment.isHarness, morningOn, isOut, !quietByHand,
              autoQuietReason == nil || !quietsAutomatically,
              (5..<12).contains(Calendar.current.component(.hour, from: Date())),
              CatController.secondsSinceInput() < 60,
              host.preferences.value(forKey: Key.morningGreeted, default: "") != StarDay.today else { return false }
        host.preferences.setValue(StarDay.today, forKey: Key.morningGreeted)
        let reads = tellsCalendar && calendarAllowed
        cat?.stretch()
        cat?.say(CatWords.goodMorning(first: reads ? CalendarWatcher.firstEventToday() : nil, calendar: reads))
        return true
    }

    // MARK: Welcome back

    func setWelcomeBack(_ on: Bool) {
        welcomeBackOn = on
        host?.preferences.setValue(on, forKey: Key.welcomeBack)
        refreshAlerts()
    }

    /// Back at the Mac after a while away: the pet runs over to say hello,
    /// unless good morning or a late night has something to say first.
    private func welcomeBack() {
        guard let cat, cat.quietReason == nil, !refreshMorning(), !refreshLateNight() else { return }
        cat.callOver()
        if let line = CatWords.welcomeBack.randomElement() {
            cat.say(CatLine(text: line, symbol: "hand.wave.fill"))
        }
    }

    // MARK: Late nights

    func setLateNights(_ on: Bool) {
        lateNightsOn = on
        host?.preferences.setValue(on, forKey: Key.lateNights)
        refreshLateNight()
    }

    /// From midnight to five in the morning the pet wears a nightcap, and
    /// the first time it sees you at the Mac it says it is late, once a night.
    /// True when it said so.
    @discardableResult
    private func refreshLateNight() -> Bool {
        guard let host, !host.environment.isHarness else { return false }
        let late = lateNightsOn && (0..<5).contains(Calendar.current.component(.hour, from: Date()))
        if cat?.wearsNightcap != late { cat?.wearsNightcap = late }
        guard late, isOut, !quietByHand, autoQuietReason == nil || !quietsAutomatically,
              CatController.secondsSinceInput() < 60,
              host.preferences.value(forKey: Key.lateNightTold, default: "") != StarDay.today else { return false }
        host.preferences.setValue(StarDay.today, forKey: Key.lateNightTold)
        cat?.say(CatWords.lateNight)
        return true
    }

    // MARK: Focus

    /// The timer on the shelf and in its menu: starts a session, stops one,
    /// or skips a Pomodoro break.
    func toggleFocus() {
        if droppyFocusTimer != nil {
            endDroppyFocus()
            cat?.say(CatLine(text: "Droppy's Pomodoro keeps going until you stop it there", symbol: "timer", seconds: 6))
            return
        }
        if breakEndsAt != nil { endBreak() } else if focusEndsAt == nil { focusByHand() } else { stopFocus() }
    }

    /// A focus session: the pet sits by you without a sound, the time left
    /// shows over its head (between anything else it has to tell you) and
    /// beside the notch, and when it is up the pet comes to say so.
    func startFocus(minutes: Int? = nil, round: Int = 1) {
        if !isOut { setOut(true) }
        clearBreak()
        pomodoroRound = round
        let length = TimeInterval((minutes ?? focusMinutes) * 60)
        focusStartedAt = Date()
        focusEndsAt = Date().addingTimeInterval(length)
        cat?.focusing = true
        if let focusEndsAt { cat?.keepSaying(CatWords.focusing(until: focusEndsAt)) }
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: length, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finishFocus() }
        }
        if nudgesOn { distractions.start() }
        if lofiWithFocus { playLofi(forFocus: true) }
        applyQuiet()
        publishActivity()
    }

    /// Ends the session, a Pomodoro break included.
    func stopFocus() {
        pauseLofiForBreak()
        lofiForFocus = false
        clearFocus()
        clearBreak()
        cat?.keepSaying(nil)
        applyQuiet()
        publishActivity()
    }

    private func clearFocus() {
        if let focusStartedAt { countStat(.focusMinutes, Int(Date().timeIntervalSince(focusStartedAt) / 60)) }
        focusTimer?.invalidate()
        focusTimer = nil
        focusStartedAt = nil
        focusEndsAt = nil
        cat?.focusing = false
        distractions.stop()
    }

    private func clearBreak() {
        breakTimer?.invalidate()
        breakTimer = nil
        breakStartedAt = nil
        breakEndsAt = nil
        cat?.onBreak = false
    }

    private func finishFocus() {
        countStat(.focusRounds)
        let minutes = Int(((focusEndsAt ?? Date()).timeIntervalSince(focusStartedAt ?? Date()) / 60).rounded())
        guard pomodoroOn else {
            stopFocus()
            cat?.callOver()
            cat?.say(CatWords.focusDone(minutes: minutes))
            return
        }
        startBreak()
    }

    /// Pomodoro: five minutes off after each round, fifteen after the
    /// fourth, starting with a stretch together.
    private func startBreak() {
        pauseLofiForBreak()
        clearFocus()
        let round = pomodoroRound
        let minutes = round % 4 == 0 ? 15 : 5
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        breakStartedAt = Date()
        breakEndsAt = end
        cat?.onBreak = true
        cat?.callOver()
        cat?.say(CatWords.breakStarts(round: round, minutes: minutes))
        cat?.keepSaying(CatWords.onBreak(until: end, round: round))
        cat?.stretchWithMe()
        breakTimer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.endBreak() }
        }
        applyQuiet()
        publishActivity()
    }

    /// The break is over (or skipped): the next round, or after the fourth
    /// round's long break, done.
    private func endBreak() {
        let round = pomodoroRound
        clearBreak()
        cat?.callOver()
        if round % 4 == 0 {
            stopFocus()
            cat?.say(CatWords.pomodoroDone)
        } else {
            cat?.say(CatWords.backToIt(round: round + 1))
            startFocus(round: round + 1)
        }
    }

    func setPomodoro(_ on: Bool) {
        pomodoroOn = on
        host?.preferences.setValue(on, forKey: Key.pomodoro)
    }

    func setFocusMinutes(_ minutes: Int) {
        focusMinutes = minutes
        host?.preferences.setValue(minutes, forKey: Key.focusMinutes)
    }

    func setHome(_ on: Bool) {
        cat?.homeOn = on
        host?.preferences.setValue(on, forKey: Key.homeOn)
    }

    func setHealth(on: Bool) {
        healthOn = on
        host?.preferences.setValue(on, forKey: Key.health)
        refreshAlerts()
    }

    /// Saved reminders, Pixpaw's own always there and first; the first time,
    /// the stretch one takes the single time reminders used to share.
    private static func loadReminders(_ prefs: any DropletPreferencesService) -> [Reminder] {
        var saved = prefs.value(forKey: Key.reminders, as: [Reminder].self) ?? []
        if saved.isEmpty {
            saved = Reminder.builtIn
            saved[0].minutes = prefs.value(forKey: Key.healthMinutes, default: 60)
        }
        let own = Reminder.builtIn.map { builtIn in saved.first { $0.id == builtIn.id } ?? builtIn }
        return own + saved.filter(\.isYours)
    }

    func updateReminder(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        saveReminders()
    }

    func addReminder(_ text: String, minutes: Int) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, reminders.filter(\.isYours).count < Self.maxOwnReminders else { return }
        reminders.append(.yours(String(text.prefix(80)), minutes: minutes))
        saveReminders()
    }

    func removeReminder(_ id: String) {
        reminders.removeAll { $0.id == id && $0.isYours }
        saveReminders()
    }

    static let maxOwnReminders = 5

    // MARK: Pets you drew

    /// Asks for a sprite sheet and brings it in as a new pet, or as a new
    /// picture for one you have. The new pet comes out at once.
    func importOwnPet(replacing slot: Int? = nil) {
        guard slot != nil || OwnPets.freeSlot != nil else { return }
        let panel = NSOpenPanel()
        // A new pet may also come as a .pixpaw file someone shared.
        panel.allowedContentTypes = slot == nil ? [.png, OwnPetPack.type] : [.png]
        panel.allowsMultipleSelection = false
        panel.message = slot == nil ? "Choose your pet's sprite sheet (one 20 × 20 cell for each pose, sitting first), or a .pixpaw file someone shared."
            : "Choose your pet's sprite sheet: one 20 × 20 cell for each pose, sitting first."
        NSApp.activate()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.addOwnPet(from: url, replacing: slot) }
        }
    }

    private func addOwnPet(from url: URL, replacing slot: Int?) {
        do {
            guard let data = try? Data(contentsOf: url) else { throw OwnPetProblem.unreadable }
            if slot == nil, url.pathExtension.lowercased() == "pixpaw" {
                guard let free = OwnPets.freeSlot else { return }
                let pet = try OwnPets.unpack(data, into: free)
                ownPetProblem = nil
                ownPets.append(pet)
                saveOwnPets()
                setKind(pet.kind)
                return
            }
            let sheet = try OwnPets.sheet(from: data)
            ownPetProblem = nil
            if let slot, let index = ownPets.firstIndex(where: { $0.slot == slot }) {
                ownPets[index].sheet = sheet
                saveOwnPets()
            } else if let slot = OwnPets.freeSlot {
                let name = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespaces)
                let pet = OwnPet(slot: slot, name: String((name.isEmpty ? "My pet" : name).prefix(30)), actsLike: .cat, sheet: sheet)
                ownPets.append(pet)
                saveOwnPets()
                setKind(pet.kind)
            }
        } catch {
            ownPetProblem = error.localizedDescription
        }
    }

    func renameOwnPet(_ slot: Int, to name: String) {
        guard let index = ownPets.firstIndex(where: { $0.slot == slot }) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        ownPets[index].name = name.isEmpty ? "My pet" : String(name.prefix(30))
        saveOwnPets()
    }

    func setOwnPet(_ slot: Int, actsLike kind: PetKind) {
        guard !kind.isOwn, let index = ownPets.firstIndex(where: { $0.slot == slot }) else { return }
        ownPets[index].actsLike = kind
        saveOwnPets()
    }

    /// Lets the pet go; if it was out, the cat comes back in its place.
    func removeOwnPet(_ slot: Int) {
        guard let pet = ownPets.first(where: { $0.slot == slot }) else { return }
        ownPets.removeAll { $0.slot == slot }
        if friendKind == pet.kind { setFriendKind(nil) }
        if cat?.kind == pet.kind { setKind(.cat) }
        saveOwnPets()
    }

    /// Asks for a short sound and gives it to the pet, in place of the
    /// voice of the character it acts like.
    func chooseOwnSound(_ sound: OwnSound, for slot: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a sound \(sound.when), up to \(sound.longest.formatted()) seconds long."
        NSApp.activate()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.setOwnSound(sound, for: slot, from: url) }
        }
    }

    private func setOwnSound(_ sound: OwnSound, for slot: Int, from url: URL) {
        guard let index = ownPets.firstIndex(where: { $0.slot == slot }) else { return }
        do {
            let name = try OwnPets.keep(url, as: sound, for: slot)
            ownPetProblem = nil
            ownPets[index].sounds = (ownPets[index].sounds ?? [:]).merging([sound.rawValue: name]) { $1 }
            saveOwnPets()
            playOwnSound(sound, of: slot)
        } catch {
            ownPetProblem = error.localizedDescription
        }
    }

    /// Back to the voice of the character it acts like.
    func removeOwnSound(_ sound: OwnSound, from slot: Int) {
        guard let index = ownPets.firstIndex(where: { $0.slot == slot }) else { return }
        ownPets[index].sounds?[sound.rawValue] = nil
        saveOwnPets()
    }

    /// Plays it, even with sounds off: you asked to hear it.
    func playOwnSound(_ sound: OwnSound, of slot: Int) {
        guard let pet = ownPets.first(where: { $0.slot == slot }), let url = OwnPets.sound(sound, of: pet.kind) else { return }
        CatSounds.shared.preview(url)
    }

    /// A pet you drew in one .pixpaw file, its sounds and all, for a friend
    /// to bring in.
    func sharePet(_ slot: Int) {
        guard let pet = ownPets.first(where: { $0.slot == slot }), let data = OwnPets.pack(pet) else { return }
        PetPhoto.save(data, named: "\(pet.name).pixpaw", type: OwnPetPack.type)
    }

    /// A character's sprite sheet, to draw over or to share.
    func saveSheet(of kind: PetKind) {
        guard let cat else { return }
        let data = kind.isOwn ? OwnPets.pet(kind)?.sheet : OwnPets.template(kind, coat: cat.coat)
        guard let data else { return }
        PetPhoto.save(data, named: "\(kind.title).png")
    }

    private func saveOwnPets() {
        OwnPets.use(ownPets)
        OwnPets.tidySounds()
        host?.preferences.setValue(ownPets, forKey: Key.ownPets)
        cat?.ownPetChanged()
        friend?.ownPetChanged()
        objectWillChange.send()
    }

    private func saveReminders() {
        host?.preferences.setValue(reminders, forKey: Key.reminders)
        health?.reminders = reminders
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
        if let host {
            var status: [DropletPermission: DropletPermissionStatus] = [:]
            for permission in PixpawPermission.allCases.map(\.permission) { status[permission] = host.permissions.status(for: permission) }
            // Accessibility as macOS itself has it, the way the notifications row does.
            if notifications { status[.accessibility] = .granted }
            if calendar { status[.calendars] = .granted }
            if status != permissionStatus { permissionStatus = status }
        }
    }

    /// Notes a hook speaking, at most once a minute so the preferences aren't
    /// written on every tool call.
    private func heardHook(_ name: String) {
        let now = Date()
        if let last = hooksHeard[name], now.timeIntervalSince(last) < 60 { return }
        hooksHeard[name] = now
        host?.preferences.setValue(hooksHeard.mapValues(\.timeIntervalSince1970), forKey: Key.hooksHeard)
    }

    /// When a hook for this agent last spoke: any name it sent that starts the same way
    /// ("Claude", "Claude Code").
    func hookHeard(_ agent: String) -> Date? {
        hooksHeard.filter { $0.key.lowercased().hasPrefix(agent.lowercased()) }.values.max()
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

        if out, tellsHeat {
            if heat == nil {
                heat = HeatWatcher { [weak self] level in
                    guard let self, let cat = self.cat else { return }
                    cat.busyMac = level != .calm
                    self.friend?.busyMac = level != .calm
                    // Said at most every half hour.
                    guard level != .calm, Date().timeIntervalSince(self.heatToldAt) > 30 * 60 else { return }
                    self.heatToldAt = Date()
                    cat.say(level == .hot ? CatWords.hotMac : CatWords.busyMac)
                }
            }
            heat?.start()
        } else {
            heat?.stop()
            cat.busyMac = false
        }

        if out, tellsBattery {
            if battery == nil {
                battery = BatteryWatcher(onLine: say) { [weak cat] low in
                    guard let cat else { return }
                    // Plugged in at last: perks right up.
                    if cat.lowBattery, !low { cat.pose() }
                    cat.lowBattery = low
                }
            }
            battery?.start()
        } else {
            battery?.stop()
            cat.lowBattery = false
        }
        if out, welcomeBackOn {
            if returns == nil { returns = ReturnWatcher { [weak self] in self?.welcomeBack() } }
            returns?.start()
        } else {
            returns?.stop()
        }
        if out, tellsScreenshots {
            if screenshots == nil {
                screenshots = ScreenshotWatcher { [weak cat] in
                    cat?.pose()
                    say(CatWords.screenshot())
                }
            }
            screenshots?.start()
        } else {
            screenshots?.stop()
        }
        if out, tellsDownloads {
            if downloads == nil { downloads = DownloadsWatcher(onLine: say) }
            downloads?.start()
        } else {
            downloads?.stop()
        }
        if out, healthOn {
            if health == nil {
                let coach = ReminderCoach(reminders: reminders) { [weak cat] reminder in
                    guard let cat else { return }
                    if reminder.id == Reminder.stretchID {
                        cat.stretchWithMe()
                    } else {
                        // Comes over to you, then says it.
                        cat.callOver()
                        cat.say(CatLine(text: reminder.text, symbol: reminder.symbol, seconds: 5))
                    }
                }
                // A focus session ends with its own break.
                coach.canRemind = { [weak self, weak cat] in cat?.quietReason == nil && self?.focusEndsAt == nil }
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
                music = MusicWatcher(onLine: { [weak cat] line in say(line); cat?.dance() }, onPlaying: { [weak self, weak cat] playing in
                    if cat?.musicPlaying != playing { cat?.musicPlaying = playing }
                    self?.updateLofi(playing: playing)
                }, log: { [weak cat] message in cat?.log?(message) })
            }
            music?.start()
        } else {
            music?.stop()
        }
        if out, tellsCalendar, calendarAllowed, !droppyAnnouncesMeetings {
            if calendar == nil {
                calendar = CalendarWatcher(onLine: say, onMeeting: { [weak self] meeting in self?.offerJoin(meeting) })
            }
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
        heat?.stop()
        heat = nil
        returns?.stop()
        downloads?.stop()
        screenshots?.stop()
        calendar?.stop()
        notifications?.stop()
        battery = nil
        returns = nil
        downloads = nil
        screenshots = nil
        calendar = nil
        notifications = nil
    }

    // MARK: Coding agents

    /// One report from a coding agent's hook: `working`, `done`, `waiting`
    /// (it needs you) or `error`, with an optional line of text.
    /// `task`: a scheduled run's name (a Desktop scheduled task or a /loop),
    /// and `result` the first line of what it came back with.
    func agentEvent(name rawName: String, state rawState: String, text: String?, usage: String? = nil, task: String? = nil, result: String? = nil,
                    diff: String? = nil) {
        guard tellsAgents else { return }
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !name.isEmpty, let state = AgentStatus.State(rawValue: rawState.lowercased()) else { return }
        let previous = agents[name]?.state
        // "3 files · +84 −12": counts only, kept to what one looks like.
        let changed = diff.map { String($0.prefix(48)) }.flatMap { $0.wholeMatch(of: #/[0-9a-z ·+−-]+/#) != nil ? $0 : nil }
        agents[name] = AgentStatus(name: name, state: state, at: Date(), diff: state == .done ? changed : nil)
        publishActivity()
        refreshKeepAwake()
        if state != .working { cat?.showTool(nil) }
        // A turn over: no command of its is still running in the foreground.
        if state == .done || state == .error { endCommands(of: name) }
        if state == .done, let usage { checkUsage(of: name, usage) }
        if let usage, !usage.isEmpty {
            reportedUsage[name] = (String(usage.prefix(60)), Date())
            refreshPlanUsage()
        }
        guard previous != state else { return }

        let detail = text.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(90)) }.flatMap { $0.isEmpty ? nil : $0 }
        if let task = task.map({ String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)) }), !task.isEmpty, tellsScheduled {
            return scheduledRun(task, state: state, result: result.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140)) })
        }
        switch state {
        case .working:
            cat?.say(CatLine(text: CatWords.agentWorking(name), symbol: "sparkles"))
        case .done:
            // Done, what it changed and how much of the plan is left, e.g.
            // "3 files · +84 −12 · 5h 76% · week 59% left".
            let left = usage.map { String($0.prefix(40)) }.flatMap { $0.isEmpty ? nil : $0 }
            let after = [changed, left].compactMap { $0 }.joined(separator: " · ")
            cat?.say(CatLine(text: after.isEmpty ? CatWords.agentDone(name) : "\(CatWords.agentDone(name)) \(after)", symbol: "checkmark.circle.fill"))
            cat?.celebrate()
        case .waiting:
            // Already over its head with the buttons to answer.
            if cat?.askShown?.agent == name { break }
            cat?.say(CatLine(text: detail.map { "\(CatWords.agentWaiting(name)): \($0)" } ?? CatWords.agentWaiting(name), symbol: "hand.raised.fill"))
            // Comes over to get your attention.
            cat?.callOver()
        case .error:
            cat?.say(CatLine(text: CatWords.agentFailed(name), symbol: "exclamationmark.triangle.fill"))
        }
    }

    /// An agent about to use a tool (`agent?state=tool&tool=Edit&target=…`):
    /// the tag at the pet's side says what and to which file, until the
    /// agent goes quiet for a few seconds or finishes.
    func agentTool(name rawName: String, tool: String, target: String?, id: String? = nil, ports: String? = nil, ci: String? = nil) {
        guard tellsAgents else { return }
        if tool == "Bash", let ports { watchServer(ports) }
        if tool == "Bash", let ci { watchCI(String(ci.prefix(200))) }
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        // The agent moved on to its next tool, so the command before is over,
        // even without a hook saying how it went; calls made together arrive
        // within a moment of each other and are kept.
        if commands.contains(where: { $0.agent == name && Date().timeIntervalSince($0.since) > 2 }) {
            commands.removeAll { $0.agent == name && Date().timeIntervalSince($0.since) > 2 }
            tickCommands()
        }
        if tool == "Bash", !name.isEmpty {
            let label = target.flatMap { AgentTool.command(String($0.prefix(300))) } ?? "A command"
            commands.append(RunningCommand(id: id.map { String($0.prefix(80)) } ?? UUID().uuidString, agent: name, label: label, since: Date()))
            commands.removeAll { Date().timeIntervalSince($0.since) > RunningCommand.forgottenAfter }
            if commands.count > 8 { commands.removeFirst(commands.count - 8) }
        }
        guard showsAgentTools else { return }
        guard !name.isEmpty, let shown = AgentTool(agent: name, tool: String(tool.prefix(64)), target: target.map { String($0.prefix(300)) }) else { return }
        if agents[name]?.state != .working {
            agents[name] = AgentStatus(name: name, state: .working, at: Date())
            publishActivity()
            refreshKeepAwake()
        }
        agents[name]?.at = Date()
        toolAt = Date().addingTimeInterval(shown.lasts)
        cat?.showTool(shown)
    }

    func setShowsAgentTools(_ on: Bool) {
        showsAgentTools = on
        host?.preferences.setValue(on, forKey: Key.showsAgentTools)
        if !on { cat?.showTool(nil) }
    }

    func setWatchesCI(_ on: Bool) {
        watchesCI = on
        host?.preferences.setValue(on, forKey: Key.watchesCI)
        if !on { stopCIWatches() }
    }

    /// Whether GitHub's `gh` command is on this Mac, for Settings to say.
    var hasGH: Bool { CIWatch.gh != nil }

    private func stopCIWatches() {
        ciWatches.values.forEach { $0.stop() }
        ciWatches = [:]
    }

    /// Your agent pushed "owner/repo@branch": wait for its GitHub Actions.
    private func watchCI(_ pushed: String) {
        guard watchesCI, CIWatch.gh != nil, ciWatches[pushed] == nil || ciWatches.count < 4 else { return }
        ciWatches[pushed]?.stop()
        var made: CIWatch?
        made = CIWatch(pushed) { [weak self] event in
            guard let self, let watch = made else { return }
            self.ciHeard(event, from: watch)
            if case .started = event { return }
            if self.ciWatches[pushed] === watch { self.ciWatches[pushed] = nil }
        }
        guard let watch = made else { return }
        ciWatches[pushed] = watch
        watch.start()
    }

    private func ciHeard(_ event: CIWatch.Event, from watch: CIWatch) {
        guard isOut, let cat else { return }
        let bug = "CI \(watch.name)"
        switch event {
        case let .started(workflows):
            cat.say(CatWords.ciWaiting(watch.name, workflows))
        case .passed:
            cat.say(CatWords.ciPassed(watch.name))
            if ciFailedRepo == watch.name { ciFailedURL = nil }
            if let caught = bugs[bug] { catchBug(caught) } else { cat.celebrate() }
        case let .failed(workflow, url):
            cat.say(CatWords.ciFailed(watch.name, workflow))
            CatSounds.shared.play(.hiss, voice: cat.kind)
            ciFailedURL = url
            ciFailedRepo = watch.name
            releaseBug(bug)
        case .cancelled:
            cat.say(CatWords.ciCancelled(watch.name))
        }
    }

    func setShowsWaits(_ on: Bool) {
        showsWaits = on
        host?.preferences.setValue(on, forKey: Key.showsWaits)
        if !on { sendHelpersHome(now: false) }
        tickCommands()
    }

    // MARK: Lofi

    func setLofiSource(_ source: LofiSource) {
        lofiSource = source
        host?.preferences.setValue(source.rawValue, forKey: Key.lofiSource)
        lofiPausedAt = nil
    }

    func setLofiLink(_ link: String) {
        lofiLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        host?.preferences.setValue(lofiLink, forKey: Key.lofiLink)
    }

    func setLofiWithFocus(_ on: Bool) {
        lofiWithFocus = on
        host?.preferences.setValue(on, forKey: Key.lofiWithFocus)
    }

    /// Beats to study to, from where you listen; picked up again when the
    /// pet paused them for a break.
    func playLofi(forFocus: Bool = false) {
        if !isOut { setOut(true) }
        if forFocus { lofiForFocus = true }
        let source = lofiSource
        if lofiPaused {
            lofiPausedAt = nil
            lofiStartedAt = Date()
            if Lofi.canPause(source) { Task { await Lofi.resume(source) } } else if usesDroppy(.playPause) { _ = tools.run(.playPause) }
            return
        }
        // Still playing from before: nothing to open again.
        if let lofiStartedAt, musicStoppedAt == nil, Date().timeIntervalSince(lofiStartedAt) > 5, cat?.musicPlaying == true { return }
        let link = lofiLink
        Task { [weak self] in
            let opened = await Lofi.play(source, ownLink: link)
            guard let self else { return }
            if opened {
                self.lofiPausedAt = nil
                self.lofiStartedAt = Date()
                self.musicStoppedAt = nil
                self.cat?.say(CatWords.lofiOn(source))
            } else {
                self.cat?.say(CatWords.lofiNoLink)
            }
        }
    }

    /// Paused from its menu; Play lofi picks it up again.
    func pauseLofi() {
        let source = lofiSource
        if !Lofi.canPause(source) {
            // In a browser: Droppy's own play/pause, only while something plays.
            guard usesDroppy(.playPause), cat?.musicPlaying == true else {
                cat?.say(CatLine(text: "Pause it where it's playing", symbol: "pause.circle"))
                return
            }
            lofiPausedAt = Date()
            if tools.run(.playPause) == nil { cat?.say(CatLine(text: "Paused", symbol: "pause.fill")) }
            return
        }
        lofiPausedAt = Date()
        Task { await Lofi.pause(source) }
    }

    /// For the pet's menu: how long a session is, or what's left of one.
    private var focusLabel: String {
        if let end = focusEndsAt ?? breakEndsAt { return "\(max(1, Int((end.timeIntervalSinceNow / 60).rounded(.up)))) min left" }
        return "\(focusMinutes) min"
    }

    /// A break, or the end of focus: pauses lofi it started for the session.
    private func pauseLofiForBreak() {
        guard lofiForFocus, lofiStartedAt != nil, !lofiPaused, cat?.musicPlaying == true,
              Lofi.canPause(lofiSource) || usesDroppy(.playPause) else { return }
        lofiPausedAt = Date()
        let source = lofiSource
        if Lofi.canPause(source) { Task { await Lofi.pause(source) } } else { _ = tools.run(.playPause) }
    }

    /// Whether what's playing is lofi: a song that says so, or the music the
    /// pet started, until it has been off for a couple of minutes.
    private func updateLofi(playing: Bool) {
        if playing { musicStoppedAt = nil } else if musicStoppedAt == nil { musicStoppedAt = Date() }
        // Played again by hand during the break: nothing for the next round
        // to pick up (the play/pause key would pause it instead).
        if playing, let paused = lofiPausedAt, Date().timeIntervalSince(paused) > 8 { lofiPausedAt = nil }
        if let stopped = musicStoppedAt, Date().timeIntervalSince(stopped) > 120, !lofiPaused { lofiStartedAt = nil }
        let ours = lofiStartedAt != nil && (music?.playerPlaying == true || music?.othersPlaying == true)
        let lofi = playing && (music?.playerIsLofi == true || ours)
        if cat?.lofi != lofi { cat?.lofi = lofi }
    }

    // MARK: Long commands

    /// A tool an agent used is over (`agent?state=tool-done&tool=Bash&id=…&outcome=ok|failed|stopped`).
    /// A command that kept the pet waiting ends in confetti or a rain cloud;
    /// a helper's errand ends in a parcel.
    func agentToolDone(name rawName: String, tool: String, id: String?, outcome: String?) {
        guard tellsAgents else { return }
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        switch tool {
        case "Bash":
            let index = commands.firstIndex { $0.id == id } ?? commands.firstIndex { $0.agent == name }
            guard let index else { return }
            let command = commands.remove(at: index)
            let took = Date().timeIntervalSince(command.since)
            tickCommands()
            guard showsWaits, outcome != "stopped" else { return }
            if outcome == "failed", took >= RunningCommand.waitsAfter || RunningCommand.checksWork(command.label) {
                releaseBug(command.label)
            } else if outcome != "failed", let bug = bugs[command.label] {
                catchBug(bug)
            }
            guard took >= RunningCommand.waitsAfter else { return }
            countStat(.longCommands)
            countStat(.minutesWaited, Int(took / 60))
            let ok = outcome != "failed"
            cat?.commandFinished(ok: ok)
            let length = RunningCommand.length(took)
            cat?.say(ok ? CatWords.commandPassed(command.label, length) : CatWords.commandFailed(command.label, length))
        case "Task", "Agent":
            helperEvent(name: name, id: id, event: "done")
        default:
            break
        }
    }

    /// Every second: the pet waits on the oldest command that has run past a
    /// little while, with how long it has taken on its tag.
    private func tickCommands() {
        commands.removeAll { Date().timeIntervalSince($0.since) > RunningCommand.forgottenAfter }
        let waiting = showsWaits ? commands.first { Date().timeIntervalSince($0.since) >= RunningCommand.waitsAfter } : nil
        cat?.waitingSince = waiting?.since
        guard let waiting, showsAgentTools else {
            // Its hourglass tag comes down with the command.
            if cat?.toolShown?.symbol == "hourglass" { cat?.showTool(nil) }
            return
        }
        let tag = AgentTool(agent: waiting.agent, symbol: "hourglass",
                            text: "\(waiting.label) · \(RunningCommand.length(Date().timeIntervalSince(waiting.since)))", lasts: 5)
        toolAt = Date().addingTimeInterval(tag.lasts)
        if cat?.toolShown != tag { cat?.showTool(tag) }
    }

    /// The agent's turn is over: its commands are too.
    private func endCommands(of agent: String) {
        commands.removeAll { $0.agent == agent }
        tickCommands()
    }

    // MARK: Dev servers

    /// An agent ran a command that starts a dev server (`ports=5173`, or
    /// the usual ones for a project's own script): watch for it to come up.
    /// Of several, one already in use belongs to something else.
    private func watchServer(_ list: String) {
        let ports = list.split(separator: ",").prefix(8).compactMap { Int($0) }.filter { (1...65535).contains($0) }
        guard !ports.isEmpty else { return }
        let fresh = ports.count == 1 ? ports : ports.filter { !LocalServer.isListening($0) }
        guard !fresh.isEmpty else { return }
        serverWatch = (fresh, Date())
        serverCheckedAt = .distantPast
    }

    /// Every two seconds: has the server come up (it says so once), and is
    /// the one in the menu still there?
    private func tickServer() {
        guard Date().timeIntervalSince(serverCheckedAt) >= 2, localServer != nil || serverWatch != nil else { return }
        serverCheckedAt = Date()
        if let port = localServer, !LocalServer.isListening(port) { localServer = nil }
        guard let watch = serverWatch else { return }
        // A server that hasn't come up in three minutes isn't coming.
        guard Date().timeIntervalSince(watch.since) < 180 else { return serverWatch = nil }
        guard let port = watch.ports.first(where: LocalServer.isListening) else { return }
        serverWatch = nil
        guard port != localServer else { return }
        localServer = port
        if tellsAgents, cat?.chatty == true { cat?.say(CatLine(text: CatWords.serverUp(port), symbol: "safari")) }
    }

    func openLocalServer() {
        guard let port = localServer, let url = URL(string: "http://localhost:\(port)") else { return }
        host?.workspace.open(url)
    }

    // MARK: Bugs

    /// Tests or a build failed: a bug turns up and scuttles about, one per
    /// command, three at most.
    private func releaseBug(_ key: String) {
        guard isOut, let cat, bugs[key] == nil else { return }
        for (old, bug) in bugs where Date().timeIntervalSince(bug.since) > RunningCommand.forgottenAfter {
            bug.remove()
            bugs[old] = nil
        }
        guard bugs.count < 3, let bug = PixelBug(key: key, near: cat) else { return }
        bugs[key] = bug
        bug.start()
    }

    /// The same command passed: the pet runs over and catches its bug, and
    /// earns stars for it. Caught after a few seconds whatever happens, so
    /// a pet that was picked up on the way doesn't leave it about.
    private func catchBug(_ bug: PixelBug) {
        bugs[bug.key] = nil
        bug.freeze()
        // Held in `catching`, not `bugs`, until it is caught and gone, so
        // deactivate() can still close it.
        catching.append(bug)
        let caught = { [weak self] in
            guard !bug.caught else { return }
            bug.squash()
            self?.countStat(.bugsCaught)
            self?.cat?.earn(.play)
            self?.cat?.say(CatWords.bugCaught(bug.key))
        }
        cat?.catchBug(at: bug.spot, then: caught)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            caught()
            // Squashed, its panel closes 0.8 s later; then it's let go.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.catching.removeAll { $0 === bug } }
        }
    }

    private func clearBugs() {
        bugs.values.forEach { $0.remove() }
        bugs = [:]
        catching.forEach { $0.remove() }
        catching = []
    }

    // MARK: Usage running low

    /// "5h 8% · week 59% left": the pet comes over when a window is down to
    /// 10%, and again at 3%; once a window has more again, it can warn anew.
    private func checkUsage(of agent: String, _ usage: String) {
        guard tellsAgents else { return }
        for part in usage.replacingOccurrences(of: " left", with: "").components(separatedBy: " · ") {
            let bits = part.split(separator: " ")
            guard bits.count == 2, let left = Int(bits[1].dropLast()), bits[1].hasSuffix("%") else { continue }
            let window = String(bits[0])
            let key = "\(agent) \(window)"
            guard left <= 10 else {
                usageWarned[key] = nil
                continue
            }
            let level = left <= 3 ? 3 : 10
            guard level < usageWarned[key] ?? 100 else { continue }
            usageWarned[key] = level
            cat?.callOver()
            cat?.say(CatWords.usageLow(agent, window: window, left: left), essential: true)
        }
    }

    /// Claude Code's status line keeps its rate limits (Tools/agent-hooks/
    /// usage.py): read now and then, so a warning comes mid-turn, not only
    /// when Claude stops.
    private func checkClaudeUsage() {
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/Pixpaw/claude-usage.json")
        guard let data = try? Data(contentsOf: file),
              let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let at = saved["saved_at"] as? Double, Date().timeIntervalSince1970 - at < 6 * 3600 else { return }
        var parts: [String] = []
        for (window, name) in [("five_hour", "5h"), ("seven_day", "week")] {
            guard let entry = saved[window] as? [String: Any], let used = entry["used"] as? Double else { continue }
            // A window that has reset since is back to full.
            let reset = (entry["resets_at"] as? Double).map { $0 < Date().timeIntervalSince1970 } ?? false
            parts.append("\(name) \(reset ? 100 : max(0, min(100, Int((100 - used).rounded()))))%")
        }
        if !parts.isEmpty { checkUsage(of: "Claude", parts.joined(separator: " · ") + " left") }
    }

    // MARK: Plan usage in the menu bar

    func setShowsMenuBar(_ on: Bool) {
        showsMenuBar = on
        host?.preferences.setValue(on, forKey: Key.menuBarUsage)
    }

    func setAsksClaudeUsage(_ on: Bool) {
        asksClaudeUsage = on
        host?.preferences.setValue(on, forKey: Key.asksClaudeUsage)
        if on { askClaudeUsage(force: true) }
    }

    /// Without the status line (the Claude app doesn't run it), asks the
    /// `claude` command what's left of the plan (ClaudeUsage.swift): soon
    /// after Pixpaw starts, then every five minutes while Claude has been at
    /// work in the last hour, unless the status line saved it lately.
    private func askClaudeUsage(force: Bool = false) {
        guard asksClaudeUsage, tellsAgents, host?.environment.isHarness == false, claudeUsageTask == nil else { return }
        let now = Date()
        if !force {
            guard now.timeIntervalSince(claudeUsageAskedAt) >= 5 * 60,
                  claudeUsageAskedAt == .distantPast || agents["Claude"].map({ now.timeIntervalSince($0.at) < 60 * 60 }) == true else { return }
            // The status line saved it a moment ago.
            if let saved = PlanUsageReader.claude(now: now)?.at, now.timeIntervalSince(saved) < 4 * 60 { return }
        }
        claudeUsageAskedAt = now
        claudeUsageTask = Task { [weak self] in
            let answered = await ClaudeUsage.ask()
            guard let self else { return }
            self.claudeUsageTask = nil
            if answered { self.refreshPlanUsage() }
        }
    }

    func setReadsAgentFiles(_ on: Bool) {
        readsAgentFiles = on
        host?.preferences.setValue(on, forKey: Key.agentFiles)
        if !on {
            fileEvents = []
            fileUsage = [:]
            refreshPlanUsage()
        }
    }

    /// Reads what's saved again. The harness always gets a made-up example,
    /// so its picture shows every colour and none of this Mac's own plans.
    func refreshPlanUsage() {
        let found = host?.environment.isHarness == true ? PlanUsageReader.sample()
            : planPace.note(PlanUsageReader.all(reported: reportedUsage, read: fileUsage.values.map(\.plan)))
        if found != planUsage { planUsage = found }
    }

    /// While a plan runs low or will run dry before it resets, the one with
    /// the most left (40% or more in every window), to switch to.
    var planToSwitchTo: PlanUsage? {
        let short = planUsage.filter { $0.windows.contains { $0.level != .plenty || $0.runsOut != nil } }
        guard !short.isEmpty else { return nil }
        let shortIDs = Set(short.map(\.id))
        return planUsage.filter { !shortIDs.contains($0.id) && ($0.lowest ?? 0) >= 40 }.max { ($0.lowest ?? 0) < ($1.lowest ?? 0) }
    }

    /// The question for the menu: the one up, or in the harness an example.
    var menuAsk: AgentAsk? {
        if let openAsk { return openAsk }
        guard host?.environment.isHarness == true else { return nil }
        return AgentAsk(id: "example-question", agent: "Claude", title: "Run this command?", detail: "npm test -- --watch=false",
                        place: "pixpaw", options: ["Allow", "Always allow", "Deny"])
    }

    /// Every two seconds, what the agents' own logs say happened since. Each
    /// event waits three seconds, and is dropped if that agent's hook has
    /// spoken in the last ten minutes: with the hooks in, they tell it, with
    /// the diff and the questions the logs don't have.
    private func readAgentFiles() {
        let now = Date()
        guard readsAgentFiles, tellsAgents, host?.environment.isHarness == false else { return }
        // Every 2 s while your pet is out, every 10 s while it's hidden; read
        // off the main thread, one look at a time.
        if !filesReading, now.timeIntervalSince(filesReadAt) >= (isOut ? 2 : 10) {
            filesReadAt = now
            filesReading = true
            let (claude, codex, antigravity, gemini) = (claudeFiles, codexFiles, antigravityFiles, geminiFiles)
            Self.filesQueue.async {
                let found = [("Claude", claude.poll(now: now)), ("Codex", codex.poll(now: now)),
                             ("Antigravity", antigravity.poll(now: now)), ("Gemini", gemini.poll(now: now))]
                DispatchQueue.main.async { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.filesReading = false
                        // Turned off while it looked: drop what it found.
                        guard self.readsAgentFiles else { return }
                        for (agent, events) in found { self.fileEvents += events.map { (now, agent, $0) } }
                    }
                }
            }
        }
        while let first = fileEvents.first, now.timeIntervalSince(first.at) >= 3 {
            fileEvents.removeFirst()
            let hooked = hookHeardAt[first.agent].map { now.timeIntervalSince($0) < 10 * 60 } ?? false
            switch first.event {
            case let .usage(text, plan):
                fileUsage[first.agent] = (text, plan)
                refreshPlanUsage()
            case _ where hooked:
                continue
            case .working:
                agentEvent(name: first.agent, state: "working", text: nil)
            case .done:
                agentEvent(name: first.agent, state: "done", text: nil, usage: fileUsage[first.agent]?.text)
            case let .tool(name, target, id):
                agentTool(name: first.agent, tool: name, target: target, id: id)
            case let .toolDone(name, id, failed):
                agentToolDone(name: first.agent, tool: name, id: id, outcome: failed ? "failed" : "ok")
            case let .helper(id, back):
                helperEvent(name: first.agent, id: id, event: back ? "done" : "start")
            }
        }
    }

    /// The agents to list in the menu bar's menu, waiting ones first.
    var menuAgents: [AgentStatus] {
        let order: [AgentStatus.State] = [.waiting, .error, .working, .done]
        let mine = tellsAgents ? agents.values.sorted { order.firstIndex(of: $0.state)! < order.firstIndex(of: $1.state)! || ($0.state == $1.state && $0.name < $1.name) } : []
        if mine.isEmpty, host?.environment.isHarness == true {
            return [AgentStatus(name: "Claude", state: .working, at: Date().addingTimeInterval(-4 * 60)),
                    AgentStatus(name: "Antigravity", state: .done, at: Date().addingTimeInterval(-9 * 60), diff: "3 files · +84 −12")]
        }
        return mine
    }

    /// The menu bar symbol: a raised hand while an agent needs you, else a
    /// gauge as full as the emptiest window, or the paw with nothing known.
    var menuBarSymbol: String {
        if openAsk != nil || tellsAgents && agents.values.contains(where: { $0.state == .waiting }) { return "hand.raised.fill" }
        guard let lowest = planUsage.compactMap(\.lowest).min() else { return "pawprint.fill" }
        let level = lowest <= 10 ? "0" : lowest <= 33 ? "33" : lowest <= 50 ? "50" : lowest <= 75 ? "67" : "100"
        return "gauge.with.dots.needle.\(level)percent"
    }

    // MARK: Helpers

    /// A helper sent off (`agent?state=helper&event=start&id=…`) or back
    /// with what it found (`event=done`).
    func helperEvent(name rawName: String, id rawID: String?, event: String?) {
        guard tellsAgents, showsWaits, isOut, let cat else { return }
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        let id = rawID.map { String($0.prefix(80)) }
        if event == "done" {
            // Its own id, or else the one of this agent's out longest.
            let helper = id.flatMap { helpers[$0] } ?? helpers.values.filter { $0.agent == name }.min { $0.since < $1.since }
            if let helper {
                helper.deliver()
                countStat(.parcels)
            }
            return
        }
        guard let id, helpers[id] == nil else { return }
        // Errands that never came back.
        // Kept in `helpers` while they walk off (onGone drops them), so
        // deactivate() can still stop them.
        for old in helpers.values where Date().timeIntervalSince(old.since) > RunningCommand.forgottenAfter { old.leave() }
        guard helpers.count < 4, let helper = HelperPet(id: id, agent: name, beside: cat, index: helpers.count) else { return }
        helper.onGone = { [weak self] in self?.helpers[id] = nil }
        helpers[id] = helper
        helper.start()
    }

    /// All helpers off home: walking, or gone at once when the pet goes in.
    private func sendHelpersHome(now: Bool) {
        for helper in helpers.values {
            if now { helper.remove() } else { helper.leave() }
        }
        if now { helpers = [:] }
    }

    // MARK: The year together

    /// One more for this year's tally.
    func countStat(_ stat: PetStat, _ count: Int = 1) {
        guard count > 0 else { return }
        stats.add(stat, count)
        host?.preferences.setValue(stats, forKey: Key.stats)
    }

    func clearStats() {
        stats = PetStats()
        host?.preferences.setValue(stats, forKey: Key.stats)
    }

    // MARK: Rock, paper, scissors

    /// Both pets have coins to bet; one that lost everything gets a little
    /// pocket money each day. A game you asked for still goes ahead: the
    /// other spots it some, and if neither can, the pet says so.
    private func canPlayHands(asked: Bool) -> Bool {
        social.topUp(today: StarDay.today)
        guard asked, !social.canPlay else { return social.canPlay }
        guard let shared = social.share() else {
            cat?.say(CatWords.handsBroke, essential: true)
            return false
        }
        host?.preferences.setValue(social, forKey: Key.social)
        cat?.say(CatWords.handsShared(shared.coins, petGave: shared.petGave), essential: true)
        return true
    }

    /// The pet tells how it went: what it won or lost, and what it has.
    private func handsPlayed(_ won: Bool?, how: String?) {
        guard let won else {
            if let line = CatWords.handsDraw.randomElement(), cat?.chatty == true { cat?.say(CatLine(text: line, symbol: "hand.raised.fill")) }
            return
        }
        countStat(.gamesPlayed)
        if won { countStat(.gamesWon) }
        let stake = social.stake()
        guard stake > 0 else { return }
        social.settle(petWon: won, stake: stake)
        host?.preferences.setValue(social, forKey: Key.social)
        let competitive = social.petTraits.contains(.competitive)
        guard cat?.chatty == true else { return }
        cat?.say(won ? CatWords.handsWon(stake, have: social.petCoins, competitive: competitive, how: how)
                     : CatWords.handsLost(stake, have: social.petCoins, competitive: competitive, how: how))
    }

    /// New characters for both, purses and score back to the start.
    func resetSocial() {
        social = PetSocial.fresh()
        host?.preferences.setValue(social, forKey: Key.social)
        cat?.traits = social.petTraits
        friend?.traits = social.friendTraits
    }

    // MARK: Scheduled runs

    func setTellsScheduled(_ on: Bool) {
        tellsScheduled = on
        host?.preferences.setValue(on, forKey: Key.tellsScheduled)
    }

    func setScheduledOnSign(_ on: Bool) {
        scheduledOnSign = on
        host?.preferences.setValue(on, forKey: Key.scheduledOnSign)
    }

    /// A scheduled run starting, finishing or failing: it says when one
    /// starts, and comes over with the result when it's done.
    private func scheduledRun(_ task: String, state: AgentStatus.State, result: String?) {
        let said = result.flatMap { $0.isEmpty ? nil : $0 }
        switch state {
        case .working:
            cat?.say(CatWords.scheduledStarted(task))
        case .done:
            cat?.callOver()
            cat?.say(CatWords.scheduledDone(task, said), essential: true)
            cat?.celebrate()
            if scheduledOnSign { addNote("\(task): \(said ?? "done")", timed: false) }
        case .error:
            cat?.callOver()
            cat?.say(CatWords.scheduledFailed(task, said), essential: true)
            if scheduledOnSign { addNote("\(task) failed", timed: false) }
        case .waiting:
            cat?.callOver()
            cat?.say(CatWords.scheduledWaiting(task))
        }
    }

    // MARK: Agents asking

    func setAnswersAsks(_ on: Bool) {
        answersAsks = on
        host?.preferences.setValue(on, forKey: Key.answersAsks)
        if !on { skipAllAsks() }
        tickAsks()
    }

    func setTouchIDForRisky(_ on: Bool) {
        touchIDForRisky = on
        host?.preferences.setValue(on, forKey: Key.touchIDForRisky)
    }

    func setReadsAsksAloud(_ on: Bool) {
        readsAsksAloud = on
        host?.preferences.setValue(on, forKey: Key.readsAsksAloud)
        if !on { voice.stopSpeaking(at: .immediate) }
    }

    /// A question an agent's hook left (`ask?id=…`): the pet comes over,
    /// says it and holds up the answers. One at a time; the rest wait.
    private func handleAsk(id: String) {
        guard let ask = AgentAsk.load(id: id) else { return }
        guard tellsAgents, answersAsks, let cat, isOut, Self.atTheMac else { return ask.answer(AgentAsk.skip) }
        guard cat.askShown?.id != ask.id, !askQueue.contains(where: { $0.id == ask.id }) else { return }
        askQueue.append(ask)
        if cat.askShown == nil { showNextAsk() }
    }

    private func showNextAsk() {
        guard let cat else { return }
        askQueue.removeAll { !$0.isOpen }
        guard !askQueue.isEmpty else { return putUp(nil) }
        let ask = askQueue.removeFirst()
        cat.callOver()
        putUp(ask)
        askShownAt = Date()
        let risk = ask.risk
        if risk != nil {
            cat.bristle()
            countStat(.carefulAsks)
        }
        CatSounds.shared.play(risk == nil ? .meow : .hiss, voice: cat.kind)
        if readsAsksAloud {
            let said = ask.spoken ?? "\(ask.agent) needs you. \(ask.title)"
            let speech = AVSpeechUtterance(string: risk.map { "Careful. \($0). \(said)" } ?? said)
            speech.voice = AVSpeechSynthesisVoice(language: "en-US")
            voice.stopSpeaking(at: .immediate)
            voice.speak(speech)
        }
    }

    /// Allowing a risky one takes Touch ID, or your Mac's password: a
    /// stray click or key can't let it through. Deny, a typed answer and
    /// handing it back don't.
    private func answer(_ ask: AgentAsk, with choice: String) {
        let allows = choice != AgentAsk.skip && !choice.hasPrefix(AgentAsk.typedPrefix) && !choice.localizedCaseInsensitiveContains("deny")
        guard let risk = ask.risk, allows, touchIDForRisky else { return answered(ask, with: choice) }
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return answered(ask, with: choice) }
        guard !confirmingRisky else { return }
        confirmingRisky = true
        context.localizedCancelTitle = "Not now"
        let reason = "allow \(ask.agent) to run this: \(risk.prefix(1).lowercased() + risk.dropFirst())"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] allowed, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.confirmingRisky = false
                    guard allowed else {
                        self.cat?.say(CatWords.notAllowed)
                        return
                    }
                    guard ask.isOpen, self.openAsk?.id == ask.id else { return }
                    self.answered(ask, with: choice)
                }
            }
        }
    }

    private func answered(_ ask: AgentAsk, with choice: String) {
        ask.answer(choice)
        voice.stopSpeaking(at: .immediate)
        putUp(nil)
        if choice != AgentAsk.skip { cat?.say(CatWords.askAnswered(ask.agent, choice)) }
        showNextAsk()
    }

    /// Hands every open question back to its agent.
    private func skipAllAsks() {
        if let shown = cat?.askShown { shown.answer(AgentAsk.skip) }
        askQueue.forEach { $0.answer(AgentAsk.skip) }
        askQueue = []
        putUp(nil)
    }

    /// Holds a question up on the card, and in the menu bar's menu; nil
    /// takes it down from both.
    private func putUp(_ ask: AgentAsk?) {
        openAsk = ask
        cat?.showAsk(ask) { [weak self] choice in
            if let ask { self?.answer(ask, with: choice) }
        }
    }

    /// An answer clicked in the menu bar's menu, for the question still up.
    func answerOpenAsk(_ choice: String) {
        guard let ask = openAsk, ask.isOpen, choice == AgentAsk.skip || ask.options.contains(choice) else { return }
        answer(ask, with: choice)
    }

    /// You're at the Mac: the screen isn't locked and you've touched the
    /// keyboard or mouse in the last minute. Away (say, driving Claude from
    /// your phone with Remote Control), questions go straight back to Claude,
    /// which asks you wherever you are.
    private static var atTheMac: Bool {
        !ReturnWatcher.screenIsLocked && CatController.secondsSinceInput() < 60
    }

    /// Each second: tells the hooks someone is here to answer (or that
    /// nobody is), and takes down a question its agent stopped asking.
    private func tickAsks() {
        tickCommands()
        tickServer()
        publishLockScreen()
        readAgentFiles()
        if Date().timeIntervalSince(usageCheckedAt) >= 60 {
            usageCheckedAt = Date()
            checkClaudeUsage()
            askClaudeUsage()
            refreshPlanUsage()
        }
        if musicStoppedAt != nil { updateLofi(playing: cat?.musicPlaying ?? false) }
        let here = tellsAgents && answersAsks && isOut && cat != nil && Self.atTheMac
        if here {
            if Date().timeIntervalSince(aliveAt) >= 15 {
                try? FileManager.default.createDirectory(at: AgentAsk.folder, withIntermediateDirectories: true)
                try? "\(Date().timeIntervalSince1970)".write(to: AgentAsk.alive, atomically: true, encoding: .utf8)
                aliveAt = Date()
            }
        } else if aliveAt != .distantPast {
            try? FileManager.default.removeItem(at: AgentAsk.alive)
            aliveAt = .distantPast
            skipAllAsks()
        }
        // A tool's tag comes down once the agent has gone quiet a while.
        if Date() >= toolAt { cat?.showTool(nil) }
        // Up a while and you've walked away: back to Claude with it.
        if let shown = cat?.askShown, shown.isOpen, !Self.atTheMac, Date().timeIntervalSince(askShownAt) >= 20 {
            skipAllAsks()
        }
        if let shown = cat?.askShown, !shown.isOpen {
            voice.stopSpeaking(at: .immediate)
            putUp(nil)
            showNextAsk()
        }
    }

    private func sweepAgents() {
        let now = Date()
        let kept = agents.filter { _, agent in
            switch agent.state {
            case .working: now.timeIntervalSince(agent.at) < 4 * 60 * 60
            case .waiting: now.timeIntervalSince(agent.at) < 30 * 60
            case .done, .error: now.timeIntervalSince(agent.at) < 90
            }
        }
        if kept.count != agents.count {
            agents = kept
            publishActivity()
            refreshKeepAwake()
        }
    }

    func setAwakeForAgents(_ on: Bool) {
        awakeForAgents = on
        host?.preferences.setValue(on, forKey: Key.awakeForAgents)
        refreshKeepAwake()
    }

    /// While an agent is working the Mac stays awake, so a long run is not
    /// cut short; the screen may still go dark. Let go the moment none is.
    /// A closed lid still sleeps a laptop that is not on an external display.
    private func refreshKeepAwake() {
        // The pets code along at their laptops while one works.
        let working = agents.values.contains { $0.state == .working }
        cat?.agentWorking = working
        friend?.agentWorking = working
        let wanted = awakeForAgents && working
        if wanted, awakeAssertion == nil {
            var id = IOPMAssertionID(0)
            let made = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                   IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                   "Pixpaw: a coding agent is working" as CFString, &id)
            if made == kIOReturnSuccess {
                awakeAssertion = id
                host?.log.debug("keeping the Mac awake for an agent")
            }
        } else if !wanted, let id = awakeAssertion {
            IOPMAssertionRelease(id)
            awakeAssertion = nil
            host?.log.debug("letting the Mac sleep again")
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

    /// A friend of another kind: a dog for your cat, a rabbit for your shark.
    func setFriendKind(_ kind: PetKind?) {
        friendKind = kind
        host?.preferences.setValue(kind?.rawValue ?? "", forKey: Key.friendKind)
        friend?.kind = friendsKind
    }

    /// The friend's character: the one chosen for it, or else your pet's.
    var friendsKind: PetKind {
        if let friendKind, !friendKind.isOwn || OwnPets.pet(friendKind) != nil { return friendKind }
        return cat?.kind ?? .cat
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
                kind: friendsKind, coat: friendCoat, chasesPointer: cat.chasesPointer, roaming: cat.roaming,
                pouncesOnDrags: cat.pouncesOnDrags, chatty: false, pets: 0,
                hat: CatAccessory(rawValue: host.preferences.value(forKey: Key.friendHat, default: "")),
                collar: CatAccessory(rawValue: host.preferences.value(forKey: Key.friendCollar, default: "")),
                lastFed: cat.lastFed
            )
            friend.isFriend = true
            // Dressed from its own menu, with your pet's stars; kept for next time.
            friend.onPersist = { [weak self, weak friend] in
                guard let friend else { return }
                self?.host?.preferences.setValue(friend.hat?.rawValue ?? "", forKey: Key.friendHat)
                self?.host?.preferences.setValue(friend.collar?.rawValue ?? "", forKey: Key.friendCollar)
            }
            friend.traits = social.friendTraits
            friend.typesAlong = typesAlong
            friend.carriesFiles = carriesFiles
            friend.onDeliver = { [weak self] urls in self?.addToShelf(urls) }
            friend.forwardAward = { [weak cat] source in cat?.earn(source) }
            // What its menu offers that isn't the friend's own (a photo, a
            // GIF, focus, lofi, a note) does the same as from your pet's.
            friend.onPhoto = cat.onPhoto
            friend.onCapturePage = cat.onCapturePage
            friend.droppyTools = cat.droppyTools
            friend.onDroppyTool = cat.onDroppyTool
            friend.droppyFocusing = cat.droppyFocusing
            friend.cardStyle = cat.cardStyle
            friend.cardOpensOnClick = cat.cardOpensOnClick
            friend.onRecordGIF = cat.onRecordGIF
            friend.onFocus = cat.onFocus
            friend.focusLabel = cat.focusLabel
            friend.onLofi = cat.onLofi
            friend.onPauseLofi = cat.onPauseLofi
            friend.lofiLabel = cat.lofiLabel
            friend.localServer = cat.localServer
            friend.onOpenServer = cat.onOpenServer
            friend.failedCI = cat.failedCI
            friend.onOpenFailedCI = cat.onOpenFailedCI
            friend.onAskSign = cat.onAskSign
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
        // Indoors, or the row switched off: nothing beside the notch. A
        // focus session shows its clock there either way.
        guard isOut, isPinned || inSession, let cat else {
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
        prefs.setValue(cat.meals, forKey: Key.meals)
        prefs.setValue(cat.giftDay, forKey: Key.giftDay)
        prefs.setValue(cat.plays, forKey: Key.plays)
        prefs.setValue(cat.stretches, forKey: Key.stretches)
        prefs.setValue(cat.homeX.map(Double.init) ?? -1, forKey: Key.homeX)
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

extension PixpawDroplet: LockScreenStatusProviding {
    public var lockScreenStatus: AnyPublisher<LockScreenStatusEntry?, Never> {
        lockSubject.eraseToAnyPublisher()
    }

    /// Each second: what to see on the lock screen when you come back. An
    /// agent that needs you first, then the focus or break clock, a long
    /// command, how your agents got on, and otherwise what your pet is up to.
    fileprivate func publishLockScreen() {
        let entry = lockScreenEntry()
        if lockSubject.value != entry { lockSubject.send(entry) }
    }

    private func lockScreenEntry() -> LockScreenStatusEntry? {
        // Droppy's lock screen says it already while the pet uses Droppy's tools.
        if usesDroppyTools, tools.isAvailable { return nil }
        let now = Date()
        let mine = tellsAgents ? agents.values.sorted { $0.name < $1.name } : []
        if let waiting = mine.first(where: { $0.state == .waiting }) {
            return LockScreenStatusEntry(id: "pixpaw.agent", systemImage: "hand.raised.fill", text: "\(waiting.name) needs you",
                                         roundedCenterText: "!", roundedBottomText: String(waiting.name.prefix(10)), ticksEverySecond: false)
        }
        if let end = focusEndsAt ?? breakEndsAt, let start = focusStartedAt ?? breakStartedAt, end > now {
            let left = end.timeIntervalSince(now), length = max(1, end.timeIntervalSince(start))
            let focus = focusEndsAt != nil
            let seconds = Int(left.rounded(.up))
            let name = focus ? (pomodoroOn ? "Focus · round \(pomodoroRound)" : "Focus") : "Break"
            return LockScreenStatusEntry(id: "pixpaw.session", systemImage: focus ? "timer" : "cup.and.saucer.fill",
                                         text: String(format: "%d:%02d", seconds / 60, seconds % 60), detail: name,
                                         roundedCenterText: "\(Int((left / 60).rounded(.up)))", roundedBottomText: focus ? "Focus" : "Break",
                                         progress: left / length, ticksEverySecond: true)
        }
        if showsWaits, let waiting = commands.first(where: { now.timeIntervalSince($0.since) >= RunningCommand.waitsAfter }) {
            return LockScreenStatusEntry(id: "pixpaw.command", systemImage: "hourglass", text: waiting.label,
                                         detail: RunningCommand.length(now.timeIntervalSince(waiting.since)),
                                         roundedCenterText: "\(Int(now.timeIntervalSince(waiting.since) / 60))m", roundedBottomText: waiting.label, ticksEverySecond: false)
        }
        if let snag = mine.first(where: { $0.state == .error }) {
            return LockScreenStatusEntry(id: "pixpaw.agent", systemImage: "exclamationmark.triangle.fill", text: "\(snag.name) hit a snag",
                                         roundedCenterText: "!", roundedBottomText: String(snag.name.prefix(10)), ticksEverySecond: false)
        }
        let working = mine.filter { $0.state == .working }
        if !working.isEmpty {
            let text = working.count == 1 ? "\(working[0].name) working" : "\(working.count) agents working"
            return LockScreenStatusEntry(id: "pixpaw.agent", systemImage: "sparkles", text: text,
                                         roundedCenterText: "…", roundedBottomText: working.count == 1 ? String(working[0].name.prefix(10)) : "Working", ticksEverySecond: false)
        }
        if let done = mine.first(where: { $0.state == .done }) {
            return LockScreenStatusEntry(id: "pixpaw.agent", systemImage: "checkmark.circle.fill", text: "\(done.name) done", detail: done.diff,
                                         roundedCenterText: "✓", roundedBottomText: "Done", ticksEverySecond: false)
        }
        guard let cat else { return nil }
        return LockScreenStatusEntry(id: "pixpaw.pet", systemImage: isOut ? "pawprint.fill" : "moon.zzz.fill",
                                     text: isOut ? cat.statusTitle : "Napping in the notch", roundedCenterText: isOut ? "♥" : "Zzz",
                                     roundedBottomText: cat.kind.title, ticksEverySecond: false)
    }
}

extension PixpawDroplet: MenuBarExtraProviding {
    /// A gauge in the menu bar: how much is left of each agent's plan, and
    /// what your agents are up to. Turned off in Settings, it goes away.
    public func makeMenuBarExtra() -> MenuBarExtraDescriptor? {
        // Droppy's Agents has a gauge of its own while the pet uses Droppy's tools.
        guard showsMenuBar, !(usesDroppyTools && tools.isOn("agents")) else { return nil }
        return MenuBarExtraDescriptor(title: "Pixpaw: AI Usage left", systemImage: menuBarSymbol) { [self] in
            AnyView(PixpawMenuBarMenu(droplet: self))
        }
    }
}

/// The menu under the gauge: what your pet is up to, your agents, and a
/// bar for each window of each plan, green, then amber at 20% and red at 10%.
private struct PixpawMenuBarMenu: View {
    @ObservedObject var droplet: PixpawDroplet

    private static let labelWidth: CGFloat = 38
    private static let barWidth: CGFloat = 118

    var body: some View {
        // Counts down the reset times while the menu is open.
        TimelineView(.periodic(from: .now, by: 15)) { timeline in
            VStack(alignment: .leading, spacing: DroppySpacing.md) {
                Label(droplet.isOut ? droplet.cat?.statusTitle ?? "Out and about" : "Napping in the notch",
                      systemImage: droplet.isOut ? "pawprint.fill" : "moon.zzz.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                    .lineLimit(1)
                if let ask = droplet.menuAsk { askBox(ask) }
                let agents = droplet.menuAgents
                if !agents.isEmpty {
                    section("Agents") {
                        ForEach(agents, id: \.name) { agentRow($0, now: timeline.date) }
                    }
                }
                section("AI Usage left") {
                    if droplet.planUsage.isEmpty {
                        Text("Shows up once Claude Code, Antigravity or Codex reports it. Needs the hooks in the README.")
                            .font(.system(size: 11))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(PlanUsage.byAgent(droplet.planUsage)) { agentPlans($0, now: timeline.date) }
                        if let other = droplet.planToSwitchTo, let left = other.lowest {
                            Label("Most left: \(AgentLook.name(other)) \(left)%",
                                  systemImage: "arrow.triangle.swap")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                        }
                    }
                }
                if let port = droplet.localServer {
                    Button { droplet.openLocalServer() } label: {
                        Label("Open localhost:\(String(port))", systemImage: "safari")
                    }
                    .buttonStyle(DroppyQuietButtonStyle(size: .small))
                }
            }
            .foregroundStyle(AdaptiveColors.primaryTextAuto)
            .padding(.vertical, DroppySpacing.xs)
            .frame(width: 290, alignment: .leading)
        }
    }

    /// The question up on the pet's card, with the same answers: a risky one
    /// says why and puts no answer forward.
    private func askBox(_ ask: AgentAsk) -> some View {
        let risk = ask.risk
        return VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            Label(ask.place.map { "\(ask.agent) asks · \($0)" } ?? "\(ask.agent) asks", systemImage: "hand.raised.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
            if let risk {
                Label("Careful: \(risk.prefix(1).lowercased() + risk.dropFirst())", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
            }
            Text(ask.title)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = ask.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(3)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill((risk == nil ? AdaptiveColors.contrastTintAuto : .red).opacity(0.1)))
            }
            HStack(spacing: DroppySpacing.xs) {
                ForEach(Array(ask.options.enumerated()), id: \.offset) { index, option in
                    if index == 0 && risk == nil {
                        Button(option) { droplet.answerOpenAsk(option) }
                            .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                    } else {
                        Button(option) { droplet.answerOpenAsk(option) }
                            .buttonStyle(DroppyQuietButtonStyle(size: .small))
                    }
                }
            }
            .lineLimit(1)
            Button("Answer in \(ask.agent) instead") { droplet.answerOpenAsk(AgentAsk.skip) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
        }
        .padding(DroppySpacing.sm)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.1)))
        .accessibilityElement(children: .contain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
            content()
        }
    }

    private func agentRow(_ agent: AgentStatus, now: Date) -> some View {
        let (symbol, tint): (String, Color) = switch agent.state {
        case .waiting: ("hand.raised.fill", .orange)
        case .error: ("exclamationmark.triangle.fill", .red)
        case .working: ("sparkles", AdaptiveColors.secondaryTextAuto)
        case .done: ("checkmark.circle.fill", .green)
        }
        let minutes = Int(now.timeIntervalSince(agent.at) / 60)
        let since = minutes < 1 ? "just now" : minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h"
        let state = agent.state == .done ? agent.diff ?? "Done" : agent.state.title.prefix(1).uppercased() + agent.state.title.dropFirst()
        return HStack(spacing: DroppySpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(agent.name)
                .font(.system(size: 13, weight: .medium))
            Text(state)
                .font(.system(size: 12))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                .lineLimit(1)
            Spacer(minLength: DroppySpacing.sm)
            Text(since)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
        }
    }

    /// A box per agent in its own color: its name and how fresh the numbers
    /// are, then each model group (Antigravity's) with its windows.
    private func agentPlans(_ agent: AgentPlans, now: Date) -> some View {
        let look = AgentLook(agent.agent)
        return VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DroppySpacing.xs) {
                Image(systemName: look.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(look.color)
                Text(look.name)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: DroppySpacing.sm)
                if let age = agent.plans.max(by: { $0.at < $1.at })?.age(now: now) {
                    Text(age)
                        .font(.system(size: 11))
                        .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                }
            }
            ForEach(agent.plans) { plan($0, now: now) }
        }
        .padding(DroppySpacing.sm)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(look.color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(look.color.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func plan(_ usage: PlanUsage, now: Date) -> some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            if let group = usage.group {
                Text(group)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
            }
            ForEach(usage.windows) { window in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DroppySpacing.sm) {
                        Text(window.label)
                            .font(.system(size: 12))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                            .frame(width: Self.labelWidth, alignment: .leading)
                        bar(window)
                        Spacer(minLength: DroppySpacing.sm)
                        Text("\(window.left)% left")
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(window.level == .plenty ? AdaptiveColors.primaryTextAuto : tint(window.level))
                    }
                    let reset = window.resetText(now: now), pace = window.paceText(now: now)
                    if reset != nil || pace != nil {
                        HStack(spacing: 0) {
                            if let reset {
                                Text(pace == nil ? reset : "\(reset) · ")
                                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                            }
                            if let pace {
                                Text(pace)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.system(size: 11).monospacedDigit())
                        .lineLimit(1)
                        .padding(.leading, Self.labelWidth + DroppySpacing.sm)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func bar(_ window: PlanWindow) -> some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(AdaptiveColors.contrastTintAuto.opacity(0.12))
            Capsule(style: .continuous)
                .fill(tint(window.level))
                .frame(width: max(window.left > 0 ? 4 : 0, Self.barWidth * CGFloat(window.left) / 100))
        }
        .frame(width: Self.barWidth, height: 5)
    }

    private func tint(_ level: PlanWindow.Level) -> Color {
        switch level {
        case .plenty: .green
        case .low: .orange
        case .out: .red
        }
    }
}

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
                    // Header (28), the pet and its lines (about 94 laid out), the control
                    // row (34) and two 8pt gaps, plus the 16pt the host's
                    // insets take: nothing squeezed against the floor.
                    contentHeight: .fixed(190)
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

/// How each agent shows wherever its usage does (the widget, the menu bar,
/// Settings): its name, a mark and a color of its own, so it's plain whose
/// numbers are whose.
struct AgentLook {
    let name: String
    let symbol: String
    let color: Color

    init(_ agent: String) {
        let look: (String, String, Color) = switch agent.lowercased() {
        case "claude", "claude code": ("Claude Code", "sparkle", Color(red: 0.85, green: 0.47, blue: 0.34))
        case "antigravity": ("Antigravity", "paperplane.fill", Color(red: 0.42, green: 0.58, blue: 1.0))
        case "codex": ("Codex", "terminal.fill", Color(red: 0.30, green: 0.76, blue: 0.62))
        case "cursor": ("Cursor", "cursorarrow.rays", Color(red: 0.70, green: 0.55, blue: 0.95))
        default: (agent, "cpu", .gray)
        }
        name = look.0
        symbol = look.1
        color = look.2
    }

    /// "Claude Code", "Antigravity · Gemini".
    static func name(_ plan: PlanUsage) -> String {
        let agent = AgentLook(plan.agent).name
        return plan.group.map { "\(agent) · \($0)" } ?? agent
    }
}

/// The widget's second page, AI Usage left: what's left of each coding
/// agent's plan in a section of its own, and a question your agent asks with
/// its answers. Solo it's a small table, five hours and week side by side;
/// paired, each plan's emptier window.
private struct UsageLeftPage: View {
    @ObservedObject var droplet: PixpawDroplet
    let context: ShelfWidgetContext

    private static let nameWidth: CGFloat = 112
    private static let barWidth: CGFloat = 44
    private static let percentWidth: CGFloat = 38
    private static var columnWidth: CGFloat { barWidth + DroppySpacing.xs + percentWidth }

    /// The rule down the side of each agent's section, and what's left of
    /// the name column beside it.
    private static let ruleWidth: CGFloat = 3
    private static var sectionNameWidth: CGFloat { nameWidth - ruleWidth - DroppySpacing.sm }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                if let ask = droplet.menuAsk {
                    askCard(ask)
                }
                if droplet.planUsage.isEmpty {
                    empty
                } else if droplet.menuAsk != nil {
                    // The question takes the room: each agent's emptiest window on one line.
                    ViewThatFits(in: .horizontal) {
                        summary(named: true)
                        summary(named: false)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        sections(now: timeline.date)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            Text("No numbers yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            Text("They show up after Claude Code, Antigravity or Codex finishes a turn with Pixpaw's hooks on.")
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The question

    /// Who asks and what, with the answers beside it; underneath, the command
    /// it's about, or why it's risky.
    private func askCard(_ ask: AgentAsk) -> some View {
        let risk = ask.risk
        // Paired, Always allow makes room for Deny.
        let options = context.isPaired ? Array(ask.options.filter { $0 != "Always allow" }.prefix(2)) : Array(ask.options.prefix(3))
        return VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            HStack(spacing: DroppySpacing.xs) {
                Image(systemName: risk == nil ? "hand.raised.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(risk == nil ? .orange : .red)
                Text(ask.agent)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(risk == nil ? .orange : .red)
                Text(ask.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                    .lineLimit(1)
                if !context.isPaired {
                    Spacer(minLength: DroppySpacing.xs)
                    answers(options, ask: ask)
                }
            }
            if let line = risk ?? ask.detail, !line.isEmpty {
                Text(line)
                    .font(risk == nil ? .system(size: 11, design: .monospaced) : .system(size: 11, weight: .semibold))
                    .foregroundStyle(risk == nil ? AdaptiveColors.notchSurfaceSecondaryText : .red)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous)
                        .fill(AdaptiveColors.notchSurfaceCardFill))
            }
            if context.isPaired {
                answers(options, ask: ask)
            }
        }
    }

    /// The first answer stands out, unless the ask is risky.
    private func answers(_ options: [String], ask: AgentAsk) -> some View {
        HStack(spacing: DroppySpacing.xs) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                if index == 0 && ask.risk == nil {
                    Button(option) { droplet.answerOpenAsk(option) }
                        .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                } else {
                    Button(option) { droplet.answerOpenAsk(option) }
                        .buttonStyle(DroppyQuietButtonStyle(size: .small))
                }
            }
        }
        .lineLimit(1)
        .fixedSize()
        .droppyFlatGlassControls()
    }

    // MARK: Usage

    /// A section per agent; solo, five hours and week in columns under one
    /// heading each, and when one runs dry at this pace at the end of its row.
    private func sections(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !context.isPaired {
                HStack(spacing: DroppySpacing.md) {
                    Color.clear.frame(width: Self.nameWidth, height: 1)
                    Text("5 hours").frame(width: Self.columnWidth, alignment: .leading)
                    Text("Week").frame(width: Self.columnWidth, alignment: .leading)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            }
            ForEach(PlanUsage.byAgent(droplet.planUsage)) { section($0, now: now) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "✦ Claude Code 59%  ✈ Antigravity 18%", or just the marks when that
    /// doesn't fit.
    private func summary(named: Bool) -> some View {
        HStack(spacing: DroppySpacing.md) {
            ForEach(PlanUsage.byAgent(droplet.planUsage)) { agent in
                let look = AgentLook(agent.agent)
                let window = agent.plans.flatMap(\.windows).min { $0.left < $1.left }
                HStack(spacing: 4) {
                    Image(systemName: look.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(look.color)
                    if named {
                        Text(look.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                    }
                    if let window { percent(window) }
                }
                .fixedSize()
                .help(look.name)
            }
        }
    }

    /// One agent, with a rule in its color down the side: its mark and name,
    /// with its numbers on that line (Claude Code, Codex) or a line for each
    /// model group under it (Antigravity).
    private func section(_ agent: AgentPlans, now: Date) -> some View {
        let look = AgentLook(agent.agent)
        return VStack(alignment: .leading, spacing: 2) {
            row(agent.single, now: now) {
                HStack(spacing: 4) {
                    Image(systemName: look.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(look.color)
                    Text(look.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                }
            }
            if agent.single == nil {
                ForEach(agent.plans) { plan in
                    row(plan, now: now) {
                        Text(plan.group ?? look.name)
                            .font(.system(size: 12))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            .padding(.leading, context.isPaired ? 8 : 13)
                    }
                    .help(AgentLook.name(plan))
                }
            }
        }
        .padding(.leading, Self.ruleWidth + DroppySpacing.sm)
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(look.color)
                .frame(width: Self.ruleWidth)
        }
        .accessibilityElement(children: .combine)
    }

    /// A name, then the plan's numbers if it has one: solo both windows and
    /// the pace; paired the emptier window.
    private func row<Name: View>(_ plan: PlanUsage?, now: Date, @ViewBuilder name: () -> Name) -> some View {
        HStack(spacing: context.isPaired ? DroppySpacing.xs : DroppySpacing.md) {
            name()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: context.isPaired ? nil : Self.sectionNameWidth, alignment: .leading)
            if context.isPaired {
                Spacer(minLength: DroppySpacing.xs)
                if let plan { pairedNumbers(plan, now: now) }
            } else {
                if let plan {
                    cell(plan.windows.first { $0.label == "5h" })
                    cell(plan.windows.first { $0.label == "Week" })
                }
                Spacer(minLength: 0)
                if let plan, let window = plan.windows.first(where: { $0.paceText(now: now) != nil }),
                   let pace = window.paceText(now: now), let when = window.paceShort(now: now) {
                    Label(when, systemImage: "timer")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .fixedSize()
                        .help(pace)
                }
            }
        }
    }

    private func cell(_ window: PlanWindow?) -> some View {
        HStack(spacing: DroppySpacing.xs) {
            if let window {
                bar(window, width: Self.barWidth)
                percent(window)
                    .frame(width: Self.percentWidth, alignment: .trailing)
            } else {
                Text("–")
                    .font(.system(size: 11))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            }
        }
        .frame(width: Self.columnWidth, alignment: .leading)
    }

    /// The emptier window: its bar, percent and which it is; an orange timer
    /// when it runs dry before it resets.
    @ViewBuilder private func pairedNumbers(_ plan: PlanUsage, now: Date) -> some View {
        if let window = plan.windows.min(by: { $0.left < $1.left }) {
            HStack(spacing: DroppySpacing.xs) {
                if let pace = window.paceText(now: now) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                        .help(pace)
                }
                bar(window, width: 22)
                percent(window)
                    .frame(width: 34, alignment: .trailing)
                Text(window.label == "Week" ? "wk" : window.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                    .frame(width: 14, alignment: .leading)
            }
        }
    }

    private func percent(_ window: PlanWindow) -> some View {
        Text("\(window.left)%")
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(window.level == .plenty ? AdaptiveColors.notchSurfacePrimaryText : tint(window.level))
    }

    private func bar(_ window: PlanWindow, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(AdaptiveColors.notchSurfaceCardFill)
            Capsule(style: .continuous)
                .fill(tint(window.level))
                .frame(width: max(window.left > 0 ? 4 : 0, width * CGFloat(window.left) / 100))
        }
        .frame(width: width, height: 5)
    }

    private func tint(_ level: PlanWindow.Level) -> Color {
        switch level {
        case .plenty: .green
        case .low: .orange
        case .out: .red
        }
    }
}

private struct PixpawWidget: View {
    @ObservedObject var droplet: PixpawDroplet
    @ObservedObject var cat: CatController
    let context: ShelfWidgetContext

    /// Droppy's shelf sizes: a control alone on the shelf is 34pt, beside
    /// another widget 28, the header's toggles 28, a small choice 24.
    private var actionSize: CGFloat { context.isPaired ? 28 : 34 }
    private static let headerSize: CGFloat = 28
    private static let choiceSize: CGFloat = 24

    var body: some View {
        // The header on the card's top edge, the control row on its bottom
        // edge, and the room between them shared above and below the pet,
        // the way Droppy's own widgets sit on the shelf's lines.
        VStack(alignment: .leading, spacing: 0) {
            header
            if droplet.widgetShowsPlans {
                Spacer(minLength: DroppySpacing.sm)
                UsageLeftPage(droplet: droplet, context: context)
                Spacer(minLength: 0)
            } else {
                petPage
            }
        }
        .padding(context.contentInsets)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        // One family of controls on the shelf: the header's buttons draw the
        // same flat wash as the row of controls under the pet.
        .droppyFlatGlassControls()
    }

    @ViewBuilder private var petPage: some View {
            Spacer(minLength: DroppySpacing.sm)
            HStack(alignment: .center, spacing: DroppySpacing.md) {
                portrait
                VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                    Text(droplet.isOut ? cat.statusTitle : "Indoors")
                        .font(.system(size: context.isCompact ? 15 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                        .lineLimit(1)
                    subline
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    fullnessBar
                    togetherLine
                    if let summary = droplet.agentSummary {
                        symbolText("sparkles", summary)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: DroppySpacing.sm)
            if !context.isCompact {
                controls
            }
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: droplet.widgetShowsPlans ? "gauge.with.dots.needle.67percent" : "pawprint.fill")
                .font(.system(size: 12, weight: .medium))
            Text(droplet.widgetShowsPlans ? "AI Usage left" : "Pixpaw")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            if droplet.widgetShowsPlans, !context.isPaired, let other = droplet.planToSwitchTo, let left = other.lowest {
                Text("Most left: \(AgentLook.name(other)) \(left)%")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button {
                droplet.toggleWidgetPlans()
            } label: {
                Image(systemName: droplet.widgetShowsPlans ? "pawprint.fill" : droplet.openAsk != nil ? "hand.raised.fill" : "gauge.with.dots.needle.67percent")
                    .foregroundStyle(droplet.openAsk != nil && !droplet.widgetShowsPlans ? Color.orange : AdaptiveColors.notchSurfaceSecondaryText)
            }
            .buttonStyle(DroppyCircleButtonStyle(size: Self.headerSize))
            .help(droplet.widgetShowsPlans ? "Back to your pet" : "AI Usage left: what's left of each AI's plan")
            .accessibilityLabel(droplet.widgetShowsPlans ? "Show your pet" : "Show AI usage left")
            if !droplet.widgetShowsPlans {
                petButtons
            }
        }
        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
    }

    @ViewBuilder private var petButtons: some View {
            // Paired, the photo makes room for the plan button; it's in the pet's menu too.
            if !context.isPaired {
                Button {
                    droplet.takePhoto()
                } label: {
                    Image(systemName: "camera")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: Self.headerSize))
                .help("Take a photo of your pet")
                .accessibilityLabel("Take a photo of your pet")
            }
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
            .buttonStyle(DroppyCircleButtonStyle(size: Self.headerSize))
            .help("Character: \(cat.kind.title). Click to change.")
            .accessibilityLabel("Change character, now \(cat.kind.title)")
            Button {
                droplet.toggleQuiet()
            } label: {
                Image(systemName: cat.quietReason == nil ? "bell" : "bell.slash.fill")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: Self.headerSize))
            .help(droplet.quietByHand ? "Let your pet talk again" : "Quiet: no speech bubbles")
            .accessibilityLabel(droplet.quietByHand ? "Turn quiet mode off" : "Turn quiet mode on")
            Button {
                droplet.toggle()
            } label: {
                Image(systemName: droplet.isOut ? "eye.slash" : "eye")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: Self.headerSize))
            .help(droplet.isOut ? "Bring your pet inside" : "Let your pet out")
            .accessibilityLabel(droplet.isOut ? "Hide your pet" : "Show your pet")
    }

    private var portrait: some View {
        let frame: CatFrame = droplet.isOut ? cat.frame : .sleep1
        return Group {
            if let image = CatSprites.shared.image(frame, coat: cat.coat, hat: cat.hat, collar: cat.collar,
                                                   headphones: droplet.isOut && cat.wearsHeadphones,
                                                   costume: droplet.isOut ? cat.costume : nil, kind: cat.kind,
                                                   laptop: droplet.isOut && cat.atLaptop) {
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

    /// A symbol, then words, as one Text. The symbol is joined on rather than
    /// interpolated into a literal: inside Droppy an interpolated Image came
    /// out spelled as "Image(provider: …)" instead of drawn.
    private func symbolText(_ symbol: String, _ words: String) -> Text {
        Text(Image(systemName: symbol)) + Text(verbatim: " " + words)
    }

    /// Why it is quiet, with a bell; otherwise its stars.
    private var subline: Text {
        if let start = droplet.focusStartedAt, let end = droplet.focusEndsAt {
            let round = droplet.pomodoroOn ? " \(droplet.pomodoroRound)/4" : ""
            return symbolText("timer", "Focus\(round), ") + Text(timerInterval: start...end, countsDown: true) + Text(" left")
        }
        if let start = droplet.breakStartedAt, let end = droplet.breakEndsAt {
            return symbolText("cup.and.saucer.fill", "Break, ") + Text(timerInterval: start...end, countsDown: true) + Text(" left")
        }
        if let reason = cat.quietReason { return symbolText("bell.slash.fill", "Quiet, \(reason)") }
        return Text(pointsLine)
    }

    /// "★ 37 · next: Bow at 45"
    private var pointsLine: String {
        let today = cat.starDay.day == StarDay.today ? cat.starDay.stars : 0
        if let next = CatAccessory.next(after: cat.points) {
            return "★ \(cat.points) · \(today)/\(StarSource.dailyTotal) today · \(next.title) at \(next.unlockAt)"
        }
        guard cat.hasHome else { return "★ \(cat.points) · \(today)/\(StarSource.dailyTotal) today · Home at \(CatController.homeUnlockAt)" }
        return "★ \(cat.points) · \(today)/\(StarSource.dailyTotal) today"
    }

    private var days: Int { droplet.daysTogether }

    /// "♥ 12 days ✋ 40 🐟 9 🎮 3 🧘 2": how long you have been together and how
    /// often you have petted, fed, played and stretched with it. Fewer of them
    /// when the row is narrow.
    private var togetherLine: some View {
        let tallies = [("heart.fill", days == 1 ? "1 day" : "\(days) days"), ("hand.raised.fill", "\(cat.pets)"),
                       ("fish.fill", "\(cat.meals)"), ("gamecontroller.fill", "\(cat.plays)"), ("figure.cooldown", "\(cat.stretches)")]
        let row = { (count: Int) in
            HStack(spacing: DroppySpacing.sm) {
                ForEach(tallies.prefix(count), id: \.0) { symbol, text in
                    HStack(spacing: 3) {
                        Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
                        Text(text)
                    }
                }
            }
        }
        return ViewThatFits(in: .horizontal) {
            row(5)
            row(4)
            row(2)
            row(1)
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
        .lineLimit(1)
        .help("Together \(days) \(days == 1 ? "day" : "days") · \(cat.pets) pets · \(cat.meals) meals · \(cat.plays) games · \(cat.stretches) stretches")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Together \(days) days, \(cat.pets) pets, \(cat.meals) meals, \(cat.plays) games, \(cat.stretches) stretches")
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
            HStack(spacing: DroppySpacing.xsm) {
                coatSwatches
            }
            Spacer(minLength: 0)
            actions
        }
    }

    @ViewBuilder private var coatSwatches: some View {
            ForEach(cat.kind.hasCoats ? CatCoat.choices : []) { coat in
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
                                    .foregroundStyle(coat.isDark ? Color.white : Color.black.opacity(0.7))
                            }
                        }
                }
                .buttonStyle(DroppyCircleButtonStyle(size: Self.choiceSize))
                .help(coat.title)
                .accessibilityLabel(coat.title)
            }
    }

    @ViewBuilder private var actions: some View {
            Button {
                droplet.feed()
            } label: {
                Image(systemName: "fork.knife")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: actionSize))
            .help("Feed your pet")
            .accessibilityLabel("Feed your pet")
            Button {
                droplet.napNow()
            } label: {
                Image(systemName: "moon.zzz.fill")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: actionSize))
            .disabled(cat.mood == .sleeping)
            .help("Nap now")
            .accessibilityLabel("Nap now")
            Button {
                droplet.toggleFocus()
            } label: {
                Image(systemName: droplet.breakEndsAt != nil ? "forward.end.fill" : droplet.focusEndsAt == nil ? "timer" : "stop.fill")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: actionSize))
            .help(droplet.breakEndsAt != nil ? "Skip the break" : droplet.focusEndsAt == nil ? "Focus for \(droplet.focusMinutes) minutes" : "Stop focusing")
            .accessibilityLabel(droplet.breakEndsAt != nil ? "Skip the break" : droplet.focusEndsAt == nil ? "Start focusing" : "Stop focusing")
            Button {
                droplet.callOver()
            } label: {
                // The pill as tall as the discs beside it.
                Text(cat.mood == .sleeping ? "Wake up" : "Come here")
                    .frame(minHeight: actionSize - 16)
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
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
                                                   headphones: cat.wearsHeadphones, costume: cat.costume, kind: cat.kind,
                                                   laptop: cat.atLaptop) {
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
        if let start = droplet.focusStartedAt ?? droplet.breakStartedAt, let end = droplet.focusEndsAt ?? droplet.breakEndsAt {
            // The time left, ticking down by itself.
            Text(timerInterval: start...end, countsDown: true)
                .monospacedDigit()
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(1)
                .accessibilityLabel(droplet.focusEndsAt != nil ? "Focus time left" : "Break time left")
        } else {
            mood
        }
    }

    private var mood: some View {
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

extension PixpawDroplet: SettingsPagesProviding {
    public func makeSettingsPage(id: String, context: SettingsPaneContext) -> AnyView? {
        guard let cat, let page = SettingsPage(rawValue: id) else { return nil }
        return AnyView(PixpawSettings(droplet: self, cat: cat, shown: page))
    }
}

extension PixpawDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        guard let cat else { return AnyView(EmptyView()) }
        return AnyView(PixpawSettings(droplet: self, cat: cat))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: "A second pet", keywords: ["cat", "friend", "two", "companion", "dog", "second", "pair"]),
            SettingsSearchEntry(title: "Wardrobe", keywords: ["cat", "hat", "collar", "points", "happiness", "unlock"]),
            SettingsSearchEntry(title: "Festival decorations", keywords: ["festival", "halloween", "new year", "christmas", "songkran", "valentine", "fireworks", "ghost", "snow"]),
            SettingsSearchEntry(title: "Focus session", keywords: ["focus", "pomodoro", "timer", "work", "break"]),
            SettingsSearchEntry(title: "Lofi", keywords: ["lofi", "lo-fi", "music", "study", "focus", "youtube", "spotify", "apple music", "lofi girl"]),
            SettingsSearchEntry(title: "Home", keywords: ["home", "house", "kennel", "hive", "nap", "sleep", "500", "unlock", "challenge"]),
            SettingsSearchEntry(title: "Break reminders", keywords: ["cat", "health", "stretch", "water", "eyes", "break", "reminder", "custom", "pill", "exercise"]),
            SettingsSearchEntry(title: "Sounds", keywords: ["cat", "meow", "purr", "sound", "mute"]),
            SettingsSearchEntry(title: "Your own pets", keywords: ["draw", "design", "custom", "own", "sprite", "pixel", "png", "aseprite", "piskel", "template", "import"]),
            SettingsSearchEntry(title: "Character", keywords: ["cat", "bee", "parrot", "bird", "dinosaur", "dino", "dog", "puppy", "hamster", "chicken", "hen", "giraffe", "hippo", "pig", "piggy", "hog", "hippopotamus", "rabbit", "bunny", "shark", "pet", "character", "animal", "coat", "colour", "color", "photo", "picture", "my cat", "fold", "folded", "ears", "scottish"]),
            SettingsSearchEntry(title: "Where it walks", keywords: ["cat", "roam", "windows", "bottom", "screen"]),
            SettingsSearchEntry(title: "Notes", keywords: ["sign", "note", "todo", "to-do", "task", "list", "reminder", "board", "placard", "streak"]),
            SettingsSearchEntry(title: "Countdowns", keywords: ["countdown", "days", "until", "trip", "deadline", "launch", "date"]),
            SettingsSearchEntry(title: "Join your next video call", keywords: ["meeting", "zoom", "meet", "teams", "webex", "join", "call"]),
            SettingsSearchEntry(title: "Pomodoro", keywords: ["pomodoro", "focus", "break", "timer", "rounds", "tomato"]),
            SettingsSearchEntry(title: "Nudge me back to work", keywords: ["distraction", "focus", "youtube", "procrastinate", "nudge", "social"]),
            SettingsSearchEntry(title: "Carry files to your shelf", keywords: ["shelf", "file", "drop", "carry", "fetch", "drag"]),
            SettingsSearchEntry(title: "Type along", keywords: ["typing", "keyboard", "keys", "bongo", "laptop", "type"]),
            SettingsSearchEntry(title: "Follow the cursor", keywords: ["cat", "chase", "pointer", "mouse"]),
            SettingsSearchEntry(title: "Pounce on dragged files", keywords: ["cat", "drag", "file", "pounce", "play"]),
            SettingsSearchEntry(title: "Quiet during calls and screen sharing", keywords: ["cat", "quiet", "meeting", "privacy", "share", "zoom"]),
            SettingsSearchEntry(title: "Mac notifications", keywords: ["cat", "speech", "bubble", "alert", "banner"]),
            SettingsSearchEntry(title: "Calendar events", keywords: ["cat", "meeting", "reminder", "event", "appointment"]),
            SettingsSearchEntry(title: "Battery", keywords: ["cat", "battery", "charge", "power", "sleepy", "yawn"]),
            SettingsSearchEntry(title: "Busy Mac", keywords: ["cpu", "heat", "hot", "busy", "fan", "load", "runcat", "sweat"]),
            SettingsSearchEntry(title: "Volume", keywords: ["cat", "sound", "volume", "mute", "speakers"]),
            SettingsSearchEntry(title: "Headphones", keywords: ["cat", "airpods", "bluetooth", "headset", "connect"]),
            SettingsSearchEntry(title: "Pose for screenshots", keywords: ["screenshot", "photo", "pose", "camera"]),
            SettingsSearchEntry(title: "GIF of your pet", keywords: ["gif", "animation", "share", "discord", "record", "video"]),
            SettingsSearchEntry(title: "A whole web page", keywords: ["screenshot", "full page", "safari", "chrome", "arc", "capture", "scroll", "web"]),
            SettingsSearchEntry(title: "Your birthday", keywords: ["birthday", "party", "confetti", "cake"]),
            SettingsSearchEntry(title: "Good morning", keywords: ["morning", "greeting", "wake", "calendar", "stretch"]),
            SettingsSearchEntry(title: "Welcome back", keywords: ["away", "return", "back", "hello", "greeting", "idle"]),
            SettingsSearchEntry(title: "Late nights", keywords: ["night", "late", "bedtime", "sleep", "nightcap", "midnight"]),
            SettingsSearchEntry(title: "Music", keywords: ["cat", "music", "song", "spotify", "youtube", "video", "dance", "now playing"]),
            SettingsSearchEntry(title: "Scheduled runs", keywords: ["schedule", "scheduled task", "loop", "cron", "routine", "result", "claude"]),
            SettingsSearchEntry(title: "Long commands and helpers", keywords: ["claude", "agent", "subagent", "helper", "test", "build", "command", "wait", "popcorn"]),
            SettingsSearchEntry(title: "Rock, paper, scissors", keywords: ["friend", "game", "coins", "bet", "personality", "character", "trait"]),
            SettingsSearchEntry(title: "What it's working on", keywords: ["claude", "agent", "file", "editing", "tool", "command"]),
            SettingsSearchEntry(title: "Answer from your pet", keywords: ["claude", "permission", "allow", "deny", "question", "agent", "approve", "type", "other", "answer", "instead"]),
            SettingsSearchEntry(title: "Touch ID to allow a risky one", keywords: ["touch id", "fingerprint", "password", "risky", "allow", "security", "rm", "sudo"]),
            SettingsSearchEntry(title: "Wait for CI after a push", keywords: ["ci", "github", "actions", "gh", "push", "checks", "build", "workflow"]),
            SettingsSearchEntry(title: "Talk to your pet", keywords: ["voice", "talk", "speak", "say", "microphone", "speech", "dictation", "siri", "command"]),
            SettingsSearchEntry(title: "Meeting notes", keywords: ["meeting", "notes", "minutes", "transcript", "summary", "summarize", "record", "call", "zoom", "meet", "teams", "microphone", "claude", "apple intelligence"]),
            SettingsSearchEntry(title: "Listen to", keywords: ["meeting", "microphone", "mac sound", "system audio", "screen recording", "call"]),
            SettingsSearchEntry(title: "Read questions aloud", keywords: ["voice", "speak", "speech", "aloud", "agent"]),
            SettingsSearchEntry(title: "Agent updates", keywords: ["cat", "claude", "codex", "cursor", "agent"]),
            SettingsSearchEntry(title: "Keep the Mac awake while agents work", keywords: ["sleep", "awake", "caffeinate", "agent", "claude", "codex"]),
            SettingsSearchEntry(title: "Beside the notch", keywords: ["cat", "live activity", "status", "notch"]),
            SettingsSearchEntry(title: "Photo of your pet", keywords: ["photo", "picture", "camera", "capture"]),
            SettingsSearchEntry(title: "Permissions", keywords: ["permission", "privacy", "allow", "access", "accessibility", "calendar", "microphone", "screen recording", "automation", "system settings"]),
            SettingsSearchEntry(title: "Agent hooks", keywords: ["hook", "hooks", "plugin", "setup", "install", "readme", "claude", "antigravity", "codex", "pixpaw-ask"]),
        ]
    }
}

/// The pages of Pixpaw's own under its page in Droppy's Settings.
enum SettingsPage: String, CaseIterable, Identifiable {
    case wardrobe, friend, moving, ownPets
    case ai, focus, notes, meetings, talk
    case tells, capture, festivals
    case permissions

    /// The main page's groups, by what you're there to do.
    static let groups: [(title: String, pages: [SettingsPage])] = [
        ("Your pet", [.wardrobe, .friend, .moving, .ownPets]),
        ("Working with you", [.ai, .focus, .notes, .meetings, .talk]),
        ("Around you", [.tells, .capture, .festivals]),
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai: "AI agents"
        case .notes: "Notes and countdowns"
        case .meetings: "Meeting notes"
        case .talk: "Talk to your pet"
        case .focus: "Breaks and focus"
        case .moving: "Moving about"
        case .ownPets: "Your own pets"
        case .wardrobe: "Wardrobe and home"
        case .friend: "Friend"
        case .tells: "What it tells you"
        case .capture: "Capture"
        case .festivals: "Festivals and birthday"
        case .permissions: "Permissions"
        }
    }

    var subtitle: String {
        switch self {
        case .ai: "Claude Code, Antigravity, Codex: updates, answers, usage left"
        case .notes: "Your to-do list on its sign"
        case .meetings: "Listens to a call and sums it up with the model you pick"
        case .talk: "Say what you'd like and it does it"
        case .focus: "Break reminders, focus sessions, Pomodoro, lofi"
        case .moving: "Where it walks, typing along, carrying files"
        case .ownPets: "Draw your own pet and give it sounds"
        case .wardrobe: "Hats, collars and a home of its own"
        case .friend: "A second pet of any kind"
        case .tells: "Notifications, calendar, music · quiet in calls"
        case .capture: "A photo or GIF of your pet, a whole web page"
        case .festivals: "Your birthday and festival days"
        case .permissions: "What Droppy is allowed, and your agents' hooks"
        }
    }

    var symbol: String {
        switch self {
        case .ai: "sparkles"
        case .notes: "signpost.right.fill"
        case .meetings: "waveform.badge.mic"
        case .talk: "mic.fill"
        case .focus: "timer"
        case .moving: "figure.walk"
        case .ownPets: "paintbrush.pointed.fill"
        case .wardrobe: "tshirt.fill"
        case .friend: "pawprint.fill"
        case .tells: "bubble.left.fill"
        case .capture: "camera.fill"
        case .festivals: "party.popper.fill"
        case .permissions: "lock.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .ai: .indigo
        case .notes: .orange
        case .meetings: .mint
        case .talk: .cyan
        case .focus: .red
        case .moving: .green
        case .ownPets: .purple
        case .wardrobe: .pink
        case .friend: .teal
        case .tells: .blue
        case .capture: .brown
        case .festivals: .yellow
        case .permissions: .gray
        }
    }
}

/// The permissions Pixpaw asks Droppy for that you allow in System Settings,
/// with what each is for.
enum PixpawPermission: CaseIterable, Identifiable {
    case accessibility, calendars, microphone, speech, screenAudio, appleEvents

    var id: String { permission.rawValue }

    var permission: DropletPermission {
        switch self {
        case .accessibility: .accessibility
        case .calendars: .calendars
        case .microphone: .microphone
        case .speech: .speechRecognition
        case .screenAudio: .screenCapture
        case .appleEvents: .appleEvents
        }
    }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .calendars: "Calendar"
        case .microphone: "Microphone"
        case .speech: "Speech recognition"
        case .screenAudio: "Screen and system audio"
        case .appleEvents: "Automation"
        }
    }

    var usedFor: String {
        switch self {
        case .accessibility: "Mac notifications, nudges on web pages, lofi in a browser"
        case .calendars: "Calendar events and joining a call"
        case .microphone: "Talk to your pet, meeting notes"
        case .speech: "Talk to your pet, meeting notes"
        case .screenAudio: "The Mac's sound in meeting notes, whole-page capture"
        case .appleEvents: "Pausing Spotify or Apple Music, whole-page capture"
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "accessibility"
        case .calendars: "calendar"
        case .microphone: "mic.fill"
        case .speech: "waveform"
        case .screenAudio: "rectangle.dashed.badge.record"
        case .appleEvents: "gearshape.2.fill"
        }
    }
}

/// A page link's tile, the way System Settings draws one: a white symbol
/// on a coloured rounded square.
private struct SettingsPageTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
            .fill(color.gradient)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

private struct PixpawSettings: View {
    @ObservedObject var droplet: PixpawDroplet
    @ObservedObject var cat: CatController
    /// One of its own pages, or nil for the droplet's page.
    var shown: SettingsPage?
    /// Access granted in System Settings shows up here without reopening.
    private let recheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State private var newReminder = ""
    @State private var newReminderMinutes = 60
    @State private var templateKind: PetKind = .cat
    @State private var newSign = ""
    @State private var distractionText: String?
    @State private var lofiLinkText: String?
    @State private var newCountdown = ""
    @State private var newCountdownDay = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var renamingSlot: Int?
    @State private var newName = ""

    /// A reminder: how often and whether it is on; one of yours can go.
    private func reminderRow(_ reminder: Reminder) -> some View {
        DropletControlRow(title: Reminder.builtInTitles[reminder.id] ?? reminder.text, icon: reminder.symbol) {
            HStack(spacing: 6) {
                minutesPicker(Binding(get: { reminder.minutes }, set: { var changed = reminder; changed.minutes = $0; droplet.updateReminder(changed) }))
                Toggle("On", isOn: Binding(get: { reminder.isOn }, set: { var changed = reminder; changed.isOn = $0; droplet.updateReminder(changed) }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                if reminder.isYours {
                    Button {
                        droplet.removeReminder(reminder.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this reminder")
                    .accessibilityLabel("Remove \(reminder.text)")
                }
            }
        }
        .disabled(!droplet.healthOn)
    }

    private func ownPetRow(_ pet: OwnPet) -> some View {
        DropletControlRow(title: renamingSlot == pet.slot ? "Name" : pet.kind.title) {
            HStack(spacing: 8) {
                if renamingSlot == pet.slot {
                    TextField("Name", text: $newName, prompt: Text("Your pet"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit { finishRenaming(pet) }
                    Button("Done") { finishRenaming(pet) }
                } else {
                    if let face = CatSprites.shared.menuImage(pet.kind, coat: cat.coat, points: 2) {
                        Image(nsImage: face)
                            .interpolation(.none)
                            .accessibilityHidden(true)
                    }
                    Picker("Acts like", selection: Binding(get: { pet.actsLike }, set: { droplet.setOwnPet(pet.slot, actsLike: $0) })) {
                        ForEach(PetKind.builtIn.sorted { $0.title < $1.title }) { kind in
                            Text("Acts like a \(kind.title.lowercased())").tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .help("Its sounds, words, ways of moving and home")
                    Menu {
                        Button("Let it out") { droplet.setKind(pet.kind) }
                        Button("Rename…") { newName = pet.name; renamingSlot = pet.slot }
                        Button("New picture…") { droplet.importOwnPet(replacing: pet.slot) }
                        Button("Share as a .pixpaw file…") { droplet.sharePet(pet.slot) }
                        Button("Save picture…") { droplet.saveSheet(of: pet.kind) }
                        Divider()
                        ForEach(OwnSound.allCases) { sound in
                            ownSoundMenu(sound, of: pet)
                        }
                        Divider()
                        Button("Remove") { droplet.removeOwnPet(pet.slot) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .tint(.secondary)
                    .fixedSize()
                    .accessibilityLabel("More for \(pet.kind.title)")
                }
            }
        }
    }

    /// A sound of its own: choose one, hear it, or go back to the voice of
    /// the character it acts like.
    private func ownSoundMenu(_ sound: OwnSound, of pet: OwnPet) -> some View {
        let has = pet.sounds?[sound.rawValue] != nil
        return Menu {
            Button("Choose a sound…") { droplet.chooseOwnSound(sound, for: pet.slot) }
            if has {
                Button("Play") { droplet.playOwnSound(sound, of: pet.slot) }
                Button("Use the \(pet.actsLike.title.lowercased())'s") { droplet.removeOwnSound(sound, from: pet.slot) }
            }
        } label: {
            Label("\(sound.title) sound, \(sound.when): \(has ? "its own" : "the \(pet.actsLike.title.lowercased())'s")",
                  systemImage: has ? "speaker.wave.2.fill" : "speaker.wave.2")
        }
    }

    private func saveLofiLink() {
        guard let lofiLinkText else { return }
        droplet.setLofiLink(lofiLinkText)
        self.lofiLinkText = nil
    }

    private func saveDistractions() {
        guard let distractionText else { return }
        droplet.setDistractions(distractionText)
        self.distractionText = nil
    }

    /// A note on the list: when it's due, done, and moving it up or off.
    private func noteRow(_ note: PetNote, first: Bool) -> some View {
        DropletControlRow(title: note.text, icon: first ? "signpost.right.fill" : "circle") {
            HStack(spacing: 6) {
                if let due = note.due {
                    Label(due.formatted(date: Calendar.current.isDateInToday(due) ? .omitted : .abbreviated, time: .shortened),
                          systemImage: note.told ? "alarm.fill" : "alarm")
                        .foregroundStyle(.secondary)
                }
                Button("Done") { droplet.completeNote(note.id) }
                Menu {
                    if !first { Button("Hold it up first") { droplet.moveNoteToTop(note.id) } }
                    Button("Remove") { droplet.removeNote(note.id) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .tint(.secondary)
                .fixedSize()
                .accessibilityLabel("More for \(note.text)")
            }
        }
    }

    private func holdSign() {
        droplet.addNote(newSign)
        newSign = ""
    }

    private func finishRenaming(_ pet: OwnPet) {
        droplet.renameOwnPet(pet.slot, to: newName)
        renamingSlot = nil
    }

    private func minutesPicker(_ minutes: Binding<Int>) -> some View {
        Picker("Every", selection: minutes) {
            ForEach(Reminder.choices, id: \.self) { choice in
                Text(choice < 60 ? "Every \(choice) min" : choice == 60 ? "Every hour" : "Every \(choice / 60) hours").tag(choice)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }

    private func addReminder() {
        droplet.addReminder(newReminder, minutes: newReminderMinutes)
        newReminder = ""
    }

    var body: some View {
        Group {
            if let shown { page(shown) } else { pane }
        }
            .onAppear { droplet.refreshPermissionState() }
            .onReceive(recheck) { _ in droplet.refreshPermissionState() }
    }

    /// English month names whatever the Mac's calendar, like the rest of the pane.
    private static let monthNames: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar.monthSymbols
    }()

    /// Your pet as the main page names it: "your cat", or the name you gave one you drew.
    private var petName: String { cat.kind.isOwn ? cat.kind.title : cat.kind.title.lowercased() }

    private var pane: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                DropletControlRow(title: "Show your \(petName)",
                                  infoTip: "Lets your pet out onto your desktop. Control-Option-C does the same.") {
                    HStack(spacing: DroppySpacing.sm) {
                        if let face = CatSprites.shared.menuImage(cat.kind, coat: cat.coat, points: 2) {
                            Image(nsImage: face)
                                .interpolation(.none)
                                .accessibilityHidden(true)
                        }
                        Toggle("Show your \(petName)", isOn: Binding(get: { droplet.isOut }, set: { droplet.setOut($0) }))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
                DropletGroupedPickerRow(
                    title: "Character",
                    subtitle: "Who lives on your desktop."
                ) {
                    Picker("Character", selection: Binding(get: { cat.kind }, set: { droplet.setKind($0) })) {
                        ForEach(PetKind.alphabetical) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if cat.kind.hasCoats {
                    DropletControlRow(title: "Coat from a photo", icon: "photo",
                                      infoTip: "Pixpaw paints the cat in your own cat's colours: fur, stripes or patches, white and eyes. Only the colours are kept, never the photo.") {
                        HStack(spacing: DroppySpacing.sm) {
                            if droplet.readingPhoto {
                                ProgressView().controlSize(.small)
                            } else if droplet.hasPhotoCoat {
                                Circle()
                                    .fill(Color(nsColor: CatCoat.photo.swatch))
                                    .frame(width: 14, height: 14)
                                    .accessibilityHidden(true)
                                Button("Forget") { droplet.forgetPhotoCoat() }
                                    .buttonStyle(DroppyQuietButtonStyle(size: .small))
                            }
                            Button(droplet.hasPhotoCoat ? "Another photo…" : "Choose…") { droplet.coatFromPhoto() }
                                .disabled(droplet.readingPhoto)
                        }
                    }
                    if let problem = droplet.photoCoatProblem {
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    DropletToggleRow(
                        title: "Folded ears",
                        subtitle: "Ears folded down, like a Scottish Fold's.",
                        isOn: Binding(get: { droplet.foldedEars }, set: { droplet.setFoldedEars($0) })
                    )
                }
                DropletToggleRow(
                    title: "Sounds",
                    subtitle: "Its own voice when it talks, a purr when you pet it, crunching while it eats. Silent while quiet.",
                    isOn: Binding(get: { droplet.soundsOn }, set: { droplet.setSounds($0) })
                )
                DropletToggleRow(
                    title: "Beside the notch",
                    subtitle: "A row beside the notch with your pet and what it, or your AI agents, are up to.",
                    isOn: Binding(get: { droplet.isPinned }, set: { droplet.setPinned($0) })
                )
            }

            droppyToolsSection
            petCardSection

            ForEach(SettingsPage.groups, id: \.title) { group in
                DropletSettingsSection {
                    settingsSectionHeader(LocalizedStringKey(group.title))
                } content: {
                    DropletSettingsCard {
                        ForEach(group.pages) { pageLink($0) }
                    }
                }
            }

            DropletSettingsCard {
                pageLink(.permissions)
            }
        }
    }

    private func pageLink(_ page: SettingsPage) -> some View {
        DropletSettingsPageLink(page.title, subtitle: subtitle(of: page), page: page.rawValue) {
            SettingsPageTile(symbol: page.symbol, color: page.color)
        }
    }

    /// What a link to a page says under its title: what's set, where there's something to say.
    private func subtitle(of page: SettingsPage) -> String {
        switch page {
        case .notes:
            let count = droplet.notes.count
            let streak = droplet.noteStreak.current >= 2 ? " · \(droplet.noteStreak.current)-day streak" : ""
            let countdowns = droplet.countdowns.isEmpty ? "" : " · \(droplet.countdowns.count) countdown\(droplet.countdowns.count == 1 ? "" : "s")"
            return (count == 0 ? "Your to-do list on its sign" : count == 1 ? "1 note" : "\(count) notes") + streak + countdowns
        case .wardrobe: return "\(cat.points) ★ · hats, collars and a home of its own"
        case .friend: return droplet.hasFriend ? "\(droplet.friendsKind.title) · \(droplet.social.friendTraits.map(\.title).joined(separator: ", "))" : "Off · a second pet of any kind"
        case .moving: return "\(cat.roaming.title)\(droplet.typesAlong ? " · types along" : "")\(cat.chasesPointer ? " · follows the cursor" : "")"
        case .meetings: return "\(droplet.notesSource.title) · summed up by \(droplet.notesModel.title.components(separatedBy: " (").first ?? "")"
        case .talk: return droplet.talks ? "Control-Option-T · English" : "Off · say what you'd like and it does it"
        case .permissions:
            let missing = PixpawPermission.allCases.filter { droplet.permissionStatus[$0.permission] != .granted }.count
            let allowed = PixpawPermission.allCases.count - missing
            return missing == 0 ? "All \(allowed) allowed" : "\(missing) not allowed · \(allowed) allowed"
        default: return page.subtitle
        }
    }

    /// One of the pages the main page links to.
    private func page(_ page: SettingsPage) -> some View {
        DropletSettingsPage {
            switch page {
            case .ai:
                agentsSection
                workSection
                scheduledSection
                asksSection
                usageSection
            case .notes:
                notesSection
                countdownsSection
            case .meetings: meetingNotesSection
            case .talk: talkSection
            case .focus: healthSection
            case .moving: movingSection
            case .ownPets: ownPetsSection
            case .wardrobe: wardrobeSection
            case .friend: friendSection
            case .tells:
                speechSection
                aroundSection
                quietSection
            case .capture: captureSection
            case .festivals: festivalsSection
            case .permissions:
                permissionsSection
                hooksSection
            }
        }
    }

    /// The pet's card: how it opens and how much glass it has.
    private var petCardSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Your pet's card")
        } content: {
            DropletSettingsCard {
                DropletGroupedPickerRow(title: "Open it", subtitle: "Holding leaves a click for petting; with a click, you pet it by stroking it with the pointer. A right-click always gives the plain menu.") {
                    Picker("Open it", selection: Binding(get: { droplet.cardOpening }, set: { droplet.setCardOpening($0) })) {
                        ForEach(PetCardOpening.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletGroupedPickerRow(title: "Look", subtitle: "Droppy's theme follows Settings, Theming; or a glass of its own.") {
                    Picker("Look", selection: Binding(get: { droplet.cardLook }, set: { droplet.setCardLook($0) })) {
                        ForEach(PetCardLook.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                PetCardPreview(look: droplet.cardLook, level: droplet.cardGlass)
                    .padding(.horizontal, DroppySpacing.md)
                    .padding(.vertical, DroppySpacing.sm)
                if droplet.cardLook != .droppy, droplet.cardLook != .solid {
                    DropletSliderRow(title: "Glass level", value: "\(Int((droplet.cardGlass * 100).rounded()))%",
                                     binding: Binding(get: { droplet.cardGlass }, set: { droplet.setCardGlass($0) }), range: 0...1, step: 0.05)
                }
            }
        }
    }

    /// Droppy's own tools, run by the pet instead of its own copies.
    private var droppyToolsSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Droppy's own tools")
                Text(droplet.tools.isAvailable
                     ? "Here: \(droplet.droppyToolsFound.isEmpty ? "none yet" : droplet.droppyToolsFound.map { $0.title.lowercased() }.joined(separator: ", "))."
                     : "This Droppy doesn't let droplets run its tools, so your pet uses its own.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Use Droppy's own tools",
                    subtitle: "Your pet runs Droppy's version of a tool instead of its own.",
                    isOn: Binding(get: { droplet.usesDroppyTools }, set: { droplet.setUsesDroppyTools($0) })
                )
                .disabled(!droplet.tools.isAvailable)
            }
        }
    }

    private var notesSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Your to-do list")
                Text("Your pet holds the first note up on a little sign and carries it about until you click the sign to say it's done (a star, up to five a day), then holds up the next. Put a time in a note (“in 10 min”, “at 5pm”) and it comes over to remind you. The sign is hidden while it's quiet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletControlRow(title: "New note", icon: "plus.circle",
                                  infoTip: "Also with Control-Option-N from anywhere, from its menu, or droppy://droplet/pixpaw/note?text=… in Shortcuts.") {
                    HStack(spacing: 6) {
                        if droplet.noteStreak.current >= 2 {
                            Label("\(droplet.noteStreak.current) days", systemImage: "flame.fill")
                                .foregroundStyle(.secondary)
                                .help("Days in a row with a note done")
                        }
                        TextField("Note", text: $newSign, prompt: Text("Buy milk…"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 170)
                            .onSubmit(holdSign)
                        Button("Add", action: holdSign)
                            .disabled(newSign.trimmingCharacters(in: .whitespaces).isEmpty || droplet.notes.count >= PetNote.limit)
                    }
                }
                ForEach(Array(droplet.notes.enumerated()), id: \.element.id) { index, note in
                    noteRow(note, first: index == 0)
                }
            }
        }
    }

    private var countdownsSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Countdowns")
                Text("The nearest one shows under the note on its sign, or on the sign by itself: “Trip to Japan · 12 days”. On the day your pet comes over to celebrate.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                if droplet.countdowns.count < Countdown.limit {
                    DropletControlRow(title: "New countdown", icon: "plus.circle",
                                      infoTip: "Up to \(Countdown.limit). Also droppy://droplet/pixpaw/countdown?title=…&date=2026-12-24 in Shortcuts.") {
                        HStack(spacing: 6) {
                            TextField("Countdown", text: $newCountdown, prompt: Text("Trip to Japan…"))
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                                .onSubmit(addCountdown)
                            DatePicker("Day", selection: $newCountdownDay,
                                       in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                            Button("Add", action: addCountdown)
                                .disabled(newCountdown.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                ForEach(droplet.countdowns) { countdown in
                    DropletControlRow(title: countdown.title, icon: "calendar") {
                        HStack(spacing: 8) {
                            Text("\(countdown.day.formatted(date: .abbreviated, time: .omitted)) · \(countdown.whenText)")
                                .foregroundStyle(.secondary)
                            Button {
                                droplet.removeCountdown(countdown.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Remove")
                            .accessibilityLabel("Remove \(countdown.title)")
                        }
                    }
                }
            }
        }
    }

    private func addCountdown() {
        droplet.addCountdown(newCountdown, day: newCountdownDay)
        newCountdown = ""
    }

    private var ownPetsSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Your own pets")
                Text("Draw a pet in any pixel editor (Aseprite, Piskel…) and bring it in as a PNG. One 20 × 20 sitting pose is enough: Pixpaw makes it hop to walk and sink down to sleep. Add more poses in cells beside it, in the template's order, whenever you like.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                ForEach(droplet.ownPets) { pet in
                    ownPetRow(pet)
                }
                if droplet.ownPets.count < OwnPets.limit {
                    DropletControlRow(title: "Add a pet you drew", icon: "plus.circle",
                                      infoTip: "A PNG you drew, or a .pixpaw file a friend shared. Up to \(OwnPets.limit); it comes out as soon as it's in, and picking another character swaps back.") {
                        Button("Choose…") { droplet.importOwnPet() }
                    }
                }
                DropletControlRow(title: "Start from a template", icon: "square.grid.3x3",
                                  infoTip: "Saves a character's sheet: 18 cells of 20 × 20, sitting first. Draw over it, or keep only the first cell.") {
                    HStack(spacing: 6) {
                        Picker("Template", selection: $templateKind) {
                            ForEach(PetKind.builtIn.sorted { $0.title < $1.title }) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                        Button("Save…") { droplet.saveSheet(of: templateKind) }
                    }
                }
                if let problem = droplet.ownPetProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private var movingSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Moving about")
        } content: {
            DropletSettingsCard {
                DropletGroupedPickerRow(
                    title: "Where it walks",
                    subtitle: "Bottom and on windows: it jumps onto the tops of your windows and rides along when you move one. The bee flies anywhere; the parrot perches."
                ) {
                    Picker("Where it walks", selection: Binding(get: { cat.roaming }, set: { droplet.setRoaming($0) })) {
                        ForEach(CatRoaming.allCases) { roaming in
                            Text(roaming.title).tag(roaming)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletToggleRow(
                    title: "Follow the cursor",
                    subtitle: "Your pet runs after your pointer when it moves far away. Off, it just wanders.",
                    isOn: Binding(get: { cat.chasesPointer }, set: { droplet.setChases($0) })
                )
                DropletToggleRow(
                    title: "Carry files to your shelf",
                    subtitle: "Hold a dragged file over your pet for a moment and drop it: your pet runs it to Droppy's shelf. Dragged past it, it goes where you were taking it.",
                    isOn: Binding(get: { droplet.carriesFiles }, set: { droplet.setCarriesFiles($0) })
                )
                DropletToggleRow(
                    title: "Type along",
                    subtitle: "Your pet taps along at its laptop while you type. Only how many keys go down is counted, never which; no permission needed.",
                    isOn: Binding(get: { droplet.typesAlong }, set: { droplet.setTypesAlong($0) })
                )
                DropletToggleRow(
                    title: "Pounce on dragged files",
                    subtitle: "Drag a file anywhere and your pet stalks it and pounces. Dropping still works: it never gets in the way.",
                    isOn: Binding(get: { cat.pouncesOnDrags }, set: { droplet.setPounces($0) })
                )
            }
        }
    }

    private var wardrobeSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Wardrobe")
                Text("Petting (+1, up to 10 a day), meals (+3, +5 when hungry, 3 a day), play (+5, 3 a day), catches (+2, 5 a day) and stretches (+2, 5 a day) earn up to 30 happiness points a day, which unlock things to wear, and at 500 a home of its own.")
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
                DropletStackedRow(title: "This year together", icon: "calendar",
                                  infoTip: "Counts only (minutes focused, bugs caught, games won, notes done), kept on this Mac, for a card at the end of the year.") {
                    HStack(spacing: DroppySpacing.sm) {
                        Text(droplet.stats.summary ?? "Nothing counted yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if droplet.stats.summary != nil {
                            Button("Clear") { droplet.clearStats() }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        }
                    }
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
                if cat.hasHome {
                    DropletToggleRow(
                        title: "Home",
                        subtitle: "A home after where the animal really lives: a box, a beehive, a tree, a pond. Click it for a nap, click again to call it out; drag it to move it.",
                        isOn: Binding(get: { cat.homeOn }, set: { droplet.setHome($0) })
                    )
                } else {
                    DropletControlRow(title: "Challenge: a home of its own", icon: "house",
                                      infoTip: "At \(CatController.homeUnlockAt) ★ your pet gets a home after where it really lives (a beehive, a tree, a pond) to nap in.") {
                        DropletValuePill(text: "\(CatController.homeUnlockAt - cat.points) ★ to go")
                    }
                }
            }
        }
    }

    private var friendSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Friend")
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "A second pet",
                    subtitle: "A friend that roams with your pet, sits with it, plays tag and rock, paper, scissors. It never talks, and its happiness counts for your pet.",
                    isOn: Binding(get: { droplet.hasFriend }, set: { droplet.setFriend($0) })
                )
                DropletGroupedPickerRow(title: "Friend", subtitle: "Any character, or one you drew: a dog for your cat, a rabbit for your shark.") {
                    Picker("Friend", selection: Binding(get: { droplet.friendKind }, set: { droplet.setFriendKind($0) })) {
                        Text("Same as your pet").tag(PetKind?.none)
                        ForEach(PetKind.alphabetical) { kind in
                            Text(kind.title).tag(PetKind?.some(kind))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if droplet.friendsKind.hasCoats {
                    DropletGroupedPickerRow(title: "Friend's coat") {
                        Picker("Friend's coat", selection: Binding(get: { droplet.friendCoat }, set: { droplet.setFriendCoat($0) })) {
                            ForEach(CatCoat.choices) { coat in
                                Text(coat.title).tag(coat)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                if droplet.hasFriend {
                    DropletControlRow(title: "Your pet is", icon: "theatermasks") {
                        DropletValuePill(text: droplet.social.petTraits.map(\.title).joined(separator: ", "))
                    }
                    DropletControlRow(title: "Its friend is", icon: "theatermasks.fill") {
                        DropletValuePill(text: droplet.social.friendTraits.map(\.title).joined(separator: ", "))
                    }
                    DropletControlRow(title: "Rock, paper, scissors", icon: "hand.raised.fingers.spread",
                                      infoTip: "When both sit about they play for make-believe coins, each in its own character. Start over draws new characters and \(PetSocial.startingCoins) coins each.") {
                        HStack(spacing: DroppySpacing.sm) {
                            DropletValuePill(text: "\(droplet.social.petCoins) vs \(droplet.social.friendCoins) coins · \(droplet.social.petWins)–\(droplet.social.friendWins)")
                            Button("Start over") { droplet.resetSocial() }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        }
                    }
                }
            }
        }
    }

    private var speechSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Speech bubble")
                Text("Your pet says it in a bubble over its head, or under the notch while it naps.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
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
                    subtitle: droplet.droppyAnnouncesMeetings ? "Droppy shows your meetings instead, while Use Droppy's own tools is on."
                        : "It comes over two minutes before each event. With a Zoom, Meet or Teams link, click your pet to join.",
                    isOn: Binding(get: { droplet.tellsCalendar }, set: { droplet.setTells(calendar: $0) })
                )
                if droplet.tellsCalendar, !droplet.calendarAllowed {
                    DropletControlRow(title: "Calendar access") {
                        Button("Allow…") { droplet.requestPermission(.calendars) }
                    }
                }
                DropletToggleRow(
                    title: "Battery",
                    subtitle: "Low battery at 20% and 10%, plugging in, and a full charge. Below 20% it gets sleepy, yawning and strolling slowly, until you plug in.",
                    isOn: Binding(get: { droplet.tellsBattery }, set: { droplet.setTells(battery: $0) })
                )
                DropletToggleRow(
                    title: "Busy Mac",
                    subtitle: "When the Mac works flat out or runs hot, your pet hurries about with a bead of sweat. Only the overall load is read, never which apps.",
                    isOn: Binding(get: { droplet.tellsHeat }, set: { droplet.setTells(heat: $0) })
                )
                DropletToggleRow(
                    title: "Volume",
                    subtitle: "Says the new level when you turn the sound up or down, in one bubble that updates as you hold the key.",
                    isOn: Binding(get: { droplet.tellsLevels }, set: { droplet.setTells(levels: $0) })
                )
                DropletToggleRow(
                    title: "Finished downloads",
                    subtitle: "When a file lands in Downloads. macOS may ask Droppy for access to the folder.",
                    isOn: Binding(get: { droplet.tellsDownloads }, set: { droplet.setTells(downloads: $0) })
                )
            }
        }
    }

    private var quietSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Quiet")
                Text("When the bubbles stay hidden, so nothing private shows on a shared screen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Quiet during calls and screen sharing",
                    subtitle: "No bubbles while a microphone or camera is in use or a screen is shared, so nothing private shows in a meeting.",
                    isOn: Binding(get: { droplet.quietsAutomatically }, set: { droplet.setQuietsAutomatically($0) })
                )
                if droplet.quietsAutomatically {
                    DropletToggleRow(
                        title: "Also quiet while mirroring",
                        subtitle: "When the display is mirrored to a projector or a TV. Turn off if you mirror to a TV at home.",
                        isOn: Binding(get: { droplet.quietWhenMirroring }, set: { droplet.setQuietWhenMirroring($0) })
                    )
                }
            }
        }
    }

    private var aroundSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Around your Mac")
                Text("Things your pet notices and joins in with.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Music",
                    subtitle: "Dances to whatever is playing, from Spotify to a YouTube video in your browser, and names each new song in Apple Music or Spotify.",
                    isOn: Binding(get: { droplet.tellsMusic }, set: { droplet.setTells(music: $0) })
                )
                DropletToggleRow(
                    title: "Headphones",
                    subtitle: "When headphones connect or disconnect. Your pet wears a pair while yours are on.",
                    isOn: Binding(get: { droplet.tellsHeadphones }, set: { droplet.setTells(headphones: $0) })
                )
                DropletToggleRow(
                    title: "Good morning",
                    subtitle: "The first time it sees you on a morning, it stretches and says good morning, with your first event of the day when Calendar events is on.",
                    isOn: Binding(get: { droplet.morningOn }, set: { droplet.setMorning($0) })
                )
                DropletToggleRow(
                    title: "Welcome back",
                    subtitle: "Back at your Mac after ten minutes or more away, it runs over to say hello.",
                    isOn: Binding(get: { droplet.welcomeBackOn }, set: { droplet.setWelcomeBack($0) })
                )
                DropletToggleRow(
                    title: "Late nights",
                    subtitle: "From midnight to 5 am it wears a nightcap, and the first time it sees you up it says it's late. Once a night.",
                    isOn: Binding(get: { droplet.lateNightsOn }, set: { droplet.setLateNights($0) })
                )
            }
        }
    }

    private var talkSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Talk to your pet")
                Text("Press Control-Option-T, or choose Talk to me in its menu, and say what you'd like: \"come here\", \"focus for 25 minutes\", \"note buy milk\", and Droppy's own tools: \"open my notes\", \"my tasks\", \"show my clipboard\", \"my meetings\", \"capture the page\", \"next song\". Change the shortcut on Droppy's Shortcuts page.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Talk to your pet",
                    subtitle: "Heard on your Mac with Apple's on-device speech recognition, only while you talk to it. Nothing is recorded or kept.",
                    isOn: Binding(get: { droplet.talks }, set: { droplet.setTalks($0) })
                )
                if let problem = droplet.talkProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                DropletStackedRow(title: "Things to say", icon: "text.bubble") {
                    Text("Come here · feed · nap · focus for 25 minutes · stop focus · play lofi · take a photo · note buy milk · remind me to… · how much usage is left · good kitty")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                DropletControlRow(title: "Language", icon: "globe") {
                    DropletValuePill(text: "English for now")
                }
            }
        }
    }

    private var captureSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Capture")
                Text("Also from your pet's menu, a shortcut on Droppy's Shortcuts page, or droppy://droplet/pixpaw/photo, gif and capture in Shortcuts.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletControlRow(title: "Photo of your pet", icon: "camera",
                                  infoTip: "A picture of your pet where your screenshots go.") {
                    Button("Take") { droplet.takePhoto() }
                        .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        .disabled(!droplet.isOut)
                }
                DropletControlRow(title: "GIF of your pet", icon: "film",
                                  infoTip: "Five seconds of whatever it's doing, as a looping GIF. It brings it to the shelf, ready to drop into a chat.") {
                    Button("Record") { droplet.recordGIF() }
                        .buttonStyle(.bordered)
                        .disabled(!droplet.isOut)
                }
                DropletControlRow(title: "A whole web page", icon: "safari",
                                  infoTip: "Safari, Chrome, Arc, Edge, Brave or Vivaldi, in front. Turn on JavaScript from Apple Events (Safari: Settings → Developer; others: View → Developer).") {
                    Button("Capture") { droplet.capturePage() }
                        .buttonStyle(.bordered)
                }
                DropletToggleRow(
                    title: "Pose for screenshots",
                    subtitle: "Strikes a pose when you take a screenshot. Found through Spotlight, so no permission is needed.",
                    isOn: Binding(get: { droplet.tellsScreenshots }, set: { droplet.setTells(screenshots: $0) })
                )
            }
        }
    }

    private var permissionsSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("What Droppy is allowed")
                Text("Pixpaw asks through Droppy, so these are Droppy's switches in System Settings → Privacy & Security.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                ForEach(PixpawPermission.allCases) { item in
                    DropletControlRow(title: item.title, icon: item.symbol, infoTip: "For: \(item.usedFor).") {
                        if droplet.permissionStatus[item.permission] == .granted {
                            DropletValuePill(text: "Allowed")
                        } else if droplet.permissionStatus[item.permission] == .unavailable {
                            DropletValuePill(text: "Not on this Mac")
                        } else {
                            Button("Allow…") { droplet.requestPermission(item.permission) }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        }
                    }
                }
            }
        }
    }

    /// The hooks that make an agent speak, and when each last did.
    private var hooksSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Agent hooks")
                Text("Without them your pet still follows Claude Code, Codex, Antigravity and Gemini CLI from their logs; the hooks add questions, diffs, long commands and helpers.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                ForEach([("Claude Code hooks", "Claude"), ("Antigravity plugin", "Antigravity"), ("Codex notify", "Codex"), ("pixpaw-ask hook", "pixpaw-ask")], id: \.1) { title, key in
                    DropletControlRow(title: title, icon: "link",
                                      infoTip: key == "pixpaw-ask" ? "Puts Claude's questions on your pet's card." : "Tells your pet when \(key) starts, works, finishes or needs you.") {
                        if let heard = droplet.hookHeard(key) {
                            DropletValuePill(text: "Heard " + heard.formatted(.relative(presentation: .named)))
                        } else {
                            Button("How to set up") { NSWorkspace.shared.open(URL(string: "https://github.com/Josakcat/pixpaw#readme")!) }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        }
                    }
                }
            }
        }
    }

    private var agentsSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Your agents")
                Text("Claude Code, Antigravity, Codex, Cursor and others: your pet reads their logs, or they report through hooks that open droppy://droplet/pixpaw/agent?name=…&state=working|done|waiting|error.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Agent updates",
                    subtitle: "Says when an agent starts, finishes or needs you, and codes along at its laptop while it works.",
                    isOn: Binding(get: { droplet.tellsAgents }, set: { droplet.setTells(agents: $0) })
                )
                DropletToggleRow(
                    title: "Follow agents without hooks",
                    subtitle: "Reads the logs Claude Code, Codex, Antigravity and Gemini CLI keep on this Mac. Keeps only tool and file names, a command's first two words and percentages, never what anyone wrote.",
                    isOn: Binding(get: { droplet.readsAgentFiles }, set: { droplet.setReadsAgentFiles($0) })
                )
                DropletToggleRow(
                    title: "Keep the Mac awake while agents work",
                    subtitle: "The Mac stays awake while an agent works, so a long run can finish. The screen still turns off, and closing the lid still sleeps.",
                    isOn: Binding(get: { droplet.awakeForAgents }, set: { droplet.setAwakeForAgents($0) })
                )
                .disabled(!droplet.tellsAgents)
            }
        }
    }

    private var workSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("While they work")
                Text("What your agent is up to, beside your pet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "What it's working on",
                    subtitle: "A tag at your pet's side: “Editing App.swift”, “Running swift build”. Only a file's name and a command's first words; hidden while quiet.",
                    isOn: Binding(get: { droplet.showsAgentTools }, set: { droplet.setShowsAgentTools($0) })
                )
                .disabled(!droplet.tellsAgents)
                DropletToggleRow(
                    title: "Wait for CI after a push",
                    subtitle: droplet.hasGH
                        ? "When your agent pushes to GitHub, your pet waits for its Actions with you: it jumps for joy when they pass, and a bug turns up when they fail, until a push makes them green. Asks GitHub's gh command every 20 seconds, signed in as you, so it goes online. Needs the hooks in the README."
                        : "When your agent pushes to GitHub, your pet waits for its Actions with you. Needs GitHub's gh command, signed in (brew install gh, then gh auth login).",
                    isOn: Binding(get: { droplet.watchesCI }, set: { droplet.setWatchesCI($0) })
                )
                .disabled(!droplet.tellsAgents)
                DropletToggleRow(
                    title: "Long commands and helpers",
                    subtitle: "Your pet waits out long tests and builds (popcorn, cobwebs, a nap), hunts the bug a failure leaves, and a subagent works beside it at its own laptop.",
                    isOn: Binding(get: { droplet.showsWaits }, set: { droplet.setShowsWaits($0) })
                )
                .disabled(!droplet.tellsAgents)
            }
        }
    }

    private var scheduledSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("On a schedule")
                Text("Claude Code scheduled tasks, /loop and Antigravity Automations that run on this Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Scheduled runs",
                    subtitle: "When a Claude Code scheduled task, a /loop or an Antigravity Automation runs on this Mac, your pet says so and brings the result.",
                    isOn: Binding(get: { droplet.tellsScheduled }, set: { droplet.setTellsScheduled($0) })
                )
                .disabled(!droplet.tellsAgents)
                DropletToggleRow(
                    title: "Keep results on its sign",
                    subtitle: "Each finished run's result goes on its sign as a note (“Morning review: 3 PRs need you”) until you click it done.",
                    isOn: Binding(get: { droplet.scheduledOnSign }, set: { droplet.setScheduledOnSign($0) })
                )
                .disabled(!droplet.tellsAgents || !droplet.tellsScheduled)
            }
        }
    }

    private var meetingNotesSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Meeting notes")
                Text("Take meeting notes from your pet's menu (or a shortcut on Droppy's Shortcuts page): it listens to the call, turns it into words on your Mac, and when you stop, the model you pick sums it up. The notes go on Droppy's shelf and into Documents → Pixpaw Meetings; the sound is never kept. Let everyone in the call know you're taking notes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletGroupedPickerRow(title: "Language", subtitle: "What the meeting is in. Your Mac needs it for dictation (System Settings → Keyboard → Dictation).") {
                    Picker("Language", selection: Binding(get: { droplet.notesLanguage }, set: { droplet.setNotesLanguage($0) })) {
                        ForEach(MeetingLanguage.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletGroupedPickerRow(title: "Listen to", subtitle: droplet.notesSource.detail) {
                    Picker("Listen to", selection: Binding(get: { droplet.notesSource }, set: { droplet.setNotesSource($0) })) {
                        ForEach(MeetingSource.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletGroupedPickerRow(title: "Summary by", subtitle: droplet.notesModel.online
                    ? "Sends the transcript to the model's company under your own account, through its command on this Mac, and counts toward your plan."
                    : droplet.notesModel == .apple ? "Stays on your Mac. English and some other languages, not Thai yet." : "Only the transcript, no summary.") {
                    Picker("Summary by", selection: Binding(get: { droplet.notesModel }, set: { droplet.setNotesModel($0) })) {
                        ForEach(NoteModel.allCases) { model in
                            Text(model.available ? model.title : "\(model.title), not installed").tag(model)
                                .disabled(!model.available)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                switch droplet.notesModel {
                case .claude:
                    DropletGroupedPickerRow(title: "Model") {
                        Picker("Model", selection: Binding(get: { droplet.notesModelName }, set: { droplet.setNotesModelName($0) })) {
                            ForEach(NoteModel.claude.presets, id: \.self) { Text($0.isEmpty ? "Claude's default" : $0.capitalized).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                default:
                    EmptyView()
                }
                DropletControlRow(title: "Your meeting notes", icon: "folder") {
                    Button("Open folder") { droplet.openNotesFolder() }
                }
                if let problem = droplet.notesProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private var asksSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Questions")
                Text("When your agent asks to run something or asks you a question.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Answer from your pet",
                    subtitle: "Claude Code's questions come over on a card: click to answer, or ignore it and Claude asks as usual. While you're away they go straight back to Claude.",
                    isOn: Binding(get: { droplet.answersAsks }, set: { droplet.setAnswersAsks($0) })
                )
                .disabled(!droplet.tellsAgents)
                DropletToggleRow(
                    title: "Touch ID to allow a risky one",
                    subtitle: "Allowing rm -rf, a force-push, sudo or a secrets file takes your fingerprint or password, so a stray click can't let it through.",
                    isOn: Binding(get: { droplet.touchIDForRisky }, set: { droplet.setTouchIDForRisky($0) })
                )
                .disabled(!droplet.tellsAgents || !droplet.answersAsks)
                DropletToggleRow(
                    title: "Read questions aloud",
                    subtitle: "Says the question out loud as it comes over, so you hear it from across the room.",
                    isOn: Binding(get: { droplet.readsAsksAloud }, set: { droplet.setReadsAsksAloud($0) })
                )
                .disabled(!droplet.tellsAgents || !droplet.answersAsks)
            }
        }
    }

    /// What's left of each AI's plan: where it's shown, then a row for each
    /// agent saying where its numbers come from.
    private var usageSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("AI Usage left")
                Text("What's left of each AI's five hours and week, a section for each, on the second page of your pet's widget (the gauge button at its top) and in the menu bar.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "AI Usage left in the menu bar",
                    icon: "gauge.with.dots.needle.67percent",
                    subtitle: droplet.droppyShowsUsage ? "Droppy's Agents shows this instead, while Use Droppy's own tools is on."
                        : "A gauge as full as your emptiest plan window, a raised hand while an agent needs you. Click it for every AI's windows and resets.",
                    isOn: Binding(get: { droplet.showsMenuBar }, set: { droplet.setShowsMenuBar($0) })
                )
                let claude = AgentLook("Claude")
                DropletToggleRow(
                    title: "\(claude.name): ask the claude command",
                    icon: claude.symbol,
                    iconColor: claude.color,
                    subtitle: "Every five minutes while Claude works, your pet asks the claude command for the plan left. No prompt is sent, nothing is billed, no hooks run.",
                    isOn: Binding(get: { droplet.asksClaudeUsage }, set: { droplet.setAsksClaudeUsage($0) })
                )
                let antigravity = AgentLook("Antigravity")
                DropletControlRow(
                    title: antigravity.name,
                    icon: antigravity.symbol,
                    iconColor: antigravity.color,
                    infoTip: "Each model group with limits of its own gets a line under Antigravity. The Pixpaw plugin asks agy for /usage when a turn ends."
                ) {
                    sourceText("From the Pixpaw plugin")
                }
                let codex = AgentLook("Codex")
                DropletControlRow(
                    title: codex.name,
                    icon: codex.symbol,
                    iconColor: codex.color,
                    infoTip: "Codex writes what's left of its plan into its own log as it works; your pet reads it there with Follow agents without hooks on."
                ) {
                    sourceText(droplet.readsAgentFiles ? "From its own log" : "Turn on Follow agents without hooks")
                }
                DropletControlRow(
                    title: "Other agents",
                    icon: "cpu",
                    infoTip: "Any other agent's hook can send “5h 77% · week 59% left” when a turn ends, and it gets a section of its own."
                ) {
                    sourceText("From their hooks")
                }
            }
        }
    }

    private func sourceText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var healthSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Health")
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Break reminders",
                    subtitle: "Your pet comes over to remind you, and stretches along with you. Time counts only while you're at the Mac; never during a call or focus.",
                    isOn: Binding(get: { droplet.healthOn }, set: { droplet.setHealth(on: $0) })
                )
                ForEach(droplet.reminders) { reminder in
                    reminderRow(reminder)
                }
                if droplet.reminders.filter(\.isYours).count < PixpawDroplet.maxOwnReminders {
                    DropletControlRow(title: "Your own reminder", icon: "plus.circle") {
                        HStack(spacing: 6) {
                            TextField("Reminder", text: $newReminder, prompt: Text("Take a pill…"))
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 170)
                                .onSubmit(addReminder)
                            minutesPicker(Binding(get: { newReminderMinutes }, set: { newReminderMinutes = $0 }))
                            Button("Add", action: addReminder)
                                .disabled(newReminder.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .disabled(!droplet.healthOn)
                }
                DropletGroupedPickerRow(
                    title: "Focus session",
                    subtitle: "Start one from the shelf timer or your pet's menu. It sits by you quietly with the time left over its head, and comes over at break time."
                ) {
                    Picker("Focus session", selection: Binding(get: { droplet.focusMinutes }, set: { droplet.setFocusMinutes($0) })) {
                        ForEach([15, 25, 45, 50], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                DropletToggleRow(
                    title: "Pomodoro",
                    subtitle: "Four focus sessions with 5-minute breaks, and 15 minutes off after the fourth. Each break starts with a stretch.",
                    isOn: Binding(get: { droplet.pomodoroOn }, set: { droplet.setPomodoro($0) })
                )
                DropletGroupedPickerRow(
                    title: "Lofi",
                    subtitle: "Play lofi from your pet's menu or a shortcut, in your browser, Spotify or Apple Music. Your pet puts its headphones on and studies along."
                ) {
                    Picker("Lofi", selection: Binding(get: { droplet.lofiSource }, set: { droplet.setLofiSource($0) })) {
                        ForEach(LofiSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if droplet.lofiSource == .own {
                    DropletControlRow(title: "Your lofi link", icon: "link", infoTip: "A web page, or a spotify: or music: link.") {
                        TextField("Your lofi link", text: Binding(get: { lofiLinkText ?? droplet.lofiLink }, set: { lofiLinkText = $0 }),
                                  prompt: Text("https://…"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                            .onSubmit { saveLofiLink() }
                            .onDisappear { saveLofiLink() }
                    }
                }
                DropletToggleRow(
                    title: "Lofi with each focus session",
                    subtitle: "A focus session starts lofi, and a break or the end pauses it. Pausing asks once for Automation (Spotify, Music) or needs Accessibility (a browser).",
                    isOn: Binding(get: { droplet.lofiWithFocus }, set: { droplet.setLofiWithFocus($0) })
                )
                DropletToggleRow(
                    title: "Nudge me back to work",
                    subtitle: "Two minutes in an app or page with one of these words in its name, and your pet comes over. Only the front window's title is read, while focusing; nothing is kept.",
                    isOn: Binding(get: { droplet.nudgesOn }, set: { droplet.setNudges($0) })
                )
                if droplet.nudgesOn {
                    DropletControlRow(title: "Distractions", icon: "eyes", infoTip: "Comma-separated: app names, and words in window titles such as a browser tab's.") {
                        TextField("Distractions", text: Binding(
                            get: { distractionText ?? droplet.distractionWords.joined(separator: ", ") },
                            set: { distractionText = $0 }
                        ))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                        .onSubmit { saveDistractions() }
                        .onDisappear { saveDistractions() }
                    }
                }
            }
        }
    }

    private var festivalsSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Festivals")
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Your birthday",
                    subtitle: "On the day, confetti falls, your pet wears a party hat and wishes you a happy birthday.",
                    isOn: Binding(get: { droplet.birthdayOn }, set: { droplet.setBirthday(on: $0) })
                )
                if droplet.birthdayOn {
                    DropletGroupedPickerRow(title: "Month") {
                        Picker("Month", selection: Binding(get: { droplet.birthdayMonth }, set: { droplet.setBirthday(month: $0) })) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Self.monthNames[month - 1]).tag(month)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    DropletGroupedPickerRow(title: "Day") {
                        Picker("Day", selection: Binding(get: { droplet.birthdayDay }, set: { droplet.setBirthday(day: $0) })) {
                            ForEach(1...PixpawDroplet.days(in: droplet.birthdayMonth), id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                DropletToggleRow(
                    title: "Festival decorations",
                    subtitle: "On a festival's own days the screen joins in, then clears when the day is over. Never during calls or screen sharing.",
                    isOn: Binding(get: { droplet.festivalsOn }, set: { droplet.setFestivals($0) })
                )
                ForEach(Festival.calendar) { festival in
                    DropletToggleRow(
                        title: festival.title,
                        subtitle: "\(festival.when): \(festival.decoration)\(festival.hat.map { ", and your pet wears a \($0.title.lowercased())" } ?? "").",
                        isOn: Binding(get: { !droplet.festivalsHidden.contains(festival) },
                                      set: { droplet.setFestival(festival, shown: $0) })
                    )
                    .disabled(!droplet.festivalsOn)
                }
            }
        }
    }

}

// MARK: - URLs

/// `droppy://droplet/pixpaw/<action>` (or `droppy-playground://…` in the
/// Playground), for Shortcuts and scripts: show, hide, come, nap, feed,
/// play?toy=yarn|teaser|stop, wear?hat=…&collar=…, quiet?on=1|0, say?text=…,
/// agent?name=…&state=working|done|waiting|error&text=…&usage=…,
/// agent?name=…&state=tool&tool=Edit&target=…, gif, and
/// roam?mode=anywhere|floor|windows.
extension PixpawDroplet: DropletURLHandling {
    public func handle(_ request: DropletURLRequest) {
        if request.path.lowercased() == "agent", let name = request.query["name"] {
            let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            hookHeardAt[name] = Date()
            heardHook(name)
        }
        if request.path.lowercased() == "ask" { heardHook("pixpaw-ask") }
        switch request.path.lowercased() {
        case "show": setOut(true)
        case "hide": setOut(false)
        case "come": callOver()
        case "nap": napNow()
        case "feed": feed()
        case "photo": takePhoto()
        case "gif": recordGIF()
        case "meeting":
            // Any app or web page can open a URL, so a URL may only stop meeting
            // notes. Starting them (or Talk to me, or lofi) takes a click, a
            // shortcut or the menu in Pixpaw.
            if takingNotes { toggleMeetingNotes() }
        case "focus":
            // focus?minutes=25, or focus?stop
            if request.query["stop"] != nil { stopFocus() } else { startFocus(minutes: request.query["minutes"].flatMap(Int.init).map { min(180, max(1, $0)) }) }
        case "stretch":
            if !isOut { setOut(true) }
            cat?.stretchWithMe()
        case "treat":
            if !isOut { setOut(true) }
            cat?.giveTreat()
        case "play":
            if !isOut { setOut(true) }
            // play?toy=yarn|teaser|laser|ball|mouse|frisbee|…|stop
            switch request.query["toy"]?.lowercased() {
            case "stop": cat?.stopPlaying()
            case "hands": cat?.challengeFriend()
            case "ball": cat?.play(PetGame.fetch)
            case let name?: cat?.play(PetGame.allCases.first { $0.rawValue.lowercased() == name } ?? .yarn)
            case nil: cat?.play(PetGame.yarn)
            }
        case "wear":
            // wear?hat=crown&collar= ; an empty value takes it off.
            if let hat = request.query["hat"] { wear(CatAccessory(rawValue: hat), in: .hat) }
            if let collar = request.query["collar"] { wear(CatAccessory(rawValue: collar), in: .collar) }
        case "quiet":
            setQuietByHand(["1", "on", "true"].contains(request.query["on"]?.lowercased() ?? "1"))
        case "agent" where request.query["state"]?.lowercased() == "tool":
            agentTool(name: request.query["name"] ?? "", tool: request.query["tool"] ?? "", target: request.query["target"], id: request.query["id"],
                      ports: request.query["ports"], ci: request.query["ci"])
        case "agent" where request.query["state"]?.lowercased() == "tool-done":
            agentToolDone(name: request.query["name"] ?? "", tool: request.query["tool"] ?? "", id: request.query["id"], outcome: request.query["outcome"]?.lowercased())
        case "agent" where request.query["state"]?.lowercased() == "helper":
            helperEvent(name: request.query["name"] ?? "", id: request.query["id"], event: request.query["event"]?.lowercased())
        case "agent":
            agentEvent(name: request.query["name"] ?? "", state: request.query["state"] ?? "", text: request.query["text"], usage: request.query["usage"],
                       task: request.query["task"], result: request.query["result"], diff: request.query["diff"])
        case "join":
            joinNextMeeting()
        case "capture":
            capturePage()
        case "ask":
            handleAsk(id: request.query["id"] ?? "")
        case "countdown":
            // countdown?title=Trip%20to%20Japan&date=2026-12-24
            let format = DateFormatter()
            format.calendar = Calendar(identifier: .gregorian)
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "yyyy-MM-dd"
            if let title = request.query["title"], let day = request.query["date"].flatMap(format.date(from:)) { addCountdown(title, day: day) }
        case "sign", "note":
            // sign?text=Buy%20milk adds a note to the list; sign with no text
            // marks the one on the sign done.
            if let text = request.query["text"], !text.trimmingCharacters(in: .whitespaces).isEmpty { addNote(text) } else { cat?.signDone() }
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

/// A command an agent is running, by the hook's id for the call.
struct RunningCommand {
    let id: String
    let agent: String
    /// Its program and first word, e.g. "npm test".
    let label: String
    let since: Date

    /// Past this, the pet sits down to wait on it.
    static let waitsAfter: TimeInterval = 20
    /// A command or errand never heard of again is let go after this.
    static let forgottenAfter: TimeInterval = 2 * 3600

    /// Tools that test, build or check code: when one fails, a bug turns up
    /// however quickly it failed.
    static func checksWork(_ label: String) -> Bool {
        let program = label.split(separator: " ").first.map { String($0).lowercased() } ?? ""
        return ["npm", "npx", "yarn", "pnpm", "bun", "deno", "make", "cargo", "go", "swift", "xcodebuild", "gradle", "gradlew",
                "mvn", "pytest", "jest", "vitest", "tsc", "eslint", "ruff", "mypy", "rspec", "dotnet", "flutter", "dart", "droppykit"]
            .contains(program.replacingOccurrences(of: "./", with: ""))
    }

    /// "40s", "4 min", "1 h 5 min".
    static func length(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s / 10 * 10)s" }
        if s < 3600 { return "\(s / 60) min" }
        return "\(s / 3600) h \(s % 3600 / 60) min"
    }
}

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
    /// What the turn changed, when it's done: "3 files · +84 −12".
    var diff: String? = nil
}
