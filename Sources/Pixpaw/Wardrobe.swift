//
//  Wardrobe.swift
//  Pixpaw
//
//  Stars, and the things to wear they unlock: what each thing is, where it
//  goes, who it is drawn for, and what opens it (stars, days in a row, an
//  all-time count). Also the drawing rules that need no art of their own:
//  glasses found from a frame's eye pixels, and the headset built on the
//  headphones' spot. Foundation only and pure, so Tools/wardrobe-check.swift
//  checks it without Droppy.
//

import Foundation

/// Things the pet can wear. Raw values are kept in preferences and URLs
/// (`?hat=crown`), so they never change.
enum CatAccessory: String, CaseIterable, Identifiable, Codable {
    case redCollar, partyHat, bow, bellCollar, witchHat, santaHat, crown
    case flowerCrown, roundGlasses, beanie, acornCap, sunglasses
    case headset, pencil, workTie, nameBadge, sprout

    /// Where it goes; the raw value is the menu's and the URL's word.
    enum Slot: String, CaseIterable { case hat, face, collar }

    /// What opens it.
    enum Unlock: Equatable {
        case stars(Int)
        /// Stars earned on this many days in a row, once.
        case streak(Int)
        /// An all-time count of something done together.
        case count(PetStat, Int)
        /// Days since you first let it out.
        case daysTogether(Int)
    }

    var id: String { rawValue }

    var slot: Slot {
        switch self {
        case .redCollar, .bellCollar, .workTie, .nameBadge: .collar
        case .roundGlasses, .sunglasses: .face
        default: .hat
        }
    }

    var title: String {
        switch self {
        case .redCollar: "Red collar"
        case .partyHat: "Party hat"
        case .bow: "Bow"
        case .bellCollar: "Bell collar"
        case .witchHat: "Witch hat"
        case .santaHat: "Santa hat"
        case .crown: "Crown"
        case .flowerCrown: "Flower crown"
        case .roundGlasses: "Round glasses"
        case .beanie: "Knit beanie"
        case .acornCap: "Acorn cap"
        case .sunglasses: "Sunglasses"
        case .headset: "Tiny headset"
        case .pencil: "Pencil behind the ear"
        case .workTie: "Work tie"
        case .nameBadge: "Name badge"
        case .sprout: "Little sprout"
        }
    }

    var unlock: Unlock {
        switch self {
        case .redCollar: .stars(10)
        case .partyHat: .stars(25)
        case .bow: .stars(45)
        case .bellCollar: .stars(70)
        case .witchHat: .stars(100)
        case .santaHat: .stars(150)
        case .flowerCrown: .stars(180)
        case .crown: .stars(220)
        case .roundGlasses: .stars(260)
        case .beanie: .stars(300)
        case .acornCap: .stars(400)
        case .sunglasses: .stars(600)
        case .headset: .count(.focusRounds, 100)
        case .pencil: .count(.notesDone, 25)
        case .workTie: .count(.bugsCaught, 50)
        case .nameBadge: .daysTogether(30)
        case .sprout: .streak(7)
        }
    }

    /// Opened by something done rather than by stars.
    var isAchievement: Bool {
        if case .stars = unlock { return false }
        return true
    }

    /// Who it is drawn for. Collars sit where only the cat has a neck drawn;
    /// glasses and the headset need eyes and headphone spots, which a pet you
    /// drew doesn't have; the acorn cap is for the small ones. The dragon's
    /// three small heads take a hat on the middle one, and no glasses or headset.
    func fits(_ wearer: Wearer) -> Bool {
        if self == .acornCap { return wearer.looksLike == "hamster" || wearer.looksLike == "rabbit" }
        let dragon = !wearer.isOwn && wearer.looksLike == "dragon"
        switch slot {
        case .hat: return self != .headset || (!wearer.isOwn && !dragon)
        case .face: return !wearer.isOwn && !dragon
        case .collar: return wearer.hasNeck
        }
    }

    /// How far along it is: done out of needed, done never past needed.
    func progress(_ p: WardrobeProgress) -> (done: Int, needed: Int) {
        switch unlock {
        case .stars(let n): (min(p.stars, n), n)
        case .streak(let n): (p.bestStreak >= n ? n : min(p.streak, n), n)
        case .count(let stat, let n): (min(p.counts[stat] ?? 0, n), n)
        case .daysTogether(let n): (min(p.daysTogether, n), n)
        }
    }

    func isUnlocked(_ p: WardrobeProgress) -> Bool {
        let (done, needed) = progress(p)
        return done >= needed
    }

    /// What's left, for a locked one: "18 ★ to go", "2 more days in a row",
    /// "62 / 100 focus rounds", "21 / 30 days together".
    func whatsLeft(_ p: WardrobeProgress) -> String {
        let (done, needed) = progress(p)
        switch unlock {
        case .stars: return "\(needed - done) ★ to go"
        case .streak:
            let left = needed - done
            return left == 1 ? "1 more day in a row" : "\(left) more days in a row"
        case .count(let stat, _): return "\(done) / \(needed) \(stat.wardrobeWords)"
        case .daysTogether: return "\(done) / \(needed) days together"
        }
    }

    /// How it is opened, for a tip: "300 ★", "Stars 7 days in a row".
    var howToGet: String {
        switch unlock {
        case .stars(let n): "\(n) ★"
        case .streak(let n): "Stars on \(n) days in a row"
        case .count(let stat, let n): "\(n) \(stat.wardrobeWords)"
        case .daysTogether(let n): "\(n) days together"
        }
    }

    /// Everything `after` opens that `before` hadn't, in the order they are listed.
    static func newlyUnlocked(before: WardrobeProgress, after: WardrobeProgress) -> [CatAccessory] {
        allCases.filter { !$0.isUnlocked(before) && $0.isUnlocked(after) }
    }

    /// The locked thing for this slot the wearer is nearest to, for the menu.
    static func next(in slot: Slot, for wearer: Wearer, _ p: WardrobeProgress) -> CatAccessory? {
        allCases.filter { $0.slot == slot && $0.fits(wearer) && !$0.isUnlocked(p) }
            .max { a, b in
                let (x, y) = (a.progress(p), b.progress(p))
                return Double(x.done) / Double(x.needed) < Double(y.done) / Double(y.needed)
            }
    }

    /// The next thing stars open, for the stars line.
    static func nextByStars(after points: Int) -> CatAccessory? {
        allCases.compactMap { item -> (CatAccessory, Int)? in
            if case .stars(let n) = item.unlock, n > points { return (item, n) }
            return nil
        }.min { $0.1 < $1.1 }?.0
    }
}

/// What a pet is like, for whether a thing fits it.
struct Wearer: Equatable {
    var isOwn: Bool
    /// Has a collar spot drawn: only the cat, for now.
    var hasNeck: Bool
    /// Its kind's name, or for a pet you drew, the kind it acts like.
    var looksLike: String
}

/// Everything that opens things to wear.
struct WardrobeProgress: Equatable {
    var stars = 0
    /// Days in a row with stars, the run going now and the longest.
    var streak = 0
    var bestStreak = 0
    var counts: [PetStat: Int] = [:]
    var daysTogether = 0
}

extension PetStat {
    /// The count's words on a locked thing: "62 / 100 focus rounds".
    var wardrobeWords: String {
        switch self {
        case .focusRounds: "focus rounds"
        case .notesDone: "notes done"
        case .bugsCaught: "bugs caught"
        default: rawValue
        }
    }
}

// MARK: - Drawing without art

/// Where a frame's eyes are, in art pixels.
struct EyeBox: Equatable {
    var x0: Int, x1: Int, y0: Int, y1: Int
}

/// One accessory pixel: where, and its letter in `CatArt.accessoryColors`.
struct WornPixel: Equatable {
    var x: Int, y: Int, colour: Character
}

enum WardrobeArt {
    /// The frames that show the face with the eyes closed and the head
    /// elsewhere (carried, asleep): no glasses there.
    /// Takes an art key, "sleep1" or "dog.sleep1".
    static func hidesGlasses(_ frame: String) -> Bool {
        let pose = frame.split(separator: ".").last.map(String.init) ?? frame
        return pose.hasPrefix("held") || pose.hasPrefix("sleep")
    }

    /// Poses that close the eyes with the head where it sits (a blink, a
    /// happy squint, grooming): they borrow the sitting frame's eyes, moved
    /// with the head, as
    /// what's left of the eye colour there can be a nose (the dog's).
    static func borrowsSitEyes(_ frame: String) -> Bool {
        let pose = frame.split(separator: ".").last.map(String.init) ?? frame
        return pose == "blink" || pose == "happy" || pose.hasPrefix("groom")
    }

    static func moved(_ box: EyeBox, x: Int, y: Int) -> EyeBox {
        EyeBox(x0: box.x0 + x, x1: box.x1 + x, y0: box.y0 + y, y1: box.y1 + y)
    }

    /// The eyes: pixels of the eye letter, grouped where they touch, keeping
    /// only the topmost (a pig's nostrils share the eye colour, lower down).
    /// Two boxes is a face seen from the front, one from the side.
    static func eyes(in rows: [String], eye: Character) -> [EyeBox] {
        var clusters: [[(x: Int, y: Int)]] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == eye {
                let near = clusters.indices.filter { i in clusters[i].contains { abs($0.x - x) <= 1 && abs($0.y - y) <= 1 } }
                if let first = near.first {
                    // Join every cluster this pixel touches into the first.
                    for i in near.dropFirst().reversed() { clusters[first] += clusters.remove(at: i) }
                    clusters[first].append((x, y))
                } else {
                    clusters.append([(x, y)])
                }
            }
        }
        let boxes = clusters.map { c in
            EyeBox(x0: c.map(\.x).min()!, x1: c.map(\.x).max()!, y0: c.map(\.y).min()!, y1: c.map(\.y).max()!)
        }
        guard let top = boxes.map(\.y0).min() else { return [] }
        return boxes.filter { $0.y0 == top }.sorted { $0.x0 < $1.x0 }
    }

    /// Dark enough that dark glasses would vanish on it (the black cat).
    static func isDark(_ rgb: UInt32) -> Bool {
        let r = Double(rgb >> 16 & 0xFF), g = Double(rgb >> 8 & 0xFF), b = Double(rgb & 0xFF)
        return 0.299 * r + 0.587 * g + 0.114 * b < 70
    }

    /// Glasses around the eyes. Round ones are a ring each eye shows
    /// through; sunglasses are dark lenses at least two rows tall with a
    /// glint, and on dark fur a silver rim so they still read. From the
    /// front a bridge joins the lenses; from the side an arm runs back.
    static func glasses(_ item: CatAccessory, eyes: [EyeBox], darkFur: Bool) -> [WornPixel] {
        guard !eyes.isEmpty, item.slot == .face else { return [] }
        let rim: Character = darkFur ? "g" : "k"
        var pixels: [WornPixel] = []
        for b in eyes {
            if item == .sunglasses {
                for y in b.y0...max(b.y1, b.y0 + 1) {
                    for x in (b.x0 - 1)...(b.x1 + 1) { pixels.append(WornPixel(x: x, y: y, colour: "k")) }
                }
                pixels.append(WornPixel(x: b.x1 + 1, y: b.y0, colour: "l"))
                if darkFur {
                    for x in (b.x0 - 1)...(b.x1 + 1) { pixels.append(WornPixel(x: x, y: b.y0 - 1, colour: "g")) }
                }
            } else {
                for y in (b.y0 - 1)...(b.y1 + 1) {
                    for x in (b.x0 - 1)...(b.x1 + 1) where y == b.y0 - 1 || y == b.y1 + 1 || x == b.x0 - 1 || x == b.x1 + 1 {
                        pixels.append(WornPixel(x: x, y: y, colour: rim))
                    }
                }
            }
        }
        let frame: Character = item == .sunglasses ? (darkFur ? "g" : "k") : rim
        if eyes.count >= 2 {
            let (a, b) = (eyes[0], eyes[1])
            if a.x1 + 2 < b.x0 - 1 {
                for x in (a.x1 + 2)..<(b.x0 - 1) { pixels.append(WornPixel(x: x, y: a.y0, colour: frame)) }
            }
        } else {
            let b = eyes[0]
            pixels.append(WornPixel(x: b.x0 - 2, y: b.y0, colour: frame))
            pixels.append(WornPixel(x: b.x0 - 3, y: b.y0, colour: frame))
        }
        return pixels
    }

    /// The headset: the headphones' band and cups at their spot, in grey on
    /// dark fur and near-black otherwise, with a mic from the lowest cup
    /// forward under the chin and a red tip. `size` is the mic's thickness,
    /// 2 for finer art.
    static func headset(_ phones: [String], left: Int, top: Int, darkFur: Bool, size: Int = 1) -> [WornPixel] {
        let colour: Character = darkFur ? "G" : "k"
        var pixels: [WornPixel] = []
        for (y, line) in phones.enumerated() {
            for (x, ch) in line.enumerated() where ch != "." { pixels.append(WornPixel(x: left + x, y: top + y, colour: colour)) }
        }
        guard let bottom = pixels.map(\.y).max(), let last = phones.last else { return pixels }
        let cup = pixels.filter { $0.y == bottom }.map(\.x)
        // Cups in both halves of the bottom row: seen from the front, so the
        // mic comes off the left cup; from the side, off the one cup.
        let front = cup.min()! - left < last.count / 2 && cup.max()! - left >= last.count / 2
        let start = front ? cup.min()! : cup.max()!
        for along in 0..<(2 * size) {
            for down in 1...size {
                pixels.append(WornPixel(x: start + 1 + along, y: bottom + down, colour: along < size ? colour : "r"))
            }
        }
        return pixels
    }
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

    static var today: String { string(for: Date()) }

    static var yesterday: String { string(for: Date(), dayBefore: true) }

    /// A day's name, "2026-11-8". Gregorian, so switching the Mac's calendar
    /// never resets the day; `dayBefore` names the calendar day before it.
    static func string(for date: Date, dayBefore: Bool = false) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let day = dayBefore ? calendar.date(byAdding: .day, value: -1, to: date) ?? date : date
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
