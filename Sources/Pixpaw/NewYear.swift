// Pixpaw
//
// New Year on the screen: rockets going up from above the Dock and bursting
// in one colour each, now and then a gold willow that hangs and falls, a
// countdown from ten at midnight with a salvo after it, and fireworks your
// pet lights itself. All of it is Core Animation in the festival's
// click-through panels (Festivals.swift); nothing runs between bursts.

import AppKit

extension FestivalOverlay {
    private static let burstColors: [UInt32] = [0xFF5A5A, 0x5AFF8C, 0x5AA8FF, 0xFF7AE0, 0xFFE15A]

    static func fireworks(in layer: CALayer, size: CGSize, floor: CGFloat) {
        let emitter = CAEmitterLayer()
        emitter.name = "fireworks"
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = CGPoint(x: size.width / 2, y: floor)
        emitter.emitterSize = CGSize(width: size.width * 0.8, height: 1)
        emitter.emitterShape = .line
        emitter.renderMode = .additive
        emitter.emitterCells = burstColors.map { rocket(burst: peony($0), rate: 0.17) } + [rocket(burst: willow(), rate: 0.12)]
        layer.addSublayer(emitter)
    }

    /// A rocket with a short trail, bursting near the top of its climb.
    private static func rocket(burst: CAEmitterCell, rate: Float) -> CAEmitterCell {
        let trail = CAEmitterCell()
        trail.contents = square(2, 0xFFFFFF)
        trail.color = NSColor(srgbRed: 1, green: 0.85, blue: 0.6, alpha: 1).cgColor
        trail.birthRate = 50
        trail.lifetime = 0.4
        trail.velocity = 10
        trail.emissionRange = .pi * 2
        trail.alphaSpeed = -2.5

        let pop = CAEmitterCell()
        pop.birthRate = 15 // over its 0.1 s: one burst
        pop.beginTime = 1.15
        pop.duration = 0.1
        pop.lifetime = 0.1
        pop.emitterCells = [burst]

        let rocket = CAEmitterCell()
        rocket.contents = square(3, 0xFFF2C0)
        rocket.birthRate = rate
        rocket.lifetime = 1.25
        rocket.velocity = 560
        rocket.velocityRange = 120
        rocket.emissionLongitude = .pi
        rocket.emissionRange = .pi / 14
        rocket.yAcceleration = -160
        rocket.emitterCells = [trail, pop]
        return rocket
    }

    /// A round burst in one colour.
    private static func peony(_ rgb: UInt32, velocity: CGFloat = 150, spread: CGFloat = 40) -> CAEmitterCell {
        let spark = CAEmitterCell()
        spark.contents = square(4, 0xFFFFFF)
        spark.color = color(rgb)
        spark.birthRate = 2400
        spark.lifetime = 1.6
        spark.velocity = velocity
        spark.velocityRange = spread
        spark.emissionRange = .pi * 2
        spark.yAcceleration = -90
        spark.alphaSpeed = -0.6
        return spark
    }

    /// Gold sparks that hang a long while and drift down.
    private static func willow() -> CAEmitterCell {
        let spark = CAEmitterCell()
        spark.contents = square(3, 0xFFFFFF)
        spark.color = color(0xFFC85A)
        spark.birthRate = 1500
        spark.lifetime = 2.8
        spark.velocity = 110
        spark.velocityRange = 30
        spark.emissionRange = .pi * 2
        spark.yAcceleration = -45
        spark.alphaSpeed = -0.33
        return spark
    }

    private static func color(_ rgb: UInt32) -> CGColor {
        NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255, alpha: 1).cgColor
    }

    /// A firework your pet lit at `point` on screen: one rocket straight up
    /// and a ring burst in a colour of its own. At most four in the air.
    func launchFirework(from point: CGPoint, shape: CGImage? = nil) {
        guard showing == .newYear || showing == .birthday,
              let ground = grounds.first(where: { $0.frame.contains(point) }) else { return }
        let size = ground.frame.size
        let start = CGPoint(x: point.x - ground.frame.minX, y: point.y - ground.frame.minY)
        let rise = max(60, min(420, size.height - 120 - start.y))
        if let shape {
            // Its own firework bursts in its own shape.
            Self.animalBurst(shape, in: ground.layer, from: start, at: CGPoint(x: start.x, y: start.y + rise))
            return
        }
        petFireworks.removeAll { $0.superlayer == nil }
        guard petFireworks.count < 4 else { return }

        let rgb = Self.burstColors.randomElement() ?? 0xFFFFFF
        let ring = Self.peony(rgb, velocity: 170, spread: 6)
        let inner = Self.peony(0xFFFFFF, velocity: 80, spread: 6)
        inner.birthRate = 1000
        let pop = CAEmitterCell()
        pop.birthRate = 15 // over its 0.1 s: one burst
        pop.beginTime = 0.9
        pop.duration = 0.1
        pop.lifetime = 0.1
        pop.emitterCells = [ring, inner]
        let rocket = CAEmitterCell()
        rocket.contents = Self.square(3, 0xFFF2C0)
        rocket.birthRate = 15
        rocket.duration = 0.1 // exactly one rocket
        rocket.lifetime = 1
        rocket.velocity = rise / 0.9
        rocket.emissionLongitude = .pi
        rocket.emitterCells = [pop]

        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = start
        emitter.renderMode = .additive
        emitter.beginTime = ground.layer.convertTime(CACurrentMediaTime(), from: nil)
        emitter.emitterCells = [rocket]
        ground.layer.addSublayer(emitter)
        petFireworks.append(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { emitter.removeFromSuperlayer() }
    }

    /// On New Year's Eve, the countdown ten seconds before midnight. Wall
    /// clock, so a Mac that slept through the evening still counts on time.
    func scheduleCountdown(now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let midnight = calendar.nextDate(after: now, matching: DateComponents(month: 1, day: 1, hour: 0, minute: 0, second: 0),
                                               matchingPolicy: .strict),
              midnight.timeIntervalSince(now) < 7 * 3600 else { return }
        startCountdown(after: midnight.timeIntervalSince(now) - 10)
    }

    /// Ten to one in the middle of every screen, then the greeting and a salvo.
    func startCountdown(after delay: TimeInterval) {
        countdown?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.count(from: 10) }
        countdown = work
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + max(0, delay), execute: work)
    }

    private func count(from number: Int) {
        guard showing == .newYear else { return }
        let text = number > 0 ? "\(number)" : "Happy New Year!"
        for ground in grounds { flash(text, big: number > 0, in: ground.layer, size: ground.frame.size) }
        if number > 0 {
            let work = DispatchWorkItem { [weak self] in self?.count(from: number - 1) }
            countdown = work
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 1, execute: work)
        } else {
            salvo()
        }
    }

    private func flash(_ text: String, big: Bool, in layer: CALayer, size: CGSize) {
        let label = CATextLayer()
        label.string = text
        label.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy)
        label.fontSize = big ? 140 : 72
        label.alignmentMode = .center
        label.foregroundColor = .white
        label.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        label.shadowColor = Self.color(0xFFC85A)
        label.shadowOpacity = 0.9
        label.shadowRadius = 12
        label.shadowOffset = .zero
        label.bounds = CGRect(x: 0, y: 0, width: size.width, height: label.fontSize * 1.3)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        label.opacity = 0
        layer.addSublayer(label)

        let hold: CFTimeInterval = big ? 0.95 : 4
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.5
        scale.toValue = 1
        scale.duration = 0.25
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.1, 0.75, 1]
        fade.duration = hold
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = hold
        label.add(group, forKey: "flash")
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) { label.removeFromSuperlayer() }
    }

    /// Six times the rockets for eight seconds after midnight.
    private func salvo() {
        let emitters = grounds.compactMap { $0.layer.sublayers?.first { $0.name == "fireworks" } as? CAEmitterLayer }
        emitters.forEach { $0.birthRate = 6 }
        for delay in [0.0, 1.2, 2.4] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.launchAnimal() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { emitters.forEach { $0.birthRate = 1 } }
    }

    // MARK: Animal fireworks

    /// Every 6 s while New Year is up, a rocket that bursts into one of the
    /// pets, in its own colours. Timer on the main queue: a few hundred
    /// small layers made per burst, Core Animation does the rest.
    func startAnimalFireworks() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3, repeating: 6, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.launchAnimal() } }
        timer.resume()
        animalTimer = timer
    }

    /// Every built-in pet and the ones you drew, happy.
    static var animalShapes: [CGImage] {
        PetKind.allCases.filter { !$0.isOwn || OwnPets.pet($0) != nil }.compactMap {
            CatSprites.shared.image(.happy, coat: .orange, kind: $0, rim: false)
        }
    }

    func launchAnimal() {
        guard showing == .newYear, let ground = grounds.randomElement(), let shape = Self.animalShapes.randomElement() else { return }
        let size = ground.frame.size
        let x = CGFloat.random(in: size.width * 0.2...size.width * 0.8)
        Self.animalBurst(shape, in: ground.layer, from: CGPoint(x: x, y: size.height * 0.12),
                         at: CGPoint(x: x, y: size.height * CGFloat.random(in: 0.55...0.72)))
    }

    /// A rocket from `start` up to `burst`, where each pixel of `shape`
    /// flies out to its place in the picture, hangs, then drops and fades.
    static func animalBurst(_ shape: CGImage, in layer: CALayer, from start: CGPoint, at burst: CGPoint, pixel: CGFloat = 9) {
        let sparks = pixels(of: shape)
        guard !sparks.isEmpty else { return }
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        let climb: CFTimeInterval = 0.9
        let total: CFTimeInterval = 3

        let rocket = CALayer()
        rocket.backgroundColor = color(0xFFF2C0)
        rocket.bounds = CGRect(x: 0, y: 0, width: 4, height: 10)
        rocket.position = burst
        rocket.opacity = 0
        let up = CABasicAnimation(keyPath: "position")
        up.fromValue = start
        up.toValue = burst
        up.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let shown = CABasicAnimation(keyPath: "opacity")
        shown.fromValue = 1
        shown.toValue = 1
        let rise = CAAnimationGroup()
        rise.animations = [up, shown]
        rise.duration = climb
        rise.beginTime = now
        rocket.add(rise, forKey: "rise")
        layer.addSublayer(rocket)

        let width = CGFloat(shape.width) * pixel
        let height = CGFloat(shape.height) * pixel
        var made: [CALayer] = [rocket]
        for spark in sparks {
            let dot = CALayer()
            dot.backgroundColor = spark.color
            dot.bounds = CGRect(x: 0, y: 0, width: pixel - 1, height: pixel - 1)
            let target = CGPoint(x: burst.x - width / 2 + (CGFloat(spark.x) + 0.5) * pixel,
                                 y: burst.y - height / 2 + (CGFloat(spark.y) + 0.5) * pixel)
            dot.position = target
            dot.opacity = 0
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.values = [burst, target, target, CGPoint(x: target.x, y: target.y - 40)]
            fly.keyTimes = [0, 0.18, 0.6, 1]
            fly.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeIn)]
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 1, 0]
            fade.keyTimes = [0, 0.6, 1]
            let group = CAAnimationGroup()
            group.animations = [fly, fade]
            group.duration = total
            group.beginTime = now + climb + Double.random(in: 0...0.06)
            dot.add(group, forKey: "burst")
            layer.addSublayer(dot)
            made.append(dot)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + climb + total + 0.2) { made.forEach { $0.removeFromSuperlayer() } }
    }

    /// The picture's coloured pixels, bottom row 0, nearly black ones left out (they vanish on a dark screen).
    static func pixels(of image: CGImage) -> [(x: Int, y: Int, color: CGColor)] {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }
        var result: [(x: Int, y: Int, color: CGColor)] = []
        for row in 0..<height {
            for column in 0..<width {
                let i = (row * width + column) * 4
                let alpha = data[i + 3]
                guard alpha > 128 else { continue }
                let r = CGFloat(data[i]) / CGFloat(alpha), g = CGFloat(data[i + 1]) / CGFloat(alpha), b = CGFloat(data[i + 2]) / CGFloat(alpha)
                guard max(r, g, b) > 0.15 else { continue }
                result.append((column, height - 1 - row, NSColor(srgbRed: r, green: g, blue: b, alpha: 1).cgColor))
            }
        }
        return result
    }
}
