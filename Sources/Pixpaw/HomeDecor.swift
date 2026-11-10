//
//  HomeDecor.swift
//  Pixpaw
//
//  Things that stand beside the home, bought with stars: what they are,
//  what they cost, where they go and the wallet they are paid from. The
//  lifetime stars (`points`) never drop, so no hat or home locks again;
//  what is spent is counted on its own and the wallet is the difference.
//  Pure values, checked on their own (Tools/home-decor-check.swift).
//

import Foundation

/// Things that stand beside the home. Raw values are kept in preferences.
enum HomeDecor: String, CaseIterable, Identifiable {
    case rug, plant, bowls, cushion, lamp, basket, books, mailbox

    /// Left or right of the home, or the doormat in front of the doorway.
    enum Spot: String, CaseIterable, Identifiable {
        case left, right, front
        var id: String { rawValue }
        var title: String {
            switch self {
            case .left: "Left"
            case .right: "Right"
            case .front: "Doormat"
            }
        }
    }

    var id: String { rawValue }

    /// The doormat lies in front of the doorway; the rest stand beside it.
    var spots: [Spot] { self == .rug ? [.front] : [.left, .right] }

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
            .cushion: Variant(title: "Cat bed", art: "cushion.cat", said: "a cat bed"),
            .basket: Variant(title: "Scratch post", art: "basket.cat", said: "a scratch post"),
        ],
        "bee": [
            .plant: Variant(title: "Nectar flowers", art: "plant.bee", said: "nectar flowers"),
            .bowls: Variant(title: "Bee bath", art: "bowls.bee", said: "a bee bath"),
            .books: Variant(title: "Honeycomb", art: "books.bee", said: "honeycomb"),
        ],
        "parrot": [
            .bowls: Variant(title: "Seed cup", art: "bowls.seed", said: "a seed cup"),
            .cushion: Variant(title: "Perch swing", art: "cushion.parrot", said: "a perch swing"),
            .basket: Variant(title: "Chew blocks", art: "basket.parrot", said: "chew blocks"),
        ],
        "dino": [
            .plant: Variant(title: "Giant fern", art: "plant.dino", said: "a giant fern"),
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
            .cushion: Variant(title: "Hidey hut", art: "cushion.hamster", said: "a hidey hut"),
            .lamp: Variant(title: "Water bottle", art: "lamp.hamster", said: "a water bottle"),
            .basket: Variant(title: "Hamster wheel", art: "basket.hamster", said: "a hamster wheel"),
        ],
        "chicken": [
            .bowls: Variant(title: "Grain feeder", art: "bowls.chicken", said: "a grain feeder"),
            .cushion: Variant(title: "Nest box", art: "cushion.chicken", said: "a nest box"),
            .basket: Variant(title: "Egg basket", art: "basket.chicken", said: "an egg basket"),
        ],
        "giraffe": [
            .plant: Variant(title: "Acacia browse", art: "plant.giraffe", said: "acacia browse"),
            .bowls: Variant(title: "Salt lick", art: "bowls.giraffe", said: "a salt lick"),
            .lamp: Variant(title: "Hay feeder", art: "hay.feeder", said: "a hay feeder"),
        ],
        "hippo": [
            .plant: Variant(title: "River grass", art: "plant.hippo", said: "river grass"),
            .bowls: Variant(title: "Watermelon", art: "bowls.hippo", said: "a watermelon"),
            .basket: Variant(title: "Pumpkin pile", art: "basket.hippo", said: "a pumpkin pile"),
        ],
        "rabbit": [
            .bowls: Variant(title: "Hay rack", art: "hay.rack", said: "a hay rack"),
            .cushion: Variant(title: "Hidey tunnel", art: "cushion.rabbit", said: "a hidey tunnel"),
            .basket: Variant(title: "Willow ball", art: "basket.rabbit", said: "a willow ball"),
        ],
        "shark": [
            .plant: Variant(title: "Seaweed", art: "plant.shark", said: "seaweed"),
            .basket: Variant(title: "Treasure chest", art: "basket.shark", said: "a treasure chest"),
            .books: Variant(title: "Coral", art: "books.shark", said: "coral"),
            .mailbox: Variant(title: "Message bottle", art: "mailbox.shark", said: "a message bottle"),
        ],
        "pig": [
            .bowls: Variant(title: "Trough", art: "bowls.pig", said: "a trough"),
            .cushion: Variant(title: "Straw bed", art: "cushion.pig", said: "a straw bed"),
            .basket: Variant(title: "Veggie crate", art: "basket.pig", said: "a veggie crate"),
        ],
        "dragon": [
            .cushion: Variant(title: "Gold hoard", art: "cushion.dragon", said: "a gold hoard"),
            .lamp: Variant(title: "Fire torch", art: "lamp.dragon", said: "a fire torch"),
            .basket: Variant(title: "Gem pile", art: "basket.dragon", said: "a gem pile"),
        ],
    ]

    /// This pet's version, if it has its own.
    func variant(for look: String?) -> Variant? { look.flatMap { Self.variants[$0]?[self] } }

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

    subscript(spot: HomeDecor.Spot) -> HomeDecor? {
        get {
            switch spot {
            case .left: left
            case .right: right
            case .front: front
            }
        }
        set {
            switch spot {
            case .left: left = newValue
            case .right: right = newValue
            case .front: front = newValue
            }
        }
    }

    var isEmpty: Bool { left == nil && right == nil && front == nil }

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

    /// The first empty spot it fits, if any.
    func freeSpot(for item: HomeDecor) -> HomeDecor.Spot? {
        item.spots.first { self[$0] == nil }
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

    init(left: HomeDecor? = nil, right: HomeDecor? = nil, front: HomeDecor? = nil) {
        self.left = left
        self.right = right
        self.front = front
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
    static func buy(_ item: HomeDecor, points: Int, spent: Int, owned: Set<HomeDecor>, placed: HomeDecorSet) -> Purchase? {
        guard !owned.contains(item), wallet(points: points, spent: spent) >= item.price else { return nil }
        let spot = placed.freeSpot(for: item)
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
        right = set.right == nil ? 0 : slot
    }

    /// Columns of the whole picture.
    func width(home: Int) -> Int { left + home + right }

    /// Left column of a thing standing in a side slot: hugging the home with
    /// `gap` columns between them.
    func sideX(_ spot: HomeDecor.Spot, itemWidth: Int, home: Int, slot: Int, gap: Int) -> Int {
        spot == .left ? max(0, slot - gap - itemWidth) : left + home + min(gap, max(0, slot - itemWidth))
    }

    /// Left column of the doormat: centred under where the pet sleeps (its
    /// frame's left column `spotX`, frame `frameWidth` wide).
    func frontX(itemWidth: Int, spotX: Int, frameWidth: Int) -> Int {
        left + spotX + (frameWidth - itemWidth) / 2
    }
}
