//
//  HomeDecor.swift
//  Pixpaw
//
//  Things that stand beside the home, bought with stars: what they are,
//  what they cost, where they go and the wallet they are paid from. The
//  lifetime stars (`points`) never drop, so no hat or home locks again;
//  what is spent is counted on its own and the wallet is the difference.
//  Pure values, checked on their own (.droppykit/Tools/home-decor-check.swift).
//

import CoreGraphics
import Foundation

/// Things that stand beside the home. Raw values are kept in preferences.
enum HomeDecor: String, CaseIterable, Identifiable {
    case rug, plant, bowls, cushion, lamp, basket, books, mailbox
    /// A PNG you dropped on the widget, framed (`FramedPicture`): never
    /// sold, yours once you hang one.
    case picture

    /// What the shop and the menus list: the framed picture only once it's yours.
    static func shown(owned: Set<HomeDecor>) -> [HomeDecor] {
        allCases.filter { $0 != .picture || owned.contains(.picture) }
    }

    /// Left or right of the home, or the doormat in front of the doorway;
    /// far right once the home has grown (`Wrapped.widerHomeAt` days together).
    enum Spot: String, CaseIterable, Identifiable {
        case left, right, front, outer
        var id: String { rawValue }
        var title: String {
            switch self {
            case .left: "Left"
            case .right: "Right"
            case .front: "Doormat"
            case .outer: "Far right"
            }
        }

        /// The spots there are: the far right one only in a grown home.
        static func open(wide: Bool) -> [Spot] { wide ? allCases : allCases.filter { $0 != .outer } }
    }

    var id: String { rawValue }

    /// The doormat lies in front of the doorway; the rest stand beside it.
    var spots: [Spot] { self == .rug ? [.front] : [.left, .right, .outer] }

    /// The spots it can go in now.
    func spots(wide: Bool) -> [Spot] { spots.filter(Spot.open(wide: wide).contains) }

    var title: String {
        switch self {
        case .rug: "Doormat rug"
        case .plant: "Potted plant"
        case .bowls: "Pet bowls"
        case .cushion: "Comfy cushion"
        case .lamp: "Floor lamp"
        case .basket: "Toy basket"
        case .books: "Little bookshelf"
        case .mailbox: "Mailbox"
        case .picture: "Your picture"
        }
    }

    /// In stars, spent from the wallet.
    var price: Int {
        switch self {
        case .rug: 60
        case .plant: 80
        case .bowls: 90
        case .cushion: 110
        case .lamp: 140
        case .basket: 160
        case .books: 180
        case .mailbox: 220
        case .picture: 0
        }
    }

    var symbol: String {
        switch self {
        case .rug: "rectangle.portrait.bottomhalf.filled"
        case .plant: "leaf"
        case .bowls: "fork.knife"
        case .cushion: "bed.double"
        case .lamp: "lamp.floor"
        case .basket: "basket"
        case .books: "books.vertical"
        case .mailbox: "envelope"
        case .picture: "photo.artframe"
        }
    }

    /// What the pet says when it gets one: "A floor lamp, for me?"
    var thanks: String {
        let name: String = switch self {
        case .rug: "a doormat"
        case .plant: "a plant"
        case .bowls: "new bowls"
        case .cushion: "a comfy cushion"
        case .lamp: "a floor lamp"
        case .basket: "a toy basket"
        case .books: "a bookshelf"
        case .mailbox: "a mailbox"
        case .picture: "my own picture"
        }
        return name.prefix(1).uppercased() + name.dropFirst() + ", for me?"
    }

    // MARK: Each pet's own version

    /// The same thing (slot, price, save key, spot) drawn the way that animal
    /// lives: a cat's bowls are a fish dish, a hamster's lamp a water bottle.
    /// Owned items carry over between pets and just look like the current
    /// pet's version. `art` names the picture in `CatArt.decor` /
    /// `FineArt.decor`; `said` is what the pet calls it when it gets one.
    struct Variant: Equatable {
        let title: String
        let art: String
        let said: String
    }

    /// By the kind the home is drawn for (`PetKind.actsLike`'s raw value, so
    /// a pet you drew gets the version of the animal it acts like).
    static let variants: [String: [HomeDecor: Variant]] = [
        "cat": [
            .plant: Variant(title: "Cat grass", art: "plant.cat", said: "cat grass"),
            .bowls: Variant(title: "Fish dish", art: "bowls.cat", said: "a fish dish"),
            .cushion: Variant(title: "Round cushion", art: "cushion.cat", said: "a round cushion"),
            .basket: Variant(title: "Scratch post", art: "basket.cat", said: "a scratch post"),
        ],
        "bee": [
            .plant: Variant(title: "Nectar flowers", art: "plant.bee", said: "nectar flowers"),
            .bowls: Variant(title: "Bee bath", art: "bowls.bee", said: "a bee bath"),
            .cushion: Variant(title: "Big flower", art: "cushion.bee", said: "a big flower"),
            .books: Variant(title: "Honeycomb", art: "books.bee", said: "honeycomb"),
        ],
        "parrot": [
            .bowls: Variant(title: "Seed cup", art: "bowls.seed", said: "a seed cup"),
            .cushion: Variant(title: "Perch stand", art: "cushion.parrot", said: "a perch stand"),
            .basket: Variant(title: "Chew blocks", art: "basket.parrot", said: "chew blocks"),
        ],
        "dino": [
            .plant: Variant(title: "Giant fern", art: "plant.dino", said: "a giant fern"),
            .cushion: Variant(title: "Leaf nest", art: "cushion.dino", said: "a leaf nest"),
            .basket: Variant(title: "Egg nest", art: "basket.dino", said: "an egg nest"),
            .books: Variant(title: "Fossil shelf", art: "books.dino", said: "a fossil shelf"),
        ],
        "dog": [
            .bowls: Variant(title: "Bone bowl", art: "bowls.dog", said: "a bone bowl"),
            .cushion: Variant(title: "Dog bed", art: "cushion.dog", said: "a dog bed"),
            .basket: Variant(title: "Chew bones", art: "basket.dog", said: "chew bones"),
        ],
        "hamster": [
            .bowls: Variant(title: "Seed dish", art: "bowls.seed", said: "a seed dish"),
            .cushion: Variant(title: "Shavings nest", art: "cushion.hamster", said: "a shavings nest"),
            .lamp: Variant(title: "Water bottle", art: "lamp.hamster", said: "a water bottle"),
            .basket: Variant(title: "Hamster wheel", art: "basket.hamster", said: "a hamster wheel"),
        ],
        "chicken": [
            .bowls: Variant(title: "Grain feeder", art: "bowls.chicken", said: "a grain feeder"),
            .cushion: Variant(title: "Straw nest", art: "cushion.chicken", said: "a straw nest"),
            .basket: Variant(title: "Egg basket", art: "basket.chicken", said: "an egg basket"),
        ],
        "giraffe": [
            .plant: Variant(title: "Acacia browse", art: "plant.giraffe", said: "acacia browse"),
            .bowls: Variant(title: "Salt lick", art: "bowls.giraffe", said: "a salt lick"),
            .cushion: Variant(title: "Grass patch", art: "cushion.giraffe", said: "a grass patch"),
            .lamp: Variant(title: "Hay feeder", art: "hay.feeder", said: "a hay feeder"),
        ],
        "hippo": [
            .plant: Variant(title: "River grass", art: "plant.hippo", said: "river grass"),
            .bowls: Variant(title: "Watermelon", art: "bowls.hippo", said: "a watermelon"),
            .cushion: Variant(title: "Shallow pool", art: "cushion.hippo", said: "a shallow pool"),
            .basket: Variant(title: "Pumpkin pile", art: "basket.hippo", said: "a pumpkin pile"),
        ],
        "rabbit": [
            .bowls: Variant(title: "Hay rack", art: "hay.rack", said: "a hay rack"),
            .cushion: Variant(title: "Hay pile", art: "cushion.rabbit", said: "a hay pile"),
            .basket: Variant(title: "Willow ball", art: "basket.rabbit", said: "a willow ball"),
        ],
        "shark": [
            .plant: Variant(title: "Seaweed", art: "plant.shark", said: "seaweed"),
            .cushion: Variant(title: "Water tub", art: "cushion.shark", said: "a water tub"),
            .basket: Variant(title: "Treasure chest", art: "basket.shark", said: "a treasure chest"),
            .books: Variant(title: "Coral", art: "books.shark", said: "coral"),
            .mailbox: Variant(title: "Message bottle", art: "mailbox.shark", said: "a message bottle"),
        ],
        "pig": [
            .bowls: Variant(title: "Trough", art: "bowls.pig", said: "a trough"),
            .cushion: Variant(title: "Mud puddle", art: "cushion.pig", said: "a mud puddle"),
            .basket: Variant(title: "Veggie crate", art: "basket.pig", said: "a veggie crate"),
        ],
        "dragon": [
            .cushion: Variant(title: "Gold hoard", art: "cushion.dragon", said: "a gold hoard"),
            .lamp: Variant(title: "Fire torch", art: "lamp.dragon", said: "a fire torch"),
            .basket: Variant(title: "Gem pile", art: "basket.dragon", said: "a gem pile"),
        ],
    ]

    /// This pet's version, if it has its own. The cushion is each pet's own
    /// resting spot, a pet you drew keeping the cat's (`RestSpot.look`).
    func variant(for look: String?) -> Variant? { RestSpot.look(look, for: self).flatMap { Self.variants[$0]?[self] } }

    /// "Fish dish" for a cat, "Pet bowls" for a pet without its own bowls.
    func title(for look: String?) -> String { variant(for: look)?.title ?? title }

    /// The picture's name in `CatArt.decor` / `FineArt.decor`.
    func artKey(for look: String?) -> String { variant(for: look)?.art ?? rawValue }

    /// "A fish dish, for me?"
    func thanks(for look: String?) -> String {
        guard let said = variant(for: look)?.said else { return thanks }
        return said.prefix(1).uppercased() + said.dropFirst() + ", for me?"
    }
}

/// What stands where: one thing a spot, one spot a thing.
struct HomeDecorSet: Equatable, Hashable {
    var left: HomeDecor?
    var right: HomeDecor?
    var front: HomeDecor?
    /// Far right, beyond the right spot: only in a grown home.
    var outer: HomeDecor?

    subscript(spot: HomeDecor.Spot) -> HomeDecor? {
        get {
            switch spot {
            case .left: left
            case .right: right
            case .front: front
            case .outer: outer
            }
        }
        set {
            switch spot {
            case .left: left = newValue
            case .right: right = newValue
            case .front: front = newValue
            case .outer: outer = newValue
            }
        }
    }

    var isEmpty: Bool { left == nil && right == nil && front == nil && outer == nil }

    /// Where it stands, if it is out.
    func spot(of item: HomeDecor) -> HomeDecor.Spot? {
        HomeDecor.Spot.allCases.first { self[$0] == item }
    }

    /// Puts it in a spot it fits (off any other spot), or with nil empties the spot.
    func placing(_ item: HomeDecor?, in spot: HomeDecor.Spot) -> HomeDecorSet {
        var set = self
        if let item {
            guard item.spots.contains(spot) else { return self }
            if let was = set.spot(of: item) { set[was] = nil }
        }
        set[spot] = item
        return set
    }

    /// The first empty spot it fits, if any (far right only in a grown home).
    func freeSpot(for item: HomeDecor, wide: Bool = false) -> HomeDecor.Spot? {
        item.spots(wide: wide).first { self[$0] == nil }
    }

    /// "left=lamp,right=plant,front=rug", for preferences.
    var saved: String {
        HomeDecor.Spot.allCases.compactMap { spot in self[spot].map { "\(spot.rawValue)=\($0.rawValue)" } }.joined(separator: ",")
    }

    /// Read back, keeping only what is owned and fits where it was put.
    init(saved: String, owned: Set<HomeDecor>) {
        for pair in saved.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, let place = HomeDecor.Spot(rawValue: parts[0]), let item = HomeDecor(rawValue: parts[1]),
                  owned.contains(item), self.spot(of: item) == nil else { continue }
            self = placing(item, in: place)
        }
    }

    init(left: HomeDecor? = nil, right: HomeDecor? = nil, front: HomeDecor? = nil, outer: HomeDecor? = nil) {
        self.left = left
        self.right = right
        self.front = front
        self.outer = outer
    }
}

/// Buying: the lifetime stars stay, what is spent is counted beside them.
enum DecorShop {
    /// Stars there are to spend.
    static func wallet(points: Int, spent: Int) -> Int { max(0, points - spent) }

    /// How many more stars it needs, 0 when it can be bought now.
    static func short(of item: HomeDecor, points: Int, spent: Int) -> Int {
        max(0, item.price - wallet(points: points, spent: spent))
    }

    /// "Floor lamp · 140 ★", or "Floor lamp · 30 ★ more" while the wallet is short;
    /// `look` names it as that pet's version ("Fish dish · 90 ★").
    static func label(_ item: HomeDecor, points: Int, spent: Int, look: String? = nil) -> String {
        let more = short(of: item, points: points, spent: spent), title = item.title(for: look)
        return more > 0 ? "\(title) · \(more) ★ more" : "\(title) · \(item.price) ★"
    }

    struct Purchase: Equatable {
        var spent: Int
        var owned: Set<HomeDecor>
        var placed: HomeDecorSet
    }

    /// Spends its price, owns it and puts it in the first free spot it fits;
    /// nil when it is owned already or the wallet is short.
    static func buy(_ item: HomeDecor, points: Int, spent: Int, owned: Set<HomeDecor>, placed: HomeDecorSet,
                    wide: Bool = false) -> Purchase? {
        guard !owned.contains(item), wallet(points: points, spent: spent) >= item.price else { return nil }
        let spot = placed.freeSpot(for: item, wide: wide)
        return Purchase(spent: spent + item.price, owned: owned.union([item]),
                        placed: spot.map { placed.placing(item, in: $0) } ?? placed)
    }

    /// "rug,lamp", in price order, for preferences.
    static func saved(_ owned: Set<HomeDecor>) -> String {
        HomeDecor.allCases.filter(owned.contains).map(\.rawValue).joined(separator: ",")
    }

    static func owned(saved: String) -> Set<HomeDecor> {
        Set(saved.split(separator: ",").compactMap { HomeDecor(rawValue: String($0)) })
    }
}

/// Where decorations go around the home, in the art's pixels (classic, or
/// twice that for HD): a slot each side only while something stands there.
struct HomeDecorLayout: Equatable {
    /// Columns added on the left and right of the home.
    let left: Int
    let right: Int

    init(_ set: HomeDecorSet, slot: Int) {
        left = set.left == nil ? 0 : slot
        // Far right stands a slot beyond the right one, used or not.
        right = set.outer != nil ? 2 * slot : set.right == nil ? 0 : slot
    }

    /// Columns of the whole picture.
    func width(home: Int) -> Int { left + home + right }

    /// Left column of a thing standing in a side slot: hugging the home with
    /// `gap` columns between them.
    func sideX(_ spot: HomeDecor.Spot, itemWidth: Int, home: Int, slot: Int, gap: Int) -> Int {
        switch spot {
        case .left: max(0, slot - gap - itemWidth)
        case .outer: left + home + slot + min(gap, max(0, slot - itemWidth))
        default: left + home + min(gap, max(0, slot - itemWidth))
        }
    }

    /// Left column of the doormat: centred under where the pet sleeps (its
    /// frame's left column `spotX`, frame `frameWidth` wide).
    func frontX(itemWidth: Int, spotX: Int, frameWidth: Int) -> Int {
        left + spotX + (frameWidth - itemWidth) / 2
    }
}

extension HomeDecorLayout {
    /// Where a thing stands in the picture, in its art's pixels from the
    /// bottom-left (the view's way up): a side thing in its slot, the
    /// doormat under where the pet sleeps. Every thing stands on the floor.
    func rect(_ spot: HomeDecor.Spot, itemWidth: Int, itemHeight: Int, home: Int, slot: Int, gap: Int,
              spotX: Int, frameWidth: Int) -> CGRect {
        let x = spot == .front ? frontX(itemWidth: itemWidth, spotX: spotX, frameWidth: frameWidth)
                               : sideX(spot, itemWidth: itemWidth, home: home, slot: slot, gap: gap)
        return CGRect(x: x, y: 0, width: itemWidth, height: itemHeight)
    }

    /// The thing beside the home under a click (a little slack round it),
    /// or nil for the home itself; the doormat is the home's own.
    static func hit(_ point: CGPoint, in rects: [(HomeDecor, CGRect)], slack: CGFloat = 2) -> HomeDecor? {
        rects.first(where: { $0.0 != .rug && $0.1.insetBy(dx: -slack, dy: -slack).contains(point) })?.0
    }
}

// MARK: Using them

/// When the pet goes over to a thing beside its home by itself, and which.
enum DecorUse {
    /// Between two uses it picked itself; a click doesn't wait.
    static let cooldown: TimeInterval = 90

    static func ready(now: Date, last: Date?) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= cooldown
    }

    /// The lamp is lit from seven in the evening to six in the morning.
    static func isNight(hour: Int) -> Bool { hour >= 19 || hour < 6 }

    /// How much it fancies each thing now (0: not by itself).
    static func weight(_ item: HomeDecor, hungry: Bool, night: Bool, hasMail: Bool) -> Int {
        switch item {
        case .rug: 0
        case .bowls: hungry ? 1 : 0
        case .mailbox: hasMail ? 1 : 0
        case .cushion, .basket: 3
        case .plant, .books, .picture: 2
        case .lamp: night ? 4 : 1
        }
    }

    /// What it picks from what stands there: hungry, the bowls; a letter
    /// waiting, the mailbox; otherwise by weight, `roll` in 0..<1.
    static func pick(_ placed: HomeDecorSet, hungry: Bool, night: Bool, hasMail: Bool, roll: Double) -> HomeDecor? {
        let items = HomeDecor.Spot.allCases.compactMap { placed[$0] }
        if hungry, items.contains(.bowls) { return .bowls }
        if hasMail, items.contains(.mailbox) { return .mailbox }
        let weighted = items.map { ($0, weight($0, hungry: hungry, night: night, hasMail: hasMail)) }.filter { $0.1 > 0 }
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var left = Int(max(0, min(0.999_999, roll)) * Double(total))
        for (item, weight) in weighted {
            if left < weight { return item }
            left -= weight
        }
        return weighted.last?.0
    }
}

/// Letters for the mailbox: what was earned since it was last checked (a
/// hundred stars more, something unlocked). Its flag is up while one waits.
/// Kept only while the pet is out; nothing comes from anywhere else.
struct Mailbox: Equatable {
    static let holds = 3
    private(set) var letters: [String] = []

    var hasMail: Bool { !letters.isEmpty }

    /// A new letter, the oldest dropped past `holds`; the same twice is one.
    mutating func post(_ text: String) {
        guard !letters.contains(text) else { return }
        letters.append(text)
        if letters.count > Self.holds { letters.removeFirst(letters.count - Self.holds) }
    }

    /// The newest letter, taken out; the flag goes down with the last.
    mutating func take() -> String? { letters.popLast() }

    /// A hundred stars more: the hundred passed, if stars went past one.
    static func milestone(before: Int, after: Int) -> Int? {
        let passed = after / 100 * 100
        return after > before && passed > before && passed > 0 ? passed : nil
    }
}
