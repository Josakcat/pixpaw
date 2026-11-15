// Checks drops on the shelf widget: which files are pictures, the size
// limits, and the framed picture's art, on their own, no Droppy needed:
//   cp .droppykit/Tools/widget-drop-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/DropOnWidget.swift /tmp/main.swift -o /tmp/widget-drop-check && /tmp/widget-drop-check

import AppKit
import Foundation

/// Stand-in for the sprite cache the real FramedPicture clears.
@MainActor final class CatSprites {
    static let shared = CatSprites()
    var cleared = 0
    func forgetDecor() { cleared += 1 }
}

func problem(_ result: Result<Void, WidgetDrop.Problem>) -> WidgetDrop.Problem? {
    if case .failure(let p) = result { return p }
    return nil
}

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Size rules.
check((try? WidgetDrop.check(bytes: 1000, width: 64, height: 64).get()) != nil, "a small PNG is fine")
check(problem(WidgetDrop.check(bytes: WidgetDrop.maxBytes + 1, width: 64, height: 64)) == .tooBig, "over 20 MB is too big")
check(problem(WidgetDrop.check(bytes: 10, width: WidgetDrop.maxSide + 1, height: 10)) == .tooBig, "too many pixels a side is too big")
check(problem(WidgetDrop.check(bytes: 10, width: 0, height: 10)) == .unreadable, "no size is unreadable")

// Real files: a PNG, a PNG named .txt, a text file named .png, a folder.
let dir = FileManager.default.temporaryDirectory.appendingPathComponent("widget-drop-check-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: dir) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 30, pixelsHigh: 20, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let bytes = rep.bitmapData!
for y in 0..<20 { for x in 0..<30 {
    let i = y * rep.bytesPerRow + x * 4
    (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]) = x < 15 ? (220, 40, 40, 255) : (60, 200, 60, 255)
} }
let png = rep.representation(using: .png, properties: [:])!
let picture = dir.appendingPathComponent("pic.png"), disguised = dir.appendingPathComponent("pic.txt")
let fake = dir.appendingPathComponent("notes.png")
try? png.write(to: picture)
try? png.write(to: disguised)
try? "hello".write(to: fake, atomically: true, encoding: .utf8)
let before = try? Data(contentsOf: picture)
check(WidgetDrop.classify(picture) == .success(.picture(picture)), "a PNG is a picture")
check(WidgetDrop.classify(disguised) == .success(.picture(disguised)), "a PNG with another name is still a picture")
check(WidgetDrop.classify(fake) == .success(.snack("notes")), "text named .png is a snack")
check(WidgetDrop.classify(dir) == .success(.snack(dir.lastPathComponent)), "a folder is a snack")

// Quantizing and framing.
let palette: [Character: UInt32] = ["o": 0x2a1e1a, "d": 0x2e2226, "r": 0xc94f45, "g": 0x6fb05a, "k": 0xa0693d, "w": 0xf3e3c4]
let choices = palette.sorted { $0.key < $1.key }
check(FramedPicture.nearest(250, 10, 10, in: choices) == "r", "red is nearest red")
let rgba: [UInt8] = [200, 70, 60, 255, 0, 0, 0, 0, 100, 170, 90, 255, 30, 34, 38, 255]
let rows = FramedPicture.quantized(rgba, width: 2, palette: palette)
check(rows == ["r.", "go"], "pixels to letters, see-through to dots, never the door's dark: \(rows)")

MainActor.assumeIsolated {
    let art = FramedPicture.read(picture, classic: palette, fine: palette, fineScale: 2)
    let classic = art?["classic"] ?? [], fine = art?["fine"] ?? []
    let inner = FramedPicture.inner
    check(classic.count == inner.height + 6 && classic.allSatisfy { $0.count == inner.width + 4 }, "classic art is \(inner.width + 4) x \(inner.height + 6)")
    check(fine.count == 2 * (inner.height + 6) && fine.allSatisfy { $0.count == 2 * (inner.width + 4) }, "HD art is twice that")
    check(classic.allSatisfy { $0.count <= 20 } && fine.allSatisfy { $0.count <= 40 }, "it fits a decoration slot")
    check(classic.joined().contains("r") && classic.joined().contains("g"), "the picture's colours are in it")
    check(classic.last?.contains("K") == true, "it stands on legs")
    check((try? Data(contentsOf: picture)) == before, "the file is untouched")
    FramedPicture.use(art)
    check(FramedPicture.stored == art && CatSprites.shared.cleared == 1, "kept as letters only, cache cleared")
    FramedPicture.use(["classic": []])
    check(FramedPicture.art == nil, "broken stored art is dropped")
}

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
