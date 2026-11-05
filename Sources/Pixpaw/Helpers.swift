//
//  Helpers.swift
//  Pixpaw
//
//  When a coding agent sends a helper off on a task (a Claude Code subagent,
//  an Antigravity subagent), a little one of your pet's kind walks in from
//  the edge of the screen and sits down at its own laptop beside it. When
//  the helper is done it brings the result over in a parcel, hands it to
//  your pet and goes home.
//

import AppKit

@MainActor
final class HelperPet {
    private enum Stage { case arriving, working, delivering, leaving }

    let id: String
    let agent: String
    let since = Date()
    /// Gone off the screen: the droplet forgets it.
    var onGone: (() -> Void)?

    /// Points per art pixel: a size smaller than the pet's three.
    private static let points: CGFloat = 2
    private static let speed: CGFloat = 6
    private static let parcelRoom: CGFloat = 16
    private static var size: CGSize {
        CGSize(width: CGFloat(CatArt.width) * points + 8, height: CGFloat(CatArt.height) * points + parcelRoom)
    }

    private let panel: CatPanel
    private let body = CALayer()
    private let parcel = CALayer()
    private var timer: Timer?
    private weak var pet: CatController?
    private var stage = Stage.arriving
    private var x: CGFloat
    private let floor: CGFloat
    private let area: CGRect
    private var spot: CGFloat
    private var facesRight: Bool
    private var tick = 0

    /// Walks in from the nearer edge to its place beside the pet, `index`
    /// places along when others are already there.
    init?(id: String, agent: String, beside pet: CatController, index: Int) {
        guard let feet = pet.feet,
              let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(feet) }) ?? NSScreen.main else { return nil }
        self.id = id
        self.agent = agent
        self.pet = pet
        area = screen.visibleFrame
        floor = area.minY
        let size = Self.size
        let petMiddle = feet.x + CatSprites.catSize.width / 2
        // Lined up on the roomier side of the pet, one place each.
        let side: CGFloat = petMiddle > area.midX ? -1 : 1
        spot = petMiddle + side * (CatSprites.catSize.width * 0.6 + CGFloat(index) * (size.width + 4)) - size.width / 2
        spot = min(max(spot, area.minX), area.maxX - size.width)
        x = side < 0 ? area.minX - size.width : area.maxX
        facesRight = side < 0
        panel = CatPanel(contentRect: CGRect(origin: CGPoint(x: x, y: floor), size: size))
        panel.ignoresMouseEvents = true
        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        for layer in [body, parcel] {
            layer.magnificationFilter = .nearest
            layer.actions = ["contents": NSNull(), "transform": NSNull(), "position": NSNull(), "bounds": NSNull(), "opacity": NSNull()]
            view.layer?.addSublayer(layer)
        }
        if let box = AgentArt.parcel.frames.first {
            parcel.contents = box
            parcel.bounds = CGRect(x: 0, y: 0, width: CGFloat(box.width) * Self.points, height: CGFloat(box.height) * Self.points)
        }
        parcel.opacity = 0
        panel.contentView = view
    }

    func start() {
        draw()
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    /// Done: it brings the parcel over to the pet.
    func deliver() {
        guard stage == .arriving || stage == .working else { return }
        stage = .delivering
        parcel.opacity = 1
    }

    /// Off home at once, no parcel: its agent went quiet, or the pet went in.
    func leave() {
        guard stage != .leaving else { return }
        stage = .leaving
        parcel.opacity = 0
    }

    func remove() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
        panel.close()
    }

    private func step() {
        tick += 1
        switch stage {
        case .arriving:
            if walk(to: spot) { stage = .working }
        case .working:
            break
        case .delivering:
            guard let feet = pet?.feet else { return leave() }
            let petWidth = CatSprites.catSize.width
            let middle = x + Self.size.width / 2
            let target = middle < feet.x + petWidth / 2 ? feet.x - Self.size.width + 6 : feet.x + petWidth - 6
            if walk(to: target) {
                facesRight = feet.x + petWidth / 2 > middle
                pet?.parcelArrived()
                leave()
            }
        case .leaving:
            let home = x + Self.size.width / 2 < area.midX ? area.minX - Self.size.width : area.maxX
            if walk(to: home) {
                remove()
                onGone?()
                return
            }
        }
        draw()
    }

    /// A step toward `target`; true once there.
    private func walk(to target: CGFloat) -> Bool {
        let gap = target - x
        if abs(gap) <= Self.speed {
            x = target
        } else {
            x += gap > 0 ? Self.speed : -Self.speed
            facesRight = gap > 0
        }
        panel.setFrameOrigin(CGPoint(x: x, y: floor))
        return x == target
    }

    private func draw() {
        guard let pet else { return }
        let frame: CatFrame
        switch stage {
        case .working: frame = tick % 50 < 2 ? .blink : .sit
        default: frame = [CatFrame.walk1, .walk2, .walk3][(tick / 2) % 3]
        }
        guard let image = CatSprites.shared.image(frame, coat: pet.coat, kind: pet.kind, laptop: stage == .working) else { return }
        let w = CGFloat(image.width) * Self.points, h = CGFloat(image.height) * Self.points
        body.contents = image
        body.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        body.position = CGPoint(x: Self.size.width / 2, y: h / 2 + (stage == .working ? 0 : CGFloat(tick % 2)))
        body.setAffineTransform(facesRight ? .identity : CGAffineTransform(scaleX: -1, y: 1))
        // Carried high over its head.
        parcel.position = CGPoint(x: Self.size.width / 2 + (facesRight ? 6 : -6), y: h + parcel.bounds.height / 2 - 2)
    }
}
