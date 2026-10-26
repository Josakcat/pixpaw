//
//  Fetch.swift
//  Pixpaw
//
//  A tennis ball (or a frisbee, a bone) for a game of fetch: thrown along the floor, carried back in
//  the pet's mouth, and dropped for you to click and throw again.
//

import AppKit

@MainActor
final class FetchBall {
    private static let rows = [
        "..ooo..",
        ".oyyyo.",
        "oWyyyyo",
        "oyWWyyo",
        "oyyyWWo",
        ".oyyyo.",
        "..ooo..",
    ]
    private static let ball: CGImage? = {
        let palette: [Character: UInt32] = ["o": 0x2E3A12, "y": 0xD4E84A, "W": 0xFFFFFF]
        let w = rows[0].count, h = rows.count
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for (y, row) in rows.enumerated() {
            for (x, key) in row.enumerated() {
                guard let color = palette[key] else { continue }
                let i = (y * w + x) * 4
                bytes[i] = UInt8(color >> 16 & 0xFF); bytes[i + 1] = UInt8(color >> 8 & 0xFF); bytes[i + 2] = UInt8(color & 0xFF); bytes[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()

    let size: CGSize
    private let panel: CatPanel
    private let view: BallView
    private var flight: Timer?
    private(set) var position: CGPoint = .zero

    /// `image`: what is thrown, the tennis ball when nil; `onClick`: it is
    /// clicked while it waits on the floor.
    init(image: CGImage? = nil, onClick: @escaping @MainActor () -> Void) {
        let image = image ?? Self.ball
        size = CGSize(width: CGFloat(image?.width ?? 7) * CatSprites.scale, height: CGFloat(image?.height ?? 7) * CatSprites.scale)
        panel = CatPanel(contentRect: CGRect(origin: .zero, size: size))
        view = BallView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.contents = image
        view.layer?.magnificationFilter = .nearest
        view.onClick = onClick
        panel.contentView = view
        panel.ignoresMouseEvents = true
    }

    /// Clickable while it lies on the floor waiting to be thrown again.
    var waits = false {
        didSet {
            panel.ignoresMouseEvents = !waits
            view.toolTip = waits ? "Throw it again" : nil
        }
    }

    func place(_ point: CGPoint) {
        position = point
        panel.setFrameOrigin(point)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    /// Up in an arc from `start` to `end` (bottom-left corners), a couple of
    /// little bounces, then `landed`.
    func fly(from start: CGPoint, to end: CGPoint, landed: @escaping @MainActor () -> Void) {
        flight?.invalidate()
        place(start)
        let began = CACurrentMediaTime()
        let time = 0.8, height = max(90, abs(end.x - start.x) * 0.35)
        flight = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.flight != nil else { return }
                let elapsed = CACurrentMediaTime() - began
                let t = min(1, elapsed / time)
                var point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t + height * 4 * t * (1 - t))
                // Two small bounces after it lands, rolling on a little.
                let after = elapsed - time
                if after > 0 {
                    let bounce = after < 0.25 ? 18 * sin(.pi * after / 0.25) : after < 0.4 ? 6 * sin(.pi * (after - 0.25) / 0.15) : 0
                    point = CGPoint(x: end.x + (end.x - start.x).sign(1) * min(after, 0.4) * 40, y: end.y + bounce)
                }
                self.place(point)
                if after >= 0.4 {
                    self.flight?.invalidate()
                    self.flight = nil
                    landed()
                }
            }
        }
    }

    func remove() {
        flight?.invalidate()
        flight = nil
        panel.orderOut(nil)
        panel.close()
    }
}

private extension CGFloat {
    func sign(_ unit: CGFloat) -> CGFloat { self < 0 ? -unit : unit }
}

/// Takes the click that throws it again, without making Droppy active.
final class BallView: NSView {
    var onClick: (@MainActor () -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { MainActor.assumeIsolated { onClick?() } }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}
