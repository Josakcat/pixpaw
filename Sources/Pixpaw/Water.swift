// Pixpaw
//
// The water festivals on the screen. Loy Krathong: a full moon and stars,
// a dark river above the Dock with the moon on it, and krathongs your pet
// floats with a wish. Songkran: a puddle above the Dock rippling where the
// drops land, flower petals, and your pet splashing water about. All of it
// is Core Animation in the festival's click-through panels (Festivals.swift).

import AppKit

extension FestivalOverlay {
    // MARK: Loy Krathong

    static func loyKrathongNight(in layer: CALayer, size: CGSize, floor: CGFloat, top: CGFloat) {
        stars(in: layer, size: size, top: top)
        let moonX = size.width * 0.78
        moon(in: layer, at: CGPoint(x: moonX, y: size.height - top - 90))
        water(in: layer, size: size, floor: floor, height: 64, rgb: 0x0B1D45, alpha: 0.6, waves: 0x9FB8FF)
        moonlight(in: layer, x: moonX, floor: floor)
        krathongs(in: layer, size: size, floor: floor)
    }

    /// A pixel full moon with a soft glow.
    private static func moon(in layer: CALayer, at point: CGPoint) {
        let craters: Set<[Int]> = [[5, 9], [6, 9], [5, 10], [10, 5], [11, 5], [9, 11], [4, 5], [11, 10], [12, 10]]
        guard let image = pixels(16, 16, { c, r in
            let dx = Double(c) - 7.5, dy = Double(r) - 7.5
            guard dx * dx + dy * dy <= 56 else { return nil }
            return craters.contains([c, r]) ? 0xE6D9A2 : 0xFFF6CF
        }) else { return }
        let sprite = CALayer()
        sprite.contents = image
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        sprite.position = point
        sprite.shadowColor = NSColor(rgb: 0xFFF2B0).cgColor
        sprite.shadowOpacity = 0.7
        sprite.shadowRadius = 28
        sprite.shadowOffset = .zero
        layer.addSublayer(sprite)
    }

    /// Small stars twinkling in the upper part of the sky.
    private static func stars(in layer: CALayer, size: CGSize, top: CGFloat) {
        var random = SystemRandomNumberGenerator()
        for index in 0..<28 {
            let star = CALayer()
            let side: CGFloat = index % 5 == 0 ? 4 : 2
            star.backgroundColor = NSColor(rgb: index % 3 == 0 ? 0xFFF1C2 : 0xFFFFFF).cgColor
            star.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            star.position = CGPoint(x: .random(in: 0...size.width, using: &random),
                                    y: size.height - top - .random(in: 20...size.height * 0.4, using: &random))
            star.opacity = 0.8
            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = 0.9
            twinkle.toValue = 0.15
            twinkle.duration = .random(in: 1.2...3)
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            twinkle.timeOffset = .random(in: 0...3)
            star.add(twinkle, forKey: "twinkle")
            layer.addSublayer(star)
        }
    }

    /// A band of water along the Dock, fading out upward, with pixel waves
    /// sliding along it.
    static func water(in layer: CALayer, size: CGSize, floor: CGFloat, height: CGFloat, rgb: UInt32, alpha: CGFloat, waves: UInt32) {
        let band = CAGradientLayer()
        band.frame = CGRect(x: 0, y: floor, width: size.width, height: height)
        band.colors = [NSColor(rgb: rgb).withAlphaComponent(alpha).cgColor, NSColor(rgb: rgb).withAlphaComponent(0).cgColor]
        band.startPoint = CGPoint(x: 0.5, y: 0)
        band.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(band)
        // A dash every 32 points, so sliding 32 along loops without a seam.
        guard let dash = pixels(32, 1, { c, _ in c < 6 ? waves : nil }) else { return }
        for (index, y) in [height * 0.15, height * 0.35, height * 0.55].enumerated() {
            let line = CALayer()
            line.contents = dash
            line.magnificationFilter = .nearest
            line.contentsGravity = .resize
            line.frame = CGRect(x: 0, y: 0, width: 32, height: 2)
            let strip = CAReplicatorLayer()
            strip.instanceCount = Int(size.width / 32) + 3
            strip.instanceTransform = CATransform3DMakeTranslation(32, 0, 0)
            strip.frame = CGRect(x: CGFloat(index) * 11 - 32, y: floor + y, width: size.width + 64, height: 2)
            strip.opacity = Float(0.35 - Double(index) * 0.08)
            strip.addSublayer(line)
            let slide = CABasicAnimation(keyPath: "position.x")
            slide.byValue = index % 2 == 0 ? 32 : -32
            slide.duration = [3.2, 4.4, 5.6][index]
            slide.repeatCount = .infinity
            strip.add(slide, forKey: "slide")
            layer.addSublayer(strip)
        }
    }

    /// The moon's reflection: short gold dashes shimmering on the water under it.
    private static func moonlight(in layer: CALayer, x: CGFloat, floor: CGFloat) {
        for index in 0..<6 {
            let dash = CALayer()
            dash.backgroundColor = NSColor(rgb: 0xFFE9A0).cgColor
            let width = CGFloat([30, 22, 36, 18, 26, 14][index])
            dash.bounds = CGRect(x: 0, y: 0, width: width, height: 3)
            dash.position = CGPoint(x: x + CGFloat([-4, 6, -8, 3, -2, 5][index]), y: floor + 6 + CGFloat(index) * 9)
            let shimmer = CABasicAnimation(keyPath: "opacity")
            shimmer.fromValue = 0.75 - Double(index) * 0.08
            shimmer.toValue = 0.15
            shimmer.duration = 0.9 + Double(index) * 0.23
            shimmer.autoreverses = true
            shimmer.repeatCount = .infinity
            dash.add(shimmer, forKey: "shimmer")
            layer.addSublayer(dash)
        }
    }

    /// Your pet's krathong, set on the water under `point` and floating off
    /// to the right. Up to five on the water at once.
    func floatKrathong(at point: CGPoint) {
        guard showing == .loyKrathong, let ground = groundUnder(point), let image = CatSprites.shared.image(.krathong) else { return }
        floated.removeAll { $0.superlayer == nil }
        guard floated.count < 5 else { return }
        let x = point.x - ground.frame.minX
        let y = ground.floor + 30
        let sprite = CALayer()
        sprite.contents = image
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * 5, height: CGFloat(image.height) * 5)
        sprite.shadowColor = NSColor(rgb: 0xFFD27A).cgColor
        sprite.shadowOpacity = 0.8
        sprite.shadowRadius = 10
        sprite.shadowOffset = .zero
        let end = ground.frame.width + 80
        let float = CAKeyframeAnimation(keyPath: "position")
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y + 50))
        path.addLine(to: CGPoint(x: x, y: y))
        let steps = 24
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x + (end - x) * t, y: y + sin(t * .pi * 8) * 3))
        }
        float.path = path
        float.calculationMode = .paced
        float.duration = Double(end - x) / 22 + 1
        sprite.position = CGPoint(x: end, y: y)
        sprite.add(float, forKey: "float")
        ground.layer.addSublayer(sprite)
        floated.append(sprite)
        DispatchQueue.main.asyncAfter(deadline: .now() + float.duration) { sprite.removeFromSuperlayer() }
    }

    // MARK: Songkran

    static func songkranSplash(in layer: CALayer, size: CGSize, floor: CGFloat) {
        layer.addSublayer(falling(size: size, image: rect(3, 8, 0x8FC3FF), birthRate: 5, speed: 300, sway: 0, alpha: 0.7))
        // Petals from the garlands, pink, white and yellow, drifting down slowly.
        for rgb: UInt32 in [0xFF9EC7, 0xFFFFFF, 0xFFD45E] {
            layer.addSublayer(falling(size: size, image: square(4, rgb), birthRate: 0.25, speed: 40, sway: 10, alpha: 0.85))
        }
        water(in: layer, size: size, floor: floor, height: 26, rgb: 0x3A8FD8, alpha: 0.4, waves: 0xCFE7FF)
        ripples(in: layer, size: size, floor: floor)
    }

    /// Rings spreading on the puddle where drops land.
    private static func ripples(in layer: CALayer, size: CGSize, floor: CGFloat) {
        for index in 0..<12 {
            let ring = CAShapeLayer()
            ring.path = CGPath(ellipseIn: CGRect(x: -18, y: -4, width: 36, height: 8), transform: nil)
            ring.fillColor = nil
            ring.strokeColor = NSColor(rgb: 0xCFE7FF).cgColor
            ring.lineWidth = 1.5
            ring.position = CGPoint(x: size.width * (CGFloat(index) + .random(in: 0.1...0.9)) / 12, y: floor + .random(in: 6...18))
            ring.opacity = 0
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.2
            grow.toValue = 1.6
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.8
            fade.toValue = 0
            let group = CAAnimationGroup()
            group.animations = [grow, fade]
            group.duration = .random(in: 1.2...1.8)
            group.repeatCount = .infinity
            group.timeOffset = .random(in: 0...1.8)
            ring.add(group, forKey: "ripple")
            layer.addSublayer(ring)
        }
    }

    /// Every 9 s while Songkran is up, two of the pets hop onto the puddle
    /// and have a water-gun fight. Timer on the main queue; Core Animation
    /// does the rest.
    func startWaterFights() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 9, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.waterFight() } }
        timer.resume()
        animalTimer = timer
    }

    func waterFight() {
        guard showing == .songkran, let ground = grounds.randomElement() else { return }
        var shapes = Self.animalShapes.shuffled()
        guard shapes.count >= 2 else { return }
        let size = ground.frame.size
        let floor = ground.y - Self.snowbankHeight + 6
        let left = CGFloat.random(in: size.width * 0.12...size.width * 0.55)
        let right = left + CGFloat.random(in: 240...380)
        let y = floor + 34
        let length: CFTimeInterval = 5
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        var made: [CALayer] = []
        for (index, x) in [left, right].enumerated() {
            let shape = shapes.removeFirst()
            let facesRight = index == 0
            let pet = CALayer()
            pet.contents = shape
            pet.magnificationFilter = .nearest
            pet.bounds = CGRect(x: 0, y: 0, width: CGFloat(shape.width) * 4, height: CGFloat(shape.height) * 4)
            pet.position = CGPoint(x: x, y: y)
            if !facesRight { pet.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
            if let gun = Self.waterGun {
                let held = CALayer()
                held.contents = gun
                held.magnificationFilter = .nearest
                held.bounds = CGRect(x: 0, y: 0, width: 28, height: 16)
                // In front of it, at about its chin; the flip above turns it with the pet.
                held.position = CGPoint(x: pet.bounds.width - 4, y: pet.bounds.height * 0.45)
                pet.addSublayer(held)
            }
            pet.opacity = 0
            Self.show(pet, for: length, from: now, hop: index == 0 ? 0 : 0.15)
            ground.layer.addSublayer(pet)
            made.append(pet)
        }
        // Each shoots an arc of drops at the other, with a splash where it hits.
        for index in 0..<2 {
            let from = CGPoint(x: (index == 0 ? left + 46 : right - 46), y: y + 4)
            let to = CGPoint(x: (index == 0 ? right - 24 : left + 24), y: y + 10)
            made += Self.stream(from: from, to: to, in: ground.layer, from: now + 0.7 + Double(index) * 0.35, for: length - 1.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + length + 0.3) { made.forEach { $0.removeFromSuperlayer() } }
    }

    /// A pixel water gun pointing right: orange body, blue tank.
    private static var waterGun: CGImage? {
        pixels(7, 4) { c, r in
            switch (c, r) {
            case (1...2, 2...3): 0x3AA0FF
            case (0...6, 1): 0xFF8A3D
            case (6, 2): 0xFF8A3D
            case (1, 0): 0xC2571F
            default: nil
            }
        }
    }

    /// Fades `layer` in with a little hop, holds it, and fades it out.
    private static func show(_ layer: CALayer, for length: CFTimeInterval, from now: CFTimeInterval, hop delay: CFTimeInterval) {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.06, 0.92, 1]
        let hop = CAKeyframeAnimation(keyPath: "position.y")
        let y = layer.position.y
        hop.values = [y - 20, y + 18, y, y, y + 10, y]
        hop.keyTimes = [0, 0.05, 0.1, 0.5, 0.55, 0.6]
        let group = CAAnimationGroup()
        group.animations = [fade, hop]
        group.duration = length
        group.beginTime = now + delay
        layer.add(group, forKey: "show")
    }

    /// Drops flying from `start` to `end` on an arc, over and over for
    /// `length` seconds, and a splash at `end` meanwhile.
    private static func stream(from start: CGPoint, to end: CGPoint, in layer: CALayer, from begin: CFTimeInterval,
                               for length: CFTimeInterval) -> [CALayer] {
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + 70))
        let flight: CFTimeInterval = 0.6
        let count = 10
        var made: [CALayer] = []
        for index in 0..<count {
            let drop = CALayer()
            drop.backgroundColor = NSColor(rgb: index % 3 == 0 ? 0xE4F2FF : 0x7EC0FF).cgColor
            drop.bounds = CGRect(x: 0, y: 0, width: 5, height: 5)
            drop.position = end
            drop.opacity = 0
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.path = path
            let seen = CABasicAnimation(keyPath: "opacity")
            seen.fromValue = 1
            seen.toValue = 1
            let group = CAAnimationGroup()
            group.animations = [fly, seen]
            group.duration = flight
            group.repeatCount = Float(length / flight)
            group.beginTime = begin + flight * Double(index) / Double(count)
            drop.add(group, forKey: "fly")
            layer.addSublayer(drop)
            made.append(drop)
        }
        let spray = CAEmitterCell()
        spray.contents = square(3, 0xCFE7FF)
        spray.birthRate = 45
        spray.lifetime = 0.6
        spray.velocity = 110
        spray.velocityRange = 40
        spray.emissionLongitude = .pi
        spray.emissionRange = .pi / 2
        spray.yAcceleration = -400
        spray.alphaSpeed = -1.4
        spray.beginTime = flight
        spray.duration = length - flight
        let emitter = CAEmitterLayer()
        emitter.frame = layer.bounds
        emitter.emitterPosition = end
        emitter.beginTime = begin
        emitter.emitterCells = [spray]
        layer.addSublayer(emitter)
        made.append(emitter)
        return made
    }

    /// Your pet splashing water: drops flying up around `point` and falling.
    func splash(at point: CGPoint) {
        guard showing == .songkran, let ground = groundUnder(point) else { return }
        let drop = CAEmitterCell()
        drop.contents = Self.rect(3, 7, 0xA8D4FF)
        drop.birthRate = 400
        drop.duration = 0.15
        drop.lifetime = 1.3
        drop.velocity = 340
        drop.velocityRange = 70
        drop.emissionLongitude = .pi
        drop.emissionRange = .pi / 3
        drop.yAcceleration = -480
        drop.alphaSpeed = -0.5
        drop.spin = 2
        drop.spinRange = 4
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: ground.frame.size)
        emitter.emitterPosition = CGPoint(x: point.x - ground.frame.minX, y: point.y - ground.frame.minY)
        emitter.beginTime = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        emitter.emitterCells = [drop]
        ground.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { emitter.removeFromSuperlayer() }
    }

    // MARK: Shared

    /// What your pet does for the festival that's up, at `point` on screen
    /// (CatController.festivalAct): floats a krathong, or splashes water.
    func festivalAct(at point: CGPoint) {
        switch showing {
        case .loyKrathong: floatKrathong(at: point)
        case .songkran: splash(at: point)
        case .halloween: boo(at: point)
        case .chineseNewYear: redEnvelope(at: point)
        case .valentines: loveLetter(at: point)
        case .birthday: makeWish(at: point)
        default: break
        }
    }

    /// The screen under `point`, with the height of its Dock.
    func groundUnder(_ point: CGPoint) -> (frame: CGRect, layer: CALayer, floor: CGFloat)? {
        grounds.first { $0.frame.contains(point) }.map { ($0.frame, $0.layer, $0.y - Self.snowbankHeight + 6) }
    }
}
