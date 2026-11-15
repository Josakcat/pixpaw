//
//  DropOnWidget.swift
//  Pixpaw
//
//  Files dropped on the shelf widget (Droppy's drop zone,
//  `.droppyWidgetDropTarget`, DroppyKit 1.23). A PNG offers to become a coat
//  or a framed picture beside the home; anything else is a snack worth a
//  star. The file itself is only read, never moved, changed or kept: a
//  picture is shrunk to a few pixels in the home's own colours, and only
//  those letters are saved, so no metadata or photo stays behind.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What a dropped file can turn into.
enum WidgetDrop: Equatable {
    /// A PNG small enough to read: the widget asks what to make of it.
    case picture(URL)
    /// Anything else (a folder too): eaten for a star, the file left alone.
    case snack(String)

    /// The biggest PNG it opens, in bytes and in pixels a side.
    static let maxBytes = 20 * 1024 * 1024
    static let maxSide = 8192

    enum Problem: Error, Equatable {
        case tooBig, unreadable

        var message: String {
            switch self {
            case .tooBig: "That picture is too big for me. Try one under 20 MB."
            case .unreadable: "I couldn't open that picture."
            }
        }
    }

    /// Sorts a file by its contents' type, not its name, and checks a PNG's
    /// size from its header without decoding it. Reads the disk: call it off
    /// the main actor.
    nonisolated static func classify(_ url: URL) -> Result<WidgetDrop, Problem> {
        let name = url.deletingPathExtension().lastPathComponent
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?,
              UTType(type)?.conforms(to: .png) == true else { return .success(.snack(name)) }
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        return check(bytes: bytes, width: width, height: height).map { _ in .picture(url) }
    }

    /// The size rules on their own (the self-check runs them).
    nonisolated static func check(bytes: Int, width: Int, height: Int) -> Result<Void, Problem> {
        guard width > 0, height > 0 else { return .failure(.unreadable) }
        guard bytes <= maxBytes, width <= maxSide, height <= maxSide else { return .failure(.tooBig) }
        return .success(())
    }
}

/// A dropped picture, framed, as decoration art: letters of the home's
/// palette, the way every other decoration is drawn.
@MainActor
enum FramedPicture {
    /// The picture inside the frame, in classic art pixels (HD doubles it).
    nonisolated static let inner = (width: 10, height: 8)

    /// The art in use, classic and HD, or nil before you've hung one.
    private(set) static var art: (classic: [String], fine: [String])?

    static func use(_ stored: [String: [String]]?) {
        defer { CatSprites.shared.forgetDecor() }
        guard let classic = stored?["classic"], let fine = stored?["fine"], !classic.isEmpty, !fine.isEmpty else {
            art = nil
            return
        }
        art = (classic, fine)
    }

    static var stored: [String: [String]]? {
        art.map { ["classic": $0.classic, "fine": $0.fine] }
    }

    /// Reads a PNG into framed art for both pixel sizes. Decodes only a
    /// small thumbnail (never the full image) and keeps nothing else of it.
    /// Slow-ish: call it off the main actor.
    nonisolated static func read(_ url: URL, classic: [Character: UInt32], fine: [Character: UInt32], fineScale: Int) -> [String: [String]]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 256,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        let small = pixels(thumb, width: inner.width, height: inner.height)
        let big = pixels(thumb, width: inner.width * fineScale, height: inner.height * fineScale)
        guard let small, let big else { return nil }
        return [
            "classic": framed(quantized(small, width: inner.width, palette: classic), edge: 1),
            "fine": framed(quantized(big, width: inner.width * fineScale, palette: fine), edge: fineScale),
        ]
    }

    /// The thumbnail drawn into `width` x `height`, filling it (cropped to
    /// the middle), as RGBA rows top down.
    nonisolated private static func pixels(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = rgba.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            let scale = max(CGFloat(width) / CGFloat(image.width), CGFloat(height) / CGFloat(image.height))
            let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
            context.draw(image, in: CGRect(x: (CGFloat(width) - w) / 2, y: (CGFloat(height) - h) / 2, width: w, height: h))
            return true
        }
        return drawn ? rgba : nil
    }

    /// Each pixel as the nearest palette letter; see-through ones as ".".
    /// The door's own dark ("d") is left out so nothing reads as a doorway.
    nonisolated static func quantized(_ rgba: [UInt8], width: Int, palette: [Character: UInt32]) -> [String] {
        let choices = palette.filter { $0.key != "d" }.sorted { $0.key < $1.key }
        guard width > 0, !choices.isEmpty else { return [] }
        let height = rgba.count / 4 / width
        return (0..<height).map { y in
            String((0..<width).map { x -> Character in
                let i = (y * width + x) * 4
                let alpha = Int(rgba[i + 3])
                guard alpha >= 128 else { return "." }
                // Premultiplied: back to the colour itself.
                let r = Int(rgba[i]) * 255 / alpha, g = Int(rgba[i + 1]) * 255 / alpha, b = Int(rgba[i + 2]) * 255 / alpha
                return nearest(r, g, b, in: choices)
            })
        }
    }

    nonisolated static func nearest(_ r: Int, _ g: Int, _ b: Int, in choices: [(key: Character, value: UInt32)]) -> Character {
        var best: Character = choices[0].key, bestDistance = Int.max
        for (letter, rgb) in choices {
            let dr = r - Int(rgb >> 16 & 0xFF), dg = g - Int(rgb >> 8 & 0xFF), db = b - Int(rgb & 0xFF)
            // Weighted like the eye: green counts most, blue least.
            let distance = 3 * dr * dr + 4 * dg * dg + 2 * db * db
            if distance < bestDistance { best = letter; bestDistance = distance }
        }
        return best
    }

    /// The picture in a wooden frame ("o" outline, "k" wood) on two little
    /// legs, `edge` pixels a line (1 classic, 2 HD); the bottom row on the floor.
    nonisolated static func framed(_ inner: [String], edge: Int) -> [String] {
        guard let first = inner.first, edge > 0 else { return [] }
        let width = first.count + 4 * edge
        let outline = String(repeating: "o", count: width)
        let wood = String(repeating: "o", count: edge) + String(repeating: "k", count: width - 2 * edge) + String(repeating: "o", count: edge)
        let o = String(repeating: "o", count: edge), k = String(repeating: "k", count: edge)
        var rows: [String] = []
        rows += Array(repeating: outline, count: edge)
        rows += Array(repeating: wood, count: edge)
        // See-through bits of the picture show the frame's backing.
        rows += inner.map { o + k + $0.replacingOccurrences(of: ".", with: "w") + k + o }
        rows += Array(repeating: wood, count: edge)
        rows += Array(repeating: outline, count: edge)
        // Two legs under the frame, a third of the way in from each side.
        let gap = String(repeating: ".", count: width / 3 - edge)
        let middle = String(repeating: ".", count: width - 2 * (width / 3) - 2 * edge)
        let legs = gap + String(repeating: "K", count: edge) + middle + String(repeating: "K", count: edge) + gap
        let padded = legs + String(repeating: ".", count: max(0, width - legs.count))
        rows += Array(repeating: String(padded.prefix(width)), count: 2 * edge)
        return rows
    }
}
