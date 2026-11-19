// Pixpaw
//
// Valentine's Day and your birthday on the screen. Valentine's: hearts
// and rose petals, a pink glow along the Dock, two pets meeting under a
// big heart, and love letters from your pet. Birthday: confetti, balloons,
// bunting under the menu bar, a cake on the Dock whose candles your pet
// blows out, and pets floating by on balloons. All of it is Core
// Animation in the festival's click-through panels (Festivals.swift).

import AppKit

extension FestivalOverlay {
    // MARK: Valentine's Day

    static func valentineDay(in layer: CALayer, size: CGSize, floor: CGFloat) {
        water(in: layer, size: size, floor: floor, height: 50, rgb: 0x7A1F4A, alpha: 0.45, waves: 0xFF9EC7)
        for rgb: UInt32 in [0xE8304A, 0xFF7A9C] {
            layer.addSublayer(falling(size: size, image: square(4, rgb), birthRate: 0.3, speed: 38, sway: 12, alpha: 0.9))
        }
        hearts(in: layer, size: size)
    }

    /// Every 10 s on Valentine's Day, two of the pets walk in from either
    /// side, meet in the middle, and a big heart pops up between them.
    func startCouples() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 10, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.couple() } }
        timer.resume()
        animalTimer = timer
    }

    func couple() {
        guard showing == .valentines, let ground = grounds.randomElement(), let heart = CatSprites.shared.image(.heart) else { return }
        var shapes = Self.animalShapes.shuffled()
        guard shapes.count >= 2 else { return }
        let size = ground.frame.size
        let y = ground.y - Self.snowbankHeight + 6 + 34
        let middle = CGFloat.random(in: size.width * 0.3...size.width * 0.7)
        let length: CFTimeInterval = 7
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        var made: [CALayer] = []
        for index in 0..<2 {
            let shape = shapes.removeFirst()
            let fromLeft = index == 0
            let pet = CALayer()
            pet.contents = shape
            pet.magnificationFilter = .nearest
            pet.bounds = CGRect(x: 0, y: 0, width: CGFloat(shape.width) * 4, height: CGFloat(shape.height) * 4)
            if !fromLeft { pet.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
            let start = CGPoint(x: fromLeft ? middle - 260 : middle + 260, y: y)
            let meet = CGPoint(x: fromLeft ? middle - 44 : middle + 44, y: y)
            pet.position = meet
            pet.opacity = 0
            let walk = CAKeyframeAnimation(keyPath: "position")
            walk.values = [start, meet, meet, start]
            walk.keyTimes = [0, 0.35, 0.75, 1]
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.1, 0.85, 1]
            let group = CAAnimationGroup()
            group.animations = [walk, fade]
            group.duration = length
            group.beginTime = now
            pet.add(group, forKey: "walk")
            ground.layer.addSublayer(pet)
            made.append(pet)
        }
        let big = CALayer()
        big.contents = heart
        big.magnificationFilter = .nearest
        big.bounds = CGRect(x: 0, y: 0, width: CGFloat(heart.width) * 7, height: CGFloat(heart.height) * 7)
        big.position = CGPoint(x: middle, y: y + 90)
        big.opacity = 0
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.1, 1.25, 1, 1.12, 1]
        pop.keyTimes = [0, 0.15, 0.3, 0.6, 1]
        let rise = CABasicAnimation(keyPath: "position.y")
        rise.fromValue = y + 50
        rise.toValue = y + 110
        let seen = CAKeyframeAnimation(keyPath: "opacity")
        seen.values = [1, 1, 0]
        seen.keyTimes = [0, 0.7, 1]
        let group = CAAnimationGroup()
        group.animations = [pop, rise, seen]
        group.duration = 2.6
        group.beginTime = now + length * 0.35
        big.add(group, forKey: "pop")
        ground.layer.addSublayer(big)
        made.append(big)
        DispatchQueue.main.asyncAfter(deadline: .now() + length + 0.3) { made.forEach { $0.removeFromSuperlayer() } }
    }

    /// Your pet's love letter: it floats up from `point` and bursts into hearts.
    func loveLetter(at point: CGPoint) {
        guard showing == .valentines, let ground = groundUnder(point),
              let letter = Self.art(["wwwwwwww", "wkwwwwkw", "wwkwwkww", "wwwrrwww", "wwrrrrww", "wwwrrwww", "wwwwwwww"],
                                    ["w": 0xFFF6F0, "k": 0xD8C8C0, "r": 0xE8304A]),
              let heart = CatSprites.shared.image(.heart) else { return }
        let start = CGPoint(x: point.x - ground.frame.minX, y: point.y - ground.frame.minY)
        let top = CGPoint(x: start.x, y: start.y + 120)
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        let sprite = CALayer()
        sprite.contents = letter
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: 40, height: 35)
        sprite.position = top
        sprite.opacity = 0
        let rise = CAKeyframeAnimation(keyPath: "position")
        rise.values = [start, CGPoint(x: start.x + 14, y: start.y + 60), top]
        rise.duration = 0.8
        let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wobble.values = [-0.2, 0.2, -0.1, 0]
        wobble.duration = 0.8
        let seen = CAKeyframeAnimation(keyPath: "opacity")
        seen.values = [1, 1, 0]
        seen.keyTimes = [0, 0.9, 1]
        seen.duration = 0.9
        let group = CAAnimationGroup()
        group.animations = [rise, wobble, seen]
        group.duration = 0.9
        group.beginTime = now
        sprite.add(group, forKey: "letter")
        ground.layer.addSublayer(sprite)

        let burst = CAEmitterCell()
        burst.contents = heart
        burst.birthRate = 120
        burst.beginTime = 0.8
        burst.duration = 0.12
        burst.lifetime = 1.8
        burst.velocity = 120
        burst.velocityRange = 50
        burst.emissionRange = .pi * 2
        burst.yAcceleration = 40
        burst.scale = 2
        burst.scaleRange = 0.8
        burst.alphaSpeed = -0.5
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: ground.frame.size)
        emitter.emitterPosition = top
        emitter.beginTime = now
        emitter.emitterCells = [burst]
        ground.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            sprite.removeFromSuperlayer()
            emitter.removeFromSuperlayer()
        }
    }

    // MARK: Birthday

    private static let partyColors: [UInt32] = [0xFF5A5A, 0xFFC83A, 0x5AC8FF, 0x7AE07A, 0xC88AFF, 0xFF8AC8]

    static func birthdayParty(in layer: CALayer, size: CGSize, floor: CGFloat, top: CGFloat) {
        confetti(in: layer, size: size)
        bunting(in: layer, size: size, top: top)
        balloons(in: layer, size: size)
        cake(in: layer, at: CGPoint(x: size.width - 150, y: floor + 2))
    }

    static func balloon(_ rgb: UInt32) -> CGImage? {
        art(["  bbb  ", " bbbbb ", "bbWbbbb", "bWbbbbb", "bbbbbbb", " bbbbb ", "  bbb  ", "   b   ", "   s   ", "    s  ", "   s   ", "   s   "],
            ["b": rgb, "W": 0xFFFFFF, "s": 0xBBBBBB])
    }

    /// Balloons in party colours drifting up from the bottom.
    private static func balloons(in layer: CALayer, size: CGSize) {
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = CGPoint(x: size.width / 2, y: -40)
        emitter.emitterSize = CGSize(width: size.width, height: 1)
        emitter.emitterShape = .line
        emitter.emitterCells = partyColors.compactMap { rgb in
            guard let image = balloon(rgb).flatMap({ scaled($0, by: 4) }) else { return nil }
            let cell = CAEmitterCell()
            cell.contents = image
            cell.birthRate = 0.05
            cell.lifetime = Float(size.height / 45) + 4
            cell.velocity = 50
            cell.velocityRange = 12
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 20
            cell.xAcceleration = 3
            cell.scaleRange = 0.25
            return cell
        }
        layer.addSublayer(emitter)
    }

    /// Flags in party colours on sagging strings under the menu bar.
    private static func bunting(in layer: CALayer, size: CGSize, top: CGFloat) {
        let span: CGFloat = 220, sag: CGFloat = 26
        let y = size.height - top - 6
        let string = CAShapeLayer()
        let path = CGMutablePath()
        var x: CGFloat = 0
        path.move(to: CGPoint(x: 0, y: y))
        while x < size.width {
            path.addQuadCurve(to: CGPoint(x: x + span, y: y), control: CGPoint(x: x + span / 2, y: y - sag * 2))
            x += span
        }
        string.path = path
        string.fillColor = nil
        string.strokeColor = NSColor(white: 0.9, alpha: 0.7).cgColor
        string.lineWidth = 1.5
        layer.addSublayer(string)
        var index = 0
        var start: CGFloat = 0
        while start < size.width {
            for step in 1...6 {
                let t = CGFloat(step) / 7
                guard let flag = art(["fffff", "fffff", " fff ", " fff ", "  f  "], ["f": partyColors[index % partyColors.count]]) else { continue }
                let sprite = CALayer()
                sprite.contents = flag
                sprite.magnificationFilter = .nearest
                sprite.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
                sprite.anchorPoint = CGPoint(x: 0.5, y: 1)
                // On the curve: a quadratic from (start, y) through (mid, y - 2 sag) to (start + span, y).
                sprite.position = CGPoint(x: start + span * t, y: y - 2 * sag * 2 * t * (1 - t))
                let flutter = CABasicAnimation(keyPath: "transform.rotation.z")
                flutter.fromValue = -0.08
                flutter.toValue = 0.08
                flutter.duration = 1.2 + Double(index % 3) * 0.3
                flutter.autoreverses = true
                flutter.repeatCount = .infinity
                sprite.add(flutter, forKey: "flutter")
                layer.addSublayer(sprite)
                index += 1
            }
            start += span
        }
    }

    /// A birthday cake on the Dock, its three candles flickering.
    private static func cake(in layer: CALayer, at bottom: CGPoint) {
        guard let image = art([
            "  c   c   c  ",
            "  C   C   C  ",
            "  c   c   c  ",
            " wwwwwwwwwww ",
            "wpwwpwwwpwwpw",
            "bbbbbbbbbbbbb",
            "bbbpbbbbbpbbb",
            "bbbbbbbbbbbbb",
            "yyyyyyyyyyyyy",
            "bbbbbbbbbbbbb",
            "bbbbbbbbbbbbb",
            " ggggggggggg ",
        ], ["c": 0x8AC8FF, "C": 0xFFFFFF, "w": 0xFFF6F0, "p": 0xFF8AC8, "b": 0xC8865A, "y": 0xFFE07A, "g": 0xD0D0D8]),
              let flame = art([" y ", "yoy", "yoy", " o "], ["y": 0xFFE07A, "o": 0xFF8A3A]) else { return }
        let pixel: CGFloat = 6
        let sprite = CALayer()
        sprite.contents = image
        sprite.magnificationFilter = .nearest
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * pixel, height: CGFloat(image.height) * pixel)
        sprite.position = bottom
        layer.addSublayer(sprite)
        for column in [2, 6, 10] {
            let fire = CALayer()
            fire.name = "candle"
            fire.contents = flame
            fire.magnificationFilter = .nearest
            fire.anchorPoint = CGPoint(x: 0.5, y: 0)
            fire.bounds = CGRect(x: 0, y: 0, width: 3 * pixel * 0.7, height: 4 * pixel * 0.7)
            fire.position = CGPoint(x: bottom.x - sprite.bounds.width / 2 + (CGFloat(column) + 0.5) * pixel, y: bottom.y + sprite.bounds.height)
            fire.shadowColor = NSColor(rgb: 0xFFB04A).cgColor
            fire.shadowOpacity = 0.9
            fire.shadowRadius = 8
            fire.shadowOffset = .zero
            let flicker = CAKeyframeAnimation(keyPath: "transform.scale.y")
            flicker.values = [1, 0.8, 1.15, 0.9, 1]
            flicker.duration = 0.5 + Double(column) * 0.03
            flicker.repeatCount = .infinity
            fire.add(flicker, forKey: "flicker")
            layer.addSublayer(fire)
        }
    }

    /// Every 12 s on your birthday, one of the pets floats by hanging from balloons.
    func startBalloonRides() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 12, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.balloonRide() } }
        timer.resume()
        animalTimer = timer
    }

    func balloonRide() {
        guard showing == .birthday, let ground = grounds.randomElement(), let shape = Self.animalShapes.randomElement() else { return }
        let size = ground.frame.size
        let ride = CALayer()
        let petSize = CGSize(width: CGFloat(shape.width) * 4, height: CGFloat(shape.height) * 4)
        ride.bounds = CGRect(x: 0, y: 0, width: max(petSize.width, 110), height: petSize.height + 110)
        let pet = CALayer()
        pet.contents = shape
        pet.magnificationFilter = .nearest
        pet.frame = CGRect(x: (ride.bounds.width - petSize.width) / 2, y: 0, width: petSize.width, height: petSize.height)
        ride.addSublayer(pet)
        for (index, rgb) in Self.partyColors.shuffled().prefix(3).enumerated() {
            guard let image = Self.balloon(rgb) else { continue }
            let up = CALayer()
            up.contents = image
            up.magnificationFilter = .nearest
            up.frame = CGRect(x: ride.bounds.width / 2 - 14 + CGFloat(index - 1) * 26, y: petSize.height - 6 + CGFloat(index % 2) * 14, width: 28, height: 48 + 30)
            up.contentsGravity = .resize
            ride.addSublayer(up)
        }
        let x = CGFloat.random(in: size.width * 0.15...size.width * 0.85)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: -ride.bounds.height))
        for step in 1...20 {
            let t = CGFloat(step) / 20
            path.addLine(to: CGPoint(x: x + sin(t * .pi * 4) * 40 + t * 120, y: -ride.bounds.height + (size.height + ride.bounds.height * 2) * t))
        }
        let float = CAKeyframeAnimation(keyPath: "position")
        float.path = path
        float.calculationMode = .paced
        float.duration = 16
        ride.position = CGPoint(x: x, y: size.height + ride.bounds.height)
        ride.add(float, forKey: "float")
        ground.layer.addSublayer(ride)
        DispatchQueue.main.asyncAfter(deadline: .now() + float.duration) { ride.removeFromSuperlayer() }
    }

    /// Your pet makes a wish: the candles go out in a puff of smoke, a party
    /// popper of confetti goes off from `point`, and the candles light again.
    func makeWish(at point: CGPoint) {
        guard showing == .birthday, let ground = groundUnder(point) else { return }
        let start = CGPoint(x: point.x - ground.frame.minX, y: point.y - ground.frame.minY)
        let now = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        let paper = CAEmitterCell()
        paper.contents = Self.rect(4, 7, 0xFFFFFF)
        paper.color = NSColor(rgb: 0xFF8AC8).cgColor
        paper.redRange = 0.6
        paper.greenRange = 0.8
        paper.blueRange = 0.8
        paper.birthRate = 300
        paper.duration = 0.15
        paper.lifetime = 2
        paper.velocity = 300
        paper.velocityRange = 80
        paper.emissionLongitude = .pi
        paper.emissionRange = .pi / 3
        paper.yAcceleration = -320
        paper.spin = 4
        paper.spinRange = 8
        paper.alphaSpeed = -0.4
        let popper = CAEmitterLayer()
        popper.frame = CGRect(origin: .zero, size: ground.frame.size)
        popper.emitterPosition = start
        popper.beginTime = now
        popper.emitterCells = [paper]
        ground.layer.addSublayer(popper)
        var made: [CALayer] = [popper]

        for candle in grounds.flatMap({ $0.layer.sublayers ?? [] }).filter({ $0.name == "candle" }) {
            candle.isHidden = true
            guard let parent = candle.superlayer else { continue }
            let smoke = CAEmitterCell()
            smoke.contents = Self.square(3, 0xCCCCCC)
            smoke.birthRate = 20
            smoke.duration = 0.8
            smoke.lifetime = 1.4
            smoke.velocity = 30
            smoke.emissionLongitude = .pi
            smoke.emissionRange = .pi / 8
            smoke.alphaSpeed = -0.7
            let puff = CAEmitterLayer()
            puff.frame = parent.bounds
            puff.emitterPosition = CGPoint(x: candle.position.x, y: candle.position.y + 4)
            puff.beginTime = parent.convertTime(CACurrentMediaTime(), from: nil)
            puff.emitterCells = [smoke]
            parent.addSublayer(puff)
            made.append(puff)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { made.forEach { $0.removeFromSuperlayer() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.grounds.flatMap { $0.layer.sublayers ?? [] }.filter { $0.name == "candle" }.forEach { $0.isHidden = false }
        }
    }
}
