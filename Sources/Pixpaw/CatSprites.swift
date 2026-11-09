//
//  CatSprites.swift
//  Pixpaw
//
//  Turns the character grids in CatSprites.generated.swift into images, once
//  per coat, and keeps them.
//

import AppKit

/// The coats a cat can wear, in the order the widget lists them.
enum CatCoat: String, CaseIterable, Identifiable, Codable {
    case orange, black, white, gray, siamese, calico
    /// Your own cat's colours, read from a photo (see PhotoCoat.swift).
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orange: "Orange tabby"
        case .black: "Black"
        case .white: "White"
        case .gray: "Gray tabby"
        case .siamese: "Siamese"
        case .calico: "Calico"
        case .photo: "From your photo"
        }
    }

    /// Its colours by palette letter; until there's a photo, the gray tabby's.
    @MainActor var palette: [Character: UInt32]? {
        self == .photo ? PhotoCoat.palette ?? CatArt.coats[CatCoat.gray.rawValue] : CatArt.coats[rawValue]
    }

    /// The coats to pick from: the one from your photo once you've chosen a photo.
    @MainActor static var choices: [CatCoat] { allCases.filter { $0 != .photo || PhotoCoat.palette != nil } }

    /// The swatch the widget draws for this coat.
    @MainActor var swatch: NSColor {
        // Calico's base fur is white; its orange patches tell it apart from White.
        NSColor(rgb: palette?[self == .calico ? "s" : "f"] ?? 0xFFFFFF)
    }

    /// Whether a tick on the swatch wants to be white.
    @MainActor var isDark: Bool { (swatch.usingColorSpace(.sRGB)?.brightnessComponent ?? 1) < 0.45 }
}

/// Who lives on the desktop: the cat, or a character picked instead of it.
/// Every character has the cat's frames, so the same moods drive them all.
/// `own1` to `own5` are the pets you drew yourself (see OwnPets.swift).
enum PetKind: String, CaseIterable, Identifiable, Codable {
    case cat, bee, parrot, dino, dog, hamster, chicken, giraffe, hippo, rabbit, shark, pig
    case own1, own2, own3, own4, own5

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .own1, .own2, .own3, .own4, .own5: OwnPets.pet(self)?.name.nilIfEmpty ?? "Your pet"
        case .cat: "Cat"
        case .bee: "Bee"
        case .parrot: "Parrot"
        case .dino: "Dinosaur"
        case .dog: "Dog"
        case .hamster: "Hamster"
        case .chicken: "Chicken"
        case .giraffe: "Giraffe"
        case .hippo: "Hippo"
        case .rabbit: "Rabbit"
        case .shark: "Shark"
        case .pig: "Pig"
        }
    }

    /// The characters Pixpaw comes with.
    static let builtIn = allCases.filter { !$0.isOwn }

    /// Every character by name, A to Z, for the pickers, then the pets you drew.
    @MainActor static var alphabetical: [PetKind] {
        builtIn.sorted { $0.title < $1.title } + OwnPets.pets.map(\.kind)
    }

    var isOwn: Bool { rawValue.hasPrefix("own") }

    /// Whose sounds, words, ways of moving and home it has: its own, or for a
    /// pet you drew, the character you said it acts like.
    @MainActor var actsLike: PetKind { isOwn ? OwnPets.pet(self)?.actsLike ?? .cat : self }

    /// Flies (or, for the shark, swims through the air) wherever it likes,
    /// whatever the walking setting says.
    @MainActor var flies: Bool { actsLike == .bee || actsLike == .shark }

    /// Perches where the cat would stand, but takes off and flies whenever
    /// it goes somewhere.
    @MainActor var fliesWhenMoving: Bool { actsLike == .parrot }

    /// The games it plays, in its Play menu: a cat bats yarn and chases the
    /// teaser and the laser but won't fetch; a dog fetches, and so on.
    @MainActor var games: [PetGame] {
        switch actsLike {
        case .cat: [.mouse, .yarn, .teaser, .laser]
        case .dog: [.frisbee, .fetch, .yarn, .laser]
        case .dino: [.bigBone, .fetch, .yarn]
        case .hamster: [.seed, .yarn, .teaser]
        case .rabbit: [.carrot, .teaser, .yarn]
        case .chicken: [.worm, .laser, .teaser]
        case .parrot: [.bell, .fetch, .teaser]
        case .bee: [.flower, .laser, .teaser]
        case .giraffe: [.leaves, .teaser, .yarn]
        case .hippo: [.watermelon, .yarn, .fetch]
        case .shark: [.fish, .fetch, .laser]
        case .pig: [.watermelon, .carrot, .yarn]
        case .own1, .own2, .own3, .own4, .own5: [.yarn, .teaser, .laser]
        }
    }

    /// Only the cat comes in coats; the others have their own colours.
    var hasCoats: Bool { self == .cat }

    /// Only the cat has a collar drawn for it; the others wear hats.
    var wearsCollars: Bool { self == .cat }

    /// Where a frame's art is: the cat's under its name, the others' as
    /// "<kind>.<frame>".
    func artKey(_ frame: CatFrame) -> String { self == .cat ? frame.rawValue : "\(rawValue).\(frame.rawValue)" }
}

/// Something to play with, from the Play menu. Each is played one of four
/// ways: rolled about and batted like the yarn, dangled from the pointer
/// like the teaser, chased like the laser dot, or thrown for fetch.
enum PetGame: String, CaseIterable {
    case yarn, teaser, laser, fetch
    case mouse, frisbee, bigBone, seed, carrot, worm, bell, flower, leaves, watermelon, fish

    enum Way { case roll, dangle, chase, fetch }

    var way: Way {
        switch self {
        case .yarn, .mouse, .watermelon: .roll
        case .teaser, .seed, .carrot, .worm, .bell, .flower, .leaves: .dangle
        case .laser, .fish: .chase
        case .fetch, .frisbee, .bigBone: .fetch
        }
    }

    var title: String {
        switch self {
        case .yarn: "Yarn ball"
        case .teaser: "Feather teaser"
        case .laser: "Laser pointer"
        case .fetch: "Fetch"
        case .mouse: "Toy mouse"
        case .frisbee: "Frisbee"
        case .bigBone: "Big bone"
        case .seed: "Sunflower seed"
        case .carrot: "Carrot"
        case .worm: "Wiggly worm"
        case .bell: "Bell"
        case .flower: "Flower"
        case .leaves: "Fresh leaves"
        case .watermelon: "Watermelon"
        case .fish: "Little fish"
        }
    }

    var symbol: String {
        switch self {
        case .yarn: "circle.hexagongrid.fill"
        case .teaser: "wand.and.stars"
        case .laser: "smallcircle.filled.circle"
        case .fetch: "tennisball.fill"
        case .mouse: "pawprint.fill"
        case .frisbee: "opticaldisc.fill"
        case .bigBone: "lizard.fill"
        case .seed: "allergens"
        case .carrot: "carrot.fill"
        case .worm: "scribble"
        case .bell: "bell.fill"
        case .flower: "camera.macro"
        case .leaves: "leaf.fill"
        case .watermelon: "circle.bottomhalf.filled"
        case .fish: "fish.fill"
        }
    }
}

enum CatFrame: String, CaseIterable {
    case sit, blink, walk1, walk2, walk3, run1, run2, groom1, groom2, sleep1, sleep2, happy, eat1, eat2, crouch1, crouch2, held1, held2

}

enum CatEffect: String {
    case heart, zzz, fish, note, code, sweat, ghost, bowl, bowlEmpty, treat, krathong, skyLantern, redLantern, giftFlower, giftBone, giftBall, giftFeather, yarn1, yarn2, teaser, laser, dizzy1, dizzy2, dizzy3
}

@MainActor
final class CatSprites {
    static let shared = CatSprites()

    /// Points per art pixel.
    static let scale: CGFloat = 3
    static var catSize: CGSize { CGSize(width: CGFloat(CatArt.width) * scale, height: CGFloat(CatArt.height) * scale) }

    private var cache: [String: CGImage] = [:]
    /// Where each frame's eyes are, found once from its pixels.
    private var eyeCache: [String: [EyeBox]] = [:]

    /// A frame's eyes. A pose that closes them (a blink, a happy squint,
    /// grooming) borrows the sitting frame's, moved with the head, so glasses
    /// don't flicker off with every blink.
    private func eyes(_ art: String, kind: PetKind) -> [EyeBox] {
        if let hit = eyeCache[art] { return hit }
        let eye: Character = kind == .parrot ? "K" : "e"
        var found = CatArt.frames[art].map { WardrobeArt.eyes(in: $0, eye: eye) } ?? []
        let sit = kind.artKey(.sit)
        if WardrobeArt.borrowsSitEyes(art), art != sit, let rows = CatArt.frames[sit],
           let here = CatArt.anchors[art], let there = CatArt.anchors[sit] {
            // Moved with the head, as far as its hat spot moved.
            found = WardrobeArt.eyes(in: rows, eye: eye).map {
                WardrobeArt.moved($0, x: Int((here.0 - there.0).rounded()), y: here.1 - there.1)
            }
        }
        eyeCache[art] = found
        return found
    }

    /// Folded ears, like a Scottish Fold's, on every cat.
    var foldedEars = false {
        didSet { if foldedEars != oldValue { forgetDrawings() } }
    }

    /// Goes up whenever drawings already made are out of date (a new photo
    /// coat, ears folded), so a pet on screen knows to draw itself again.
    private(set) var version = 0

    func forgetDrawings() {
        cache.removeAll()
        version += 1
    }
    /// The frame in its coat, wearing the hat and collar if it has them, and
    /// headphones in place of the hat while a pair is connected, or else a
    /// costume hat of the day (a party hat, a nightcap). The image
    /// grows upward when a hat rises above the art; the feet stay on the
    /// bottom row. `swing` pushes the legs that many art pixels sideways;
    /// `laptop` puts one in front of it, under its head, while it works.
    func image(_ frame: CatFrame, coat: CatCoat, hat: CatAccessory? = nil, collar: CatAccessory? = nil, glasses: CatAccessory? = nil,
               headphones: Bool = false, costume: String? = nil, kind: PetKind = .cat, swing: Int = 0, laptop: Bool = false) -> CGImage? {
        let art = kind.artKey(frame)
        // No headphones are drawn for a pet you drew, so it keeps its hat on.
        let hat = headphones && !kind.isOwn ? nil : costume ?? hat?.rawValue
        // Glasses only where they are drawn: a built-in pet, eyes in view.
        let glasses = kind.isOwn ? nil : glasses
        let key = "\(kind.rawValue).\(coat.rawValue).\(frame.rawValue).\(hat ?? "-").\(collar?.rawValue ?? "-").\(glasses?.rawValue ?? "-").\(headphones).\(swing).\(laptop)"
        if let hit = cache[key] { return hit }
        let folded = foldedEars && kind == .cat
        guard let rows = (CatArt.frames[art] ?? OwnPets.frames[art]).map({ folded ? Self.fold($0) : $0 })
                .map({ swing == 0 ? $0 : Self.swing($0, by: swing) }),
              let palette = kind.isOwn ? OwnPets.colours[kind] : kind.hasCoats ? coat.palette : CatArt.coats[kind.rawValue] else { return nil }
        // A pet you drew wears its hat on top of its head, and no collar.
        let anchor = CatArt.anchors[art] ?? OwnPets.hatSpots[art].map { ($0.0, $0.1, -1.0, -1) }
        let width = rows.first?.count ?? 0

        // Accessory pixels laid over the art, in art coordinates (y may be negative).
        var overlay: [(x: Int, y: Int, rgb: UInt32)] = []
        let darkFur = palette["f"].map(WardrobeArt.isDark) ?? false
        // Glasses first, so a hat brim wins where they meet.
        if let glasses, !WardrobeArt.hidesGlasses(art) {
            for pixel in WardrobeArt.glasses(glasses, eyes: eyes(art, kind: kind), darkFur: darkFur) {
                if let rgb = CatArt.accessoryColors[pixel.colour], pixel.x >= 0, pixel.x < width {
                    overlay.append((pixel.x, pixel.y, rgb))
                }
            }
        }
        // The headset goes where headphones go, not on top of the head.
        if hat == CatAccessory.headset.rawValue, let (view, left, top) = CatArt.headphonesAt[art], let phones = CatArt.headphones[view] {
            for pixel in WardrobeArt.headset(phones, left: left, top: top, darkFur: darkFur) {
                if let rgb = CatArt.accessoryColors[pixel.colour], pixel.x >= 0, pixel.x < width {
                    overlay.append((pixel.x, pixel.y, rgb))
                }
            }
        }
        if let anchor {
            for (item, isHat, centre, row) in [(hat, true, anchor.0, anchor.1), (collar?.rawValue, false, anchor.2, anchor.3)] {
                guard let item, row >= 0, let art = CatArt.accessories[item] else { continue }
                let left = Int((centre - Double(art[0].count) / 2).rounded()) + (CatArt.accessoryShift[item] ?? 0)
                let top = isHat ? row - art.count + 1 - (CatArt.accessoryLift[item] ?? 0) : row
                for (y, line) in art.enumerated() {
                    for (x, char) in line.enumerated() {
                        if let rgb = CatArt.accessoryColors[char], left + x >= 0, left + x < width {
                            overlay.append((left + x, top + y, rgb))
                        }
                    }
                }
            }
        }
        if headphones, let (view, left, top) = CatArt.headphonesAt[art], let phones = CatArt.headphones[view] {
            for (y, line) in phones.enumerated() {
                for (x, char) in line.enumerated() {
                    if let rgb = CatArt.accessoryColors[char], left + x >= 0, left + x < width {
                        overlay.append((left + x, top + y, rgb))
                    }
                }
            }
        }
        if laptop, let computer = CatArt.accessories["laptop"], let anchor {
            // On the floor, centred under the head.
            let left = Int((anchor.0 - Double(computer[0].count) / 2).rounded())
            let top = rows.count - computer.count
            for (y, line) in computer.enumerated() {
                for (x, char) in line.enumerated() {
                    if let rgb = CatArt.accessoryColors[char], left + x >= 0, left + x < width {
                        overlay.append((left + x, top + y, rgb))
                    }
                }
            }
        }
        let pad = max(0, -(overlay.map(\.y).min() ?? 0))
        var grid: [[UInt32?]] = Array(repeating: Array(repeating: nil, count: width), count: pad)
        grid += rows.map { row in row.map { palette[$0] } }
        for pixel in overlay where pixel.y + pad < grid.count {
            grid[pixel.y + pad][pixel.x] = pixel.rgb
        }
        let image = Self.render(grid)
        cache[key] = image
        return image
    }

    /// The cat's ears folded down: each pointed ear (a tip over outline,
    /// pink, outline) loses its tip and lies flat as a line of outline.
    private static func fold(_ rows: [String]) -> [String] {
        var grid = rows.map(Array.init)
        for y in grid.indices.dropLast() {
            for x in grid[y].indices.dropFirst().dropLast() where grid[y][x] == "o" && (y == 0 || grid[y - 1][x] == ".")
                && x + 1 < grid[y + 1].count && String(grid[y + 1][x - 1...x + 1]) == "opo" {
                grid[y][x] = "."
                grid[y + 1][x] = "o"
            }
        }
        return grid.map { String($0) }
    }

    /// The bottom quarter of a frame (legs, tail) pushed `amount` art pixels
    /// sideways, its lowest rows by the whole amount and the rest by one:
    /// legs swinging the way the pet is carried.
    private static func swing(_ rows: [String], by amount: Int) -> [String] {
        let filled = rows.indices.filter { rows[$0].contains { $0 != "." } }
        guard let top = filled.first, let bottom = filled.last else { return rows }
        let hips = top + Int((Double(bottom - top + 1) * 0.75).rounded())
        let knees = hips + (bottom - hips + 1) / 2
        return rows.enumerated().map { y, row in
            let shift = y < hips ? 0 : y < knees ? amount.signum() : amount
            guard shift != 0 else { return row }
            let blank = String(repeating: ".", count: abs(shift))
            return shift > 0 ? blank + row.dropLast(shift) : String(row.dropFirst(-shift)) + blank
        }
    }

    /// A character sitting, for a menu: crisp pixels at `points` per art pixel
    /// on a Retina screen.
    func menuImage(_ kind: PetKind, coat: CatCoat, points: CGFloat = 1) -> NSImage? {
        guard let art = image(.sit, coat: coat, kind: kind) else { return nil }
        let factor = 2 * Int(points)
        let width = art.width * factor, height = art.height * factor
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(art, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return nil }
        return NSImage(cgImage: scaled, size: NSSize(width: CGFloat(art.width) * points, height: CGFloat(art.height) * points))
    }

    func image(_ effect: CatEffect) -> CGImage? {
        let key = "effect.\(effect.rawValue)"
        if let hit = cache[key] { return hit }
        guard let rows = CatArt.effects[effect.rawValue] else { return nil }
        let image = Self.render(rows, palette: CatArt.effectColors)
        cache[key] = image
        return image
    }

    /// The character's home; with someone asleep inside, the doorway is
    /// left open so the pet behind shows through it.
    func home(_ kind: PetKind, occupied: Bool) -> CGImage? {
        let key = "home.\(kind.actsLike.rawValue).\(occupied)"
        if let hit = cache[key] { return hit }
        guard let rows = CatArt.homes[kind.actsLike.rawValue] else { return nil }
        let image = Self.render(rows.map { row in row.map { occupied && $0 == "d" ? nil : CatArt.homeColors[$0] } })
        cache[key] = image
        return image
    }

    /// Drops every picture of a pet you drew, after its sheet changed.
    func forgetOwnPets() {
        cache = cache.filter { !$0.key.hasPrefix("own") }
    }

    private static func render(_ rows: [String], palette: [Character: UInt32]) -> CGImage? {
        render(rows.map { row in row.map { palette[$0] } })
    }

    /// One bitmap pixel per art pixel; layers scale it up with nearest-neighbour filtering.
    private static func render(_ grid: [[UInt32?]]) -> CGImage? {
        let height = grid.count
        let width = grid.first?.count ?? 0
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (y, row) in grid.enumerated() {
            for (x, colour) in row.enumerated() {
                guard let rgb = colour else { continue }
                let i = (y * width + x) * 4
                bytes[i] = UInt8((rgb >> 16) & 0xFF)
                bytes[i + 1] = UInt8((rgb >> 8) & 0xFF)
                bytes[i + 2] = UInt8(rgb & 0xFF)
                bytes[i + 3] = 0xFF
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}

extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
