//
//  PetGIF.swift
//  Pixpaw
//
//  Five seconds of the pet as it is, whatever it's doing (walking, napping,
//  dancing, coding along), as a looping GIF to share: big crisp pixels on a
//  little stage, saved where your screenshots go. Drawn from its own art, so
//  it needs no Screen Recording; nothing is sent anywhere.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class PetGIF {
    static let seconds = 5.0
    private static let delay = 0.1
    /// The stage, in the pet's window points: room for a hat and a Zzz.
    private static let stage = CGSize(width: 120, height: 100)
    private static let floor: CGFloat = 16
    /// Pixels to a point: each of the art's pixels comes out 12 across.
    private static let zoom: CGFloat = 4

    private weak var cat: CatController?
    private var timer: Timer?
    private var frames: [CGImage] = []
    private let backdrop: CGImage?
    private let done: (URL?) -> Void

    /// Starts recording `cat` at once; `done` gets the saved file, or nil.
    init(_ cat: CatController, done: @escaping (URL?) -> Void) {
        self.cat = cat
        self.done = done
        backdrop = Self.drawBackdrop()
        timer = Timer.scheduledTimer(withTimeInterval: Self.delay, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.shoot() }
        }
        shoot()
    }

    /// Stops without saving anything.
    func cancel() {
        timer?.invalidate()
        timer = nil
        frames = []
    }

    private func shoot() {
        guard let cat, let look = cat.look else { return finish() }
        if let frame = drawFrame(look) { frames.append(frame) }
        if Double(frames.count) * Self.delay >= Self.seconds { finish() }
    }

    private func finish() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        let url = frames.count >= 5 ? Self.save(frames, kind: cat?.kind.title ?? "Pet") : nil
        frames = []
        done(url)
    }

    // MARK: Drawing

    private static func context() -> CGContext? {
        let context = CGContext(data: nil, width: Int(stage.width * zoom), height: Int(stage.height * zoom),
                                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.scaleBy(x: zoom, y: zoom)
        context?.interpolationQuality = .none
        return context
    }

    /// A warm wall, a wooden floor with an edge, and the mark in the corner.
    private static func drawBackdrop() -> CGImage? {
        guard let context = context() else { return nil }
        context.setFillColor(NSColor(rgb: 0xFFF1D6).cgColor)
        context.fill(CGRect(origin: .zero, size: stage))
        context.setFillColor(NSColor(rgb: 0xE8C9A0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: stage.width, height: floor))
        context.setFillColor(NSColor(rgb: 0xD2AE80).cgColor)
        context.fill(CGRect(x: 0, y: floor - 2, width: stage.width, height: 2))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let base = NSFont.systemFont(ofSize: 6, weight: .bold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 6) } ?? base
        let mark = NSAttributedString(string: "Pixpaw", attributes: [.font: font, .foregroundColor: NSColor(rgb: 0x8A6A48)])
        mark.draw(at: CGPoint(x: stage.width - mark.size().width - 4, y: 3.5))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    private func drawFrame(_ look: (sprite: CGImage, right: Bool, bob: CGFloat, effect: (image: CGImage, frame: CGRect)?)) -> CGImage? {
        guard let context = Self.context() else { return nil }
        if let backdrop { context.draw(backdrop, in: CGRect(origin: .zero, size: Self.stage)) }
        let window = CatSprites.catSize
        let origin = CGPoint(x: ((Self.stage.width - window.width) / 2).rounded(), y: Self.floor - 1)
        let size = CGSize(width: CGFloat(look.sprite.width) * CatSprites.scale, height: CGFloat(look.sprite.height) * CatSprites.scale)
        context.saveGState()
        // Feet on the floor, turned the way it faces, as on screen.
        context.translateBy(x: origin.x + window.width / 2, y: origin.y + look.bob)
        if !look.right { context.scaleBy(x: -1, y: 1) }
        context.draw(look.sprite, in: CGRect(x: -size.width / 2, y: 0, width: size.width, height: size.height))
        context.restoreGState()
        if let effect = look.effect {
            context.draw(effect.image, in: effect.frame.offsetBy(dx: origin.x, dy: origin.y))
        }
        return context.makeImage()
    }

    // MARK: Saving

    private static func save(_ frames: [CGImage], kind: String) -> URL? {
        let format = DateFormatter()
        format.calendar = Calendar(identifier: .gregorian)
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = PageCapture.folder.appendingPathComponent("\(kind) by Pixpaw \(format.string(from: Date())).gif")
        guard let file = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return nil }
        CGImageDestinationSetProperties(file, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let each = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary
        frames.forEach { CGImageDestinationAddImage(file, $0, each) }
        return CGImageDestinationFinalize(file) ? url : nil
    }
}
