// Pixpaw
//
// Halloween on the screen: ghosts drifting by, jack-o'-lanterns flickering
// along the Dock in a purple fog, bats flapping across, cobwebs in the top
// corners with a spider on its thread, the pets drifting past dressed as
// ghosts, and your pet saying Boo. All of it is Core Animation in the
// festival's click-through panels (Festivals.swift).

import AppKit

extension FestivalOverlay {
    static func halloweenNight(in layer: CALayer, size: CGSize, floor: CGFloat, top: CGFloat) {
        water(in: layer, size: size, floor: floor, height: 70, rgb: 0x3B1F5C, alpha: 0.55, waves: 0x8A6BBE)
        pumpkins(in: layer, size: size, floor: floor)
        cobwebs(in: layer, size: size, top: top)
        bats(in: layer, size: size)
        ghosts(in: layer, size: size)
    }

    /// Pixel art from rows of letters, top row first; a space is clear.
    static func art(_ rows: [String], _ palette: [Character: UInt32]) -> CGImage? {
        let lines = rows.map(Array.init)
        return pixels(lines.map(\.count).max() ?? 0, lines.count) { c, r in
            let line = lines[lines.count - 1 - r]
            return c < line.count ? palette[line[c]] : nil
        }
    }

    private static let pumpkin = art([
        "     gg     ",
        "    gg      ",
        "  oOOooOOo  ",
        " oOOooooOOo ",
        "oOyyOooOyyOo",
        "oOyyOooOyyOo",
        "oOOOOyyOOOOo",
        "oOyOyyyyOyOo",
        "oOOyyyyyyOOo",
        " oOOOooOOOo ",
        "  oOOooOOo  ",
    ], ["g": 0x4E8A2E, "o": 0xD8641C, "O": 0xF08A2A, "y": 0xFFE07A])

    private static let batFrames: [CGImage] = [
        art(["b         b", "bb  b b  bb", "bbbbbbbbbbb", " bbbbbbbbb ", "   b r b   ", "    bbb    "], ["b": 0x3A2A52, "r": 0xFF4A4A]),
        art(["    b b    ", "    bbb    ", "  bbbbbbb  ", " bbbbbbbbb ", "bb  r r  bb", "b   bbb   b"], ["b": 0x3A2A52, "r": 0xFF4A4A]),
    ].compactMap { $0 }

    /// Jack-o'-lanterns along the Dock, their candles flickering.
    private static func pumpkins(in layer: CALayer, size: CGSize, floor: CGFloat) {
        guard let pumpkin else { return }
        for index in 0..<5 {
            let sprite = CALayer()
            let scale: CGFloat = index % 2 == 0 ? 5 : 4
            sprite.contents = pumpkin
            sprite.magnificationFilter = .nearest
            sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(pumpkin.width) * scale, height: CGFloat(pumpkin.height) * scale)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = CGPoint(x: size.width * (CGFloat(index) + 0.5) / 5 + CGFloat([-30, 40, -10, 25, -45][index]), y: floor + 2)
            sprite.shadowColor = NSColor(rgb: 0xFF9A2E).cgColor
            sprite.shadowOffset = .zero
            sprite.shadowRadius = 16
            let flicker = CAKeyframeAnimation(keyPath: "shadowOpacity")
            flicker.values = [0.9, 0.5, 0.8, 0.35, 0.95, 0.6, 0.9]
            flicker.duration = [1.3, 1.7, 1.1, 1.5, 1.9][index]
            flicker.repeatCount = .infinity
            sprite.add(flicker, forKey: "flicker")
            layer.addSublayer(sprite)
        }
    }

    /// Bats flapping across on wavy paths.
    private static func bats(in layer: CALayer, size: CGSize) {
        guard batFrames.count == 2 else { return }
        for index in 0..<6 {
            let bat = CALayer()
            let scale: CGFloat = index % 3 == 0 ? 4 : 3
            bat.contents = batFrames[0]
            bat.magnificationFilter = .nearest
            bat.bounds = CGRect(x: 0, y: 0, width: CGFloat(batFrames[0].width) * scale, height: CGFloat(batFrames[0].height) * scale)
            let flap = CAKeyframeAnimation(keyPath: "contents")
            flap.values = batFrames
            flap.calculationMode = .discrete
            flap.duration = 0.32
            flap.repeatCount = .infinity
            bat.add(flap, forKey: "flap")
            let leftToRight = index % 2 == 1
            let baseY = size.height * CGFloat([0.82, 0.66, 0.74, 0.55, 0.88, 0.62][index])
            let from = leftToRight ? -50.0 : size.width + 50
            let to = leftToRight ? size.width + 50 : -50.0
            let path = CGMutablePath()
            path.move(to: CGPoint(x: from, y: baseY))
            for step in 1...30 {
                let t = CGFloat(step) / 30
                path.addLine(to: CGPoint(x: from + (to - from) * t, y: baseY + sin(t * .pi * 9 + CGFloat(index)) * 22))
            }
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.path = path
            fly.calculationMode = .paced
            fly.duration = [14, 19, 16, 22, 12, 18][index]
            fly.repeatCount = .infinity
            fly.timeOffset = fly.duration * Double(index) / 6
            bat.add(fly, forKey: "fly")
            layer.addSublayer(bat)
        }
    }

    /// A cobweb in each top corner under the menu bar, a spider bobbing on
    /// its thread from the left one.
    private static func cobwebs(in layer: CALayer, size: CGSize, top: CGFloat) {
        let corner: CGFloat = 110
        for right in [false, true] {
            let web = CAShapeLayer()
            let path = CGMutablePath()
            // Spokes from the corner, and sagging threads across them.
            let angles = (0...5).map { CGFloat($0) / 5 * .pi / 2 }
            for angle in angles {
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: cos(angle) * corner, y: -sin(angle) * corner))
            }
            for ring in 1...4 {
                let radius = corner * CGFloat(ring) / 4.4
                for (a, b) in zip(angles, angles.dropFirst()) {
                    let start = CGPoint(x: cos(a) * radius, y: -sin(a) * radius)
                    let end = CGPoint(x: cos(b) * radius, y: -sin(b) * radius)
                    let mid = (a + b) / 2
                    if a == angles[0] { path.move(to: start) }
                    path.addQuadCurve(to: end, control: CGPoint(x: cos(mid) * radius * 0.82, y: -sin(mid) * radius * 0.82))
                }
            }
            web.path = path
            web.fillColor = nil
            web.strokeColor = NSColor(white: 0.85, alpha: 0.5).cgColor
            web.lineWidth = 1
            web.position = CGPoint(x: right ? size.width : 0, y: size.height - top)
            if right { web.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
            layer.addSublayer(web)
        }
        guard let spider = art(["b  b  b", " bbbbb ", "bbrbrbb", " bbbbb ", "b  b  b"], ["b": 0x1A1A1A, "r": 0xFF4A4A]) else { return }
        let hanger = CALayer()
        hanger.anchorPoint = CGPoint(x: 0.5, y: 1)
        hanger.bounds = CGRect(x: 0, y: 0, width: 28, height: 90)
        hanger.position = CGPoint(x: 70, y: size.height - top - 30)
        let thread = CALayer()
        thread.backgroundColor = NSColor(white: 0.85, alpha: 0.5).cgColor
        thread.frame = CGRect(x: 13.5, y: 18, width: 1, height: 72)
        let body = CALayer()
        body.contents = spider
        body.magnificationFilter = .nearest
        body.frame = CGRect(x: 0, y: 0, width: 28, height: 20)
        hanger.addSublayer(thread)
        hanger.addSublayer(body)
        let bob = CABasicAnimation(keyPath: "transform.scale.y")
        bob.fromValue = 0.6
        bob.toValue = 1.1
        bob.duration = 2.6
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        hanger.add(bob, forKey: "bob")
        layer.addSublayer(hanger)
    }

    /// Every 10 s while Halloween is up, one of the pets floats by dressed
    /// as a ghost (its shape in white, its outline and eyes dark).
    func startGhostPets() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 10, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.ghostPet() } }
        timer.resume()
        animalTimer = timer
    }

    func ghostPet() {
        guard showing == .halloween, let ground = grounds.randomElement(), let shape = Self.animalShapes.randomElement(),
              let ghost = Self.sheet(shape) else { return }
        let size = ground.frame.size
        let sprite = CALayer()
        sprite.contents = ghost
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(ghost.width) * 5, height: CGFloat(ghost.height) * 5)
        let leftToRight = Bool.random()
        if !leftToRight { sprite.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
        let baseY = size.height * CGFloat.random(in: 0.3...0.65)
        let from = leftToRight ? -90.0 : size.width + 90
        let to = leftToRight ? size.width + 90 : -90.0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: from, y: baseY))
        for step in 1...24 {
            let t = CGFloat(step) / 24
            path.addLine(to: CGPoint(x: from + (to - from) * t, y: baseY + sin(t * .pi * 5) * 30))
        }
        let float = CAKeyframeAnimation(keyPath: "position")
        float.path = path
        float.calculationMode = .paced
        float.duration = 16
        sprite.position = CGPoint(x: to, y: baseY)
        sprite.opacity = 0.75
        sprite.add(float, forKey: "float")
        ground.layer.addSublayer(sprite)
        DispatchQueue.main.asyncAfter(deadline: .now() + float.duration) { sprite.removeFromSuperlayer() }
    }

    /// `shape` under a sheet: light pixels white, dark ones (outline, eyes) dark.
    private static func sheet(_ shape: CGImage) -> CGImage? {
        var lit: [[Int]: UInt32] = [:]
        let width = shape.width, height = shape.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(shape, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        for row in 0..<height {
            for column in 0..<width {
                let i = (row * width + column) * 4
                guard data[i + 3] > 128 else { continue }
                let light = max(data[i], data[i + 1], data[i + 2]) > 70
                lit[[column, height - 1 - row]] = light ? 0xF4F2FF : 0x2B2440
            }
        }
        return pixels(width, height) { c, r in lit[[c, r]] }
    }

    /// Your pet says Boo: a ghost pops out of it and floats up, and bats
    /// scatter from it.
    func boo(at point: CGPoint) {
        guard showing == .halloween, let ground = groundUnder(point), let ghost = CatSprites.shared.image(.ghost) else { return }
        let start = CGPoint(x: point.x - ground.frame.minX, y: point.y - ground.frame.minY)
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        var made: [CALayer] = []

        let sprite = CALayer()
        sprite.contents = ghost
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(ghost.width) * 6, height: CGFloat(ghost.height) * 6)
        sprite.position = start
        sprite.opacity = 0
        let rise = CAKeyframeAnimation(keyPath: "position")
        rise.values = [start, CGPoint(x: start.x, y: start.y + 60), CGPoint(x: start.x + 20, y: start.y + 160)]
        rise.keyTimes = [0, 0.2, 1]
        let grow = CAKeyframeAnimation(keyPath: "transform.scale")
        grow.values = [0.2, 1.3, 1]
        grow.keyTimes = [0, 0.15, 0.3]
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 0.9, 0.9, 0]
        fade.keyTimes = [0, 0.1, 0.6, 1]
        let group = CAAnimationGroup()
        group.animations = [rise, grow, fade]
        group.duration = 2.2
        group.beginTime = now
        sprite.add(group, forKey: "boo")
        ground.layer.addSublayer(sprite)
        made.append(sprite)

        if Self.batFrames.count == 2 {
            for index in 0..<5 {
                let bat = CALayer()
                bat.contents = Self.batFrames[0]
                bat.magnificationFilter = .nearest
                bat.bounds = CGRect(x: 0, y: 0, width: CGFloat(Self.batFrames[0].width) * 3, height: CGFloat(Self.batFrames[0].height) * 3)
                bat.position = start
                bat.opacity = 0
                let flap = CAKeyframeAnimation(keyPath: "contents")
                flap.values = Self.batFrames
                flap.calculationMode = .discrete
                flap.duration = 0.24
                flap.repeatCount = 8
                let angle = CGFloat(index) / 4 * .pi * 0.8 + .pi * 0.1
                let away = CABasicAnimation(keyPath: "position")
                away.fromValue = start
                away.toValue = CGPoint(x: start.x + cos(angle) * 320, y: start.y + sin(angle) * 260)
                away.timingFunction = CAMediaTimingFunction(name: .easeIn)
                let seen = CAKeyframeAnimation(keyPath: "opacity")
                seen.values = [1, 1, 0]
                seen.keyTimes = [0, 0.7, 1]
                let scatter = CAAnimationGroup()
                scatter.animations = [flap, away, seen]
                scatter.duration = 1.6
                scatter.beginTime = now + 0.1
                bat.add(scatter, forKey: "scatter")
                ground.layer.addSublayer(bat)
                made.append(bat)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { made.forEach { $0.removeFromSuperlayer() } }
    }
}
