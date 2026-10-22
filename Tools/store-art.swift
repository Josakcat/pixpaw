// Draws the Store art from the real sprites: the creator avatar and the
// screenshots in Assets/.
//
//   cp Tools/store-art.swift /tmp/main.swift   (top-level code needs the name main.swift)
//   swiftc -O Sources/Pixpaw/CatSprites.generated.swift /tmp/main.swift -o /tmp/store-art
//   /tmp/store-art Assets
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "Assets"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// A canvas drawn top-down in points, saved as a PNG.
func canvas(_ width: Int, _ height: Int, _ name: String, _ draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let flipped = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    NSGraphicsContext.current = flipped
    let ctx = flipped.cgContext
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
    print("wrote \(out)/\(name)")
}

/// A frame of the cat, in a coat, wearing things, `px` points a pixel, with
/// its feet at `feet` (the bottom-left corner of the art).
func cat(_ ctx: CGContext, _ frame: String, coat: String = "orange", hat: String? = nil, collar: String? = nil,
         feet: CGPoint, px: CGFloat, flip: Bool = false) {
    guard let rows = CatArt.frames[frame], let palette = CatArt.coats[coat] else { return }
    let width = rows[0].count
    var grid: [(Int, Int, UInt32)] = []
    for (y, row) in rows.enumerated() {
        for (x, ch) in row.enumerated() { if let c = palette[ch] { grid.append((x, y, c)) } }
    }
    if let anchor = CatArt.anchors[frame] {
        for (item, centre, row) in [(hat, anchor.0, anchor.1), (collar, anchor.2, anchor.3)] {
            guard let item, row >= 0, let art = CatArt.accessories[item] else { continue }
            let left = Int((centre - Double(art[0].count) / 2).rounded())
            let isHat = item != "redCollar" && item != "bellCollar"
            let top = isHat ? row - art.count + 1 - (CatArt.accessoryLift[item] ?? 0) : row
            for (y, line) in art.enumerated() {
                for (x, ch) in line.enumerated() { if let c = CatArt.accessoryColors[ch] { grid.append((left + x, top + y, c)) } }
            }
        }
    }
    let h = CGFloat(rows.count)
    for (x, y, c) in grid {
        let col = flip ? CGFloat(width - 1 - x) : CGFloat(x)
        ctx.setFillColor(rgb(c).cgColor)
        ctx.fill(CGRect(x: feet.x + col * px, y: feet.y - (h - CGFloat(y)) * px, width: px, height: px))
    }
}

func sprite(_ ctx: CGContext, _ rows: [String], palette: [Character: UInt32], at origin: CGPoint, px: CGFloat) {
    for (y, row) in rows.enumerated() {
        for (x, ch) in row.enumerated() {
            guard let c = palette[ch] else { continue }
            ctx.setFillColor(rgb(c).cgColor)
            ctx.fill(CGRect(x: origin.x + CGFloat(x) * px, y: origin.y + CGFloat(y) * px, width: px, height: px))
        }
    }
}

/// The app's speech bubble: white, rounded, dark outline, tail pointing down
/// at `tip`.
func bubble(_ ctx: CGContext, _ text: String, symbol: String? = nil, tip: CGPoint, scale: CGFloat = 2) {
    let font = NSFont.systemFont(ofSize: 12.5 * scale, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: rgb(0x1A1A1A)]
    let textSize = (text as NSString).size(withAttributes: attrs)
    let icon = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 11 * scale, weight: .semibold)) }
    let iconWidth = icon.map { $0.size.width + 5 * scale } ?? 0
    let w = textSize.width + iconWidth + 20 * scale
    let h = textSize.height + 14 * scale
    let body = CGRect(x: tip.x - w / 2, y: tip.y - 7 * scale - h, width: w, height: h)
    let path = NSBezierPath(roundedRect: body, xRadius: 10 * scale, yRadius: 10 * scale)
    path.move(to: CGPoint(x: tip.x - 6 * scale, y: body.maxY - 1))
    path.line(to: tip)
    path.line(to: CGPoint(x: tip.x + 6 * scale, y: body.maxY - 1))
    rgb(0xFFFFFF).setFill(); path.fill()
    rgb(0x1F1F1F).setStroke(); path.lineWidth = 2 * scale; path.stroke()
    var x = body.minX + 10 * scale
    if let icon {
        icon.isTemplate = true
        let tinted = NSImage(size: icon.size, flipped: false) { rect in
            icon.draw(in: rect); rgb(0x1A1A1A).set(); rect.fill(using: .sourceAtop); return true
        }
        tinted.draw(in: CGRect(x: x, y: body.midY - icon.size.height / 2, width: icon.size.width, height: icon.size.height),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        x += iconWidth
    }
    (text as NSString).draw(at: CGPoint(x: x, y: body.minY + 7 * scale), withAttributes: attrs)
}

func label(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .bold, color: NSColor = .white, centered: Bool = false) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    let width = (text as NSString).size(withAttributes: attrs).width
    (text as NSString).draw(at: CGPoint(x: centered ? point.x - width / 2 : point.x, y: point.y), withAttributes: attrs)
}

/// A soft desktop: dusk gradient, a floor line where the Dock would be.
func desktop(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat, title: String, subtitle: String) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(0x2B2F7A).cgColor, rgb(0x6A4BB8).cgColor, rgb(0xE98D7A).cgColor] as CFArray,
                              locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
    label(title, at: CGPoint(x: 80, y: 70), size: 64)
    label(subtitle, at: CGPoint(x: 82, y: 150), size: 30, weight: .medium, color: rgb(0xFFFFFF, 0.85))
}

let W: CGFloat = 1600, H: CGFloat = 1000, floorY: CGFloat = 900, px: CGFloat = 9

// 1. The cat on the desktop, telling you an agent is done.
canvas(Int(W), Int(H), "Screenshot-1.png") { ctx in
    desktop(ctx, W, H, title: "Pixpaw", subtitle: "A pixel cat that lives on your desktop and talks to you.")
    cat(ctx, "sit", hat: "partyHat", collar: "redCollar", feet: CGPoint(x: 560, y: floorY), px: px)
    bubble(ctx, "Claude is done! 5h 76% · week 59% left", symbol: "checkmark.circle.fill", tip: CGPoint(x: 560 + 14.5 * px, y: floorY - 22 * px))
    cat(ctx, "walk2", coat: "gray", feet: CGPoint(x: 1050, y: floorY), px: px, flip: true)
    sprite(ctx, CatArt.effects["bowl"]!, palette: CatArt.effectColors, at: CGPoint(x: 330, y: floorY - 6 * px), px: px)
}

// 2. Playtime.
canvas(Int(W), Int(H), "Screenshot-2.png") { ctx in
    desktop(ctx, W, H, title: "Playtime", subtitle: "Hold the cat for its menu: a yarn ball, or a feather teaser.")
    cat(ctx, "run1", collar: "bellCollar", feet: CGPoint(x: 230, y: floorY), px: px)
    sprite(ctx, CatArt.effects["yarn1"]!, palette: CatArt.effectColors, at: CGPoint(x: 470, y: floorY - 9 * px - 60), px: px)
    cat(ctx, "crouch2", coat: "black", hat: "witchHat", feet: CGPoint(x: 950, y: floorY), px: px)
    sprite(ctx, CatArt.effects["teaser"]!, palette: CatArt.effectColors, at: CGPoint(x: 1240, y: floorY - 330), px: px)
    if let cursor = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 44, weight: .regular)) {
        cursor.draw(in: CGRect(x: 1262, y: floorY - 410, width: cursor.size.width, height: cursor.size.height),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    bubble(ctx, "Got it!", tip: CGPoint(x: 950 + 16.5 * px, y: floorY - 18 * px))
}

// 3. The wardrobe.
canvas(Int(W), Int(H), "Screenshot-3.png") { ctx in
    desktop(ctx, W, H, title: "A wardrobe to earn", subtitle: "Petting, meals, play and catches earn stars, up to 30 a day.")
    let items: [(String?, String?, String, Int, String)] = [
        (nil, "redCollar", "Red collar", 10, "orange"), ("partyHat", nil, "Party hat", 25, "white"),
        ("bow", nil, "Bow", 45, "calico"), (nil, "bellCollar", "Bell collar", 70, "gray"),
        ("witchHat", nil, "Witch hat", 100, "black"), ("santaHat", nil, "Santa hat", 150, "siamese"),
        ("crown", nil, "Crown", 220, "orange"),
    ]
    for (i, item) in items.enumerated() {
        let column = CGFloat(i % 4), row = CGFloat(i / 4)
        let x = 150 + column * 340, y = 520 + row * 360
        cat(ctx, "sit", coat: item.4, hat: item.0, collar: item.1, feet: CGPoint(x: x, y: y), px: 8)
        label(item.2, at: CGPoint(x: x + 80, y: y + 18), size: 28, weight: .semibold, centered: true)
        label("\(item.3) ★", at: CGPoint(x: x + 80, y: y + 56), size: 24, weight: .medium, color: rgb(0xFFE08A), centered: true)
    }
}

// 4. What it tells you.
canvas(Int(W), Int(H), "Screenshot-4.png") { ctx in
    desktop(ctx, W, H, title: "It keeps you posted", subtitle: "Songs, agents, meetings, headphones, battery, breaks. Quiet in calls.")
    let lines: [(String, String)] = [
        ("Let It Happen — Tame Impala", "music.note"), ("Team sync in 5 min", "calendar"),
        ("AirPods Pro connected", "airpodspro"), ("Codex needs you", "hand.raised.fill"),
        ("Battery at 20%. Plug me in?", "battery.25"), ("Time to stretch! Stand up for a minute.", "figure.cooldown"),
    ]
    for (i, line) in lines.enumerated() {
        let column = CGFloat(i % 2), row = CGFloat(i / 2)
        let feet = CGPoint(x: 280 + column * 720, y: 500 + row * 210)
        cat(ctx, i % 2 == 0 ? "sit" : "happy", coat: ["orange", "gray", "calico", "white", "black", "siamese"][i],
            feet: feet, px: 6)
        // Tail on the top of the head, as in the app.
        bubble(ctx, line.0, symbol: line.1, tip: CGPoint(x: feet.x + 14.5 * 6, y: feet.y - 12 * 6), scale: 1.6)
    }
}

/// Any character's frame, `px` points a pixel, feet at `feet`, with a laptop
/// in front of it if it is working.
func pet(_ ctx: CGContext, _ kind: String, _ frame: String, feet: CGPoint, px: CGFloat, laptop: Bool = false) {
    let key = kind == "cat" ? frame : "\(kind).\(frame)"
    guard let rows = CatArt.frames[key], let palette = CatArt.coats[kind == "cat" ? "orange" : kind] else { return }
    let h = CGFloat(rows.count)
    sprite(ctx, rows, palette: palette, at: CGPoint(x: feet.x, y: feet.y - h * px), px: px)
    if laptop, let computer = CatArt.accessories["laptop"], let anchor = CatArt.anchors[key] {
        let left = CGFloat((anchor.0 - Double(computer[0].count) / 2).rounded())
        sprite(ctx, computer, palette: CatArt.accessoryColors,
               at: CGPoint(x: feet.x + left * px, y: feet.y - CGFloat(computer.count) * px), px: px)
    }
}

/// A character's home with it asleep there, the way the app stacks them.
func home(_ ctx: CGContext, _ kind: String, at origin: CGPoint, px: CGFloat) {
    guard let rows = CatArt.homes[kind], let spot = CatArt.homeSpots[kind] else { return }
    let feet = CGPoint(x: origin.x + CGFloat(spot.0) * px, y: origin.y + CGFloat(rows.count - spot.1) * px)
    let open = rows.map { String($0.map { $0 == "d" ? "." : $0 }) }
    if spot.2 {
        pet(ctx, kind, "sleep1", feet: feet, px: px)
        sprite(ctx, open, palette: CatArt.homeColors, at: origin, px: px)
    } else {
        sprite(ctx, rows, palette: CatArt.homeColors, at: origin, px: px)
        pet(ctx, kind, "sleep1", feet: feet, px: px)
    }
}

// 5. Every character, the four new ones last.
canvas(Int(W), Int(H), "Screenshot-5.png") { ctx in
    desktop(ctx, W, H, title: "Eleven friends", subtitle: "New: a giraffe, a hippo, a rabbit, and a shark that swims through the air.")
    let kinds: [(String, String, String)] = [
        ("cat", "sit", "Cat"), ("dog", "sit", "Dog"), ("hamster", "sit", "Hamster"), ("chicken", "sit", "Chicken"),
        ("bee", "walk1", "Bee"), ("parrot", "sit", "Parrot"), ("dino", "sit", "Dinosaur"),
        ("giraffe", "sit", "Giraffe ✦"), ("hippo", "happy", "Hippo ✦"), ("rabbit", "sit", "Rabbit ✦"), ("shark", "walk1", "Shark ✦"),
    ]
    for (i, item) in kinds.enumerated() {
        let row = i < 4 ? 0 : i < 7 ? 1 : 2
        let inRow = row == 0 ? i : row == 1 ? i - 4 : i - 7
        let count = row == 1 ? 3 : 4
        let x = W / 2 - CGFloat(count) * 170 + CGFloat(inRow) * 340 + 90
        let y = 370 + CGFloat(row) * 215
        pet(ctx, item.0, item.1, feet: CGPoint(x: x, y: y), px: 7)
        label(item.2, at: CGPoint(x: x + 70, y: y + 10), size: 26, weight: .semibold,
              color: item.2.hasSuffix("✦") ? rgb(0xFFE08A) : .white, centered: true)
    }
}

// 6. Homes at 500 stars, after where each animal really lives.
canvas(Int(W), Int(H), "Screenshot-6.png") { ctx in
    desktop(ctx, W, H, title: "A home of its own", subtitle: "Reach 500 stars and it naps in a home after where it really lives.")
    let homes: [(String, String)] = [("cat", "A box"), ("bee", "A beehive"), ("parrot", "A tree"), ("hippo", "A pond"),
                                     ("dog", "A kennel"), ("rabbit", "A hutch"), ("hamster", "A cage"), ("shark", "A reef")]
    for (i, item) in homes.enumerated() {
        let column = CGFloat(i % 4), row = CGFloat(i / 4)
        let origin = CGPoint(x: 120 + column * 360, y: 250 + row * 330)
        home(ctx, item.0, at: origin, px: 8)
        label(item.1, at: CGPoint(x: origin.x + 17 * 8, y: origin.y + 26 * 8 + 12), size: 26, weight: .semibold, centered: true)
    }
}

// 7. Focusing and stretching together.
canvas(Int(W), Int(H), "Screenshot-7.png") { ctx in
    desktop(ctx, W, H, title: "Working together", subtitle: "It works at its own laptop while you focus, and stretches with you.")
    let big: CGFloat = 16
    let focus = CGPoint(x: 170, y: 880)
    pet(ctx, "cat", "sit", feet: focus, px: big, laptop: true)
    sprite(ctx, CatArt.effects["code"]!, palette: CatArt.effectColors, at: CGPoint(x: focus.x + 12 * big, y: focus.y - 19 * big), px: big * 0.67)
    bubble(ctx, "Focus time · 24:59", symbol: "timer", tip: CGPoint(x: focus.x + 14.5 * big, y: focus.y - 20 * big), scale: 2.4)
    let stretch = CGPoint(x: 940, y: 880)
    pet(ctx, "dog", "crouch1", feet: stretch, px: big)
    bubble(ctx, "Stretch with me! 0:20", symbol: "figure.cooldown", tip: CGPoint(x: stretch.x + 14.5 * big, y: stretch.y - 13.5 * big), scale: 2.4)
}

// 8. Break reminders: each on its own timer, and your own.
canvas(Int(W), Int(H), "Screenshot-8.png") { ctx in
    desktop(ctx, W, H, title: "Healthy breaks", subtitle: "Water, eye rest and stretching, each on its own timer, plus reminders of your own.")
    let reminders: [(String, String, String, String, String)] = [
        ("cat", "happy", "Drink some water.", "drop.fill", "Drink water · every 45 min"),
        ("rabbit", "sit", "Rest your eyes: look far away for 20 seconds.", "eye", "Rest your eyes · every 30 min"),
        ("dog", "crouch1", "Stretch with me! 0:20", "figure.cooldown", "Stand up & stretch · every hour"),
        ("hamster", "happy", "Take a pill", "bell.fill", "Your own · every 2 hours"),
    ]
    for (i, item) in reminders.enumerated() {
        let column = CGFloat(i % 2), row = CGFloat(i / 2)
        let feet = CGPoint(x: 230 + column * 720, y: 560 + row * 300)
        pet(ctx, item.0, item.1, feet: feet, px: 8)
        // Over the rabbit's ears, not into them.
        let above: CGFloat = item.0 == "rabbit" ? 17.5 : 14
        bubble(ctx, item.2, symbol: item.3, tip: CGPoint(x: feet.x + 14.5 * 8, y: feet.y - above * 8), scale: 1.7)
        label(item.4, at: CGPoint(x: feet.x + 190, y: feet.y - 70), size: 26, weight: .semibold, color: rgb(0xFFE08A))
    }
}

// 9. Your own pets: drawn in a pixel editor, brought in, with sounds of its own.
// The frog is an example drawn here, not one of Pixpaw's characters.
let frog = [
    "....................",
    "....................",
    "...........ooo.ooo..",
    "..........oWWWoWWWo.",
    "..........oWeWoWeWo.",
    ".........oggggggggo.",
    "........oggggggggggo",
    "........ogpggggggpgo",
    "........ogggoooooggo",
    ".......ogggwwwwwwggo",
    "......oggdgwwwwwwgo.",
    ".....oggdggwwwwwwgo.",
    "....ogggdggwwwwwgo..",
    "...oggggggggwwwggo..",
    "...ogoggogggoooggo..",
    "...oo.ooooooo.ooo...",
]
let frogColours: [Character: UInt32] = ["o": 0x1D3B1F, "g": 0x6CC04A, "d": 0x4A9A33, "w": 0xE8F5C8,
                                        "W": 0xFFFFFF, "e": 0x111111, "p": 0xF59AA8]
/// The pose a row lower, the way Pixpaw makes a sleeping frame from a sitting one.
func sunk(_ rows: [String]) -> [String] {
    var rows = rows
    rows.remove(at: 9)
    return [String(repeating: ".", count: 20)] + rows
}

canvas(Int(W), Int(H), "Screenshot-9.png") { ctx in
    desktop(ctx, W, H, title: "Draw your own", subtitle: "Bring in a pet from any pixel editor and give it sounds of its own.")
    // The editor: one 20 x 20 cell, the frog at its bottom.
    let cellPx: CGFloat = 24, editor = CGRect(x: 90, y: 240, width: 20 * cellPx + 60, height: 20 * cellPx + 110)
    ctx.setFillColor(rgb(0x1E1E24, 0.92).cgColor)
    ctx.addPath(CGPath(roundedRect: editor, cornerWidth: 22, cornerHeight: 22, transform: nil)); ctx.fillPath()
    label("frog.png · 20 × 20", at: CGPoint(x: editor.minX + 30, y: editor.minY + 22), size: 24, weight: .semibold, color: rgb(0xFFFFFF, 0.8))
    let grid = CGPoint(x: editor.minX + 30, y: editor.minY + 75)
    for y in 0..<20 { for x in 0..<20 {
        ctx.setFillColor(rgb((x + y) % 2 == 0 ? 0x3A3A44 : 0x33333C).cgColor)
        ctx.fill(CGRect(x: grid.x + CGFloat(x) * cellPx, y: grid.y + CGFloat(y) * cellPx, width: cellPx, height: cellPx))
    } }
    sprite(ctx, frog, palette: frogColours, at: CGPoint(x: grid.x, y: grid.y + 4 * cellPx), px: cellPx)
    label("One pose is enough", at: CGPoint(x: editor.midX, y: editor.maxY + 18), size: 26, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    label("→", at: CGPoint(x: 690, y: 470), size: 90, weight: .bold, color: rgb(0xFFFFFF, 0.9))

    // The poses Pixpaw makes from it.
    let small: CGFloat = 6
    for (i, item) in [("Sits", frog, CGFloat(0)), ("Hops", frog, CGFloat(-2)), ("Sleeps", sunk(sunk(frog)), CGFloat(0))].enumerated() {
        let x = 850 + CGFloat(i) * 220
        sprite(ctx, item.1, palette: frogColours, at: CGPoint(x: x, y: 260 + item.2 * small), px: small)
        label(item.0, at: CGPoint(x: x + 10 * small, y: 260 + 16 * small + 14), size: 24, weight: .semibold, centered: true)
    }

    // Out on the desktop, in a voice of its own.
    let big: CGFloat = 14, feet = CGPoint(x: 840, y: 880)
    sprite(ctx, frog, palette: frogColours, at: CGPoint(x: feet.x, y: feet.y - 16 * big), px: big)
    bubble(ctx, "Ribbit!", symbol: "speaker.wave.2.fill", tip: CGPoint(x: feet.x + 14.5 * big, y: feet.y - 14.5 * big), scale: 2.4)
    label("Sounds of its own", at: CGPoint(x: feet.x + 330, y: feet.y - 150), size: 26, weight: .semibold, color: rgb(0xFFE08A))
    label("Acts like any character", at: CGPoint(x: feet.x + 330, y: feet.y - 105), size: 26, weight: .semibold, color: rgb(0xFFE08A))
}

// The creator avatar: the cat's face, big, on Droppy blue. Square, unrounded.
canvas(512, 512, "Creator.png") { ctx in
    ctx.setFillColor(rgb(0x4446F4).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
    let rows = Array(CatArt.frames["sit"]![3...10]).map { String(Array($0)[9...18]) }
    let face = 40.0
    sprite(ctx, rows, palette: CatArt.coats["orange"]!,
           at: CGPoint(x: (512 - CGFloat(rows[0].count) * face) / 2, y: (512 - CGFloat(rows.count) * face) / 2 + 10), px: face)
}
