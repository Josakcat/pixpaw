//
//  CatController.swift
//  Pixpaw
//
//  The cat itself: a small borderless panel that wanders the desktop (all of
//  it, only the bottom edge, or the bottom edge and the tops of your windows),
//  grooms, purrs when clicked, eats from a bowl you put down, plays, pounces
//  on dragged files and talks in a speech bubble.
//

import AppKit
import Combine
import QuartzCore

/// Where the cat is allowed to walk.
enum CatRoaming: String, CaseIterable, Identifiable, Codable {
    /// Anywhere on the screen.
    case anywhere
    /// Only along the bottom edge of the screen.
    case floor
    /// The bottom edge, and the top edges of the windows you have open.
    case windows

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anywhere: "Whole screen"
        case .floor: "Bottom of the screen"
        case .windows: "Bottom and on windows"
        }
    }
}

enum CatMood: Equatable {
    case sitting, walking, chasing, grooming, sleeping, happy, held
    /// Mid-air between the floor and a window, or between two windows.
    case jumping
    /// On the way to the bowl, and eating from it.
    case goingToBowl, eating
    /// A file is being dragged, or the teaser is out: closing in on it,
    /// crouched and wiggling, mid-pounce.
    case hunting, crouching, pouncing
    /// Batting the yarn ball around the floor.
    case playing
    /// Dropping to whatever is below: let go of, or its window gone.
    case falling

    var title: String {
        switch self {
        case .sitting: "Sitting pretty"
        case .walking: "Out for a stroll"
        case .chasing: "Chasing your cursor"
        case .grooming: "Grooming"
        case .sleeping: "Asleep"
        case .happy: "Purring"
        case .held: "Being carried"
        case .jumping: "Leaping"
        case .goingToBowl: "Off to dinner"
        case .eating: "Having dinner"
        case .hunting: "Stalking your file"
        case .crouching: "About to pounce"
        case .pouncing: "Pounce!"
        case .playing: "Playing with yarn"
        case .falling: "Falling"
        }
    }

    /// Fits the 70pt wing beside the notch.
    var shortTitle: String {
        switch self {
        case .sitting: "Sitting"
        case .walking: "Strolling"
        case .chasing: "Chasing"
        case .grooming: "Grooming"
        case .sleeping: "Zzz"
        case .happy: "Purring"
        case .held: "Carried"
        case .jumping: "Leaping"
        case .goingToBowl: "Dinner!"
        case .eating: "Nom nom"
        case .hunting, .crouching: "Stalking"
        case .pouncing: "Pounce!"
        case .playing: "Playing"
        case .falling: "Whoa"
        }
    }

    /// Moods that are idling around and may be interrupted by a plan.
    var isIdle: Bool { self == .sitting || self == .grooming || self == .walking }
}

/// Something the cat can stand on: the bottom of a screen, or the top edge of
/// a window. `y` is in AppKit screen coordinates, the height of the feet.
struct CatSurface: Equatable {
    var y: CGFloat
    var minX: CGFloat
    var maxX: CGFloat
    /// nil for a screen's floor.
    var windowID: CGWindowID?
    /// The window's own left edge. The standable part can start further
    /// right when something in front covers it, so moves are measured here.
    var windowX: CGFloat?
}

@MainActor
final class CatController: ObservableObject {
    // What the widget and the live activity show. `frame` changes a few times
    // a second, so those views observe this object rather than the droplet.
    @Published private(set) var mood: CatMood = .sitting
    @Published private(set) var frame: CatFrame = .sit
    @Published private(set) var facesRight = true
    @Published var coat: CatCoat { didSet { redraw() } }
    @Published var chasesPointer: Bool
    @Published var roaming: CatRoaming { didSet { if roaming != oldValue { roamingChanged() } } }
    @Published var pouncesOnDrags: Bool
    /// Whether the cat comments on its own life: hunger, meals, naps, catches.
    @Published var chatty: Bool
    @Published private(set) var pets: Int
    /// Happiness points: petting, meals, play and catches add up and unlock
    /// things to wear.
    @Published private(set) var points: Int
    @Published var hat: CatAccessory? { didSet { redraw() } }
    @Published var collar: CatAccessory? { didSet { redraw() } }
    /// 1 just after a meal, 0 after `hungerHours` without one.
    @Published private(set) var fullness: Double = 1
    @Published private(set) var isHungry = false
    /// Music is playing in Apple Music or Spotify: an idle cat dances.
    @Published var musicPlaying = false
    /// A couple of points of bounce while dancing.
    private var bob: CGFloat = 0
    private(set) var lastFed: Date

    /// Called whenever something worth saving changes.
    var onPersist: (() -> Void)?
    /// The other cat, when there are two. Each sometimes wanders over to sit
    /// with the other, or runs at it for a game of tag.
    weak var buddy: CatController?
    /// A friend never talks (the main cat does the announcing) and sends any
    /// happiness points it earns to the main cat.
    var isFriend = false
    var forwardAward: ((StarSource) -> Void)?
    /// Stars earned today, per source and in all, against the daily limits.
    @Published private(set) var starDay: StarDay
    private var lastPetStar = Date.distantPast
    private enum BuddyPlan { case visit, tag }
    private var buddyPlan: BuddyPlan?
    /// Where the cat is, for the other cat to find it.
    var feet: CGPoint? { panel == nil ? nil : position }
    /// Droppy's log, for the moments worth tracing.
    var log: ((String) -> Void)?

    private static let fps: Double = 12
    private static let walkSpeed: CGFloat = 45
    private static let runSpeed: CGFloat = 230
    private static let gravity: CGFloat = 2600
    private static let chaseDistance: CGFloat = 170
    private static let sleepAfterIdle: Double = 45
    /// Room above the cat for a heart, a Zzz or a tall hat.
    private static let effectHeight: CGFloat = 26
    /// Where the pointer holds a carried cat, from its feet box's corner:
    /// the middle of the carried frame, a little under the ears.
    private static let heldGrip = CGPoint(x: 8 * CatSprites.scale, y: 16 * CatSprites.scale)
    private static let hungerHours: Double = 4
    private static let hungryBelow: Double = 0.25
    /// Where the mouth is in the eating frames, from the cat's left edge.
    private static let mouthX: CGFloat = 51

    private var panel: CatPanel?
    private let bubble = CatBubble()
    private var catLayer: CALayer?
    private var effectLayer: CALayer?
    private var bowlPanel: CatPanel?
    private var bowlLayer: CALayer?
    private var bowlHasFood = false
    private var bowlClearsAt: Date?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    /// Bottom-left of the cat's feet box, in screen coordinates: where the
    /// logic, which steps 12 times a second, has the cat.
    private var position: CGPoint = .zero
    /// Where the window is drawn. Between logic steps it glides from
    /// `glideFrom` to `position` on every display refresh, so motion is as
    /// smooth as the screen even though the sprite art keeps its few frames.
    private var shown: CGPoint = .zero
    private var glideFrom: CGPoint = .zero
    private var stepAt: CFTimeInterval = 0
    /// When the display link last drew; if it goes quiet, the loop draws.
    private var lastDisplayFrame: CFTimeInterval = 0
    private var catView: CatView?
    /// The window the cat is standing on, and where its top-left was last seen.
    private var perch: CatSurface?
    private var perchOrigin: CGPoint?
    private var route: Route?
    private var tick = 0
    private var stateTicks = 0
    private var stateLength = 0
    private var lastMouse: CGPoint = .zero
    private var lastMouseMove: Date = .distantPast
    /// Seconds since any keyboard or mouse input, read twice a second.
    private var idleSeconds: Double = 0
    private var fallSpeed: CGFloat = 0
    private var dragOffset: CGPoint?
    private var didDrag = false
    private var surfaceCache: (at: Date, surfaces: [CatSurface])?
    /// The drag pasteboard's count when we last looked, and whether the drag
    /// in progress (left button still down) carries files.
    private var dragCount = NSPasteboard(name: .drag).changeCount
    private var isDraggingFile = false
    /// Whether the last pounce landed on the cursor.
    private var caughtIt = false

    /// A toy out on screen: the yarn ball the cat bats about, or the feather
    /// teaser that dangles from the pointer.
    enum ToyKind { case yarn, teaser }
    private struct Toy {
        var kind: ToyKind
        var panel: CatPanel
        var layer: CALayer
        var size: CGSize
        /// Bottom-left, like the cat; `from` is where the glide starts.
        var position: CGPoint
        var from: CGPoint
        var velocity: CGVector = .zero
        var rolled: CGFloat = 0
        /// Set when the cat actually starts playing, not while it is still
        /// on its way (out of the notch, down from a window).
        var endsAt: Date?
    }
    private var toy: Toy?
    private var swatTicks = 0
    var toyKind: ToyKind? { toy?.kind }

    /// Something to stalk and pounce on: a dragged file, or the teaser.
    private var hasPrey: Bool { (isDraggingFile && pouncesOnDrags) || toy?.kind == .teaser }

    private func prey(_ mouse: CGPoint) -> CGPoint {
        guard let toy, toy.kind == .teaser else { return mouse }
        return CGPoint(x: toy.position.x + toy.size.width / 2, y: toy.position.y + toy.size.height / 2)
    }

    /// A walk along one surface to `takeoff`, an optional jump to another
    /// surface, then a walk to `destination`.
    private struct Route {
        var destination: CGPoint
        var destinationSurface: CatSurface?
        var takeoff: CGPoint?
        var landing: CGPoint?
        var jump: Jump?
    }

    private struct Jump {
        var from: CGPoint
        var to: CGPoint
        var duration: Double
        var elapsed: Double = 0
        /// Height of the arc above the higher end; nil works one out.
        var arc: CGFloat?
    }

    init(coat: CatCoat, chasesPointer: Bool, roaming: CatRoaming, pouncesOnDrags: Bool, chatty: Bool,
         pets: Int, points: Int = 0, hat: CatAccessory? = nil, collar: CatAccessory? = nil,
         starDay: StarDay? = nil, lastFed: Date) {
        self.points = points
        self.starDay = starDay ?? StarDay(day: StarDay.today)
        self.hat = hat
        self.collar = collar
        self.coat = coat
        self.chatty = chatty
        self.pouncesOnDrags = pouncesOnDrags
        self.chasesPointer = chasesPointer
        self.roaming = roaming
        self.pets = pets
        self.lastFed = lastFed
        refreshHunger()
    }

    var isVisible: Bool { panel != nil }

    /// Why the cat is keeping quiet, or nil when it may talk.
    @Published private(set) var quietReason: String?

    /// While quiet, only `essential` lines (levels you are changing yourself)
    /// get a bubble; anything already on screen goes away at once.
    func setQuiet(_ reason: String?) {
        guard reason != quietReason else { return }
        quietReason = reason
        if reason != nil { bubble.clear() }
    }

    /// Shows a line in the cat's speech bubble. A cat that is indoors says
    /// nothing, and a quiet one says only what is essential.
    func say(_ line: CatLine, essential: Bool = false) {
        guard !isFriend else { return }
        resumeIfStalled()
        guard panel != nil, quietReason == nil || essential else { return }
        bubble.say(line)
        // Levels you are changing yourself stay silent.
        if line.key == nil { CatSounds.shared.play(.meow) }
    }

    /// The cat's own remarks, when it is chatty.
    private func remark(_ text: String) {
        if chatty { say(CatLine(text: text)) }
    }

    /// What the widget says the cat is up to.
    var statusTitle: String {
        if isHungry, mood.isIdle { return "Hungry" }
        if musicPlaying, mood == .sitting { return "Vibing to the music" }
        return mood.title
    }
    /// The same, short enough for the wing beside the notch.
    var statusShortTitle: String {
        if isHungry, mood.isIdle { return "Hungry" }
        if musicPlaying, mood == .sitting { return "Vibing" }
        return mood.shortTitle
    }

    /// Earns stars for something the cat enjoyed, within the day's limits:
    /// so many times per source, a short wait between counted pets, and a
    /// daily total. Reaching the total is said once.
    func earn(_ source: StarSource) {
        if let forwardAward { return forwardAward(source) }
        if starDay.day != StarDay.today { starDay = StarDay(day: StarDay.today) }
        if source == .pet {
            guard Date().timeIntervalSince(lastPetStar) >= StarSource.petCooldown else { return }
        }
        guard starDay.counts[source.counter, default: 0] < source.dailyLimit else { return }
        let amount = min(source.amount, StarSource.dailyTotal - starDay.stars)
        guard amount > 0 else { return }
        if source == .pet { lastPetStar = Date() }
        starDay.counts[source.counter, default: 0] += 1
        starDay.stars += amount
        award(amount)
        if starDay.stars >= StarSource.dailyTotal, !starDay.announcedCap {
            starDay.announcedCap = true
            say(CatLine(text: "That's all the stars for today ⭐ See you tomorrow!", symbol: "star.fill", seconds: 3))
            onPersist?()
        }
    }

    /// Adds points straight away, no limits (what `earn` hands on), and
    /// announces (and puts on, if that slot is empty) anything they unlock.
    func award(_ amount: Int) {
        let before = points
        points += amount
        for item in CatAccessory.allCases where item.unlockAt > before && item.unlockAt <= points {
            say(CatLine(text: "Unlocked: \(item.title)!", symbol: "gift.fill", seconds: 3))
            switch item.slot {
            case .hat where hat == nil: hat = item
            case .collar where collar == nil: collar = item
            default: break
            }
        }
        onPersist?()
    }

    /// Puts on, or takes off with nil, something already unlocked.
    func wear(_ item: CatAccessory?, in slot: CatAccessory.Slot) {
        if let item, item.unlockAt > points { return }
        switch slot {
        case .hat: hat = item
        case .collar: collar = item
        }
        onPersist?()
    }

    /// A little celebration, when the cat is free for one.
    func celebrate() {
        guard panel != nil, mood.isIdle || mood == .happy else { return }
        enter(.happy)
    }

    // MARK: Showing and hiding

    func show() {
        guard panel == nil else { return }
        let size = CatSprites.catSize
        let panel = CatPanel(contentRect: CGRect(x: 0, y: 0, width: size.width, height: size.height + Self.effectHeight))
        let view = CatView(frame: CGRect(origin: .zero, size: panel.frame.size))
        view.controller = self
        view.wantsLayer = true

        let cat = CALayer()
        cat.frame = CGRect(origin: .zero, size: size)
        cat.magnificationFilter = .nearest
        cat.actions = ["contents": NSNull(), "transform": NSNull(), "position": NSNull(), "bounds": NSNull()]
        view.layer?.addSublayer(cat)

        let effect = CALayer()
        effect.magnificationFilter = .nearest
        effect.actions = ["contents": NSNull(), "position": NSNull(), "opacity": NSNull(), "bounds": NSNull()]
        view.layer?.addSublayer(effect)

        panel.contentView = view
        self.panel = panel
        catView = view
        drawn = nil
        catLayer = cat
        effectLayer = effect

        // Arrive from the bottom edge of whichever screen has the pointer.
        let screen = Self.screen(containing: NSEvent.mouseLocation) ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        // A friend turns up a little way off rather than on top of the cat.
        let offset: CGFloat = isFriend ? (buddy?.feet.map { $0.x < area.midX ? 90 : -90 } ?? 90) : 0
        position = CGPoint(x: (buddy?.feet?.x ?? area.midX - size.width / 2) + offset, y: area.minY)
        position.x = min(max(position.x, area.minX), area.maxX - size.width)
        perch = nil
        lastMouse = NSEvent.mouseLocation
        enter(.sitting)
        place()
        panel.orderFrontRegardless()
        view.startDisplayLink()

        timer = Timer.scheduledTimer(withTimeInterval: 1 / Self.fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.timer?.fireDate = .distantFuture }
            },
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.timer?.fireDate = Date() }
            },
            // A wake that never reports its screens would leave the cat frozen.
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resumeIfStalled() }
            },
            center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resumeIfStalled() }
            },
        ]
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        catView?.stopDisplayLink()
        catView = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        catLayer = nil
        effectLayer = nil
        removeBowl()
        endPlay(quietly: true)
        bubble.clear()
        route = nil
        perch = nil
        isDraggingFile = false
        mood = .sitting
    }

    /// Restarts the loop if it was paused for sleeping screens that are awake.
    func resumeIfStalled() {
        guard let timer, timer.fireDate > Date().addingTimeInterval(1), CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return }
        timer.fireDate = Date()
    }

    /// Sends the cat running to the pointer, wherever it is; a sleeping cat
    /// just wakes up.
    func callOver() {
        resumeIfStalled()
        guard panel != nil else { return }
        switch mood {
        case .falling, .jumping, .eating, .goingToBowl, .pouncing: break
        case .sleeping:
            enter(.sitting)
            remark(CatWords.awake)
        default: startChase(to: NSEvent.mouseLocation)
        }
    }

    /// A nap right where it is, until woken (a click, Come here, food, play).
    func goHome() {
        guard panel != nil else { return }
        switch mood {
        case .sleeping, .falling, .jumping, .eating, .pouncing: return
        default: break
        }
        route = nil
        enter(.sleeping)
    }

    /// Puts a full bowl on the floor; the cat comes for it as soon as it can.
    func feed() {
        resumeIfStalled()
        guard panel != nil else { return }
        placeBowl()
        if mood.isIdle || mood == .chasing || mood == .happy || mood == .sleeping { headToBowl() }
    }

    // MARK: The loop

    private func step() {
        let before = position
        tick += 1
        stateTicks += 1
        if tick % 6 == 0 { idleSeconds = Self.secondsSinceInput() }
        if tick % Int(Self.fps * 10) == 0 { refreshHunger() }
        if let clears = bowlClearsAt, Date() >= clears { removeBowl() }

        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) > 3 { lastMouseMove = Date() }
        lastMouse = mouse
        watchDrags()
        updateClickThrough(mouse)
        if tick % 3 == 0 { followPerch() }
        stepToy(mouse)
        let target = prey(mouse)

        switch mood {
        case .held:
            break
        case .sleeping:
            if hasPrey { startHunt(target) }
        case .happy:
            if stateTicks >= stateLength { enter(.sitting) }
        case .chasing where hasPrey:
            startHunt(target)
        case .chasing:
            if tick % 6 == 0, route?.jump == nil { planChase(to: mouse) }
            if advance(speed: Self.runSpeed) { enter(.sitting) }
        case .walking:
            if hasPrey { buddyPlan = nil; startHunt(target) } else if toy?.kind == .yarn { buddyPlan = nil; enter(.playing) } else if bowlHasFood { buddyPlan = nil; headToBowl() } else if wantsToChase(mouse) { buddyPlan = nil; startChase(to: mouse) } else if advance(speed: buddyPlan == .tag ? Self.runSpeed : Self.walkSpeed) { arrived() }
        case .sitting, .grooming:
            if hasPrey {
                // A short beat after landing before the next stalk.
                if stateTicks > Int(Self.fps * 0.3) { startHunt(target) }
            } else if toy?.kind == .yarn {
                enter(.playing)
            } else if bowlHasFood {
                headToBowl()
            } else if wantsToChase(mouse) {
                startChase(to: mouse)
            } else if stateTicks >= stateLength {
                pickSomethingToDo()
            }
        case .jumping:
            break
        case .hunting:
            if !hasPrey {
                enter(.sitting)
            } else if isWithinPounce(of: target) {
                enter(.crouching)
            } else {
                if tick % 6 == 0, route?.jump == nil { planApproach(to: target) }
                if advance(speed: Self.runSpeed) { enter(.crouching) }
            }
        case .crouching:
            if abs(target.x - (position.x + CatSprites.catSize.width / 2)) > 2 {
                facesRight = target.x > position.x + CatSprites.catSize.width / 2
            }
            if !hasPrey {
                enter(.sitting)
            } else if stateTicks >= stateLength {
                pounce(at: target)
            }
        case .pouncing:
            if advance(speed: Self.runSpeed) { landPounce(target) }
        case .playing:
            playYarn()
        case .goingToBowl:
            if advance(speed: Self.walkSpeed * 2.5) {
                facesRight = true
                enter(.eating)
            }
        case .eating:
            if stateTicks % 8 == 1 { CatSounds.shared.play(.chew) }
            if stateTicks >= stateLength { finishMeal() }
        case .falling:
            fall()
        }
        animate()
        glide(from: before)
        bubble.update(anchor: bubbleAnchor())
    }

    /// Starts this step's glide; the display link draws it and goes back to
    /// sleep once the cat stands still.
    private func glide(from before: CGPoint) {
        glideFrom = before
        stepAt = CACurrentMediaTime()
        let moving = before != position || toy != nil
        if moving, CACurrentMediaTime() - lastDisplayFrame > 0.25, catView?.displayLinkPaused == false {
            // The display link stopped delivering (its window was hidden):
            // draw from here at the loop's pace, and give it a fresh link.
            render(position)
            if let toy { toy.panel.setFrameOrigin(toy.position) }
            catView?.stopDisplayLink()
            catView?.startDisplayLink()
            catView?.displayLinkPaused = false
            lastDisplayFrame = CACurrentMediaTime()
        } else if moving {
            catView?.displayLinkPaused = false
        } else if catView?.displayLinkPaused ?? true {
            render(position)
        }
    }

    /// One display refresh: the window's place between the last two steps.
    fileprivate func displayFrame() {
        lastDisplayFrame = CACurrentMediaTime()
        let t = min(1, (CACurrentMediaTime() - stepAt) * Self.fps)
        render(CGPoint(
            x: glideFrom.x + (position.x - glideFrom.x) * t,
            y: glideFrom.y + (position.y - glideFrom.y) * t
        ))
        if bubble.isShowing { bubble.update(anchor: bubbleAnchor()) }
        if let toy {
            toy.panel.setFrameOrigin(CGPoint(
                x: toy.from.x + (toy.position.x - toy.from.x) * t,
                y: toy.from.y + (toy.position.y - toy.from.y) * t
            ))
        }
        if t >= 1, toy == nil { catView?.displayLinkPaused = true }
    }

    private func render(_ point: CGPoint) {
        guard point != shown || panel?.frame.origin != point else { return }
        shown = point
        panel?.setFrameOrigin(point)
    }

    /// Over the cat's head, above any heart or Zzz.
    private func bubbleAnchor() -> CatBubble.Anchor? {
        guard panel != nil else { return nil }
        let size = CatSprites.catSize
        let headX = facesRight ? size.width * 0.72 : size.width * 0.28
        let top = spriteHeight
        let lift: CGFloat = (effectLayer?.opacity ?? 0) > 0 ? Self.effectHeight : 0
        return CatBubble.Anchor(point: CGPoint(x: shown.x + headX, y: shown.y + top + lift), pointsUp: false)
    }

    /// The end of a walk: next to the buddy, turn to face it, and after a
    /// game of tag both cats are pleased with themselves.
    private func arrived() {
        let plan = buddyPlan
        buddyPlan = nil
        if plan != nil, let other = buddy?.feet {
            facesRight = other.x > position.x
        }
        if plan == .tag {
            enter(.happy)
            buddy?.celebrate()
        } else {
            enter(.sitting)
        }
    }

    private func pickSomethingToDo() {
        // With a buddy around: a third of the time go and sit with it, now
        // and then run at it for a game of tag.
        if let other = buddy?.feet, Int.random(in: 0..<10) < (isFriend ? 4 : 2) {
            let tag = Int.random(in: 0..<3) == 0
            let side: CGFloat = other.x > position.x ? -1 : 1
            let spot = CGPoint(x: other.x + side * (CatSprites.catSize.width * 0.8), y: other.y)
            planRoute(to: roaming == .anywhere ? spot : CGPoint(x: spot.x, y: floorSurface(near: spot).y),
                      on: roaming == .anywhere ? nil : floorSurface(near: spot))
            buddyPlan = tag ? .tag : .visit
            enter(.walking)
            return
        }
        switch Int.random(in: 0..<10) {
        case 0..<5:
            let (spot, surface) = randomSpot()
            planRoute(to: spot, on: surface)
            enter(.walking)
        case 5..<7:
            enter(.grooming)
        default:
            enter(.sitting)
        }
    }

    private func enter(_ next: CatMood) {
        if next != mood { log?("mood \(mood) -> \(next) at \(position)") }
        mood = next
        stateTicks = 0
        switch next {
        case .sitting: stateLength = Int(Self.fps * Double.random(in: 2...6))
        case .grooming: stateLength = Int(Self.fps * Double.random(in: 2.5...4.5))
        case .happy: stateLength = Int(Self.fps * 1.8)
        case .eating: stateLength = Int(Self.fps * 4)
        case .crouching: stateLength = Int(Self.fps * Double.random(in: 0.5...0.9))
        default: stateLength = .max
        }
        switch next {
        case .walking, .chasing, .goingToBowl, .jumping, .falling, .hunting, .pouncing, .playing: break
        default: route = nil
        }
    }

    private func roamingChanged() {
        surfaceCache = nil
        guard panel != nil else { return }
        // Off a window when windows are no longer allowed; anything above the
        // floor drops down when only the floor is.
        if roaming != .anywhere, mood.isIdle || mood == .sitting {
            let floor = floorSurface(near: position)
            if roaming == .floor || perch == nil, position.y > floor.y + 1 { startFalling() }
        }
    }

    // MARK: Routes

    /// Plans a way to `destination`: straight there when the cat may go
    /// anywhere, otherwise along its surface, with a jump when the
    /// destination is on another one.
    private func planRoute(to destination: CGPoint, on surface: CatSurface?) {
        guard roaming != .anywhere, let surface else {
            route = Route(destination: destination)
            return
        }
        let here = currentSurface()
        if abs(surface.y - position.y) < 1, surface.windowID == here.windowID {
            route = Route(destination: destination, destinationSurface: surface)
            return
        }
        // Walk to the edge of this surface nearest the destination, leap onto
        // the nearest point of the other one, then walk the rest.
        let width = CatSprites.catSize.width
        let takeoffX = min(max(destination.x, here.minX), here.maxX - width)
        let landingX = min(max(takeoffX, surface.minX), surface.maxX - width)
        route = Route(
            destination: destination,
            destinationSurface: surface,
            takeoff: CGPoint(x: takeoffX, y: position.y),
            landing: CGPoint(x: landingX, y: surface.y)
        )
    }

    /// Moves along the route; returns true on arrival.
    private func advance(speed: CGFloat) -> Bool {
        guard var route else { return true }
        if var jump = route.jump {
            jump.elapsed += 1 / Self.fps
            let t = min(1, jump.elapsed / jump.duration)
            let arc = jump.arc ?? max(40, abs(jump.to.y - jump.from.y) * 0.35 + 30)
            position.x = jump.from.x + (jump.to.x - jump.from.x) * t
            position.y = jump.from.y + (jump.to.y - jump.from.y) * t + arc * 4 * t * (1 - t)
            if abs(jump.to.x - jump.from.x) > 1 { facesRight = jump.to.x > jump.from.x }
            if t >= 1 {
                position = jump.to
                land(on: route.destinationSurface)
                route.jump = nil
                route.landing = nil
            } else {
                route.jump = jump
            }
            self.route = route
            return false
        }
        if let takeoff = route.takeoff {
            if step(toward: takeoff, speed: speed) {
                let landing = route.landing ?? route.destination
                let distance = hypot(landing.x - position.x, landing.y - position.y)
                route.takeoff = nil
                route.jump = Jump(from: position, to: landing, duration: min(0.9, max(0.45, Double(distance) / 700)))
                perch = nil
            }
            self.route = route
            return false
        }
        let arrived = step(toward: route.destination, speed: speed)
        if arrived { self.route = nil }
        return arrived
    }

    private func step(toward target: CGPoint, speed: CGFloat) -> Bool {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = hypot(dx, dy)
        let stride = speed / CGFloat(Self.fps)
        if abs(dx) > 1 { facesRight = dx > 0 }
        if distance <= stride {
            position = target
            return true
        }
        position.x += dx / distance * stride
        position.y += dy / distance * stride
        return false
    }

    private var isMidAir: Bool { route?.jump != nil || mood == .falling }

    // MARK: Chasing

    private func wantsToChase(_ mouse: CGPoint) -> Bool {
        guard chasesPointer, Date().timeIntervalSince(lastMouseMove) < 0.4 else { return false }
        let center = CGPoint(x: position.x + CatSprites.catSize.width / 2, y: position.y + CatSprites.catSize.height / 2)
        return hypot(mouse.x - center.x, mouse.y - center.y) > Self.chaseDistance
    }

    private func startChase(to mouse: CGPoint) {
        planChase(to: mouse)
        enter(.chasing)
    }

    /// Beside the pointer: right next to it when the cat may go anywhere,
    /// otherwise on whatever it can stand on below the pointer.
    private func planChase(to mouse: CGPoint) {
        let size = CatSprites.catSize
        let side: CGFloat = mouse.x >= position.x + size.width / 2 ? -1 : 1
        let x = mouse.x - size.width / 2 + side * (size.width / 2 + 6)
        switch roaming {
        case .anywhere:
            planRoute(to: clamp(CGPoint(x: x, y: mouse.y - size.height + 6), near: mouse), on: nil)
        case .floor, .windows:
            let surface = surface(below: mouse)
            let sx = min(max(x, surface.minX), surface.maxX - size.width)
            planRoute(to: CGPoint(x: sx, y: surface.y), on: surface)
        }
    }

    // MARK: Playing

    private static let playSeconds: TimeInterval = 5

    /// Puts a toy out. The yarn ball drops onto the floor in front of the cat;
    /// the teaser hangs off the pointer until playtime is over.
    func play(_ kind: ToyKind) {
        resumeIfStalled()
        guard panel != nil else { return }
        endPlay(quietly: true)
        switch mood {
        default: break
        }
        let rows = kind == .yarn ? CatEffect.yarn1 : CatEffect.teaser
        guard let image = CatSprites.shared.image(rows) else { return }
        let size = CGSize(width: CGFloat(image.width) * CatSprites.scale, height: CGFloat(image.height) * CatSprites.scale)
        let toyPanel = CatPanel(contentRect: CGRect(origin: .zero, size: size))
        toyPanel.ignoresMouseEvents = true
        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        let layer = CALayer()
        layer.frame = view.bounds
        layer.magnificationFilter = .nearest
        layer.contents = image
        layer.actions = ["contents": NSNull(), "transform": NSNull()]
        view.layer?.addSublayer(layer)
        toyPanel.contentView = view

        let start: CGPoint
        switch kind {
        case .yarn:
            let floor = floorSurface(near: position)
            let x = min(max(position.x + (facesRight ? 110 : -60), floor.minX + 10), floor.maxX - size.width - 10)
            start = CGPoint(x: x, y: floor.y)
        case .teaser:
            let mouse = NSEvent.mouseLocation
            start = CGPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 6)
        }
        toyPanel.setFrameOrigin(start)
        toyPanel.orderFrontRegardless()
        toy = Toy(kind: kind, panel: toyPanel, layer: layer, size: size, position: start, from: start)
        catView?.displayLinkPaused = false
        if mood.isIdle || mood == .happy || mood == .sleeping || mood == .chasing {
            enter(.sitting)
        }
    }

    func stopPlaying() { endPlay(quietly: false) }

    private func endPlay(quietly: Bool) {
        guard let toy else { return }
        toy.panel.orderOut(nil)
        toy.panel.close()
        self.toy = nil
        swatTicks = 0
        guard !quietly else { return }
        earn(.play)
        if mood == .playing || mood == .hunting || mood == .crouching || mood == .sitting {
            enter(.happy)
            remark("That was fun!")
        }
    }

    /// Moves the toy one step: the ball rolls and bounces with friction, the
    /// teaser swings after the pointer on a springy string.
    private func stepToy(_ mouse: CGPoint) {
        guard var toy else { return }
        let playingNow = toy.kind == .yarn ? mood == .playing : [.hunting, .crouching, .pouncing].contains(mood)
        if toy.endsAt == nil, playingNow {
            toy.endsAt = Date().addingTimeInterval(Self.playSeconds)
        }
        if let endsAt = toy.endsAt, Date() >= endsAt {
            endPlay(quietly: false)
            return
        }
        let dt = CGFloat(1 / Self.fps)
        toy.from = toy.position
        switch toy.kind {
        case .yarn:
            let floor = floorSurface(near: toy.position)
            toy.velocity.dy -= Self.gravity * dt
            toy.velocity.dx *= pow(0.35, dt)
            toy.position.x += toy.velocity.dx * dt
            toy.position.y += toy.velocity.dy * dt
            if toy.position.y <= floor.y {
                toy.position.y = floor.y
                toy.velocity.dy = abs(toy.velocity.dy) > 120 ? -toy.velocity.dy * 0.35 : 0
                toy.velocity.dx *= pow(0.5, dt)
            }
            if toy.position.x < floor.minX {
                toy.position.x = floor.minX
                toy.velocity.dx = abs(toy.velocity.dx) * 0.7
            } else if toy.position.x > floor.maxX - toy.size.width {
                toy.position.x = floor.maxX - toy.size.width
                toy.velocity.dx = -abs(toy.velocity.dx) * 0.7
            }
            if abs(toy.velocity.dx) < 4 { toy.velocity.dx = 0 }
            // Turn a quarter each time the ball rolls its own width.
            toy.rolled += abs(toy.position.x - toy.from.x)
            let turn = Int(toy.rolled / (toy.size.width / 2)) % 2
            toy.layer.contents = CatSprites.shared.image(turn == 0 ? .yarn1 : .yarn2)
        case .teaser:
            // Hangs a little below the pointer and lags behind it.
            let anchor = CGPoint(x: mouse.x - toy.size.width / 2, y: mouse.y - toy.size.height - 8)
            toy.velocity.dx = toy.velocity.dx * 0.55 + (anchor.x - toy.position.x) * 0.45 * Self.fps * dt * 6
            toy.velocity.dy = toy.velocity.dy * 0.55 + (anchor.y - toy.position.y) * 0.45 * Self.fps * dt * 6
            toy.position.x += toy.velocity.dx * dt
            toy.position.y += toy.velocity.dy * dt
        }
        self.toy = toy
    }

    /// Chase the ball along the floor and bat it on.
    private func playYarn() {
        guard let ball = toy, ball.kind == .yarn else { return enter(.sitting) }
        if swatTicks > 0 {
            swatTicks -= 1
            return
        }
        let size = CatSprites.catSize
        let floor = floorSurface(near: position)
        if position.y > floor.y + 1 {
            planRoute(to: CGPoint(x: position.x, y: floor.y), on: floor)
            _ = advance(speed: Self.runSpeed)
            return
        }
        let ballCenter = ball.position.x + ball.size.width / 2
        let fromLeft = position.x + size.width / 2 < ballCenter
        // Front paw just touching the ball.
        let spotX = fromLeft ? ballCenter - (size.width - 4) : ballCenter - 4
        let gap = spotX - position.x
        let ballSpeed = abs(ball.velocity.dx)
        if abs(gap) < 6, ballSpeed < 140, ball.position.y <= floor.y + 2 {
            facesRight = fromLeft
            swat(right: fromLeft)
        } else {
            let speed = abs(gap) > 90 ? Self.runSpeed : Self.walkSpeed * 2.5
            _ = step(toward: CGPoint(x: spotX, y: floor.y), speed: speed)
        }
    }

    private func swat(right: Bool) {
        guard var ball = toy else { return }
        ball.velocity = CGVector(dx: (right ? 1 : -1) * CGFloat.random(in: 240...460), dy: CGFloat.random(in: 160...340))
        toy = ball
        swatTicks = 4
    }

    // MARK: Pouncing on dragged files

    /// A drag starts by writing to the drag pasteboard; it lasts while the
    /// left button stays down. Only its types are read, never its contents.
    private func watchDrags() {
        let buttonDown = NSEvent.pressedMouseButtons & 1 != 0
        // A drag only exists while the button is held; with it up there is
        // nothing to ask the pasteboard server about.
        if buttonDown, !isDraggingFile, case let board = NSPasteboard(name: .drag), board.changeCount != dragCount {
            dragCount = board.changeCount
            if buttonDown, dragOffset == nil {
                isDraggingFile = board.types?.contains(.fileURL) == true
                if isDraggingFile { log?("file drag started") }
            }
        }
        if !buttonDown, isDraggingFile {
            isDraggingFile = false
            if mood == .sitting, caughtIt { enter(.happy) }
            caughtIt = false
        }
    }

    private func startHunt(_ mouse: CGPoint) {
        caughtIt = false
        if isWithinPounce(of: mouse) {
            enter(.crouching)
        } else {
            planApproach(to: mouse)
            enter(.hunting)
        }
    }

    /// Close enough to leap: a short hop sideways, and on the floor or a
    /// window, a cursor no higher than a good jump.
    private func isWithinPounce(of mouse: CGPoint) -> Bool {
        let center = CGPoint(x: position.x + CatSprites.catSize.width / 2, y: position.y + 20)
        let dx = abs(mouse.x - center.x)
        let dy = mouse.y - center.y
        switch roaming {
        case .anywhere: return hypot(dx, dy) < 260
        case .floor, .windows: return dx < 220 && dy < 420
        }
    }

    /// A spot a little short of the cursor, on the cat's side of it.
    private func planApproach(to mouse: CGPoint) {
        let size = CatSprites.catSize
        let side: CGFloat = mouse.x >= position.x + size.width / 2 ? -1 : 1
        let x = mouse.x - size.width / 2 + side * 140
        switch roaming {
        case .anywhere:
            planRoute(to: clamp(CGPoint(x: x, y: mouse.y - size.height / 2 - 60), near: mouse), on: nil)
        case .floor, .windows:
            let surface = surface(below: CGPoint(x: mouse.x, y: mouse.y))
            let sx = min(max(x, surface.minX), surface.maxX - size.width)
            planRoute(to: CGPoint(x: sx, y: surface.y), on: surface)
        }
    }

    /// Leap so the front paws reach the cursor at the top of the arc. Where
    /// the cat may only stand on things, it comes down on whatever is below.
    private func pounce(at mouse: CGPoint) {
        let size = CatSprites.catSize
        // Paws are at the front edge, about two thirds of the way up.
        let pawX: CGFloat = facesRight ? size.width - 6 : 6
        let reach = CGPoint(x: mouse.x - pawX, y: mouse.y - size.height * 0.65)
        let landing: CGPoint
        let surface: CatSurface?
        let arc: CGFloat
        switch roaming {
        case .anywhere:
            landing = clamp(reach, near: mouse)
            surface = nil
            arc = 50
        case .floor, .windows:
            let below = self.surface(below: CGPoint(x: mouse.x, y: mouse.y))
            surface = below
            landing = CGPoint(x: min(max(reach.x, below.minX), below.maxX - size.width), y: below.y)
            // A cursor out of reach gets a big jump, not a flight.
            arc = min(450, max(50, reach.y - max(position.y, landing.y)))
        }
        perch = nil
        perchOrigin = nil
        let distance = hypot(landing.x - position.x, arc)
        route = Route(
            destination: landing,
            destinationSurface: surface,
            jump: Jump(from: position, to: landing, duration: min(0.75, max(0.4, Double(distance) / 650)), arc: arc)
        )
        enter(.pouncing)
    }

    private func landPounce(_ mouse: CGPoint) {
        // Caught it if the cursor ended up over the cat.
        let body = CGRect(origin: position, size: CatSprites.catSize).insetBy(dx: -24, dy: -24)
        caughtIt = body.contains(mouse)
        if caughtIt {
            remark(CatWords.caught)
            earn(.catchFile)
        }
        enter(hasPrey ? .sitting : (caughtIt ? .happy : .sitting))
    }

    // MARK: Surfaces

    /// The floor of the screen around `point`.
    private func floorSurface(near point: CGPoint) -> CatSurface {
        let screen = Self.screen(containing: CGPoint(x: point.x + CatSprites.catSize.width / 2, y: point.y + 1))
            ?? Self.screen(containing: point) ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        return CatSurface(y: area.minY, minX: area.minX, maxX: area.maxX, windowID: nil)
    }

    private func currentSurface() -> CatSurface {
        if let perch, roaming == .windows { return perch }
        return floorSurface(near: position)
    }

    /// The highest thing to stand on at or below `point`.
    private func surface(below point: CGPoint) -> CatSurface {
        let floor = floorSurface(near: point)
        guard roaming == .windows else { return floor }
        let width = CatSprites.catSize.width
        return windowSurfaces()
            .filter { $0.y <= point.y + 1 && point.x >= $0.minX - width / 2 && point.x <= $0.maxX + width / 2 }
            .max { $0.y < $1.y } ?? floor
    }

    /// The visible top edges of the windows on screen, wide enough to stand
    /// on and low enough to stand under the menu bar. Reading window bounds
    /// needs no permission.
    private func windowSurfaces() -> [CatSurface] {
        if let cache = surfaceCache, Date().timeIntervalSince(cache.at) < 0.25 { return cache.surfaces }
        let size = CatSprites.catSize
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        // Front to back; a window's top edge is visible only where nothing in
        // front of it covers that line.
        var covers: [CGRect] = []
        var surfaces: [CatSurface] = []
        for window in info {
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  (window[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  let id = window[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            defer { covers.append(bounds) }
            guard bounds.width >= size.width * 2.5, bounds.height >= 80 else { continue }

            let top = primaryHeight - bounds.minY
            guard let screen = Self.screen(containing: CGPoint(x: bounds.midX, y: top - 1)),
                  top + size.height <= screen.visibleFrame.maxY,
                  top > screen.visibleFrame.minY + size.height
            else { continue }

            // Subtract every window in front that crosses this window's top line.
            var segments = [(bounds.minX, bounds.maxX)]
            for front in covers where front.minY <= bounds.minY + 2 && front.maxY > bounds.minY - size.height {
                segments = segments.flatMap { segment -> [(CGFloat, CGFloat)] in
                    if front.maxX <= segment.0 || front.minX >= segment.1 { return [segment] }
                    var pieces: [(CGFloat, CGFloat)] = []
                    if front.minX > segment.0 { pieces.append((segment.0, front.minX)) }
                    if front.maxX < segment.1 { pieces.append((front.maxX, segment.1)) }
                    return pieces
                }
            }
            if let widest = segments.max(by: { ($0.1 - $0.0) < ($1.1 - $1.0) }), widest.1 - widest.0 >= size.width + 10 {
                surfaces.append(CatSurface(y: top, minX: widest.0, maxX: widest.1, windowID: id, windowX: bounds.minX))
            }
        }
        surfaceCache = (Date(), surfaces)
        return surfaces
    }

    private func land(on surface: CatSurface?) {
        if let surface, surface.windowID != nil, roaming == .windows {
            perch = surface
            perchOrigin = CGPoint(x: surface.windowX ?? surface.minX, y: surface.y)
        } else {
            perch = nil
            perchOrigin = nil
        }
    }

    /// Rides along when the window under the cat moves, and falls when it
    /// closes, minimises or slides out from under it.
    private func followPerch() {
        guard let perch, roaming == .windows, !isMidAir, mood != .held else { return }
        surfaceCache = nil
        guard let now = windowSurfaces().first(where: { $0.windowID == perch.windowID }) else {
            startFalling()
            return
        }
        let nowX = now.windowX ?? now.minX
        if let origin = perchOrigin, abs(now.y - origin.y) > 0.5 || abs(nowX - origin.x) > 0.5 {
            // The window moved; whole-window moves shift the left edge and the
            // top together, so carry the cat by the same amount.
            let dx = nowX - origin.x
            let dy = now.y - origin.y
            position.x += dx
            position.y += dy
            if var route {
                route.destination.x += dx
                route.destination.y += dy
                route.takeoff?.x += dx
                route.takeoff?.y += dy
                self.route = route
            }
        }
        // Checked after the ride: a window dragged sideways carries the cat,
        // one that slides under another window drops it.
        let center = position.x + CatSprites.catSize.width / 2
        guard center >= now.minX, center <= now.maxX else {
            startFalling()
            return
        }
        self.perch = now
        perchOrigin = CGPoint(x: nowX, y: now.y)
    }

    private func startFalling() {
        route = nil
        perch = nil
        perchOrigin = nil
        fallSpeed = 0
        enter(.falling)
    }

    private func fall() {
        let below = surface(below: CGPoint(x: position.x + CatSprites.catSize.width / 2, y: position.y))
        fallSpeed += Self.gravity / CGFloat(Self.fps)
        position.y -= fallSpeed / CGFloat(Self.fps)
        if position.y <= below.y {
            position.y = below.y
            land(on: below)
            lastMouseMove = .distantPast
            enter(bowlHasFood ? .sitting : .happy)
        }
    }

    // MARK: The bowl

    private var bowlSize: CGSize {
        CGSize(width: 12 * CatSprites.scale, height: 6 * CatSprites.scale)
    }

    private func placeBowl() {
        let size = CatSprites.catSize
        let floor = floorSurface(near: position)
        // A step or two in front of the cat, on the floor, never off screen.
        let preferred = position.x + size.width + 40
        let x = min(max(preferred, floor.minX + size.width), floor.maxX - bowlSize.width - 10)

        if bowlPanel == nil {
            let bowl = CatPanel(contentRect: CGRect(origin: .zero, size: bowlSize))
            bowl.ignoresMouseEvents = true
            let view = NSView(frame: CGRect(origin: .zero, size: bowlSize))
            view.wantsLayer = true
            let layer = CALayer()
            layer.frame = view.bounds
            layer.magnificationFilter = .nearest
            layer.actions = ["contents": NSNull()]
            view.layer?.addSublayer(layer)
            bowl.contentView = view
            bowlPanel = bowl
            bowlLayer = layer
        }
        bowlLayer?.contents = CatSprites.shared.image(.bowl)
        bowlPanel?.setFrameOrigin(CGPoint(x: x, y: floor.y))
        bowlPanel?.orderFrontRegardless()
        bowlHasFood = true
        bowlClearsAt = nil
        log?("bowl down at \(x), \(floor.y)")
    }

    private func headToBowl() {
        guard let bowl = bowlPanel?.frame else { return }
        let spot = CGPoint(x: bowl.midX - Self.mouthX, y: bowl.minY)
        planRoute(to: spot, on: floorSurface(near: spot))
        enter(.goingToBowl)
    }

    private func finishMeal() {
        remark(CatWords.full)
        earn(isHungry ? .hungryMeal : .meal)
        lastFed = Date()
        refreshHunger()
        onPersist?()
        bowlHasFood = false
        bowlLayer?.contents = CatSprites.shared.image(.bowlEmpty)
        bowlClearsAt = Date().addingTimeInterval(4)
        enter(.happy)
    }

    private func removeBowl() {
        bowlPanel?.orderOut(nil)
        bowlPanel?.close()
        bowlPanel = nil
        bowlLayer = nil
        bowlHasFood = false
        bowlClearsAt = nil
    }

    private func refreshHunger() {
        let hours = Date().timeIntervalSince(lastFed) / 3600
        let next = max(0, 1 - hours / Self.hungerHours)
        if abs(next - fullness) > 0.005 { fullness = next }
        let hungry = next < Self.hungryBelow
        if hungry != isHungry {
            isHungry = hungry
            if hungry { remark(CatWords.hungry) }
        }
    }

    // MARK: Drawing

    private func animate() {
        let next: CatFrame
        switch mood {
        case .sitting where musicPlaying:
            // Head-bobbing to the beat, eyes closed on the down beat.
            next = (tick / 5) % 2 == 0 ? .happy : .sit
        case .sitting: next = (stateTicks % 40) >= 37 ? .blink : .sit
        case .walking, .goingToBowl:
            // A four-beat walk, 1-2-3-2, at six steps a second.
            next = route?.jump != nil ? .run1
                : buddyPlan == .tag ? ((tick / 2) % 2 == 0 ? .run1 : .run2)
                : [CatFrame.walk1, .walk2, .walk3, .walk2][(tick / 2) % 4]
        case .chasing: next = route?.jump != nil ? .run1 : ((tick / 2) % 2 == 0 ? .run1 : .run2)
        case .jumping: next = .run1
        case .hunting: next = route?.jump != nil ? .run1 : ((tick / 2) % 2 == 0 ? .run1 : .run2)
        case .crouching: next = (stateTicks / 2) % 2 == 0 ? .crouch1 : .crouch2
        case .pouncing: next = .run1
        case .playing:
            if swatTicks > 0 {
                next = .crouch2
            } else if let toy, abs(toy.position.x - position.x) > 70 {
                next = (tick / 2) % 2 == 0 ? .run1 : .run2
            } else {
                next = (stateTicks / 3) % 2 == 0 ? .crouch1 : .crouch2
            }
        case .falling: next = .run2
        case .grooming: next = (stateTicks / 4) % 2 == 0 ? .groom1 : .groom2
        case .eating: next = (stateTicks / 4) % 2 == 0 ? .eat1 : .eat2
        case .sleeping: next = (stateTicks / 14) % 2 == 0 ? .sleep1 : .sleep2
        case .happy: next = .happy
        // Carried: dangling, legs and tail swaying.
        case .held: next = (tick / 4) % 2 == 0 ? .held1 : .held2
        }
        if next != frame { frame = next }
        bob = (mood == .sitting && musicPlaying && (tick / 5) % 2 == 1) ? 3 : 0
        redraw()
    }

    /// What the window shows; redrawing is skipped while it stays the same.
    private var drawn: (frame: CatFrame, coat: CatCoat, right: Bool, bob: CGFloat, look: String)?
    /// Height of what is drawn, hat included, for the bubble to clear.
    private var spriteHeight: CGFloat = CatSprites.catSize.height

    private func redraw() {
        guard let catLayer, let effectLayer else { return }
        let effectShowing = mood == .happy || mood == .sleeping || (mood == .sitting && isHungry)
        let look = "\(hat?.rawValue ?? "")|\(collar?.rawValue ?? "")"
        if let drawn, drawn.frame == frame, drawn.coat == coat, drawn.right == facesRight, drawn.bob == bob,
           drawn.look == look, !effectShowing, effectLayer.opacity == 0 {
            return
        }
        drawn = (frame, coat, facesRight, bob, look)
        let sprite = CatSprites.shared.image(frame, coat: coat, hat: hat, collar: collar)
        spriteHeight = sprite.map { CGFloat($0.height) * CatSprites.scale } ?? spriteHeight
        catLayer.contents = sprite
        if let sprite {
            let w = CGFloat(sprite.width) * CatSprites.scale
            let h = CGFloat(sprite.height) * CatSprites.scale
            catLayer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
            // Feet on the window's floor; a hat makes the image taller, upward.
            catLayer.position = CGPoint(x: CatSprites.catSize.width / 2, y: h / 2 + bob)
        }
        catLayer.setAffineTransform(facesRight || mood == .held ? .identity : CGAffineTransform(scaleX: -1, y: 1))

        let size = CatSprites.catSize
        let scale = CatSprites.scale
        let effect: CatEffect?
        switch mood {
        case .happy: effect = .heart
        case .sleeping: effect = .zzz
        case .sitting where isHungry: effect = .fish
        default: effect = nil
        }
        guard let effect, let image = CatSprites.shared.image(effect) else {
            effectLayer.opacity = 0
            return
        }
        effectLayer.opacity = 1
        effectLayer.contents = image
        let w = CGFloat(image.width) * scale * 0.67
        let h = CGFloat(image.height) * scale * 0.67
        // The head is on the right of the art; mirror the effect with the cat.
        let headX = facesRight ? size.width * 0.72 : size.width * 0.28
        let rise: CGFloat
        switch effect {
        case .heart: rise = CGFloat(stateTicks) * 0.9
        case .fish: rise = CGFloat((stateTicks / 8) % 2) * 2
        default: rise = CGFloat((stateTicks / 6) % 3) * 2
        }
        effectLayer.frame = CGRect(x: headX - w / 2, y: min(size.height - 4 + rise * 0.4, size.height + Self.effectHeight - h), width: w, height: h)
    }

    /// Jumps the window straight to `position`, no glide: for a teleport
    /// out of the notch, a drag, a fresh start.
    private func place() {
        glideFrom = position
        shown = position
        panel?.setFrameOrigin(position)
    }

    /// Only the cat's own rectangle takes clicks; everything around it passes through.
    private func updateClickThrough(_ mouse: CGPoint) {
        guard let panel, dragOffset == nil else { return }
        let body = CGRect(origin: position, size: CatSprites.catSize).insetBy(dx: 6, dy: 2)
        // While a file is dragged the cat must never be a drop target.
        let ignores = isDraggingFile || !body.contains(mouse)
        if panel.ignoresMouseEvents != ignores { panel.ignoresMouseEvents = ignores }
    }

    // MARK: Mouse on the cat

    fileprivate func mouseDown(at screenPoint: CGPoint) {
        dragOffset = CGPoint(x: screenPoint.x - position.x, y: screenPoint.y - position.y)
        didDrag = false
    }

    /// A long press opened the menu: the press is no longer a pet or a drag.
    fileprivate func cancelPress() {
        dragOffset = nil
        didDrag = false
    }

    fileprivate var isAsleep: Bool { mood == .sleeping }

    fileprivate func mouseDragged(to screenPoint: CGPoint) {
        guard dragOffset != nil else { return }
        if !didDrag {
            didDrag = true
            panel?.level = .floating
            perch = nil
            perchOrigin = nil
            enter(.held)
        }
        // Held up under the arms: the head sits just below the pointer, the
        // rest of the cat hanging from it.
        position = CGPoint(x: screenPoint.x - Self.heldGrip.x, y: screenPoint.y - Self.heldGrip.y)
        animate()
        place()
    }

    fileprivate func mouseUp() {
        guard dragOffset != nil else { return }
        dragOffset = nil
        if didDrag {
            position = clamp(position, near: CGPoint(x: position.x + CatSprites.catSize.width / 2, y: position.y))
            // Let go in mid-air, it drops to whatever is below unless it may
            // stand anywhere.
            if roaming == .anywhere { enter(.sitting) } else { startFalling() }
        } else {
            pets += 1
            CatSounds.shared.play(.purr)
            earn(.pet)
            if pets % 5 == 0 { remark(CatWords.purr) }
            panel?.level = .floating
            if mood != .eating { enter(.happy) }
        }
        animate()
        place()
    }

    // MARK: Geometry

    private func randomSpot() -> (CGPoint, CatSurface?) {
        let size = CatSprites.catSize
        let floor = floorSurface(near: position)
        switch roaming {
        case .anywhere:
            let area = (Self.screen(containing: CGPoint(x: position.x + size.width / 2, y: position.y + 1)) ?? NSScreen.main)?.visibleFrame ?? .zero
            let x = CGFloat.random(in: area.minX...max(area.minX, area.maxX - size.width))
            let y = CGFloat.random(in: area.minY...max(area.minY, area.maxY - size.height))
            return (CGPoint(x: x, y: y), nil)
        case .floor:
            return (CGPoint(x: CGFloat.random(in: floor.minX...max(floor.minX, floor.maxX - size.width)), y: floor.y), floor)
        case .windows:
            // Half the time somewhere on the floor, half on a window it can see.
            let windows = windowSurfaces()
            let surface = (Bool.random() ? windows.randomElement() : nil) ?? floor
            let x = CGFloat.random(in: surface.minX...max(surface.minX, surface.maxX - size.width))
            return (CGPoint(x: x, y: surface.y), surface)
        }
    }

    private func clamp(_ point: CGPoint, near anchor: CGPoint) -> CGPoint {
        let size = CatSprites.catSize
        guard let area = (Self.screen(containing: anchor) ?? NSScreen.main)?.visibleFrame else { return point }
        return CGPoint(
            x: min(max(point.x, area.minX), area.maxX - size.width),
            y: min(max(point.y, area.minY), area.maxY - size.height)
        )
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private static func secondsSinceInput() -> Double {
        guard let any = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: any)
    }
}

// MARK: - Window

/// A borderless, non-activating panel: clicking the cat never steals focus
/// from the app you are in, and it follows you across Spaces.
final class CatPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        // No .fullScreenAuxiliary: the cat stays out of full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// The cat may be dropped or carried part off screen; never shove it back.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class CatView: NSView {
    weak var controller: CatController?
    private var link: CADisplayLink?

    /// Paused whenever the cat stands still, so an idle cat costs nothing
    /// between its 12 logic steps a second.
    var displayLinkPaused: Bool {
        get { link?.isPaused ?? true }
        set { link?.isPaused = newValue }
    }

    func startDisplayLink() {
        guard link == nil else { return }
        let link = displayLink(target: self, selector: #selector(refresh(_:)))
        // Sixty frames a second is already smooth for a pixel cat; on a
        // 120 Hz screen this halves the work.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stopDisplayLink() {
        link?.invalidate()
        link = nil
    }

    @objc private func refresh(_ link: CADisplayLink) {
        MainActor.assumeIsolated { controller?.displayFrame() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Hold on the cat for half a second to get its menu.
    private var pressTimer: Timer?
    private var pressStart: CGPoint = .zero

    override func mouseDown(with event: NSEvent) {
        pressStart = NSEvent.mouseLocation
        MainActor.assumeIsolated { controller?.mouseDown(at: pressStart) }
        pressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.longPress() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pressTimer = timer
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        // A real drag, not a wobbly hold, cancels the menu.
        if hypot(now.x - pressStart.x, now.y - pressStart.y) > 4 {
            pressTimer?.invalidate()
            pressTimer = nil
        }
        MainActor.assumeIsolated { controller?.mouseDragged(to: now) }
    }

    override func mouseUp(with event: NSEvent) {
        pressTimer?.invalidate()
        pressTimer = nil
        MainActor.assumeIsolated { controller?.mouseUp() }
    }

    private func longPress() {
        pressTimer = nil
        guard let controller else { return }
        MainActor.assumeIsolated { controller.cancelPress() }
        let menu = NSMenu()
        menu.autoenablesItems = false
        func item(_ title: String, _ symbol: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            return item
        }
        menu.addItem(item("Feed", "fork.knife", #selector(feed)))
        let asleep = MainActor.assumeIsolated { controller.isAsleep }
        menu.addItem(asleep ? item("Wake up", "sun.max", #selector(wake)) : item("Nap", "moon.zzz", #selector(nap)))
        let play = NSMenuItem(title: "Play", action: nil, keyEquivalent: "")
        play.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: nil)
        let toys = NSMenu()
        toys.addItem(item("Yarn ball", "circle.hexagongrid.fill", #selector(playYarn)))
        toys.addItem(item("Cat teaser", "wand.and.stars", #selector(playTeaser)))
        if MainActor.assumeIsolated({ controller.toyKind }) != nil {
            toys.addItem(.separator())
            toys.addItem(item("Stop playing", "stop.circle", #selector(stopPlaying)))
        }
        play.submenu = toys
        menu.addItem(play)

        let (points, worn) = MainActor.assumeIsolated { (controller.points, [controller.hat, controller.collar]) }
        let wardrobe = NSMenuItem(title: "Wardrobe (\(points) ★)", action: nil, keyEquivalent: "")
        wardrobe.image = NSImage(systemSymbolName: "tshirt", accessibilityDescription: nil)
        let clothes = NSMenu()
        clothes.autoenablesItems = false
        for (slot, none) in [(CatAccessory.Slot.hat, "No hat"), (.collar, "No collar")] {
            let off = NSMenuItem(title: none, action: #selector(wearItem(_:)), keyEquivalent: "")
            off.target = self
            off.representedObject = slot == .hat ? "hat:" : "collar:"
            off.state = worn[slot == .hat ? 0 : 1] == nil ? .on : .off
            clothes.addItem(off)
            for item in CatAccessory.allCases where item.slot == slot {
                let unlocked = item.unlockAt <= points
                let entry = NSMenuItem(title: unlocked ? item.title : "\(item.title) (at \(item.unlockAt) ★)", action: #selector(wearItem(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = (slot == .hat ? "hat:" : "collar:") + item.rawValue
                entry.isEnabled = unlocked
                entry.state = worn.contains(item) ? .on : .off
                clothes.addItem(entry)
            }
            if slot == .hat { clothes.addItem(.separator()) }
        }
        wardrobe.submenu = clothes
        menu.addItem(wardrobe)
        menu.popUp(positioning: nil, at: CGPoint(x: bounds.midX, y: bounds.maxY - 4), in: self)
    }

    @objc private func feed() { MainActor.assumeIsolated { controller?.feed() } }
    @objc private func nap() { MainActor.assumeIsolated { controller?.goHome() } }
    @objc private func wake() { MainActor.assumeIsolated { controller?.callOver() } }
    @objc private func playYarn() { MainActor.assumeIsolated { controller?.play(.yarn) } }
    @objc private func playTeaser() { MainActor.assumeIsolated { controller?.play(.teaser) } }
    @objc private func stopPlaying() { MainActor.assumeIsolated { controller?.stopPlaying() } }
    @objc private func wearItem(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let slot: CatAccessory.Slot = parts.first == "hat" ? .hat : .collar
        let item = parts.count > 1 ? CatAccessory(rawValue: String(parts[1])) : nil
        MainActor.assumeIsolated { controller?.wear(item, in: slot) }
    }
}
