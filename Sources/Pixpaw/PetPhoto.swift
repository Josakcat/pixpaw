//
//  PetPhoto.swift
//  Pixpaw
//
//  A portrait of the pet to keep or share: the pet as it is right now (coat,
//  hat, collar, headphones), big and crisp, on a little stage with a caption.
//  Drawn here, saved where you choose; nothing is sent anywhere.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum PetPhoto {
    /// The finished picture as PNG data.
    static func render(_ cat: CatController, days: Int) -> Data? {
        let width = 960, height = 720
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        defer { NSGraphicsContext.restoreGraphicsState() }
        let context = graphics.cgContext
        let floorY: CGFloat = 170

        // Sky fading into a warm wall, a floor, and a few pixel sparkles.
        let sky = NSGradient(starting: NSColor(rgb: 0xBFE3FF), ending: NSColor(rgb: 0xFFF1D6))
        sky?.draw(in: NSRect(x: 0, y: floorY, width: CGFloat(width), height: CGFloat(height) - floorY), angle: -90)
        NSColor(rgb: 0xE8C9A0).setFill()
        NSRect(x: 0, y: 0, width: CGFloat(width), height: floorY).fill()
        NSColor(rgb: 0xD2AE80).setFill()
        NSRect(x: 0, y: floorY - 8, width: CGFloat(width), height: 8).fill()
        NSColor.white.withAlphaComponent(0.85).setFill()
        for (x, y) in [(120, 600), (210, 520), (790, 610), (860, 500), (700, 660), (300, 650)] {
            NSRect(x: x, y: y, width: 10, height: 10).fill()
            NSRect(x: x - 10, y: y, width: 30, height: 10).fill()
            NSRect(x: x, y: y - 10, width: 10, height: 30).fill()
        }

        // The pet, sitting, twenty times its pixel size, feet on the floor.
        if let sprite = CatSprites.shared.image(.sit, coat: cat.coat, hat: cat.hat, collar: cat.collar,
                                                headphones: cat.wearsHeadphones, costume: cat.costume, kind: cat.kind) {
            let scale: CGFloat = 20
            let size = CGSize(width: CGFloat(sprite.width) * scale, height: CGFloat(sprite.height) * scale)
            context.interpolationQuality = .none
            context.draw(sprite, in: CGRect(x: (CGFloat(width) - size.width) / 2, y: floorY - 6, width: size.width, height: size.height))
        }

        // The caption on the floor, and a small mark in the corner.
        let caption = "\(cat.kind.title) · \(days) \(days == 1 ? "day" : "days") together"
        draw(caption, size: 40, weight: .bold, color: NSColor(rgb: 0x4A3420), centredAt: CGPoint(x: CGFloat(width) / 2, y: 70))
        draw("Pixpaw", size: 22, weight: .semibold, color: NSColor(rgb: 0x4A3420).withAlphaComponent(0.55),
             centredAt: CGPoint(x: CGFloat(width) - 70, y: 28))
        graphics.flushGraphics()
        return rep.representation(using: .png, properties: [:])
    }

    /// Asks where to keep it (the Desktop to begin with) and writes it there.
    static func save(_ data: Data, named name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [.png]
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        NSApp.activate()
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private static func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centredAt point: CGPoint) {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let bounds = string.size()
        string.draw(at: CGPoint(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2))
    }
}
