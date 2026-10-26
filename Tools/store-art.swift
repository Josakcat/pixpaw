// Draws the Store art from the real sprites: the creator avatar and the
// screenshots in Assets/.
//
//   cp Tools/store-art.swift /tmp/main.swift   (top-level code needs the name main.swift)
//   swiftc -O Sources/Pixpaw/CatSprites.generated.swift /tmp/main.swift -o /tmp/store-art
//   /tmp/store-art Assets
import AppKit
import UniformTypeIdentifiers

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

/// A character drawn turned a quarter, feet to a wall: `side` 1 for the
/// right wall, -1 for the left, `top` its top-left corner once turned.
func climbing(_ ctx: CGContext, _ kind: String, _ frame: String, side: CGFloat, top: CGPoint, px: CGFloat) {
    let key = kind == "cat" ? frame : "\(kind).\(frame)"
    guard let rows = CatArt.frames[key] else { return }
    let w = CGFloat(rows[0].count) * px, h = CGFloat(rows.count) * px
    ctx.saveGState()
    ctx.translateBy(x: top.x + h / 2, y: top.y + w / 2)
    ctx.rotate(by: side > 0 ? -.pi / 2 : .pi / 2)
    if side < 0 { ctx.scaleBy(x: -1, y: 1) }
    pet(ctx, kind, frame, feet: CGPoint(x: -w / 2, y: h / 2), px: px)
    ctx.restoreGState()
}

/// The sign it holds up: a cream board in a brown frame on a stick, the
/// stick's foot at `paw`.
func sign(_ ctx: CGContext, _ text: String, more: Int = 0, footer: String? = nil, paw: CGPoint, scale: CGFloat) {
    let wood = rgb(0x6B4524)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12.5 * scale, weight: .bold).rounded, .foregroundColor: rgb(0x4A2E17)]
    let small: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 9.5 * scale, weight: .semibold).rounded, .foregroundColor: rgb(0x6B4524, 0.8)]
    let extra = footer.map { "📅 " + $0 } ?? (more > 0 ? "+\(more) more" : nil)
    let size = (text as NSString).size(withAttributes: attrs)
    let extraSize = extra.map { ($0 as NSString).size(withAttributes: small) } ?? .zero
    let stick = 44 * scale
    ctx.setFillColor(wood.cgColor)
    ctx.fill(CGRect(x: paw.x - 2 * scale, y: paw.y - stick, width: 4 * scale, height: stick))
    let height = size.height + (extra == nil ? 0 : extraSize.height + scale)
    let wide = max(size.width, extraSize.width)
    let board = CGRect(x: paw.x - wide / 2 - 10 * scale, y: paw.y - stick - height - 12 * scale,
                       width: wide + 20 * scale, height: height + 12 * scale)
    let path = NSBezierPath(roundedRect: board, xRadius: 3 * scale, yRadius: 3 * scale)
    rgb(0xF7E3B8).setFill(); path.fill()
    wood.setStroke(); path.lineWidth = 2.5 * scale; path.stroke()
    (text as NSString).draw(at: CGPoint(x: board.midX - size.width / 2, y: board.minY + 6 * scale), withAttributes: attrs)
    if let extra {
        (extra as NSString).draw(at: CGPoint(x: board.midX - extraSize.width / 2, y: board.minY + 6 * scale + size.height + scale),
                                 withAttributes: small)
    }
}

extension NSFont {
    var rounded: NSFont {
        fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: pointSize) } ?? self
    }
}

// 10. Throwing, climbing, and a busy Mac.
canvas(Int(W), Int(H), "Screenshot-10.png") { ctx in
    desktop(ctx, W, H, title: "Full of beans", subtitle: "Throw it across the screen, watch it climb the walls, and see it sweat when your Mac works hard.")
    // Thrown: the path it flew, dashed, and it at the top of the arc.
    let throwPx: CGFloat = 8
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 130, y: 860))
    path.addQuadCurve(to: CGPoint(x: 600, y: 470), control: CGPoint(x: 250, y: 420))
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.55).cgColor)
    ctx.setLineWidth(6); ctx.setLineCap(.round); ctx.setLineDash(phase: 0, lengths: [2, 22])
    ctx.strokePath(); ctx.setLineDash(phase: 0, lengths: [])
    let flying = CGPoint(x: 540, y: 560)
    cat(ctx, "held1", feet: flying, px: throwPx)
    bubble(ctx, "Wheee!", symbol: "sparkles", tip: CGPoint(x: flying.x + 14.5 * throwPx, y: flying.y - 21 * throwPx), scale: 2.2)

    // Climbing the right-hand wall.
    let climbPx: CGFloat = 8
    let frameRows = CatArt.frames["walk1"]!
    let climbTop = CGPoint(x: W - CGFloat(frameRows.count) * climbPx, y: 330)
    climbing(ctx, "cat", "walk1", side: 1, top: climbTop, px: climbPx)
    bubble(ctx, "Look how high I am!", symbol: "arrow.up", tip: CGPoint(x: W - 260, y: climbTop.y - 6), scale: 2.2)

    // Hurrying about with a bead of sweat while the Mac works flat out.
    let runPx: CGFloat = 8, run = CGPoint(x: 820, y: floorY)
    pet(ctx, "dog", "run1", feet: run, px: runPx)
    sprite(ctx, CatArt.effects["sweat"]!, palette: CatArt.effectColors, at: CGPoint(x: run.x + 19 * runPx, y: run.y - 17 * runPx), px: runPx * 0.8)
    bubble(ctx, "Phew! Your Mac is working hard.", symbol: "flame.fill", tip: CGPoint(x: run.x + 14.5 * runPx, y: run.y - 18 * runPx), scale: 2.2)
}

// 11. A note on a sign, typing along, and files to the shelf.
canvas(Int(W), Int(H), "Screenshot-11.png") { ctx in
    desktop(ctx, W, H, title: "Right beside you", subtitle: "It holds up your notes, types along with you and carries files to your shelf.")
    let big: CGFloat = 9
    // The notch and Droppy's shelf open beneath it, two files on it.
    let shelf = CGRect(x: 1050, y: 230, width: 420, height: 150)
    ctx.setFillColor(rgb(0x000000).cgColor)
    ctx.addPath(CGPath(roundedRect: shelf, cornerWidth: 34, cornerHeight: 34, transform: nil)); ctx.fillPath()
    ctx.fill(CGRect(x: shelf.minX, y: shelf.minY, width: shelf.width, height: 40))
    for (i, type) in [UTType.pdf, UTType.png].enumerated() {
        let icon = NSWorkspace.shared.icon(for: type)
        icon.draw(in: CGRect(x: shelf.minX + 70 + CGFloat(i) * 150, y: shelf.minY + 25, width: 110, height: 110),
                  from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    label("Droppy's shelf", at: CGPoint(x: shelf.midX, y: shelf.maxY + 14), size: 24, weight: .semibold, color: rgb(0xFFFFFF, 0.8), centered: true)
    // Running a file over beneath it.
    let carry = CGPoint(x: 1130, y: floorY)
    pet(ctx, "rabbit", "walk1", feet: carry, px: big)
    bubble(ctx, "Taking all 2 to your shelf!", symbol: "tray.and.arrow.down.fill", tip: CGPoint(x: carry.x + 13 * big, y: carry.y - 13 * big), scale: 2)

    // Holding up a note.
    let sitter = CGPoint(x: 110, y: floorY)
    // In the app a pixel is 3 points: the stick in its front paw, 8 points up.
    let width = CGFloat(CatArt.frames["sit"]![0].count)
    sign(ctx, "Call Mum at 5", paw: CGPoint(x: sitter.x + 0.8 * width * big, y: sitter.y - 8 * big / 3), scale: big / 3)
    cat(ctx, "sit", feet: sitter, px: big)

    // Typing along at its laptop.
    let typer = CGPoint(x: 620, y: floorY)
    pet(ctx, "hamster", "sit", feet: typer, px: big, laptop: true)
    label("Types along with you", at: CGPoint(x: typer.x + 10 * big, y: typer.y - 17 * big), size: 28, weight: .semibold,
          color: rgb(0xFFE08A), centered: true)
}

// 12. Getting things done: notes on the sign, Pomodoro, a nudge back.
canvas(Int(W), Int(H), "Screenshot-12.png") { ctx in
    desktop(ctx, W, H, title: "Getting things done", subtitle: "Your to-do list on its sign, Pomodoro rounds, and a nudge when you wander off.")
    let big: CGFloat = 9

    // The list on its sign, the rest waiting behind.
    let sitter = CGPoint(x: 120, y: floorY)
    let width = CGFloat(CatArt.frames["sit"]![0].count)
    sign(ctx, "Call Mum at 5", more: 2, paw: CGPoint(x: sitter.x + 0.8 * width * big, y: sitter.y - 8 * big / 3), scale: big / 3)
    cat(ctx, "sit", feet: sitter, px: big)
    label("Notes · ⌃⌥N", at: CGPoint(x: sitter.x + 0.5 * width * big + 40, y: sitter.y + 20), size: 28, weight: .semibold,
          color: rgb(0xFFE08A), centered: true)

    // Pomodoro: focusing at its laptop, round 2 of 4.
    let focus = CGPoint(x: 640, y: floorY)
    pet(ctx, "dog", "sit", feet: focus, px: big, laptop: true)
    bubble(ctx, "Focus 2/4 · 18:42", symbol: "timer", tip: CGPoint(x: focus.x + 14.5 * big, y: focus.y - 14 * big), scale: 2)
    label("Pomodoro", at: CGPoint(x: focus.x + 10 * big, y: focus.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)
    for i in 0..<4 {
        ctx.setFillColor((i < 1 ? rgb(0xFF6B5A) : rgb(0xFFFFFF, 0.3)).cgColor)
        ctx.fillEllipse(in: CGRect(x: focus.x + 10 * big - 58 + CGFloat(i) * 32, y: focus.y + 66, width: 20, height: 20))
    }

    // A nudge back from a video during a focus session.
    let window = CGRect(x: 1110, y: 270, width: 400, height: 250)
    ctx.setFillColor(rgb(0x18181C, 0.92).cgColor)
    ctx.addPath(CGPath(roundedRect: window, cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.fillPath()
    label("YouTube", at: CGPoint(x: window.minX + 24, y: window.minY + 16), size: 22, weight: .semibold, color: rgb(0xFFFFFF, 0.75))
    ctx.setFillColor(rgb(0x2C2C34).cgColor)
    ctx.fill(CGRect(x: window.minX + 24, y: window.minY + 56, width: window.width - 48, height: window.height - 80))
    ctx.setFillColor(rgb(0xFF3B30).cgColor)
    let play = CGMutablePath()
    play.move(to: CGPoint(x: window.midX - 18, y: window.midY - 6))
    play.addLine(to: CGPoint(x: window.midX + 22, y: window.midY + 16))
    play.addLine(to: CGPoint(x: window.midX - 18, y: window.midY + 38))
    play.closeSubpath()
    ctx.addPath(play); ctx.fillPath()
    let nudger = CGPoint(x: 1180, y: floorY)
    pet(ctx, "rabbit", "sit", feet: nudger, px: big)
    bubble(ctx, "Back to work? 12 min left.", symbol: "eyes", tip: CGPoint(x: nudger.x + 13 * big, y: nudger.y - 17.5 * big), scale: 2)
    label("Nudges you back", at: CGPoint(x: nudger.x + 10 * big, y: nudger.y + 20), size: 28, weight: .semibold,
          color: rgb(0xFFE08A), centered: true)
}

/// A webpage, made up: a header, pictures and lines of text, `width` wide,
/// drawn from `top` (page points) for `height`, at `origin` and `scale`.
let pageLength: CGFloat = 1500
func webpage(_ ctx: CGContext, origin: CGPoint, top: CGFloat, height: CGFloat, scale: CGFloat) {
    let width: CGFloat = 600
    ctx.saveGState()
    ctx.clip(to: CGRect(x: origin.x, y: origin.y, width: width * scale, height: height * scale))
    func box(_ y: CGFloat, _ h: CGFloat, _ x: CGFloat = 40, _ w: CGFloat = 520, _ color: NSColor, radius: CGFloat = 0) {
        let rect = CGRect(x: origin.x + x * scale, y: origin.y + (y - top) * scale, width: w * scale, height: h * scale)
        ctx.setFillColor(color.cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius * scale, cornerHeight: radius * scale, transform: nil)); ctx.fillPath()
    }
    box(top, height, 0, width, rgb(0xFFFFFF))
    box(0, 70, 0, width, rgb(0xFF8A3D))
    box(24, 22, 40, 200, rgb(0xFFFFFF, 0.9), radius: 6)
    box(100, 26, 40, 380, rgb(0x2A2A2E), radius: 6)
    box(146, 210, 40, 520, rgb(0xFFD08A), radius: 14)
    box(196, 90, 230, 140, rgb(0xFF8A3D), radius: 45)
    for (i, y) in stride(from: 384, to: 600, by: 30).enumerated() { box(CGFloat(y), 14, 40, i % 3 == 2 ? 300 : 520, rgb(0xD5D5DC), radius: 7) }
    box(630, 24, 40, 300, rgb(0x2A2A2E), radius: 6)
    box(676, 240, 40, 250, rgb(0x9ED9A8), radius: 14)
    box(676, 240, 310, 250, rgb(0x8EC5F0), radius: 14)
    for (i, y) in stride(from: 946, to: 1180, by: 30).enumerated() { box(CGFloat(y), 14, 40, i % 4 == 3 ? 260 : 520, rgb(0xD5D5DC), radius: 7) }
    box(1210, 24, 40, 340, rgb(0x2A2A2E), radius: 6)
    box(1254, 120, 40, 520, rgb(0xF2E3FF), radius: 14)
    box(1410, 90, 0, width, rgb(0x2A2A2E))
    ctx.restoreGState()
}

/// Droppy's shelf open beneath the notch, files on it.
func shelf(_ ctx: CGContext, _ rect: CGRect, files: [UTType]) {
    ctx.setFillColor(rgb(0x000000).cgColor)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 34, cornerHeight: 34, transform: nil)); ctx.fillPath()
    ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 40))
    for (i, type) in files.enumerated() {
        NSWorkspace.shared.icon(for: type).draw(in: CGRect(x: rect.minX + 70 + CGFloat(i) * 150, y: rect.minY + 25, width: 110, height: 110),
                                                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    label("Droppy's shelf", at: CGPoint(x: rect.midX, y: rect.maxY + 14), size: 24, weight: .semibold, color: rgb(0xFFFFFF, 0.8), centered: true)
}

/// An SF Symbol, white, in a box of `size`.
func symbol(_ name: String, in rect: CGRect, color: NSColor = .white) {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: rect.height * 0.62, weight: .semibold)) else { return }
    let tinted = NSImage(size: image.size, flipped: false) { r in image.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true }
    tinted.draw(in: CGRect(x: rect.midX - image.size.width / 2, y: rect.midY - image.size.height / 2, width: image.size.width, height: image.size.height),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

// 13. Right on time: click to join a call, countdowns, Settings on pages.
canvas(Int(W), Int(H), "Screenshot-13.png") { ctx in
    desktop(ctx, W, H, title: "Right on time", subtitle: "Click it to join your next call, count down to the days ahead, and find every setting fast.")
    let big: CGFloat = 9

    // Come over two minutes early with the call: a click joins.
    let caller = CGPoint(x: 210, y: floorY)
    cat(ctx, "sit", feet: caller, px: big)
    bubble(ctx, "Team sync in 2 min · click me to join", symbol: "video.fill", tip: CGPoint(x: caller.x + 14.5 * big, y: caller.y - 17.5 * big), scale: 2)
    if let arrow = NSCursor.pointingHand.image.copy() as? NSImage {
        arrow.draw(in: CGRect(x: caller.x + 17 * big, y: caller.y - 6 * big, width: arrow.size.width * 2.4, height: arrow.size.height * 2.4),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    label("Click to join", at: CGPoint(x: caller.x + 10 * big, y: caller.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // A countdown under the note on its sign.
    let counter = CGPoint(x: 660, y: floorY)
    let width = CGFloat(CatArt.frames["sit"]![0].count)
    sign(ctx, "Pack the bags", footer: "Trip to Japan · 12 days", paw: CGPoint(x: counter.x + 0.8 * width * big, y: counter.y - 8 * big / 3), scale: big / 3)
    pet(ctx, "dog", "sit", feet: counter, px: big)
    label("Countdowns", at: CGPoint(x: counter.x + 10 * big, y: counter.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // Settings, one page a subject.
    let panel = CGRect(x: 1090, y: 250, width: 430, height: 600)
    ctx.setFillColor(rgb(0x1C1C20, 0.95).cgColor)
    ctx.addPath(CGPath(roundedRect: panel, cornerWidth: 22, cornerHeight: 22, transform: nil)); ctx.fillPath()
    let pages: [(String, String, String, UInt32)] = [
        ("Notes", "3 notes · 1 countdown", "signpost.right.fill", 0xFF9F0A),
        ("Breaks and focus", "Reminders, Pomodoro", "timer", 0xFF453A),
        ("Moving about", "Walking, typing, files", "figure.walk", 0x30D158),
        ("Your own pets", "Draw your own", "paintbrush.pointed.fill", 0xBF5AF2),
        ("Wardrobe and home", "Hats, collars, a home", "tshirt.fill", 0xFF375F),
        ("Friend", "A second pet", "pawprint.fill", 0x40C8E0),
        ("What it tells you", "Calendar, music, agents", "bubble.left.fill", 0x0A84FF),
        ("Festivals and birthday", "Your special days", "party.popper.fill", 0xFFD60A),
    ]
    for (i, page) in pages.enumerated() {
        let y = panel.minY + 22 + CGFloat(i) * 70
        let tile = CGRect(x: panel.minX + 22, y: y + 8, width: 44, height: 44)
        ctx.setFillColor(rgb(page.3).cgColor)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 11, cornerHeight: 11, transform: nil)); ctx.fillPath()
        symbol(page.2, in: tile.insetBy(dx: 6, dy: 6))
        label(page.0, at: CGPoint(x: tile.maxX + 16, y: y + 4), size: 21, weight: .semibold)
        label(page.1, at: CGPoint(x: tile.maxX + 16, y: y + 30), size: 16, weight: .regular, color: rgb(0xFFFFFF, 0.55))
        label("›", at: CGPoint(x: panel.maxX - 34, y: y + 8), size: 30, weight: .regular, color: rgb(0xFFFFFF, 0.4))
    }
    label("Settings on pages", at: CGPoint(x: panel.midX, y: floorY + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)
}

// 14. The whole page: Safari scrolled top to bottom, one tall picture, on the shelf.
canvas(Int(W), Int(H), "Screenshot-14.png") { ctx in
    desktop(ctx, W, H, title: "The whole page", subtitle: "It scrolls a Safari page to the bottom and hands you one tall picture.")
    let big: CGFloat = 9

    // Safari, a screen of the page showing.
    let window = CGRect(x: 70, y: 250, width: 600, height: 440)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 30, color: rgb(0x000000, 0.35).cgColor)
    ctx.setFillColor(rgb(0x2A2A2E).cgColor)
    ctx.addPath(CGPath(roundedRect: window, cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.fillPath()
    ctx.restoreGState()
    for (i, color) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        ctx.setFillColor(rgb(UInt32(color)).cgColor)
        ctx.fillEllipse(in: CGRect(x: window.minX + 20 + CGFloat(i) * 24, y: window.minY + 19, width: 14, height: 14))
    }
    let field = CGRect(x: window.minX + 150, y: window.minY + 12, width: 300, height: 28)
    ctx.setFillColor(rgb(0xFFFFFF, 0.12).cgColor)
    ctx.addPath(CGPath(roundedRect: field, cornerWidth: 8, cornerHeight: 8, transform: nil)); ctx.fillPath()
    label("recipes.example", at: CGPoint(x: field.midX, y: field.minY + 4), size: 16, weight: .medium, color: rgb(0xFFFFFF, 0.75), centered: true)
    let shown = window.height - 52
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: window, cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.clip()
    webpage(ctx, origin: CGPoint(x: window.minX, y: window.minY + 52), top: 0, height: shown, scale: 1)
    ctx.restoreGState()

    // The pet scrolling it.
    let scroller = CGPoint(x: 250, y: floorY)
    cat(ctx, "sit", feet: scroller, px: big)
    bubble(ctx, "Hold still, Safari!", symbol: "camera.viewfinder", tip: CGPoint(x: scroller.x + 14.5 * big, y: scroller.y - 17.5 * big), scale: 2)
    label("Scrolls to the bottom", at: CGPoint(x: scroller.x + 10 * big, y: scroller.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // The arrow, and the page in one piece, with where the screens joined.
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 700, y: 470)); arrow.addLine(to: CGPoint(x: 780, y: 470))
    arrow.move(to: CGPoint(x: 760, y: 450)); arrow.addLine(to: CGPoint(x: 782, y: 470)); arrow.addLine(to: CGPoint(x: 760, y: 490))
    ctx.addPath(arrow); ctx.setStrokeColor(rgb(0xFFFFFF, 0.85).cgColor); ctx.setLineWidth(6); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
    let scale: CGFloat = 0.44
    let tall = CGRect(x: 830, y: 225, width: 600 * scale, height: pageLength * scale)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 30, color: rgb(0x000000, 0.35).cgColor)
    ctx.setFillColor(rgb(0xFFFFFF).cgColor); ctx.fill(tall.insetBy(dx: -6, dy: -6))
    ctx.restoreGState()
    webpage(ctx, origin: tall.origin, top: 0, height: pageLength, scale: scale)
    ctx.setStrokeColor(rgb(0x4446F4, 0.8).cgColor); ctx.setLineWidth(2.5); ctx.setLineDash(phase: 0, lengths: [8, 6])
    var y = shown
    var n = 1
    while y < pageLength {
        ctx.move(to: CGPoint(x: tall.minX - 6, y: tall.minY + y * scale)); ctx.addLine(to: CGPoint(x: tall.maxX + 6, y: tall.minY + y * scale))
        ctx.strokePath()
        y += shown; n += 1
    }
    ctx.setLineDash(phase: 0, lengths: [])
    label("\(n) screens, one PNG", at: CGPoint(x: tall.midX, y: tall.maxY + 18), size: 22, weight: .semibold, color: rgb(0xFFFFFF, 0.85), centered: true)

    // And onto the shelf.
    shelf(ctx, CGRect(x: 1200, y: 225, width: 340, height: 150), files: [.png])
    let carrier = CGPoint(x: 1300, y: floorY)
    pet(ctx, "hamster", "walk1", feet: carrier, px: big)
    bubble(ctx, "On your shelf!", symbol: "checkmark.circle.fill", tip: CGPoint(x: carrier.x + 13 * big, y: carrier.y - 13 * big), scale: 2)
    label("To your shelf", at: CGPoint(x: carrier.x + 10 * big, y: carrier.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)
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
