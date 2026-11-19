// droppykit-lint: allow-file own-window: festival decorations on their real dates only, one click-through panel per screen just under the pet's level, each festival switchable in Settings and all closed in deactivate(); agreed by Droppy for the Store, 2026-11-04
//
//  Festivals.swift
//  Pixpaw
//
//  On a festival's days the screen gets decorated: ghosts drift across it on
//  Halloween, fireworks go up for New Year, snow falls at Christmas. The
//  decorations sit in a click-through window under the pet, are drawn by
//  Core Animation (no work for the app between frames), and go away by
//  themselves when the festival is over.
//

import AppKit

enum Festival: String, CaseIterable, Identifiable {
    case newYear, chineseNewYear, valentines, songkran, halloween, loyKrathong, christmas
    /// Yours, on the day you set in Settings.
    case birthday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newYear: "New Year"
        case .chineseNewYear: "Chinese New Year"
        case .loyKrathong: "Loy Krathong"
        case .valentines: "Valentine's Day"
        case .songkran: "Songkran"
        case .halloween: "Halloween"
        case .christmas: "Christmas"
        case .birthday: "Your birthday"
        }
    }

    /// What the pet says when the festival starts.
    var greeting: CatLine {
        switch self {
        case .newYear: CatLine(text: "Happy New Year!", symbol: "sparkles", seconds: 3)
        case .chineseNewYear: CatLine(text: "Happy Chinese New Year!", symbol: "sparkles", seconds: 3)
        case .loyKrathong: CatLine(text: "Happy Loy Krathong!", symbol: "moon.stars.fill", seconds: 3)
        case .valentines: CatLine(text: "Happy Valentine's Day!", symbol: "heart.fill", seconds: 3)
        case .songkran: CatLine(text: "Happy Songkran! Splash!", symbol: "drop.fill", seconds: 3)
        case .halloween: CatLine(text: "Happy Halloween! Boo!", symbol: "moon.stars.fill", seconds: 3)
        case .christmas: CatLine(text: "Merry Christmas!", symbol: "snowflake", seconds: 3)
        case .birthday: CatLine(text: "Happy birthday!", symbol: "birthday.cake.fill", seconds: 4)
        }
    }

    /// What the pet wears for it, in place of its own hat.
    var hat: CatAccessory? {
        switch self {
        case .newYear, .birthday: .partyHat
        case .valentines: .bow
        case .halloween: .witchHat
        case .christmas: .santaHat
        case .songkran, .chineseNewYear, .loyKrathong: nil
        }
    }

    /// When it is on, in the Mac's own time zone; for Settings.
    var when: String {
        switch self {
        case .newYear: "31 Dec from 6 pm to 1 Jan"
        case .chineseNewYear: "Lunar New Year's Day and the day after"
        case .loyKrathong: "The full moon of the twelfth Thai month, in November"
        case .valentines: "14 Feb"
        case .songkran: "13 to 15 Apr"
        case .halloween: "31 Oct"
        case .christmas: "24 and 25 Dec"
        case .birthday: "The day you set"
        }
    }

    /// What it puts on the screen; for Settings.
    var decoration: String {
        switch self {
        case .newYear: "fireworks"
        case .chineseNewYear: "red lanterns swaying"
        case .loyKrathong: "krathongs floating and lanterns rising"
        case .valentines: "hearts floating up"
        case .songkran: "water drops"
        case .halloween: "ghosts drifting by"
        case .christmas: "falling snow"
        case .birthday: "confetti"
        }
    }

    /// Whether `date` falls in the festival, in local time.
    func isOn(at date: Date) -> Bool {
        let parts = Calendar(identifier: .gregorian).dateComponents([.month, .day, .hour], from: date)
        guard let month = parts.month, let day = parts.day, let hour = parts.hour else { return false }
        switch self {
        case .newYear: return (month == 12 && day == 31 && hour >= 18) || (month == 1 && day == 1)
        case .chineseNewYear:
            guard let first = Self.lunarNewYear(in: date) else { return false }
            let start = Calendar(identifier: .gregorian).startOfDay(for: first)
            return date >= start && date < start.addingTimeInterval(2 * 86_400 + 3600)
        case .loyKrathong:
            let year = Calendar(identifier: .gregorian).component(.year, from: date)
            return Self.loyKrathongDays[year].map { $0.month == month && $0.day == day } ?? false
        case .valentines: return month == 2 && day == 14
        case .songkran: return month == 4 && (13...15).contains(day)
        case .halloween: return month == 10 && day == 31
        case .christmas: return month == 12 && (day == 24 || day == 25)
        // Only by its date, through `current(at:birthday:)`.
        case .birthday: return false
        }
    }

    /// Lunar New Year's Day, by year; the moon decides, so it is a table.
    private static let chineseNewYearDays: [Int: (month: Int, day: Int)] = [
        2026: (2, 17), 2027: (2, 6), 2028: (1, 26), 2029: (2, 13), 2030: (2, 3), 2031: (1, 23),
        2032: (2, 11), 2033: (1, 31), 2034: (2, 19), 2035: (2, 8), 2036: (1, 28), 2037: (2, 15),
    ]

    /// Loy Krathong, the full moon of the twelfth month of the Thai lunar
    /// calendar, by year (from the Thai calendar; extend as years are set).
    private static let loyKrathongDays: [Int: (month: Int, day: Int)] = [
        2026: (11, 24), 2027: (11, 13), 2028: (11, 1), 2029: (11, 20), 2030: (11, 9), 2031: (11, 28),
    ]

    private static func lunarNewYear(in date: Date) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        guard let day = chineseNewYearDays[year] else { return nil }
        return calendar.date(from: DateComponents(year: year, month: day.month, day: day.day))
    }

    /// The festivals that come round on the same dates for everyone.
    static var calendar: [Festival] { allCases.filter { $0 != .birthday } }

    /// Today's festival; your birthday, when set, comes before any other.
    /// Born on 29 February, it falls on the 28th in other years.
    static func current(at date: Date = Date(), birthday: (month: Int, day: Int)? = nil) -> Festival? {
        if let birthday {
            let calendar = Calendar(identifier: .gregorian)
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            var day = birthday.day
            if birthday.month == 2, day == 29, let year = parts.year,
               calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: 2)) ?? date)?.count == 28 {
                day = 28
            }
            if parts.month == birthday.month, parts.day == day { return .birthday }
        }
        return calendar.first { $0.isOn(at: date) }
    }
}

/// The decorations: one transparent, click-through window per screen.
@MainActor
final class FestivalOverlay {
    private(set) var showing: Festival?
    private var panels: [NSPanel] = []
    /// Christmas: snow on the tops of your windows, read every 2 s off the main thread (Winter.swift).
    private var windowSnow: WindowSnow?
    /// Christmas: each screen's panel and where its snowbank's top is, for
    /// the snowmen your pet builds (`addSnowball`).
    var grounds: [(frame: CGRect, layer: CALayer, y: CGFloat)] = []
    var snowballs = 0
    var snowmen: [CALayer] = []
    /// Where the snowman being built stands: which screen, and how far along it.
    var snowmanSpot: (ground: Int, x: CGFloat)?
    /// New Year: the next step of the midnight countdown, and the pet's fireworks in the air (NewYear.swift).
    var countdown: DispatchWorkItem?
    var petFireworks: [CALayer] = []
    /// Repeating shows: New Year's animal fireworks, Songkran's water fights, Halloween's ghost pets, Chinese New Year's dragon dance, Valentine's couples, birthday balloon rides.
    var animalTimer: DispatchSourceTimer?
    /// Loy Krathong: the krathongs your pet floated (Water.swift).
    var floated: [CALayer] = []

    func show(_ festival: Festival) {
        guard festival != showing else { return }
        hide()
        showing = festival
        var hosts: [(CGRect, CALayer)] = []
        for screen in NSScreen.screens {
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            // Over your windows, under the pet; out of full-screen apps.
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            panel.contentView = view
            if let layer = view.layer {
                Self.decorate(layer, for: festival, size: screen.frame.size, floor: screen.visibleFrame.minY - screen.frame.minY,
                              top: screen.frame.maxY - screen.visibleFrame.maxY)
                hosts.append((screen.frame, layer))
                grounds.append((screen.frame, layer, screen.visibleFrame.minY - screen.frame.minY + Self.snowbankHeight - 6))
            }
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        if festival == .christmas, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            windowSnow = WindowSnow(hosts: hosts)
            windowSnow?.start()
        }
        if festival == .newYear, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            scheduleCountdown()
            startAnimalFireworks()
        }
        if festival == .songkran, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { startWaterFights() }
        if festival == .halloween, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { startGhostPets() }
        if festival == .chineseNewYear, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { startDragonDances() }
        if festival == .valentines, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { startCouples() }
        if festival == .birthday, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { startBalloonRides() }
    }

    func hide() {
        windowSnow?.stop()
        windowSnow = nil
        countdown?.cancel()
        countdown = nil
        petFireworks = []
        floated = []
        animalTimer?.cancel()
        animalTimer = nil
        grounds = []
        snowballs = 0
        snowmen = []
        snowmanSpot = nil
        panels.forEach { $0.orderOut(nil) }
        panels = []
        showing = nil
    }

    /// Screens came or went: lay it out again on the ones there now.
    func refit() {
        guard let festival = showing else { return }
        hide()
        show(festival)
    }

    // MARK: Decorations

    private static func decorate(_ layer: CALayer, for festival: Festival, size: CGSize, floor: CGFloat, top: CGFloat) {
        // Reduce Motion: nothing falls, drifts or bursts. The pet's festival
        // hat stays on, and one still prop stands in the corner.
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            stillProp(in: layer, for: festival, size: size)
            return
        }
        switch festival {
        case .halloween: halloweenNight(in: layer, size: size, floor: floor, top: top)
        case .newYear: fireworks(in: layer, size: size, floor: floor)
        case .christmas:
            winter(in: layer, size: size, floor: floor, top: top)
        case .songkran: songkranSplash(in: layer, size: size, floor: floor)
        case .valentines: valentineDay(in: layer, size: size, floor: floor)
        case .birthday: birthdayParty(in: layer, size: size, floor: floor, top: top)
        case .loyKrathong: loyKrathongNight(in: layer, size: size, floor: floor, top: top)
        case .chineseNewYear: lunarNewYear(in: layer, size: size, floor: floor, top: top)
        }
    }

    /// One still picture near the bottom corner, for Reduce Motion.
    private static func stillProp(in layer: CALayer, for festival: Festival, size: CGSize) {
        let image: CGImage?
        switch festival {
        case .halloween: image = CatSprites.shared.image(.ghost)
        case .valentines: image = CatSprites.shared.image(.heart)
        case .loyKrathong: image = CatSprites.shared.image(.krathong)
        case .chineseNewYear: image = CatSprites.shared.image(.redLantern)
        case .christmas: image = CatSprites.shared.image(.snowman)
        case .newYear, .songkran, .birthday: image = nil
        }
        guard let image else { return }
        let sprite = CALayer()
        sprite.contents = image
        sprite.magnificationFilter = .nearest
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * 4, height: CGFloat(image.height) * 4)
        sprite.position = CGPoint(x: size.width - 60, y: 60)
        sprite.opacity = 0.9
        layer.addSublayer(sprite)
    }

    /// Ghosts drifting across the screen on wavy paths, at different
    /// heights and speeds, fading in and out a little.
    static func ghosts(in layer: CALayer, size: CGSize) {
        guard let ghost = CatSprites.shared.image(.ghost) else { return }
        for index in 0..<4 {
            let sprite = CALayer()
            let scale = CGFloat([4, 3, 5, 3][index])
            sprite.contents = ghost
            sprite.magnificationFilter = .nearest
            sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(ghost.width) * scale, height: CGFloat(ghost.height) * scale)
            sprite.opacity = 0.8
            let leftToRight = index % 2 == 0
            if !leftToRight { sprite.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }

            let path = CGMutablePath()
            let baseY = size.height * CGFloat([0.72, 0.45, 0.58, 0.3][index])
            let from = leftToRight ? -80.0 : size.width + 80
            let to = leftToRight ? size.width + 80 : -80.0
            path.move(to: CGPoint(x: from, y: baseY))
            let steps = 24
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                path.addLine(to: CGPoint(x: from + (to - from) * t, y: baseY + sin(t * .pi * 6) * 28))
            }
            let drift = CAKeyframeAnimation(keyPath: "position")
            drift.path = path
            drift.duration = [38, 52, 30, 46][index]
            drift.repeatCount = .infinity
            drift.calculationMode = .paced
            // Spread out, rather than all setting off together.
            drift.timeOffset = drift.duration * Double(index) / 4
            sprite.add(drift, forKey: "drift")

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.85
            fade.toValue = 0.45
            fade.duration = 2.4
            fade.autoreverses = true
            fade.repeatCount = .infinity
            sprite.add(fade, forKey: "fade")
            layer.addSublayer(sprite)
        }
    }

    // Emitter angles: .pi sends a particle up the screen and 0 down; ±.pi/2
    // go sideways (checked on screen, 2026-11-18).


    /// Pixel hearts drifting up from the bottom and fading.
    static func hearts(in layer: CALayer, size: CGSize) {
        guard let heart = CatSprites.shared.image(.heart).flatMap({ scaled($0, by: 3) }) else { return }
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = CGPoint(x: size.width / 2, y: -20)
        emitter.emitterSize = CGSize(width: size.width, height: 1)
        emitter.emitterShape = .line
        let cell = CAEmitterCell()
        cell.contents = heart
        cell.birthRate = 0.9
        cell.lifetime = 16
        cell.velocity = 70
        cell.velocityRange = 25
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 14
        cell.alphaSpeed = -0.05
        cell.scaleRange = 0.3
        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)
    }

    /// Krathongs floating slowly along the bottom of the screen, candles lit,
    /// and sky lanterns drifting up and away.
    static func krathongs(in layer: CALayer, size: CGSize, floor: CGFloat) {
        if let krathong = CatSprites.shared.image(.krathong) {
            for index in 0..<3 {
                let sprite = CALayer()
                let scale: CGFloat = [4, 3, 5][index]
                sprite.contents = krathong
                sprite.magnificationFilter = .nearest
                sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(krathong.width) * scale, height: CGFloat(krathong.height) * scale)
                let path = CGMutablePath()
                // On the water just above the Dock (`floor`: its height, 0 when hidden).
                let baseY = floor + CGFloat([34, 22, 48][index])
                path.move(to: CGPoint(x: -60, y: baseY))
                for step in 1...30 {
                    let t = CGFloat(step) / 30
                    path.addLine(to: CGPoint(x: -60 + (size.width + 120) * t, y: baseY + sin(t * .pi * 10) * 3))
                }
                let drift = CAKeyframeAnimation(keyPath: "position")
                drift.path = path
                drift.duration = [70, 90, 80][index]
                drift.repeatCount = .infinity
                drift.calculationMode = .paced
                drift.timeOffset = drift.duration * Double(index) / 3
                sprite.add(drift, forKey: "drift")
                layer.addSublayer(sprite)
            }
        }
        guard let lantern = CatSprites.shared.image(.skyLantern).flatMap({ scaled($0, by: 3) }) else { return }
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = CGPoint(x: size.width / 2, y: -20)
        emitter.emitterSize = CGSize(width: size.width * 0.9, height: 1)
        emitter.emitterShape = .line
        let cell = CAEmitterCell()
        cell.contents = lantern
        cell.birthRate = 0.12
        cell.lifetime = Float(size.height / 28) + 4
        cell.velocity = 28
        cell.velocityRange = 8
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 16
        cell.xAcceleration = 2
        cell.alphaSpeed = -0.02
        cell.scaleRange = 0.35
        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)
    }

    /// Red lanterns hanging along the top edge, each swaying on its string,
    /// and a few gold sparks drifting down.
    static func redLanterns(in layer: CALayer, size: CGSize) {
        if let lantern = CatSprites.shared.image(.redLantern) {
            let count = 6
            for index in 0..<count {
                let sprite = CALayer()
                let scale: CGFloat = index % 2 == 0 ? 5 : 4
                sprite.contents = lantern
                sprite.magnificationFilter = .nearest
                sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(lantern.width) * scale, height: CGFloat(lantern.height) * scale)
                // Hung by the top of its string, just under the menu bar.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 1)
                sprite.position = CGPoint(x: size.width * (CGFloat(index) + 0.5) / CGFloat(count), y: size.height - 30 - CGFloat(index % 2) * 18)
                let sway = CABasicAnimation(keyPath: "transform.rotation.z")
                sway.fromValue = -0.08
                sway.toValue = 0.08
                sway.duration = [2.6, 3.1, 2.8, 3.4, 2.5, 3.0][index]
                sway.autoreverses = true
                sway.repeatCount = .infinity
                sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                sway.timeOffset = sway.duration * Double(index) / Double(count)
                sprite.add(sway, forKey: "sway")
                layer.addSublayer(sprite)
            }
        }
        layer.addSublayer(falling(size: size, image: square(3, 0xFFD34D), birthRate: 0.8, speed: 45, sway: 4, alpha: 0.8))
    }

    /// Paper confetti in party colours, tumbling down from the top edge.
    static func confetti(in layer: CALayer, size: CGSize) {
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = CGPoint(x: size.width / 2, y: size.height + 10)
        emitter.emitterSize = CGSize(width: size.width, height: 1)
        emitter.emitterShape = .line
        emitter.emitterCells = ([0xFF5B7F, 0xFFD34D, 0x4F86E8, 0x5DBB3C, 0x9B6BFF, 0xFF9A3C] as [UInt32]).map { rgb in
            let cell = CAEmitterCell()
            cell.contents = rect(3, 6, rgb)
            cell.birthRate = 0.6
            cell.lifetime = Float(size.height / 60) + 3
            cell.velocity = 70
            cell.velocityRange = 25
            cell.emissionLongitude = 0
            cell.emissionRange = .pi / 8
            cell.spin = 2
            cell.spinRange = 6
            cell.scaleRange = 0.3
            return cell
        }
        layer.addSublayer(emitter)
    }

    /// Something falling from the top edge: snow, or water drops.
    static func falling(size: CGSize, image: CGImage?, birthRate: Float, speed: CGFloat,
                                sway: CGFloat, alpha: Float) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterPosition = CGPoint(x: size.width / 2, y: size.height + 10)
        emitter.emitterSize = CGSize(width: size.width, height: 1)
        emitter.emitterShape = .line
        let cell = CAEmitterCell()
        cell.contents = image
        cell.birthRate = birthRate
        cell.lifetime = Float(size.height / speed) + 2
        cell.velocity = speed
        cell.velocityRange = speed * 0.3
        cell.emissionLongitude = 0
        cell.emissionRange = sway > 0 ? .pi / 10 : 0
        cell.xAcceleration = sway
        cell.alphaRange = 0.2
        cell.color = NSColor(white: 1, alpha: CGFloat(alpha)).cgColor
        emitter.emitterCells = [cell]
        return emitter
    }

    // MARK: Pixels

    static func square(_ side: Int, _ rgb: UInt32) -> CGImage? { rect(side, side, rgb) }

    static func rect(_ width: Int, _ height: Int, _ rgb: UInt32) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(NSColor(rgb: rgb).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// A sprite blown up with hard edges, for a particle (which would blur it).
    static func scaled(_ image: CGImage, by factor: Int) -> CGImage? {
        let width = image.width * factor, height = image.height * factor
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
