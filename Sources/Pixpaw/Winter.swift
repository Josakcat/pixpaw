// Pixpaw
//
// Christmas on the screen: snow in three layers drifting in a light wind, a
// snowbank building up along the Dock with the snowman on it, fairy lights
// under the menu bar, and snow lying on the tops of your windows. All of it
// is Core Animation in the festival's click-through panels (Festivals.swift);
// the only work of ours is reading where the windows are, every 2 seconds on
// a background queue, while Christmas is up.

import AppKit

extension FestivalOverlay {
    /// How tall the snowbank along the Dock grows.
    static let snowbankHeight: CGFloat = 20

    /// A snowball your pet finished rolling, at `point` on screen: the first
    /// of three is a snowman's bottom, the second its middle, the third
    /// makes it a snowman. Up to three snowmen; the oldest melts away.
    func addSnowball(at point: CGPoint) {
        guard showing == .christmas else { return }
        let part = snowballs % 3
        if part == 0 {
            // A new snowman where this first ball stopped.
            guard let index = grounds.firstIndex(where: { $0.frame.minX <= point.x && point.x < $0.frame.maxX }) else { return }
            snowmanSpot = (index, point.x - grounds[index].frame.minX)
        }
        guard let spot = snowmanSpot, spot.ground < grounds.count else { return }
        let ground = grounds[spot.ground]
        snowballs += 1
        let layer = CALayer()
        layer.magnificationFilter = .nearest
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        if part == 2, let art = CatSprites.shared.image(.snowman) {
            // Done: the two balls so far give way to the whole snowman.
            snowmen.suffix(2).forEach { $0.removeFromSuperlayer() }
            snowmen.removeLast(min(2, snowmen.count))
            layer.contents = art
            layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(art.width) * 5, height: CGFloat(art.height) * 5)
            layer.position = CGPoint(x: spot.x, y: ground.y)
        } else if let ball = CatSprites.shared.image(.snowball) {
            let side: CGFloat = part == 0 ? 48 : 34
            layer.contents = ball
            layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            layer.position = CGPoint(x: spot.x, y: ground.y + (part == 0 ? 0 : 42))
        } else { return }
        let pop = CABasicAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.6
        pop.duration = 0.25
        layer.add(pop, forKey: "pop")
        ground.layer.addSublayer(layer)
        snowmen.append(layer)
        // Three finished snowmen at most: the oldest melts.
        let finished = snowmen.filter { $0.bounds.height > 60 }
        if finished.count > 3, let oldest = finished.first {
            oldest.removeFromSuperlayer()
            snowmen.removeAll { $0 === oldest }
        }
    }

    /// `floor`: the Dock's height (0 when it is hidden or at the side);
    /// `top`: the menu bar's.
    static func winter(in layer: CALayer, size: CGSize, floor: CGFloat, top: CGFloat) {
        // Far, middle and near flakes: the nearer, the bigger, faster and
        // brighter; all leaning the same way in the wind.
        layer.addSublayer(falling(size: size, image: square(2, 0xDDE6FF), birthRate: 2.4, speed: 22, sway: 5, alpha: 0.45))
        layer.addSublayer(falling(size: size, image: square(4, 0xFFFFFF), birthRate: 2.4, speed: 38, sway: 7, alpha: 0.85))
        layer.addSublayer(falling(size: size, image: square(6, 0xF4F8FF), birthRate: 0.9, speed: 62, sway: 9, alpha: 0.95))
        let bank = snowbank(in: layer, size: size, floor: floor)
        snowman(in: layer, size: size, floor: floor + bank - 6)
        fairyLights(in: layer, size: size, top: top)
    }

    /// Pixel snow along the bottom, just above the Dock, rising as it
    /// settles. Returns how tall it ends up.
    private static func snowbank(in layer: CALayer, size: CGSize, floor: CGFloat) -> CGFloat {
        let rows = 5, px = snowbankHeight / CGFloat(rows)
        let cols = Int(size.width / px) + 1
        guard let image = pixels(cols, rows, { c, r in
            // A lumpy top, two to five pixels high.
            let x = Double(c)
            let wave: Double = 3.4 + 1.1 * sin(x * 0.21) + 0.7 * sin(x * 0.57 + 1.3)
            if r >= max(2, min(rows, Int(wave.rounded()))) { return nil }
            return r == 0 ? UInt32(0xDCE6F8) : UInt32(0xF6F9FF)
        }) else { return 0 }
        let height = snowbankHeight
        let holder = CALayer()
        holder.frame = CGRect(x: 0, y: floor, width: size.width, height: height)
        holder.masksToBounds = true
        let sprite = CALayer()
        sprite.contents = image
        sprite.magnificationFilter = .nearest
        sprite.anchorPoint = .zero
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(cols) * px, height: height)
        sprite.position = .zero
        // Settling: up from a third of the way to the whole bank.
        let rise = CABasicAnimation(keyPath: "position.y")
        rise.fromValue = -height * 0.65
        rise.toValue = 0
        rise.duration = 24
        rise.timingFunction = CAMediaTimingFunction(name: .easeOut)
        sprite.add(rise, forKey: "rise")
        holder.addSublayer(sprite)
        layer.addSublayer(holder)
        return height
    }

    /// The snowman, standing at `floor` near the right edge.
    private static func snowman(in layer: CALayer, size: CGSize, floor: CGFloat) {
        guard let art = CatSprites.shared.image(.snowman) else { return }
        let sprite = CALayer()
        sprite.contents = art
        sprite.magnificationFilter = .nearest
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.bounds = CGRect(x: 0, y: 0, width: CGFloat(art.width) * 5, height: CGFloat(art.height) * 5)
        sprite.position = CGPoint(x: size.width - 110, y: floor)
        layer.addSublayer(sprite)
    }

    /// A string of coloured bulbs sagging between hooks under the menu bar,
    /// each twinkling at its own pace.
    private static func fairyLights(in layer: CALayer, size: CGSize, top: CGFloat) {
        let hookY = size.height - top - 3, span: CGFloat = 160, sag: CGFloat = 12
        let wire = CAShapeLayer()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: hookY))
        var x: CGFloat = 0
        while x < size.width {
            path.addQuadCurve(to: CGPoint(x: x + span, y: hookY), control: CGPoint(x: x + span / 2, y: hookY - sag * 2))
            x += span
        }
        wire.path = path
        wire.strokeColor = NSColor(rgb: 0x2E5E3A).cgColor
        wire.fillColor = nil
        wire.lineWidth = 2
        layer.addSublayer(wire)
        let colors: [UInt32] = [0xF0141E, 0xFFD34D, 0x5DBB3C, 0x4F86E8]
        var index = 0
        x = 0
        while x < size.width {
            for t in [0.125, 0.375, 0.625, 0.875] as [CGFloat] {
                guard let image = rect(3, 4, colors[index % colors.count]) else { continue }
                let bulb = CALayer()
                bulb.contents = image
                bulb.magnificationFilter = .nearest
                bulb.anchorPoint = CGPoint(x: 0.5, y: 1)
                bulb.bounds = CGRect(x: 0, y: 0, width: 6, height: 8)
                // On the curve: it dips `sag` at the middle of each span.
                bulb.position = CGPoint(x: x + span * t, y: hookY - sag * 4 * t * (1 - t))
                let twinkle = CABasicAnimation(keyPath: "opacity")
                twinkle.fromValue = 1
                twinkle.toValue = 0.3
                twinkle.duration = Double.random(in: 0.7...1.6)
                twinkle.autoreverses = true
                twinkle.repeatCount = .infinity
                twinkle.timeOffset = Double.random(in: 0...1.6)
                bulb.add(twinkle, forKey: "twinkle")
                layer.addSublayer(bulb)
                index += 1
            }
            x += span
        }
    }

    /// A `width`×`height` picture from `color(column, row)`, row 0 at the
    /// bottom; nil leaves a pixel clear.
    static func pixels(_ width: Int, _ height: Int, _ color: (Int, Int) -> UInt32?) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for c in 0..<width {
            for r in 0..<height {
                guard let rgb = color(c, r) else { continue }
                context.setFillColor(NSColor(rgb: rgb).cgColor)
                context.fill(CGRect(x: c, y: r, width: 1, height: 1))
            }
        }
        return context.makeImage()
    }
}

/// Snow lying on the top edges of your windows (the parts not under another
/// window), up to eight of them. Where the windows are is read every 2
/// seconds on a background queue; a window that moved since the last read
/// loses its snow until it stays put again.
@MainActor
final class WindowSnow {
    private let hosts: [(frame: CGRect, layer: CALayer)]
    private let queue = DispatchQueue(label: "pixpaw.festival.windows", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var caps: [String: CALayer] = [:]
    private var lastFrames: [Int: CGRect] = [:]

    init(hosts: [(CGRect, CALayer)]) {
        self.hosts = hosts.map { (frame: $0.0, layer: $0.1) }
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.5, repeating: 2, leeway: .milliseconds(500))
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let me = ProcessInfo.processInfo.processIdentifier
        timer.setEventHandler(handler: Self.tick(self, skipping: me, primaryHeight: primaryHeight))
        timer.resume()
        self.timer = timer
    }

    /// Built outside the main actor: a closure written inside start() would
    /// inherit @MainActor and trap when the timer fires on the utility queue.
    private nonisolated static func tick(_ owner: WindowSnow, skipping me: pid_t, primaryHeight: CGFloat) -> @Sendable () -> Void {
        { [weak owner] in
            let windows = read(skipping: me)
            Task { @MainActor in owner?.apply(windows, primaryHeight: primaryHeight) }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        caps.values.forEach { $0.removeFromSuperlayer() }
        caps = [:]
        lastFrames = [:]
    }

    /// Ordinary windows on screen, front first, in screen coordinates with
    /// the top-left of the main display at 0, 0; ours left out.
    nonisolated static func read(skipping pid: pid_t) -> [(id: Int, rect: CGRect)] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return info.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != pid,
                  ((w[kCGWindowAlpha as String] as? Double) ?? 1) > 0.05,
                  let id = w[kCGWindowNumber as String] as? Int,
                  let bounds = w[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= 120, rect.height >= 80 else { return nil }
            return (id, rect)
        }
    }

    private func apply(_ windows: [(id: Int, rect: CGRect)], primaryHeight: CGFloat) {
        guard timer != nil else { return }
        // Moving now: no snow on it until it stops.
        let moving = Set(windows.filter { window in lastFrames[window.id].map { $0 != window.rect } ?? false }.map(\.id))
        lastFrames = Dictionary(windows.map { (key: $0.id, value: $0.rect) }, uniquingKeysWith: { first, _ in first })
        var keep: Set<String> = []
        for (n, edge) in SnowEdges.open(windows).enumerated() where !moving.contains(edge.id) {
            // To the screen's own coordinates, bottom-left.
            let point = CGPoint(x: edge.from, y: primaryHeight - edge.y)
            guard let host = hosts.first(where: { $0.frame.minX <= point.x && point.x < $0.frame.maxX
                && $0.frame.minY < point.y && point.y <= $0.frame.maxY }) else { continue }
            let key = "\(edge.id):\(n):\(Int(edge.from)):\(Int(edge.to))"
            keep.insert(key)
            if caps[key] != nil { continue }
            let width = min(edge.to, host.frame.maxX) - edge.from
            guard let cap = Self.cap(width: width) else { continue }
            // Lying on the title bar, just inside the edge: a window up against
            // the menu bar would hide snow sitting above it.
            cap.position = CGPoint(x: point.x - host.frame.minX, y: point.y - host.frame.minY - cap.bounds.height + 3)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.duration = 1.2
            cap.add(fade, forKey: "fade")
            host.layer.addSublayer(cap)
            caps[key] = cap
        }
        for (key, cap) in caps where !keep.contains(key) {
            cap.removeFromSuperlayer()
            caps[key] = nil
        }
    }

    /// A lumpy strip of snow `width` points long, its bottom-left at its position.
    private static func cap(width: CGFloat) -> CALayer? {
        let px: CGFloat = 3, rows = 3
        let cols = max(1, Int(width / px))
        guard let image = FestivalOverlay.pixels(cols, rows, { c, r in
            let x = Double(c)
            let wave: Double = 2.2 + 0.9 * sin(x * 0.37) + 0.5 * sin(x * 0.91 + 2)
            let height: Int = c == 0 || c == cols - 1 ? 1 : Int(wave.rounded())
            return r < max(1, min(rows, height)) ? UInt32(0xF6F9FF) : nil
        }) else { return nil }
        let layer = CALayer()
        layer.contents = image
        layer.magnificationFilter = .nearest
        layer.anchorPoint = .zero
        layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(cols) * px, height: CGFloat(rows) * px)
        return layer
    }
}
