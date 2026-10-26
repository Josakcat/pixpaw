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

// MARK: For 15 and 16

func dustCloud(seed: Int) -> [[UInt32]] {
    var random = SeededRandom(seed: UInt64(seed + 1) * 2_654_435_761)
    let w = 54, h = 36
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
    return (0..<h).map { y in Array(pixels[(y * w)..<(y * w + w)]) }
}

/// The same jostle every time, so the frames are made once.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed | 1 }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return range.lowerBound + Double(state % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
    }
}

let frisbeeRows = [
        "..oooooo..",
            ".oRRRRRRo.",
            "oRRWWWWRRo",
            ".oooooooo."
]
let frisbeeColors: [Character: UInt32] = ["R": 0xE8453C, "W": 0xF7A49E, "o": 0x2A2420]

let carrotRows = [
        "..gg.g",
            "...gg.",
            "..oOo.",
            ".oOOo.",
            ".oOOo.",
            ".oOo..",
            "oOOo..",
            "oOo...",
            "oo...."
]
let carrotColors: [Character: UInt32] = ["g": 0x4CAF50, "O": 0xF28C28, "o": 0x2A2420]

let watermelonRows = [
        "..oooooo..",
            ".oGgGgGgo.",
            "oGgGgGgGgo",
            "oGgGgGgGgo",
            "oGgGgGgGgo",
            ".oGgGgGgo.",
            "..oooooo.."
]
let watermelonColors: [Character: UInt32] = ["G": 0x2E8B3A, "g": 0x6CC46A, "o": 0x2A2420]

/// Claude's question on the card over the pet: header, question, the thing
/// it's about, the answers as buttons and the way out; tail down at `tip`.
func askCard(_ ctx: CGContext, header: String, title: String, detail: String?, buttons: [String], tip: CGPoint, scale s: CGFloat,
             link: String = "Answer in Claude instead") {
    let width = 250 * s, pad = 10 * s
    let headerFont = NSFont.systemFont(ofSize: 10.5 * s, weight: .semibold).rounded
    let titleFont = NSFont.systemFont(ofSize: 12.5 * s, weight: .semibold).rounded
    let codeFont = NSFont.monospacedSystemFont(ofSize: 11 * s, weight: .regular)
    let buttonFont = NSFont.systemFont(ofSize: 11.5 * s, weight: .semibold).rounded
    let linkFont = NSFont.systemFont(ofSize: 10 * s, weight: .medium).rounded
    var height = 8 * s + 15 * s + 6 * s + 17 * s + 6 * s + 26 * s + 6 * s + 14 * s + 14 * s
    if detail != nil { height += 22 * s + 6 * s }
    let body = CGRect(x: tip.x - width / 2, y: tip.y - 6 * s - height + 6 * s, width: width, height: height - 6 * s)
    let path = NSBezierPath(roundedRect: body, xRadius: 10 * s, yRadius: 10 * s)
    path.move(to: CGPoint(x: tip.x - 6 * s, y: body.maxY - 1)); path.line(to: tip); path.line(to: CGPoint(x: tip.x + 6 * s, y: body.maxY - 1))
    rgb(0xFFFFFF).setFill(); path.fill()
    rgb(0x1F1F1F).setStroke(); path.lineWidth = 2 * s; path.stroke()
    var y = body.minY + 8 * s
    let x = body.minX + pad
    symbol("hand.raised.fill", in: CGRect(x: x, y: y + 1 * s, width: 12 * s, height: 12 * s), color: rgb(0x595959))
    (header as NSString).draw(at: CGPoint(x: x + 16 * s, y: y), withAttributes: [.font: headerFont, .foregroundColor: rgb(0x595959)])
    y += 15 * s + 6 * s
    (title as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: titleFont, .foregroundColor: rgb(0x1A1A1A)])
    y += 17 * s + 6 * s
    if let detail {
        let box = CGRect(x: x, y: y, width: width - 2 * pad, height: 22 * s)
        rgb(0xEDEDED).setFill(); NSBezierPath(roundedRect: box, xRadius: 5 * s, yRadius: 5 * s).fill()
        (detail as NSString).draw(at: CGPoint(x: x + 6 * s, y: y + 4 * s), withAttributes: [.font: codeFont, .foregroundColor: rgb(0x1A1A1A)])
        y += 22 * s + 6 * s
    }
    var bx = x
    for (i, title) in buttons.enumerated() {
        let warns = title.lowercased().contains("deny")
        let size = (title as NSString).size(withAttributes: [.font: buttonFont])
        let capsule = CGRect(x: bx, y: y, width: size.width + 18 * s, height: 24 * s)
        (i == 0 ? rgb(0x4545F5) : rgb(0xE6E6E6)).setFill()
        NSBezierPath(roundedRect: capsule, xRadius: 12 * s, yRadius: 12 * s).fill()
        (title as NSString).draw(at: CGPoint(x: bx + 9 * s, y: y + 12 * s - size.height / 2),
                                 withAttributes: [.font: buttonFont, .foregroundColor: i == 0 ? rgb(0xFFFFFF) : warns ? rgb(0xBF261F) : rgb(0x1A1A1A)])
        bx = capsule.maxX + 6 * s
    }
    y += 26 * s + 6 * s
    (link as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: linkFont, .foregroundColor: rgb(0x737373)])
}

// 15. Ask your pet: Claude's question comes over on a card.
canvas(Int(W), Int(H), "Screenshot-15.png") { ctx in
    desktop(ctx, W, H, title: "Ask your pet", subtitle: "When Claude Code needs a yes or an answer, your pet brings it over and reads it out.")
    // Claude Code, waiting on you.
    let term = CGRect(x: 70, y: 250, width: 640, height: 400)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 30, color: rgb(0x000000, 0.35).cgColor)
    ctx.setFillColor(rgb(0x1C1C21).cgColor)
    ctx.addPath(CGPath(roundedRect: term, cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.fillPath()
    ctx.restoreGState()
    for (i, color) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        ctx.setFillColor(rgb(UInt32(color)).cgColor)
        ctx.fillEllipse(in: CGRect(x: term.minX + 20 + CGFloat(i) * 24, y: term.minY + 19, width: 14, height: 14))
    }
    let mono = { (size: CGFloat) in NSFont.monospacedSystemFont(ofSize: size, weight: .regular) }
    let lines: [(String, UInt32)] = [("> add a dark mode to the shop", 0xFFFFFF), ("", 0), ("⏺ Updated 4 files", 0xB9B9C6), ("⏺ Claude wants to run:", 0xD6A35C),
                                     ("    npm test", 0xFFFFFF), ("", 0), ("  Do you want to proceed?", 0xB9B9C6), ("  ❯ 1. Yes", 0x8E8EF0), ("    2. No", 0xB9B9C6)]
    for (i, line) in lines.enumerated() where !line.0.isEmpty {
        (line.0 as NSString).draw(at: CGPoint(x: term.minX + 30, y: term.minY + 66 + CGFloat(i) * 34), withAttributes: [.font: mono(21), .foregroundColor: rgb(line.1)])
    }
    // The pet with the card over its head.
    let me = CGPoint(x: 1060, y: floorY)
    cat(ctx, "sit", feet: me, px: 9)
    askCard(ctx, header: "Claude · shop", title: "Run this command?", detail: "npm test", buttons: ["Allow", "Always allow", "Deny"],
            tip: CGPoint(x: me.x + 14.5 * 9, y: me.y - 17.5 * 9), scale: 2.1)
    symbol("speaker.wave.2.fill", in: CGRect(x: me.x + 200, y: me.y - 120, width: 40, height: 40), color: rgb(0xFFE08A))
    label("Click to answer", at: CGPoint(x: me.x + 90, y: me.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)
    label("Away from the Mac? Claude asks you on your phone instead.", at: CGPoint(x: term.midX, y: term.maxY + 24), size: 22, weight: .medium,
          color: rgb(0xFFFFFF, 0.8), centered: true)
}

// 16. Playtime, their way: a toy for every animal, and play-fights.
canvas(Int(W), Int(H), "Screenshot-16.png") { ctx in
    desktop(ctx, W, H, title: "Playtime, their way", subtitle: "A toy of its own for every animal, fetch for the dogs, and the odd play-fight.")
    let big: CGFloat = 10

    // A frisbee, thrown for the dog.
    let dog = CGPoint(x: 70, y: floorY)
    let arc = CGMutablePath()
    arc.move(to: CGPoint(x: dog.x + 160, y: floorY - 120))
    arc.addQuadCurve(to: CGPoint(x: dog.x + 330, y: floorY - 330), control: CGPoint(x: dog.x + 200, y: floorY - 330))
    ctx.addPath(arc)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.55).cgColor); ctx.setLineWidth(6); ctx.setLineCap(.round); ctx.setLineDash(phase: 0, lengths: [2, 22])
    ctx.strokePath(); ctx.setLineDash(phase: 0, lengths: [])
    sprite(ctx, frisbeeRows, palette: frisbeeColors, at: CGPoint(x: dog.x + 300, y: floorY - 370), px: big)
    pet(ctx, "dog", "run1", feet: dog, px: big)
    label("Frisbee", at: CGPoint(x: dog.x + 10 * big, y: dog.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // A carrot dangling from the pointer for the rabbit.
    let rabbit = CGPoint(x: 520, y: floorY)
    let pointer = CGPoint(x: rabbit.x + 250, y: floorY - 380)
    // The carrot on a string from the pointer.
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.8).cgColor); ctx.setLineWidth(3)
    ctx.move(to: CGPoint(x: pointer.x + 2, y: pointer.y + 4)); ctx.addLine(to: CGPoint(x: pointer.x + 2, y: pointer.y + 110)); ctx.strokePath()
    sprite(ctx, carrotRows, palette: carrotColors, at: CGPoint(x: pointer.x - 22, y: pointer.y + 100), px: big)
    let cursor = CGMutablePath()
    for (i, point) in [(0, 0), (0, 34), (8, 26), (14, 40), (20, 37), (14, 24), (25, 24)].enumerated() {
        let p = CGPoint(x: pointer.x + CGFloat(point.0) * 1.6, y: pointer.y + CGFloat(point.1) * 1.6)
        if i == 0 { cursor.move(to: p) } else { cursor.addLine(to: p) }
    }
    cursor.closeSubpath()
    ctx.addPath(cursor); ctx.setFillColor(rgb(0x000000).cgColor); ctx.fillPath()
    ctx.addPath(cursor); ctx.setStrokeColor(rgb(0xFFFFFF).cgColor); ctx.setLineWidth(3); ctx.setLineJoin(.round); ctx.strokePath()
    pet(ctx, "rabbit", "crouch1", feet: rabbit, px: big)
    label("Carrot", at: CGPoint(x: rabbit.x + 10 * big, y: rabbit.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // A watermelon to roll about for the hippo.
    let hippo = CGPoint(x: 900, y: floorY)
    pet(ctx, "hippo", "sit", feet: hippo, px: big)
    sprite(ctx, watermelonRows, palette: watermelonColors, at: CGPoint(x: hippo.x + 200, y: floorY - CGFloat(watermelonRows.count) * big), px: big)
    label("Watermelon", at: CGPoint(x: hippo.x + 150, y: hippo.y + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // Two friends in a cloud of dust.
    let cloudPx: CGFloat = 7
    let cloud = dustCloud(seed: 4)
    let cloudOrigin = CGPoint(x: 1200, y: floorY - CGFloat(cloud.count) * cloudPx + 3 * cloudPx)
    for (y, row) in cloud.enumerated() {
        for (x, color) in row.enumerated() where color != 0 {
            ctx.setFillColor(rgb(color).cgColor)
            ctx.fill(CGRect(x: cloudOrigin.x + CGFloat(x) * cloudPx, y: cloudOrigin.y + CGFloat(y) * cloudPx, width: cloudPx, height: cloudPx))
        }
    }
    bubble(ctx, "Rematch?", symbol: "sparkles", tip: CGPoint(x: cloudOrigin.x + 27 * cloudPx, y: cloudOrigin.y + 2 * cloudPx), scale: 2)
    label("Play-fights", at: CGPoint(x: cloudOrigin.x + 27 * cloudPx, y: floorY + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)
}

/// The tag at a pet's side while an agent works: a dark capsule, a symbol
/// and what it's doing, its left edge at `at` and its bottom on the floor.
func toolTag(_ ctx: CGContext, _ text: String, symbol name: String, at origin: CGPoint, scale s: CGFloat) {
    let font = NSFont.systemFont(ofSize: 10.5 * s, weight: .semibold).rounded
    let size = (text as NSString).size(withAttributes: [.font: font])
    let pill = CGRect(x: origin.x, y: origin.y - 20 * s, width: size.width + 34 * s, height: 20 * s)
    rgb(0x1F1F1F, 0.9).setFill()
    NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
    symbol(name, in: CGRect(x: pill.minX + 7 * s, y: pill.minY + 3 * s, width: 14 * s, height: 14 * s))
    (text as NSString).draw(at: CGPoint(x: pill.minX + 25 * s, y: pill.midY - size.height / 2), withAttributes: [.font: font, .foregroundColor: rgb(0xFFFFFF)])
}

// 17. Share it as a GIF: five seconds of the pet, on the shelf.
canvas(Int(W), Int(H), "Screenshot-17.png") { ctx in
    desktop(ctx, W, H, title: "Share it as a GIF", subtitle: "Five seconds of whatever your pet is up to, as a looping GIF on your shelf.")
    let me = CGPoint(x: 110, y: floorY)
    cat(ctx, "sit", coat: "gray", hat: "partyHat", feet: me, px: 9)
    bubble(ctx, "Rolling! Five seconds of me…", symbol: "record.circle", tip: CGPoint(x: me.x + 14.5 * 9, y: me.y - 22 * 9))

    // The film: five frames on the little stage the GIF draws.
    let strip = CGRect(x: 470, y: 300, width: 1060, height: 230)
    ctx.setFillColor(rgb(0x1A1A1E).cgColor)
    ctx.addPath(CGPath(roundedRect: strip, cornerWidth: 14, cornerHeight: 14, transform: nil)); ctx.fillPath()
    for i in 0..<22 {
        ctx.setFillColor(rgb(0xF2F2F2, 0.85).cgColor)
        for y in [strip.minY + 10, strip.maxY - 24] {
            ctx.addPath(CGPath(roundedRect: CGRect(x: strip.minX + 18 + CGFloat(i) * 48, y: y, width: 22, height: 14), cornerWidth: 3, cornerHeight: 3, transform: nil))
            ctx.fillPath()
        }
    }
    for (i, frame) in ["walk1", "walk2", "happy", "walk2", "sit"].enumerated() {
        let cell = CGRect(x: strip.minX + 20 + CGFloat(i) * 206, y: strip.minY + 38, width: 194, height: 154)
        ctx.setFillColor(rgb(0xFFF1D6).cgColor); ctx.fill(cell)
        ctx.setFillColor(rgb(0xE8C9A0).cgColor); ctx.fill(CGRect(x: cell.minX, y: cell.maxY - 26, width: cell.width, height: 26))
        ctx.setFillColor(rgb(0xD2AE80).cgColor); ctx.fill(CGRect(x: cell.minX, y: cell.maxY - 26, width: cell.width, height: 4))
        cat(ctx, frame, coat: "gray", hat: "partyHat", feet: CGPoint(x: cell.minX + 37 + CGFloat(i % 2) * 8, y: cell.maxY - 26), px: 6)
    }
    label("Cat by Pixpaw.gif · 5 seconds, looping", at: CGPoint(x: strip.midX, y: strip.maxY + 22), size: 26, weight: .semibold,
          color: rgb(0xFFE08A), centered: true)
    shelf(ctx, CGRect(x: 760, y: 700, width: 480, height: 160), files: [.gif])
    label("No permission needed: it's drawn from your pet's own art.", at: CGPoint(x: 1000, y: 920), size: 22, weight: .medium,
          color: rgb(0xFFFFFF, 0.8), centered: true)
}

// 18. What it's working on: Claude Code and Antigravity, a tag at the pet's
// side, and answers from the keyboard.
canvas(Int(W), Int(H), "Screenshot-18.png") { ctx in
    desktop(ctx, W, H, title: "What it's working on", subtitle: "Claude Code and Antigravity, at a glance, and answers from the keyboard.")
    // Antigravity, editing.
    let first = CGPoint(x: 90, y: floorY)
    pet(ctx, "cat", "sit", feet: first, px: 9, laptop: true)
    toolTag(ctx, "Editing App.tsx", symbol: "pencil", at: CGPoint(x: first.x + 20 * 9, y: floorY), scale: 2)
    bubble(ctx, "Antigravity is working", symbol: "sparkles", tip: CGPoint(x: first.x + 14.5 * 9, y: first.y - 22 * 9))
    label("Antigravity", at: CGPoint(x: first.x + 160, y: floorY + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // Claude Code, done, with the plan left.
    let second = CGPoint(x: 640, y: floorY)
    pet(ctx, "dog", "sit", feet: second, px: 9, laptop: true)
    toolTag(ctx, "Running npm test", symbol: "terminal", at: CGPoint(x: second.x + 20 * 9, y: floorY), scale: 2)
    bubble(ctx, "Claude is done! 5h 93% · week 96% left", symbol: "checkmark.circle.fill", tip: CGPoint(x: second.x + 14.5 * 9, y: second.y - 22 * 9))
    label("Claude Code", at: CGPoint(x: second.x + 160, y: floorY + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)

    // A question, answered with Option-1.
    let third = CGPoint(x: 1240, y: floorY)
    pet(ctx, "hamster", "sit", feet: third, px: 9)
    askCard(ctx, header: "Claude · shop", title: "Edit this file?", detail: "App.tsx", buttons: ["Allow  ⌥1", "Deny  ⌥2"],
            tip: CGPoint(x: third.x + 14.5 * 9, y: third.y - 17.5 * 9), scale: 1.6, link: "Answer in Claude instead  ⌥0")
    label("Option-1 to answer", at: CGPoint(x: third.x + 130, y: floorY + 20), size: 28, weight: .semibold, color: rgb(0xFFE08A), centered: true)
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
