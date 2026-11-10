//
//  BubbleEffects.swift
//  Pixpaw
//
//  How a pet's speech bubble comes up. Each pet sends something up from its
//  head, the bubble's edge comes alive with a few bits of its own, and it
//  settles with an edge tinted in the pet's colour, all in about two
//  seconds: the dragon breathes fire, the cat walks paw prints across, the
//  bee drips honey, and so on. Pure drawing, one frame at a time: CatBubble
//  steps the frames on its timer. With Reduce Motion (or under the notch)
//  only the tinted edge is left.
//

import SwiftUI

/// The way a pet's speech bubble appears; a new pet can bring its own.
enum BubbleStyle: Equatable {
    case plain
    case fire, paws, bones, honey, feathers, leaves, seeds, eggs, spots, bubbles, carrots, splash, mud
    /// A pet you drew: a gentle sparkle in its main colour (0xRRGGBB).
    case sparkle(UInt32)
}

/// The timing every effect shares, and the drawing of each.
enum BubbleEffect {
    /// Six frames a second, so the effect lingers (about two seconds).
    static let fps: Double = 6
    /// The lead-in rises for these frames; the bubble comes up on the next one.
    static let lightFrame = 5
    /// The last frame with anything moving; after it the bubble is still.
    static let lastFrame = 12
    /// How long the words wait for the lead-in.
    static var leadIn: Double { Double(lightFrame) / fps }
    /// Bubble effects in Settings; off, every bubble is plain.
    @MainActor static var isOn = true
    /// One pixel, in points.
    static let px: CGFloat = 2

    /// Room around the bubble for the lead-in below it and the bits around it:
    /// the farthest any bit gets past the bubble's edge, glyph and all, so
    /// none is clipped by the panel (at least 10, for the lead-in).
    static func margin(_ style: BubbleStyle) -> CGFloat {
        if style == .fire { return BubbleFire.margin }
        guard let look = look(style) else { return 10 }
        // A small bubble, so bits from the top corners count as close to the sides.
        let body = CGRect(x: 0, y: 0, width: 40, height: 20)
        var reach: CGFloat = 10
        for bit in look.bits {
            for age in 0...bit.life {
                guard let (point, glyph) = place(bit, age: age, body: body) else { continue }
                let w = CGFloat(glyph.first?.count ?? 0) * px / 2 + px, h = CGFloat(glyph.count) * px / 2 + px
                reach = max(reach, body.minX - (point.x - w), point.x + w - body.maxX,
                            body.minY - (point.y - h), point.y + h - body.maxY)
            }
        }
        return reach.rounded(.up)
    }

    /// The bubble's edge on a frame: bright as it comes alive, cooling to
    /// the settled tint (nil frame = settled).
    static func edge(_ style: BubbleStyle, frame: Int?) -> Color {
        let (lit, settled) = style == .fire ? BubbleFire.edges : look(style).map { ($0.lit, $0.settled) } ?? (0x1F1F1F, 0x1F1F1F)
        guard let frame, frame >= lightFrame else { return color(settled) }
        let t = Double(frame - lightFrame) / Double(lastFrame - lightFrame)
        let channel = { (shift: UInt32) -> Double in
            let a = Double((lit >> shift) & 0xFF) / 255, b = Double((settled >> shift) & 0xFF) / 255
            return a + (b - a) * t
        }
        return Color(red: channel(16), green: channel(8), blue: channel(0))
    }

    /// Draws one frame over the bubble. `size` is the whole canvas, margin
    /// included; the bubble's body sits `margin` in from every edge with its
    /// 7-point tail pointing down.
    static func draw(_ style: BubbleStyle, frame: Int, in context: GraphicsContext, size: CGSize, outline: Path) {
        if style == .fire { return BubbleFire.draw(frame, in: context, size: size, outline: outline) }
        guard let look = look(style) else { return }
        let margin = margin(style)
        let body = CGRect(x: margin, y: margin, width: size.width - margin * 2, height: size.height - margin * 2 - 7)
        if frame < lightFrame {
            lead(look, frame: frame, in: context, from: CGPoint(x: size.width / 2, y: size.height - 4), to: body.midY - 4)
        } else {
            let fade = 1 - Double(frame - lightFrame) / Double(lastFrame - lightFrame + 1)
            context.stroke(outline, with: .color(color(look.lit).opacity(0.3 * fade)), lineWidth: 6)
            context.stroke(outline, with: .color(color(look.lit).opacity(0.45 * fade)), lineWidth: 3)
            for bit in look.bits { draw(bit, look: look, age: frame - lightFrame - bit.delay, in: context, body: body) }
        }
    }

    // MARK: - Each pet's look

    /// A small pixel picture: rows of palette letters, '.' for none.
    typealias Glyph = [String]

    /// How the lead-in travels up from the head.
    enum Route { case straight, zigzag, hop, sway, steps }

    /// Where a bit starts: along the top or bottom edge (0...1), or a side.
    enum Edge { case top(CGFloat), bottom(CGFloat), left, right }

    /// How a bit moves once it leaves the edge.
    enum Move {
        /// Out and up, like a spark.
        case burst
        /// Straight up with a wobble, like a heart or a bubble.
        case rise
        /// Tossed up, then falling.
        case arc
        /// Hanging, then dropping (a honey drip).
        case drip
        /// Swaying side to side as it drifts down (a feather, a leaf).
        case flutter
        /// Kicked out sideways along the bottom (dust).
        case stomp
        /// Stays where it is and fades (a paw print, a sparkle).
        case stay
    }

    struct Bit {
        var from: Edge
        /// Shown in turn, a frame each.
        var glyphs: [Glyph]
        var move: Move
        var life: Int
        /// Frames after the bubble comes up before it appears.
        var delay = 0
    }

    struct Look {
        /// The edge just lit, and at rest.
        var lit: UInt32
        var settled: UInt32
        var colours: [Character: UInt32]
        /// The lead-in's picture, a frame each in turn.
        var lead: [Glyph]
        var route: Route
        /// Dots trailing the lead-in, in this palette letter.
        var trail: Character?
        var bits: [Bit]
    }

    private static let paw: Glyph = ["t.t.t", ".ppp.", ".ppp."]
    private static let boneA: Glyph = ["bb...", "bbB..", ".bbB.", "..bbB", "...BB"]
    private static let boneB: Glyph = ["...bb", "..bbB", ".bbB.", "bbB..", "BB..."]
    private static let heart: Glyph = ["r.r", "rRr", ".r."]
    private static let bigHeart: Glyph = ["rr.rr", "rwrrr", ".rrr.", "..r.."]
    private static let pollen: Glyph = ["yy", "yY"]
    private static let dot: Glyph = ["y"]
    private static let drip: Glyph = ["h", "h", "H"]
    private static let drop: Glyph = [".h.", "hhh", ".H."]
    private static let featherA: Glyph = ["..a", ".aa", "aA.", "a.."]
    private static let featherB: Glyph = ["a..", "aa.", ".Aa", "..a"]
    private static let leafA: Glyph = [".gg", "gGg", "gg."]
    private static let leafB: Glyph = ["gg.", "gGg", ".gg"]
    private static let dust: Glyph = [".d.", "ddd"]
    private static let smallDust: Glyph = ["d"]
    private static let seedA: Glyph = [".s.", "sws", "sws", ".s."]
    private static let seedB: Glyph = ["ss.", "sws", ".ss"]
    private static let egg: Glyph = [".ee.", "eeee", "eeeE", ".EE."]
    private static let crackedEgg: Glyph = ["e.e.", "eeee", "eeeE", ".EE."]
    private static let shell: Glyph = ["e.", "eE"]
    private static let plume: Glyph = ["y.", "yy", ".y"]
    private static let spot: Glyph = [".oo", "ooo", "oo."]
    private static let smallSpot: Glyph = ["oo", "o."]
    private static let bubble: Glyph = [".bb.", "bw.b", "b..b", ".bb."]
    private static let smallBubble: Glyph = ["bb", "bb"]
    private static let pop: Glyph = ["b.b", "...", "b.b"]
    private static let carrot: Glyph = ["..gg", ".oog", "oo..", "o..."]
    private static let fluff: Glyph = [".c.", "cwc", ".c."]
    private static let fin: Glyph = ["..f", ".ff", "fff"]
    private static let water: Glyph = [".w", "wW"]
    private static let mudBlob: Glyph = [".mm.", "mmmm", "mMMm"]
    private static let splat: Glyph = ["m.m", ".m.", "m.m"]
    private static let star: Glyph = ["..s..", "..s..", "ssSss", "..s..", "..s.."]
    private static let twinkle: Glyph = [".s.", "sSs", ".s."]
    private static let speck: Glyph = ["S"]

    /// Bits along the top, `count` of them, evenly spread.
    private static func row(_ count: Int, _ glyphs: [Glyph], _ move: Move, life: Int, stagger: Int = 0) -> [Bit] {
        (0..<count).map { i in
            let along = (CGFloat(i) + 0.5) / CGFloat(count)
            return Bit(from: .top(along), glyphs: glyphs, move: move, life: life - (i * 3) % 2, delay: stagger == 0 ? (i * 2) % 3 : i * stagger)
        }
    }

    static func look(_ style: BubbleStyle) -> Look? {
        switch style {
        case .plain, .fire:
            return nil
        case .paws:
            // Little prints walking up from its head, then across the top.
            return Look(lit: 0xF4A6BD, settled: 0x5C4048, colours: ["t": 0xF4A6BD, "p": 0xE07F9B],
                        lead: [paw], route: .steps, trail: nil,
                        bits: (0..<5).map { Bit(from: .top(0.1 + CGFloat($0) * 0.2), glyphs: [paw], move: .stay, life: 3, delay: $0) })
        case .bones:
            // A bone wagging up, then hearts bouncing off the top.
            return Look(lit: 0xE0A35A, settled: 0x5A3A1C,
                        colours: ["b": 0xFFF3DD, "B": 0xD9C3A0, "r": 0xFF7F9A, "R": 0xFF5C7E, "w": 0xFFFFFF],
                        lead: [boneA, boneB], route: .straight, trail: nil,
                        bits: row(4, [heart, bigHeart, bigHeart], .rise, life: 6)
                            + [Bit(from: .left, glyphs: [heart], move: .rise, life: 5, delay: 2),
                               Bit(from: .right, glyphs: [heart], move: .rise, life: 5, delay: 1)])
        case .honey:
            // Pollen zigzagging up, a puff of pollen and two honey drips.
            return Look(lit: 0xFFCF3A, settled: 0x6A4B0C, colours: ["y": 0xFFCF3A, "Y": 0xF2A31B, "h": 0xF2A31B, "H": 0xC97D0A],
                        lead: [pollen], route: .zigzag, trail: "y",
                        bits: row(5, [pollen, dot], .burst, life: 6)
                            + [Bit(from: .bottom(0.22), glyphs: [drip, drip, drop], move: .drip, life: 6),
                               Bit(from: .bottom(0.8), glyphs: [drip, drop], move: .drip, life: 5, delay: 2)])
        case .feathers:
            // A feather fluttering up, then a few in its colours drifting off.
            let green: [Character: UInt32] = ["a": 0x5AA838, "A": 0x2F7D2C]
            return Look(lit: 0x7CC85A, settled: 0x2A4E22, colours: green,
                        lead: [featherA, featherB], route: .sway, trail: nil,
                        bits: row(4, [featherA, featherB], .flutter, life: 7)
                            + [Bit(from: .left, glyphs: [featherB, featherA], move: .flutter, life: 6, delay: 1),
                               Bit(from: .right, glyphs: [featherA, featherB], move: .flutter, life: 6, delay: 2)])
        case .leaves:
            // A leaf drifting up, then a stomp: dust kicked out at the bottom
            // and leaves shaken off the top.
            return Look(lit: 0x8CD86A, settled: 0x2D4A22, colours: ["g": 0x6CC24A, "G": 0x4A9A33, "d": 0xC9B79C],
                        lead: [leafA, leafB], route: .sway, trail: nil,
                        bits: [Bit(from: .bottom(0.05), glyphs: [dust, dust, smallDust], move: .stomp, life: 5),
                               Bit(from: .bottom(0.95), glyphs: [dust, dust, smallDust], move: .stomp, life: 5),
                               Bit(from: .bottom(0.3), glyphs: [smallDust], move: .stomp, life: 3, delay: 1),
                               Bit(from: .bottom(0.7), glyphs: [smallDust], move: .stomp, life: 3, delay: 1)]
                            + row(3, [leafA, leafB], .flutter, life: 7, stagger: 1))
        case .seeds:
            // A seed hopping up, then seeds popping out all round.
            return Look(lit: 0xF2A65A, settled: 0x5E3A18, colours: ["s": 0x9A8070, "w": 0xFFF3DD],
                        lead: [seedA, seedB], route: .hop, trail: nil,
                        bits: row(5, [seedA, seedB], .arc, life: 6)
                            + [Bit(from: .left, glyphs: [seedB, seedA], move: .burst, life: 5),
                               Bit(from: .right, glyphs: [seedA, seedB], move: .burst, life: 5, delay: 1)])
        case .eggs:
            // An egg wobbling up; it cracks as the bubble comes, shell bits
            // fall and a fluff of yellow drifts off.
            return Look(lit: 0xF07A5E, settled: 0x5E2A1E, colours: ["e": 0xFBF7F0, "E": 0xDDD5C8, "y": 0xF5C84A],
                        lead: [egg, egg, egg, egg, crackedEgg], route: .straight, trail: nil,
                        bits: [Bit(from: .top(0.35), glyphs: [shell], move: .arc, life: 6),
                               Bit(from: .top(0.65), glyphs: [shell], move: .arc, life: 6),
                               Bit(from: .left, glyphs: [shell], move: .arc, life: 5, delay: 1),
                               Bit(from: .right, glyphs: [shell], move: .arc, life: 5, delay: 1)]
                            + row(3, [plume], .flutter, life: 7, stagger: 1))
        case .spots:
            // A spot swaying up, then spots blooming along the edge in turn.
            return Look(lit: 0xF2C14E, settled: 0x5A3214, colours: ["o": 0xB5652A],
                        lead: [spot], route: .sway, trail: "o",
                        bits: (0..<6).map { i in
                            Bit(from: i == 5 ? .right : i == 0 ? .left : .top(CGFloat(i) * 0.2),
                                glyphs: [smallSpot, spot], move: .stay, life: 4, delay: (i * 2) % 5)
                        })
        case .bubbles:
            // Bubbles rising from the head, then off the top, popping.
            return Look(lit: 0xC4B8E6, settled: 0x433A5C, colours: ["b": 0x9CC4F0, "w": 0xFFFFFF],
                        lead: [smallBubble, bubble], route: .straight, trail: "b",
                        bits: row(5, [smallBubble, bubble, bubble, bubble, bubble, pop], .rise, life: 6))
        case .carrots:
            // A carrot hopping up, then fluff puffs bouncing off.
            return Look(lit: 0xF3A3B3, settled: 0x5A3F2A,
                        colours: ["o": 0xFF8A2A, "g": 0x5AA838, "c": 0xC9B5A8, "w": 0xFFFFFF],
                        lead: [carrot], route: .hop, trail: nil,
                        bits: row(4, [fluff], .rise, life: 6)
                            + [Bit(from: .left, glyphs: [fluff], move: .arc, life: 5, delay: 1),
                               Bit(from: .right, glyphs: [fluff], move: .arc, life: 5, delay: 2)])
        case .splash:
            // A fin cutting up through the water, then a splash.
            return Look(lit: 0x9CC4F0, settled: 0x2C3E52, colours: ["f": 0x7A96B4, "w": 0x8FD0FF, "W": 0x3A8EE8],
                        lead: [fin], route: .straight, trail: "w",
                        bits: row(6, [water], .arc, life: 6)
                            + [Bit(from: .left, glyphs: [water], move: .arc, life: 5),
                               Bit(from: .right, glyphs: [water], move: .arc, life: 5)])
        case .mud:
            // A mud blob bouncing up, mud splats and a heart or two.
            return Look(lit: 0xF7B3C2, settled: 0x6E3A48,
                        colours: ["m": 0xA8764E, "M": 0x7E5236, "r": 0xFF7F9A, "R": 0xE0718B],
                        lead: [mudBlob], route: .hop, trail: "m",
                        bits: row(4, [splat], .arc, life: 6)
                            + [Bit(from: .top(0.3), glyphs: [heart], move: .rise, life: 5, delay: 2),
                               Bit(from: .top(0.75), glyphs: [heart], move: .rise, life: 5, delay: 3)])
        case .sparkle(let rgb):
            // A star twinkling up, then sparkles round the edge.
            return Look(lit: mix(rgb, 0xFFFFFF, 0.35), settled: mix(rgb, 0x000000, 0.55),
                        colours: ["s": mix(rgb, 0xFFFFFF, 0.25), "S": mix(rgb, 0xFFFFFF, 0.7)],
                        lead: [star, twinkle], route: .straight, trail: "s",
                        bits: (0..<6).map { i in
                            Bit(from: i == 5 ? .right : i == 0 ? .left : .top(CGFloat(i) * 0.2),
                                glyphs: [speck, twinkle, star, twinkle, speck], move: .stay, life: 5, delay: (i * 3) % 4)
                        })
        }
    }

    // MARK: - Drawing

    /// The lead-in rising from the head to where the bubble will be.
    private static func lead(_ look: Look, frame: Int, in context: GraphicsContext, from start: CGPoint, to top: CGFloat) {
        func spot(_ f: Int) -> CGPoint {
            let t = CGFloat(f + 1) / CGFloat(lightFrame)
            var x = start.x, y = start.y - (start.y - top) * t
            switch look.route {
            case .straight: x += f % 2 == 0 ? 0 : px
            case .zigzag: x += f % 2 == 0 ? -6 : 6
            case .hop: y -= f % 2 == 0 ? 0 : 5
            case .sway: x += [-4, 0, 4, 0, -4][f % 5]
            case .steps: x += f % 2 == 0 ? -5 : 5
            }
            return CGPoint(x: x, y: y)
        }
        let glyph = look.lead[frame % look.lead.count]
        if look.route == .steps {
            // The prints it left on the way stay a moment.
            for f in max(0, frame - 2)..<frame {
                stamp(context, glyph, at: spot(f), look.colours, opacity: 0.35 + 0.25 * Double(f - frame + 2))
            }
        } else if let trail = look.trail {
            let behind = spot(frame).y + CGFloat(glyph.count) * px / 2
            for i in 0..<min(frame + 1, 3) {
                let x = spot(frame).x + (i % 2 == 0 ? -px : 0)
                stamp(context, [String(trail)], at: CGPoint(x: x, y: behind + CGFloat(i * 2 + 1) * px),
                      look.colours, opacity: 1 - Double(i) * 0.3)
            }
        }
        stamp(context, glyph, at: spot(frame), look.colours, opacity: 1)
    }

    private static func draw(_ bit: Bit, look: Look, age: Int, in context: GraphicsContext, body: CGRect) {
        guard let (point, glyph) = place(bit, age: age, body: body) else { return }
        let left = 1 - CGFloat(age) / CGFloat(bit.life + 1)
        let opacity = bit.move == .stay ? min(1, Double(left) * 2.2) : Double(0.4 + 0.6 * left)
        stamp(context, glyph, at: point, look.colours, opacity: opacity)
    }

    /// Where a bit is at `age` frames, and its glyph then; nil when it isn't out.
    private static func place(_ bit: Bit, age: Int, body: CGRect) -> (CGPoint, Glyph)? {
        guard age >= 0, age <= bit.life else { return nil }
        let a = CGFloat(age)
        let glyph = bit.glyphs[min(age, bit.glyphs.count - 1)]
        let reach = CGFloat(glyph.count) * px / 2 + 1
        // Where it leaves the edge, just outside it, and which way is out.
        var (x, y, out): (CGFloat, CGFloat, CGFloat)
        switch bit.from {
        case .top(let along): (x, y, out) = (body.minX + body.width * along, body.minY - reach, (along - 0.5) * 1.4)
        case .bottom(let along): (x, y, out) = (body.minX + body.width * along, body.maxY + reach, along < 0.5 ? -1 : 1)
        case .left: (x, y, out) = (body.minX - reach, body.midY, -1)
        case .right: (x, y, out) = (body.maxX + reach, body.midY, 1)
        }
        switch bit.move {
        case .burst: x += out * a * 1.4; y -= a * 1.3
        case .rise: x += age % 2 == 0 ? 0 : px; y -= a * 1.8
        case .arc: x += out * a * 1.6; y += -a * 2.4 + a * a * 0.45
        case .drip: y += age < 2 ? 0 : (a - 1) * (a - 1) * 0.9
        case .flutter: x += out * a * 0.8 + [0, 3, 3, 0, -3, -3][age % 6]; y += -5 + a * 1.2
        case .stomp: x += out * a * 2; y -= a * 0.5
        case .stay: break
        }
        return (CGPoint(x: x, y: y), glyph)
    }

    /// A glyph centred on a point, snapped to the pixel grid.
    private static func stamp(_ context: GraphicsContext, _ glyph: Glyph, at point: CGPoint, _ colours: [Character: UInt32], opacity: Double) {
        let left = snap(point.x - CGFloat(glyph.first?.count ?? 0) * px / 2)
        let top = snap(point.y - CGFloat(glyph.count) * px / 2)
        for (row, line) in glyph.enumerated() {
            for (col, letter) in line.enumerated() {
                guard let rgb = colours[letter] else { continue }
                let cell = CGRect(x: left + CGFloat(col) * px, y: top + CGFloat(row) * px, width: px, height: px)
                context.fill(Path(cell), with: .color(color(rgb).opacity(opacity)))
            }
        }
    }

    static func color(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }

    /// `rgb` moved `amount` of the way to `other`.
    static func mix(_ rgb: UInt32, _ other: UInt32, _ amount: Double) -> UInt32 {
        [16, 8, 0].reduce(UInt32(0)) { sum, shift in
            let a = Double((rgb >> UInt32(shift)) & 0xFF), b = Double((other >> UInt32(shift)) & 0xFF)
            return sum | UInt32((a + (b - a) * amount).rounded()) << UInt32(shift)
        }
    }

    private static func snap(_ value: CGFloat) -> CGFloat { (value / px).rounded() * px }
}

/// The dragon's: a puff of pixel fire from its head, the bubble catches
/// alight, throws a few sparks and settles with a warm edge.
enum BubbleFire {
    /// Room around the bubble for the puff below it and the sparks around it.
    /// The side sparks go 7 points past the edge, plus their own pixel.
    static let margin: CGFloat = 10
    private static let lightFrame = BubbleEffect.lightFrame
    private static let lastFrame = BubbleEffect.lastFrame

    /// The edge just lit and once settled: a faint warm brown instead of the usual grey.
    static let edges: (lit: UInt32, settled: UInt32) = (0xFF9926, 0x572914)
    private static let yellow = Color(red: 1, green: 0.86, blue: 0.3)
    private static let orange = Color(red: 1, green: 0.52, blue: 0.12)
    private static let red = Color(red: 0.86, green: 0.22, blue: 0.1)
    /// One pixel, in points.
    private static let px: CGFloat = 2

    /// Draws one frame over the bubble. `size` is the whole canvas, margin
    /// included; the bubble's body sits `margin` in from every edge with its
    /// 7-point tail pointing down.
    static func draw(_ frame: Int, in context: GraphicsContext, size: CGSize, outline: Path) {
        let body = CGRect(
            x: margin, y: margin,
            width: size.width - margin * 2, height: size.height - margin * 2 - 7
        )
        if frame < lightFrame {
            puff(frame, in: context, from: CGPoint(x: size.width / 2, y: size.height), to: body.midY - 4)
        } else {
            glow(frame, in: context, outline: outline)
            tips(frame, in: context, body: body)
            sparks(frame, in: context, body: body)
        }
    }

    /// A ball of fire rising from the head to where the bubble will be,
    /// growing as it goes, with an ember or two trailing behind.
    private static func puff(_ frame: Int, in context: GraphicsContext, from start: CGPoint, to top: CGFloat) {
        let t = CGFloat(frame + 1) / CGFloat(lightFrame)
        let x = snap(start.x + (frame % 2 == 0 ? 0 : px))
        let y = snap(start.y - (start.y - top) * t)
        // Pixel rows, top down: red rim, orange, yellow core.
        let rows: [[Character]] = frame < 2
            ? [[".", "r", "."], ["r", "y", "r"], [".", "o", "."]]
            : [[".", "r", "r", "."], ["r", "o", "y", "r"], ["r", "y", "o", "r"], [".", "o", "r", "."]]
        let w = CGFloat(rows[0].count) * px
        for (row, line) in rows.enumerated() {
            for (col, letter) in line.enumerated() where letter != "." {
                let color = letter == "y" ? yellow : letter == "o" ? orange : red
                dot(context, x - w / 2 + CGFloat(col) * px, y + CGFloat(row) * px, color)
            }
        }
        // Embers falling behind it.
        let tail = y + CGFloat(rows.count) * px
        for i in 0..<min(frame + 1, 3) {
            let ex = x + (i % 2 == 0 ? -px : 0)
            let ey = tail + CGFloat(i * 2 + 1) * px
            dot(context, ex, ey, (i == 0 ? orange : red).opacity(1 - Double(i) * 0.3))
        }
    }

    /// The edge lit up: a bright ring that cools over the frames.
    private static func glow(_ frame: Int, in context: GraphicsContext, outline: Path) {
        let fade = 1 - Double(frame - lightFrame) / Double(lastFrame - lightFrame + 1)
        context.stroke(outline, with: .color(orange.opacity(0.35 * fade)), lineWidth: 6)
        context.stroke(outline, with: .color(yellow.opacity(0.5 * fade)), lineWidth: 3)
    }

    /// Little flames along the top edge that flicker and die down.
    private static func tips(_ frame: Int, in context: GraphicsContext, body: CGRect) {
        let age = frame - lightFrame
        guard age < 5 else { return }
        let count = max(3, Int(body.width / 40))
        for i in 0..<count {
            let x = snap(body.minX + 14 + CGFloat(i % 2) * 4 + (body.width - 32) * CGFloat(i) / CGFloat(max(count - 1, 1)))
            // A height per tip and frame, shrinking as it burns out.
            let flicker = (i * 7 + frame * 3) % 3
            let height = max(0, 3 - age / 2 - (flicker == 0 ? 1 : 0))
            for h in 0..<height {
                let color = h == 0 ? orange : h == height - 1 ? yellow : orange
                dot(context, x, snap(body.minY) - CGFloat(h + 1) * px, color)
            }
            if height >= 2 { dot(context, x + px, snap(body.minY) - px, red) }
        }
    }

    /// Sparks thrown off the edge, drifting out and up and going dark.
    private static func sparks(_ frame: Int, in context: GraphicsContext, body: CGRect) {
        let age = CGFloat(frame - lightFrame)
        // Where each spark leaves the edge (0...1 around the top and sides),
        // and how long it lives.
        let seeds: [(along: CGFloat, life: Int)] = [
            (0.05, 5), (0.18, 7), (0.32, 4), (0.45, 6), (0.58, 7),
            (0.7, 5), (0.83, 6), (0.95, 4), (1.1, 6), (-0.1, 5),
        ]
        for seed in seeds where Int(age) <= seed.life {
            var x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat
            if seed.along < 0 {
                (x, y, dx, dy) = (body.minX, body.midY, -1, -0.5)
            } else if seed.along > 1 {
                (x, y, dx, dy) = (body.maxX, body.midY, 1, -0.5)
            } else {
                (x, y) = (body.minX + body.width * seed.along, body.minY)
                (dx, dy) = ((seed.along - 0.5) * 1.4, -1)
            }
            x += dx * age * 1.2
            y += dy * age * 1.2
            let left = 1 - age / CGFloat(seed.life + 1)
            let color = left > 0.66 ? yellow : left > 0.33 ? orange : red
            dot(context, snap(x), snap(y), color.opacity(Double(0.4 + 0.6 * left)))
        }
    }

    private static func dot(_ context: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ color: Color) {
        context.fill(Path(CGRect(x: x, y: y, width: px, height: px)), with: .color(color))
    }

    private static func snap(_ value: CGFloat) -> CGFloat { (value / px).rounded() * px }
}
