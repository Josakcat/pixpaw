// Pixpaw
//
// Chinese New Year on the screen: red lanterns swaying under the menu bar,
// strings of firecrackers popping down both sides, plum blossom petals, a
// dragon dancing along above the Dock, and red envelopes from your pet that
// spill gold coins. All of it is Core Animation in the festival's
// click-through panels (Festivals.swift).

import AppKit

extension FestivalOverlay {
    static func lunarNewYear(in layer: CALayer, size: CGSize, floor: CGFloat, top: CGFloat) {
        redLanterns(in: layer, size: size)
        for rgb: UInt32 in [0xFFB3C8, 0xFF8FB1] {
            layer.addSublayer(falling(size: size, image: square(4, rgb), birthRate: 0.3, speed: 36, sway: 12, alpha: 0.85))
        }
        firecrackers(in: layer, x: 46, size: size, top: top)
        firecrackers(in: layer, x: size.width - 46, size: size, top: top)
    }

    private static let palette: [Character: UInt32] = ["r": 0xD7261E, "R": 0xFF4A3A, "y": 0xFFC83A, "w": 0xFFFFFF, "k": 0x1A1A1A, "g": 0x2E9E5A]

    private static let dragonHead = art([
        "   y   y     ",
        "   yy  yy    ",
        "  rrrrrrr    ",
        " rrwkrrrrrr  ",
        "rrrrrrrrRyyy ",
        "rrrrrrrrrrryy",
        " yyrrrrrrrr  ",
        "  wwwrrrr    ",
        "     rrr     ",
    ], palette)

    private static let dragonBody = art([
        "  y  y  ",
        " rrrrrr ",
        "rrRrrRrr",
        "rRrrRrrr",
        "rrrrrrrr",
        " yyyyyy ",
    ], palette)

    private static let dragonTail = art([
        "y  y ",
        "rrrr ",
        "rRrrr",
        " yyy ",
    ], palette)

    /// A string of firecrackers hanging from the top at `x`, shaking, with
    /// sparks popping at its end.
    private static func firecrackers(in layer: CALayer, x: CGFloat, size: CGSize, top: CGFloat) {
        guard let string = art([
            " y ", " r ", "rRr", "rRr", " y ", "rRr", "rRr", " y ", "rRr", "rRr", " y ", "rRr", "rRr", " y ", "rRr", "rRr",
        ], palette) else { return }
        let hanging = CALayer()
        hanging.contents = string
        hanging.magnificationFilter = .nearest
        hanging.bounds = CGRect(x: 0, y: 0, width: CGFloat(string.width) * 6, height: CGFloat(string.height) * 6)
        hanging.anchorPoint = CGPoint(x: 0.5, y: 1)
        hanging.position = CGPoint(x: x, y: size.height - top - 4)
        let shake = CABasicAnimation(keyPath: "transform.rotation.z")
        shake.fromValue = -0.05
        shake.toValue = 0.05
        shake.duration = 0.09
        shake.autoreverses = true
        shake.repeatCount = .infinity
        hanging.add(shake, forKey: "shake")
        layer.addSublayer(hanging)

        let spark = CAEmitterCell()
        spark.contents = square(3, 0xFFFFFF)
        spark.color = NSColor(rgb: 0xFFC83A).cgColor
        spark.redRange = 0.1
        spark.greenRange = 0.4
        spark.birthRate = 40
        spark.lifetime = 0.45
        spark.velocity = 90
        spark.velocityRange = 40
        spark.emissionRange = .pi * 2
        spark.alphaSpeed = -2
        let pops = CAEmitterLayer()
        pops.frame = CGRect(origin: .zero, size: size)
        pops.emitterPosition = CGPoint(x: x, y: hanging.position.y - hanging.bounds.height)
        pops.renderMode = .additive
        pops.emitterCells = [spark]
        layer.addSublayer(pops)
    }

    /// Every 14 s while Chinese New Year is up, a dragon dances along above
    /// the Dock: head first, the body following its path.
    func startDragonDances() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 14, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.dragonDance() } }
        timer.resume()
        animalTimer = timer
    }

    func dragonDance() {
        guard showing == .chineseNewYear, let ground = grounds.randomElement(),
              let head = Self.dragonHead, let body = Self.dragonBody, let tail = Self.dragonTail else { return }
        let size = ground.frame.size
        let floor = ground.y - Self.snowbankHeight + 6
        let leftToRight = Bool.random()
        let from = leftToRight ? -80.0 : size.width + 80
        let to = leftToRight ? size.width + 300 : -300.0
        let baseY = floor + 70
        let path = CGMutablePath()
        path.move(to: CGPoint(x: from, y: baseY))
        for step in 1...60 {
            let t = CGFloat(step) / 60
            path.addLine(to: CGPoint(x: from + (to - from) * t, y: baseY + sin(t * .pi * 9) * 26))
        }
        let length: CFTimeInterval = 15
        // How far behind the one in front each part runs, as time on the path.
        let gap = length * 30 / Double(abs(to - from))
        let parts: [CGImage] = [head] + Array(repeating: body, count: 10) + [tail]
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        var made: [CALayer] = []
        for (index, image) in parts.enumerated() {
            let part = CALayer()
            part.contents = image
            part.magnificationFilter = .nearest
            part.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * 5, height: CGFloat(image.height) * 5)
            part.opacity = 0
            part.zPosition = CGFloat(parts.count - index)
            if !leftToRight { part.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
            let follow = CAKeyframeAnimation(keyPath: "position")
            follow.path = path
            follow.calculationMode = .paced
            let seen = CABasicAnimation(keyPath: "opacity")
            seen.fromValue = 1
            seen.toValue = 1
            let group = CAAnimationGroup()
            group.animations = [follow, seen]
            group.duration = length
            group.beginTime = now + gap * Double(index)
            part.add(group, forKey: "dance")
            ground.layer.addSublayer(part)
            made.append(part)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + length + gap * Double(parts.count) + 0.3) { made.forEach { $0.removeFromSuperlayer() } }
    }

    /// Your pet's red envelope: it pops up from `point`, opens, and gold
    /// coins spill out.
    func redEnvelope(at point: CGPoint) {
        guard showing == .chineseNewYear, let ground = groundUnder(point),
              let envelope = Self.art(["rrrrrr", "rryyrr", "rryyrr", "rrrrrr", "rrrrrr", "rrrrrr", "rrrrrr", "rrrrrr"], Self.palette),
              let coin = Self.art([" yy ", "yRyy", "yyyy", " yy "], ["y": 0xFFC83A, "R": 0xFFF0A0]) else { return }
        let start = CGPoint(x: point.x - ground.frame.minX, y: point.y - ground.frame.minY)
        let top = CGPoint(x: start.x, y: start.y + 110)
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)

        let sprite = CALayer()
        sprite.contents = envelope
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: 30, height: 40)
        sprite.position = top
        sprite.opacity = 0
        let rise = CABasicAnimation(keyPath: "position")
        rise.fromValue = start
        rise.toValue = top
        rise.duration = 0.6
        rise.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = -0.6
        spin.toValue = 0
        spin.duration = 0.6
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.7, 1]
        let group = CAAnimationGroup()
        group.animations = [rise, spin, fade]
        group.duration = 1.4
        group.beginTime = now
        sprite.add(group, forKey: "envelope")
        ground.layer.addSublayer(sprite)

        let coins = CAEmitterCell()
        coins.contents = Self.scaled(coin, by: 3)
        coins.birthRate = 160
        coins.beginTime = 0.6
        coins.duration = 0.15
        coins.lifetime = 1.6
        coins.velocity = 230
        coins.velocityRange = 60
        coins.emissionLongitude = .pi
        coins.emissionRange = .pi / 2.5
        coins.yAcceleration = -520
        coins.spin = 3
        coins.spinRange = 6
        coins.alphaSpeed = -0.4
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: ground.frame.size)
        emitter.emitterPosition = top
        emitter.beginTime = now
        emitter.emitterCells = [coins]
        ground.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            sprite.removeFromSuperlayer()
            emitter.removeFromSuperlayer()
        }
    }
}
