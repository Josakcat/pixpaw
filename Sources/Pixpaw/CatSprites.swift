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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orange: "Orange tabby"
        case .black: "Black"
        case .white: "White"
        case .gray: "Gray tabby"
        case .siamese: "Siamese"
        case .calico: "Calico"
        }
    }

    /// The swatch the widget draws for this coat.
    var swatch: NSColor {
        // Calico's base fur is white; its orange patches tell it apart from White.
        NSColor(rgb: CatArt.coats[rawValue]?[self == .calico ? "s" : "f"] ?? 0xFFFFFF)
    }
}

/// Who lives on the desktop: the cat, or a character picked instead of it.
/// Every character has the cat's frames, so the same moods drive them all.
/// `own1` to `own5` are the pets you drew yourself (see OwnPets.swift).
enum PetKind: String, CaseIterable, Identifiable, Codable {
    case cat, bee, parrot, dino, dog, hamster, chicken, giraffe, hippo, rabbit, shark
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

    /// Only the cat comes in coats; the others have their own colours.
    var hasCoats: Bool { self == .cat }

    /// Only the cat has a collar drawn for it; the others wear hats.
    var wearsCollars: Bool { self == .cat }

    /// Where a frame's art is: the cat's under its name, the others' as
    /// "<kind>.<frame>".
    func artKey(_ frame: CatFrame) -> String { self == .cat ? frame.rawValue : "\(rawValue).\(frame.rawValue)" }
}

enum CatFrame: String, CaseIterable {
    case sit, blink, walk1, walk2, walk3, run1, run2, groom1, groom2, sleep1, sleep2, happy, eat1, eat2, crouch1, crouch2, held1, held2

}

/// Things the cat can wear, unlocked with happiness points.
enum CatAccessory: String, CaseIterable, Identifiable, Codable {
    case redCollar, partyHat, bow, bellCollar, witchHat, santaHat, crown

    enum Slot { case hat, collar }

    var id: String { rawValue }

    var slot: Slot { self == .redCollar || self == .bellCollar ? .collar : .hat }

    var title: String {
        switch self {
        case .redCollar: "Red collar"
        case .partyHat: "Party hat"
        case .bow: "Bow"
        case .bellCollar: "Bell collar"
        case .witchHat: "Witch hat"
        case .santaHat: "Santa hat"
        case .crown: "Crown"
        }
    }

    /// Happiness points that unlock it.
    var unlockAt: Int {
        switch self {
        case .redCollar: 10
        case .partyHat: 25
        case .bow: 45
        case .bellCollar: 70
        case .witchHat: 100
        case .santaHat: 150
        case .crown: 220
        }
    }

    static func unlocked(at points: Int) -> [CatAccessory] { allCases.filter { $0.unlockAt <= points } }
    static func next(after points: Int) -> CatAccessory? { allCases.filter { $0.unlockAt > points }.min { $0.unlockAt < $1.unlockAt } }
}

/// Where happiness points come from, what each is worth, and how many times
/// a day it counts, so stars take days of real care rather than a minute of
/// clicking.
enum StarSource: String, Codable {
    case pet, meal, hungryMeal, play, catchFile, treat, gift, stretch, note

    static let dailyTotal = 30
    /// Petting again this soon after the last counted pet earns nothing.
    static let petCooldown: TimeInterval = 10

    var amount: Int {
        switch self {
        case .pet: 1
        case .meal: 3
        case .hungryMeal: 5
        case .play: 5
        case .catchFile: 2
        case .treat: 2
        case .gift: 3
        case .stretch: 2
        case .note: 2
        }
    }

    /// Meals share one daily count whether or not the cat was hungry.
    var counter: String { self == .hungryMeal ? StarSource.meal.rawValue : rawValue }

    var dailyLimit: Int {
        switch self {
        case .pet: 10
        case .meal, .hungryMeal: 3
        case .play: 3
        case .catchFile: 5
        case .treat: 3
        case .gift: 1
        case .stretch: 5
        case .note: 5
        }
    }
}

/// Today's tally, reset at local midnight.
struct StarDay: Codable, Equatable {
    var day: String
    var stars = 0
    var counts: [String: Int] = [:]
    var announcedCap = false

    static var today: String {
        // Gregorian, so switching the Mac's calendar never resets the day.
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
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

    /// The frame in its coat, wearing the hat and collar if it has them, and
    /// headphones in place of the hat while a pair is connected, or else a
    /// costume hat of the day (a party hat, a nightcap). The image
    /// grows upward when a hat rises above the art; the feet stay on the
    /// bottom row. `swing` pushes the legs that many art pixels sideways;
    /// `laptop` puts one in front of it, under its head, while it works.
    func image(_ frame: CatFrame, coat: CatCoat, hat: CatAccessory? = nil, collar: CatAccessory? = nil,
               headphones: Bool = false, costume: String? = nil, kind: PetKind = .cat, swing: Int = 0, laptop: Bool = false) -> CGImage? {
        let art = kind.artKey(frame)
        // No headphones are drawn for a pet you drew, so it keeps its hat on.
        let hat = headphones && !kind.isOwn ? nil : costume ?? hat?.rawValue
        let key = "\(kind.rawValue).\(coat.rawValue).\(frame.rawValue).\(hat ?? "-").\(collar?.rawValue ?? "-").\(headphones).\(swing).\(laptop)"
        if let hit = cache[key] { return hit }
        guard let rows = (CatArt.frames[art] ?? OwnPets.frames[art]).map({ swing == 0 ? $0 : Self.swing($0, by: swing) }),
              let palette = kind.isOwn ? OwnPets.colours[kind] : CatArt.coats[kind.hasCoats ? coat.rawValue : kind.rawValue] else { return nil }
        // A pet you drew wears its hat on top of its head, and no collar.
        let anchor = CatArt.anchors[art] ?? OwnPets.hatSpots[art].map { ($0.0, $0.1, -1.0, -1) }
        let width = rows.first?.count ?? 0

        // Accessory pixels laid over the art, in art coordinates (y may be negative).
        var overlay: [(x: Int, y: Int, rgb: UInt32)] = []
        if let anchor {
            for (item, isHat, centre, row) in [(hat, true, anchor.0, anchor.1), (collar?.rawValue, false, anchor.2, anchor.3)] {
                guard let item, row >= 0, let art = CatArt.accessories[item] else { continue }
                let left = Int((centre - Double(art[0].count) / 2).rounded())
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
