// droppykit-lint: allow-file own-window: the scuffle's dust cloud, a click-through panel over the pet and its friend for a couple of seconds while they play-fight, never opened by itself, and closed when the pet hides and in deactivate(); under the same waiver as the pet's own panel, agreed by Droppy for the Store, 2026-11-04
//
//  Scuffle.swift
//  Pixpaw
//
//  Now and then the pet runs at its friend and the two disappear into a
//  cartoon cloud of dust, stars flying, then pop out again as if nothing
//  happened. Play-fighting, the way real cats and dogs do; nobody is hurt.
//

import AppKit

@MainActor
final class DustCloud {
    static let duration: TimeInterval = 2.6
    /// In sprite pixels, three points each like the pets.
    private static let width = 54, height = 36

    private let panel: CatPanel
    private let layer = CALayer()
    private var timer: Timer?
    private var frame = 0
    private static let frames: [CGImage] = (0..<6).compactMap { draw(seed: $0, k: 1) }
    /// The same frames drawn twice as fine, for beside an HD pet: same points, 1.5 each.
    private static let fineFrames: [CGImage] = (0..<6).compactMap { draw(seed: $0, k: 2) }
    private let shown: [CGImage]

    /// A cloud standing on the floor at `bottomCenter`; `fine`: drawn in HD.
    init(bottomCenter: CGPoint, fine: Bool = false) {
        shown = fine ? Self.fineFrames : Self.frames
        let scale = CatSprites.scale
        let size = CGSize(width: CGFloat(Self.width) * scale, height: CGFloat(Self.height) * scale)
        panel = CatPanel(contentRect: CGRect(origin: CGPoint(x: bottomCenter.x - size.width / 2, y: bottomCenter.y - 3 * scale), size: size))
        panel.ignoresMouseEvents = true
        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        layer.frame = view.bounds
        layer.magnificationFilter = .nearest
        layer.actions = ["contents": NSNull(), "transform": NSNull()]
        layer.contents = shown.first
        view.layer?.addSublayer(layer)
        panel.contentView = view
    }

    func start() {
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.frame += 1
                self.layer.contents = self.shown[self.frame % self.shown.count]
                // A bit of a bounce as they roll about.
                self.layer.transform = CATransform3DMakeTranslation(CGFloat([0, 2, -1, 3, 0, -2][self.frame % 6]), CGFloat(self.frame % 2) * 3, 0)
            }
        }
        // Keeps tumbling while a menu is open, like the pet.
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
        panel.close()
    }

    /// One frame: puffs of dust jostling about, an outline, a shadow at
    /// the bottom, and stars, paws and bits flying off. `k` grid pixels to
    /// each of the classic ones: the same draws, finer; the outline stays 1.
    private static func draw(seed: Int, k: Int) -> CGImage? {
        var random = SeededRandom(seed: UInt64(seed + 1) * 2_654_435_761)
        let w = width * k, h = height * k, kd = Double(k)
        var cloud = [[Bool]](repeating: [Bool](repeating: false, count: w), count: h)
        // Puffs along the cloud, the middle ones biggest.
        let puffs: [(x: Double, y: Double, r: Double)] = [(8, 10, 6.5), (15, 15, 8.5), (23, 17, 9.5), (31, 15, 8.5), (38, 10, 6.5), (23, 9, 8), (14, 7, 5.5), (32, 7, 5.5)]
        for puff in puffs {
            let cx = (puff.x + 4 + random.next(in: -1.6...1.6)) * kd, cy = (puff.y + 6 + random.next(in: -1.2...1.2)) * kd
            let r = (puff.r + random.next(in: -0.8...0.8)) * kd
            for y in 0..<h { for x in 0..<w where cloud[y][x] == false {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                if dx * dx + dy * dy <= r * r { cloud[y][x] = true }
            } }
        }
        let light: UInt32 = 0xF3EEE6, shade: UInt32 = 0xD8CEC1, line: UInt32 = 0x3A3330
        var pixels = [UInt32](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w where cloud[y][x] {
            let edge = [(0, 1), (0, -1), (1, 0), (-1, 0)].contains { dx, dy in
                let nx = x + dx, ny = y + dy
                return nx < 0 || ny < 0 || nx >= w || ny >= h || !cloud[ny][nx]
            }
            // Rows count from the top; the lower third is in shadow.
            pixels[y * w + x] = edge ? line : (y >= h * 2 / 3 ? shade : light)
        } }
        // A few swirls inside.
        for _ in 0..<3 {
            let x = Int(random.next(in: 14...38)) * k, y = Int(random.next(in: 15...26)) * k
            for i in 0..<3 * k where cloud[y][x + i] { pixels[y * w + x + i] = shade }
        }
        func set(_ x: Int, _ y: Int, _ color: UInt32, overCloud: Bool = true) {
            guard x >= 0, y >= 0, x < w, y < h, overCloud || !cloud[y][x] else { return }
            pixels[y * w + x] = color
        }
        // Legs flailing out of the top and the sides, one in each coat.
        for (i, coat) in [UInt32(0xF0A040), 0xA4A4B0].enumerated() {
            if random.next(in: 0...1) < 0.55 {
                let x = Int(random.next(in: 16...36)) * k
                guard let top = (0..<h).first(where: { cloud[$0][x] }) else { continue }
                for d in 1...3 * k {
                    set(x - 1, top - d, line)
                    for j in 0..<2 * k { set(x + j, top - d, coat) }
                    set(x + 2 * k, top - d, line)
                }
                for j in 0..<2 * k { set(x + j, top - 3 * k - 1, line) }
            } else {
                let y = Int(random.next(in: 14...25)) * k
                let right = i == 1
                guard let edge = right ? (0..<w).reversed().first(where: { cloud[y][$0] }) : (0..<w).first(where: { cloud[y][$0] }) else { continue }
                let step = right ? 1 : -1
                for d in 1...3 * k {
                    let x = edge + d * step
                    set(x, y - 1, line)
                    for j in 0..<2 * k { set(x, y + j, coat) }
                    set(x, y + 2 * k, line)
                }
                let tip = edge + (3 * k + 1) * step
                for j in 0..<2 * k { set(tip, y + j, line) }
            }
        }
        // Stars flying off, up and out.
        // HD: a finer star of the same reach, a lit centre and darker tips.
        let star: [(Int, Int)] = k == 1 ? [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
            : (-3...3).flatMap { d in [(d, 0), (0, d)] }.filter { $0 != (0, 0) } + [(0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)]
        for i in 0..<3 {
            let side = i % 2 == 0 ? -1.0 : 1.0
            let x = Int(27 + side * random.next(in: 18...24)) * k, y = Int(random.next(in: 2...12)) * k
            let color: UInt32 = i == 2 ? 0xFFFFFF : 0xFFD23F
            for (dx, dy) in star {
                let lit: UInt32 = k == 1 ? color : (dx, dy) == (0, 0) ? 0xFFFFFF : abs(dx) + abs(dy) == 3 ? 0xE0A92A : color
                set(x + dx, y + dy, lit, overCloud: false)
            }
        }
        // A paw poking out of the top now and then.
        if seed % 3 == 1 {
            let x = Int(random.next(in: 18...34)) * k
            if let top = (0..<h).first(where: { cloud[$0][x] }), k == 1 {
                for (dx, dy) in [(0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (0, 3), (2, 3)] {
                    set(x + dx, top - dy, dy == 3 ? line : 0xFFFFFF)
                }
            } else if let top = (0..<h).first(where: { cloud[$0][x] }) {
                // A 6 x 4 pad with its toes, then two toe tips.
                for (dy, row) in ["o.oo.o", "owowwo", "owwwwo", "owwwwo"].enumerated() {
                    for (dx, char) in row.enumerated() where char != "." { set(x + dx, top - 4 + dy, char == "o" ? line : 0xFFFFFF) }
                }
                set(x + 1, top - 5, line); set(x + 4, top - 5, line)
            }
        }
        // To RGBA, top row first, as a CGImage keeps them.
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let color = pixels[y * w + x]
            guard color != 0 else { continue }
            let i = (y * w + x) * 4
            bytes[i] = UInt8(color >> 16 & 0xFF); bytes[i + 1] = UInt8(color >> 8 & 0xFF); bytes[i + 2] = UInt8(color & 0xFF); bytes[i + 3] = 255
        } }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

/// The same jostle every time, so the frames are made once.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed | 1 }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return range.lowerBound + Double(state % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
    }
}
