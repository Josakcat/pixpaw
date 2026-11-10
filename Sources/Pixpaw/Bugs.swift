//
//  Bugs.swift
//  Pixpaw
//
//  When a coding agent's tests or build fail, a little pixel bug turns up
//  on the floor near your pet and scuttles about, running off whenever the
//  pet comes close. When the same command passes again, the pet catches it.
//

import AppKit

@MainActor
final class PixelBug {
    /// The command it came from ("npm test"): the same one passing catches it.
    let key: String
    let since = Date()
    private(set) var caught = false

    private static let points: CGFloat = 3
    private static var size: CGSize { CGSize(width: 8 * points, height: 6 * points) }
    private static let crawl: CGFloat = 1.5
    private static let dash: CGFloat = 6

    private let panel: CatPanel
    private let layer = CALayer()
    private var timer: Timer?
    private weak var pet: CatController?
    private var x: CGFloat
    private let floor: CGFloat
    private let area: CGRect
    private var heading: CGFloat
    private var resting = 0
    private var frozen = false
    private var tick = 0

    /// Where its middle is, on the floor, for the pet to run at.
    var spot: CGPoint { CGPoint(x: x + Self.size.width / 2, y: floor) }

    init?(key: String, near pet: CatController) {
        guard let feet = pet.feet,
              let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(feet) }) ?? NSScreen.main else { return nil }
        self.key = key
        self.pet = pet
        area = screen.visibleFrame
        floor = area.minY
        // Turns up a little way off, on the roomier side.
        let side: CGFloat = feet.x > area.midX ? -1 : 1
        x = min(max(feet.x + side * CGFloat.random(in: 120...220), area.minX), area.maxX - Self.size.width)
        heading = side
        panel = CatPanel(contentRect: CGRect(origin: CGPoint(x: x, y: floor), size: Self.size))
        panel.ignoresMouseEvents = true
        let view = NSView(frame: CGRect(origin: .zero, size: Self.size))
        view.wantsLayer = true
        layer.frame = view.bounds
        layer.magnificationFilter = .nearest
        layer.actions = ["contents": NSNull(), "transform": NSNull()]
        view.layer?.addSublayer(layer)
        panel.contentView = view
    }

    func start() {
        draw()
        panel.orderFrontRegardless()
        let timer = Timer(timeInterval: 1 / 12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        // Keeps moving while a menu is open, like the pet.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops still: the pet is coming for it.
    func freeze() { frozen = true }

    /// Caught: a squashed bug and a few sparks, then gone.
    func squash() {
        guard !caught else { return }
        caught = true
        frozen = true
        layer.contents = AgentArt.squashed.frames(fine: pet?.drawsFine == true).first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            MainActor.assumeIsolated { self?.remove() }
        }
    }

    func remove() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
        panel.close()
    }

    private func step() {
        tick += 1
        guard !frozen else { return }
        var speed = Self.crawl
        if let feet = pet?.feet, abs(feet.y - floor) < 40 {
            // The pet close by: it runs for it, away from the pet.
            let petMiddle = feet.x + CatSprites.catSize.width / 2
            if abs(petMiddle - spot.x) < 110 {
                heading = spot.x >= petMiddle ? 1 : -1
                speed = Self.dash
                resting = 0
            }
        }
        if speed == Self.crawl {
            if resting > 0 {
                resting -= 1
                return draw()
            }
            // Now and then it stops, or turns around.
            if Int.random(in: 0..<60) == 0 { resting = Int.random(in: 12...36) }
            if Int.random(in: 0..<80) == 0 { heading = -heading }
        }
        x += heading * speed
        if x <= area.minX || x >= area.maxX - Self.size.width {
            x = min(max(x, area.minX), area.maxX - Self.size.width)
            heading = -heading
        }
        panel.setFrameOrigin(CGPoint(x: x, y: floor))
        draw()
    }

    private func draw() {
        guard !caught else { return }
        // HD (twice the grid, same points) beside an HD pet.
        layer.contents = AgentArt.bug.frame(at: resting > 0 ? 0 : tick, every: 2, fine: pet?.drawsFine == true)
        layer.setAffineTransform(heading > 0 ? .identity : CGAffineTransform(scaleX: -1, y: 1))
    }
}
