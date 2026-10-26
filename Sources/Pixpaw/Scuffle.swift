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
    private static let frames: [CGImage] = (0..<6).compactMap { draw(seed: $0) }

    /// A cloud standing on the floor at `bottomCenter`.
    init(bottomCenter: CGPoint) {
        let scale = CatSprites.scale
        let size = CGSize(width: CGFloat(Self.width) * scale, height: CGFloat(Self.height) * scale)
        panel = CatPanel(contentRect: CGRect(origin: CGPoint(x: bottomCenter.x - size.width / 2, y: bottomCenter.y - 3 * scale), size: size))
        panel.ignoresMouseEvents = true
        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        layer.frame = view.bounds
        layer.magnificationFilter = .nearest
        layer.actions = ["contents": NSNull(), "transform": NSNull()]
        layer.contents = Self.frames.first
        view.layer?.addSublayer(layer)
        panel.contentView = view
    }

    func start() {
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.frame += 1
                self.layer.contents = Self.frames[self.frame % Self.frames.count]
                // A bit of a bounce as they roll about.
                self.layer.transform = CATransform3DMakeTranslation(CGFloat([0, 2, -1, 3, 0, -2][self.frame % 6]), CGFloat(self.frame % 2) * 3, 0)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
        panel.close()
    }

    /// One frame: puffs of dust jostling about, an outline, a shadow at
    /// the bottom, and stars, paws and bits flying off.
    private static func draw(seed: Int) -> CGImage? {
        var random = SeededRandom(seed: UInt64(seed + 1) * 2_654_435_761)
        let w = width, h = height
        var cloud = [[Bool]](repeating: [Bool](repeating: false, count: w), count: h)
        // Puffs along the cloud, the middle ones biggest.
        let puffs: [(x: Double, y: Double, r: Double)] = [(8, 10, 6.5), (15, 15, 8.5), (23, 17, 9.5), (31, 15, 8.5), (38, 10, 6.5), (23, 9, 8), (14, 7, 5.5), (32, 7, 5.5)]
        for puff in puffs {
            let cx = puff.x + 4 + random.next(in: -1.6...1.6), cy = puff.y + 6 + random.next(in: -1.2...1.2), r = puff.r + random.next(in: -0.8...0.8)
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
            let x = Int(random.next(in: 14...38)), y = Int(random.next(in: 15...26))
            for i in 0..<3 where cloud[y][x + i] { pixels[y * w + x + i] = shade }
        }
        func set(_ x: Int, _ y: Int, _ color: UInt32, overCloud: Bool = true) {
            guard x >= 0, y >= 0, x < w, y < h, overCloud || !cloud[y][x] else { return }
            pixels[y * w + x] = color
        }
        // Legs flailing out of the top and the sides, one in each coat.
        for (i, coat) in [UInt32(0xF0A040), 0xA4A4B0].enumerated() {
            if random.next(in: 0...1) < 0.55 {
                let x = Int(random.next(in: 16...36))
                guard let top = (0..<h).first(where: { cloud[$0][x] }) else { continue }
                for d in 1...3 {
                    set(x - 1, top - d, line); set(x, top - d, coat); set(x + 1, top - d, coat); set(x + 2, top - d, line)
                }
                set(x, top - 4, line); set(x + 1, top - 4, line)
            } else {
                let y = Int(random.next(in: 14...25))
                let right = i == 1
                guard let edge = right ? (0..<w).reversed().first(where: { cloud[y][$0] }) : (0..<w).first(where: { cloud[y][$0] }) else { continue }
                let step = right ? 1 : -1
                for d in 1...3 {
                    let x = edge + d * step
                    set(x, y - 1, line); set(x, y, coat); set(x, y + 1, coat); set(x, y + 2, line)
                }
                let tip = edge + 4 * step
                set(tip, y, line); set(tip, y + 1, line)
            }
        }
        // Stars flying off, up and out.
        let star: [(Int, Int)] = [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
        for i in 0..<3 {
            let side = i % 2 == 0 ? -1.0 : 1.0
            let x = Int(27 + side * random.next(in: 18...24)), y = Int(random.next(in: 2...12))
            for (dx, dy) in star { set(x + dx, y + dy, i == 2 ? 0xFFFFFF : 0xFFD23F, overCloud: false) }
        }
        // A paw poking out of the top now and then.
        if seed % 3 == 1 {
            let x = Int(random.next(in: 18...34))
            if let top = (0..<h).first(where: { cloud[$0][x] }) {
                for (dx, dy) in [(0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (0, 3), (2, 3)] {
                    set(x + dx, top - dy, dy == 3 ? line : 0xFFFFFF)
                }
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
