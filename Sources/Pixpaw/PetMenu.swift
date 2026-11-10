//
//  PetMenu.swift
//  Pixpaw
//
//  The pet's menu as plain values: its groups, their items and submenus,
//  badges, shortcuts and what's switched off. The full menu (the card's
//  ⋯ button) is built from it item by item, and the card takes its six
//  big buttons and the Right now line off the top and shows the rest in
//  the same groups, in the same order, so the two can't drift apart. Pure
//  functions, checked on their own (Tools/pet-menu-check.swift).
//

import Foundation

/// What an item does: the name of the pet view's action for it.
enum PetMenuAction: String, CaseIterable {
    case talk, ask, droppyTool = "droppyTool:", runSuggestion = "runSuggestion:"
    case feed, treat, nap, wake, playGame = "playGame:", playHands, stopPlaying
    case focus, stretch, lofi, pauseLofi, askSign, dropSign
    case meetingNotes, showTranscript, openNotes, putHomeAway, placeDecor = "placeDecor:", buyDecor = "buyDecor:"
    case photo, recordGIF, capturePage, wearItem = "wearItem:", openWardrobe, setColour = "setColour:", setPixels = "setPixels:"
    case openSettings
}

/// A shortcut as the user set it on Droppy's Shortcuts page.
struct PetMenuShortcut: Equatable {
    /// What the key types, lowercased.
    let key: String
    var control = false, option = false, shift = false, command = false

    /// "⌃⌥/", as the menu draws it.
    var text: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key.uppercased()
    }
}

struct PetMenuEntry: Equatable {
    var title = ""
    var symbol: String?
    /// A home decoration's id ("lamp"): its own art is the row's picture,
    /// in place of `symbol`. A key, not an image, so the model stays a value.
    var picture: String?
    var action: PetMenuAction?
    /// What the action reads off its sender.
    var represented: String?
    /// What it is at now, on its right: "Hungry", "25 min", "185 ★".
    var badge: String?
    var shortcut: PetMenuShortcut?
    var enabled = true
    var checked = false
    var isSeparator = false
    var children: [PetMenuEntry]?

    static let separator = PetMenuEntry(isSeparator: true)

    /// Every item in it and its submenus, each by the path of titles to it.
    var leaves: [String] {
        guard !isSeparator else { return [] }
        guard let children else { return [title] }
        return [title] + children.flatMap { $0.leaves.map { "\(title) ▸ \($0)" } }
    }
}

/// A group of the menu: a section header and its items, or (no title)
/// the ones after the separator.
struct PetMenuGroup: Equatable {
    let title: String?
    var items: [PetMenuEntry]
}

/// Everything the menu depends on, read off the pet when it opens.
struct PetMenuState {
    struct Choice: Equatable {
        let title: String
        let symbol: String
        /// The game's or Droppy tool's raw value.
        let id: String
    }
    struct Suggestion {
        struct Button {
            /// "Put the screenshot on the shelf", in the menu.
            let menu: String
            /// "To the shelf", on the card's Right now line.
            let button: String
            let symbol: String
            /// "screenshot.toShelf".
            let id: String
        }
        /// "Screenshot just now".
        let line: String
        let left: String?
        let buttons: [Button]
    }
    /// One place on the pet the Wardrobe dresses: Head, Face, Neck.
    struct Place {
        struct Thing { let title: String; let id: String; let worn: Bool }
        let title: String
        let symbol: String
        /// "No hat", and the value that takes it off.
        let none: String
        let noneID: String
        let things: [Thing]
        /// "Next: Beanie, 15 ★ to go".
        let next: String?
    }

    var suggestions: [Suggestion] = []
    var talks = false
    var talkKey: PetMenuShortcut?
    var askKey: PetMenuShortcut?
    /// Droppy's tools in the Ask me submenu.
    var droppy: [Choice] = []
    var hungry = false
    var asleep = false
    /// The home comes out for naps.
    var home = false
    var homeOut = false
    /// Home decorations: one row each, in price order.
    struct Decor: Equatable {
        let title: String
        let id: String
        let price: Int
        let spots: [String]
        /// Where it stands now ("left", "right", "front"), nil when off the floor.
        var placed: String?
        var owned = false
    }
    var decor: [Decor] = []
    /// Stars there are to spend on them.
    var wallet = 0
    var games: [Choice] = []
    var friend = false
    var playing = false
    var droppyFocus = false
    var focusing = false
    var onBreak = false
    var focus: String?
    var lofiOn = false
    var lofi: String?
    var note = false
    /// Join the next meeting, through Droppy, when none is offered up top.
    var join = false
    var todaysMeetings = false
    var takesNotes = false
    var notes: String?
    var notesKept = false
    /// Taking notes with the live transcript hidden (×, or off in Settings).
    var transcriptHidden = false
    var scrollingCapture = false
    var wholePage = false
    var places: [Place] = []
    /// Its coats or colourways, the one it has on marked worn.
    var colours: [Place.Thing] = []
    var stars = 0
    /// Whether the pet is drawn in the old chunky pixels, not the finer ones.
    var classicPixels = false
    /// Whether this pet has finer art at all; no Pixel size without it.
    var hasFineArt = false
    /// The menu is the friend's: Pixel size changes both pets.
    var isFriend = false
}

enum PetMenu {
    /// The pet's menu, group by group.
    static func groups(_ state: PetMenuState) -> [PetMenuGroup] {
        func item(_ title: String, _ symbol: String, _ action: PetMenuAction, badge: String? = nil, represented: String? = nil,
                  shortcut: PetMenuShortcut? = nil) -> PetMenuEntry {
            PetMenuEntry(title: title, symbol: symbol, action: action, represented: represented,
                         badge: badge?.isEmpty == false ? badge : nil, shortcut: shortcut)
        }
        func submenu(_ title: String, _ symbol: String, badge: String? = nil, _ items: [PetMenuEntry]) -> PetMenuEntry {
            PetMenuEntry(title: title, symbol: symbol, badge: badge, children: items)
        }
        var groups: [PetMenuGroup] = []

        // Right now: what can't wait or just happened, a button for each
        // thing you'd likely do next. Nothing runs until you choose it.
        if !state.suggestions.isEmpty {
            groups.append(PetMenuGroup(title: "Right now", items: state.suggestions.flatMap { suggestion in
                suggestion.buttons.map { item($0.menu, $0.symbol, .runSuggestion, represented: $0.id) }
            }))
        }

        // Ask me: talking to it, typing to it, and Droppy's own tools.
        var ask: [PetMenuEntry] = []
        if state.talks { ask.append(item("Talk to me", "mic", .talk, shortcut: state.talkKey)) }
        ask.append(item("What can I do?…", "magnifyingglass", .ask, shortcut: state.askKey))
        if !state.droppy.isEmpty {
            ask.append(submenu("Droppy", "drop", state.droppy.map { item($0.title, $0.symbol, .droppyTool, represented: $0.id) }))
        }
        groups.append(PetMenuGroup(title: "Ask me", items: ask))

        var care = [item("Feed", "fork.knife", .feed, badge: state.hungry ? "Hungry" : nil), item("Give a treat", "fish", .treat)]
        if !state.home { care.append(state.asleep ? item("Wake up", "sun.max", .wake) : item("Nap", "moon.zzz", .nap)) }
        // Only the games this one plays, its own toy first.
        var toys = state.games.map { item($0.title, $0.symbol, .playGame, represented: $0.id) }
        if state.friend { toys += [.separator, item("Rock, paper, scissors", "hand.raised.fingers.spread", .playHands)] }
        if state.playing { toys += [.separator, item("Stop playing", "stop.circle", .stopPlaying)] }
        care.append(submenu("Play", "gamecontroller", toys))
        groups.append(PetMenuGroup(title: "Care", items: care))

        // Work: focus and its breaks, lofi, the note on its sign.
        var work: [PetMenuEntry] = []
        if state.droppyFocus {
            // Droppy keeps the time: only Droppy can stop its Pomodoro.
            var entry = item("Focusing with Droppy", "timer", .focus)
            entry.enabled = false
            work.append(entry)
        } else {
            work.append(state.focusing ? item("Stop focus", "stop.circle", .focus, badge: state.focus)
                        : state.onBreak ? item("Skip the break", "forward.end", .focus, badge: state.focus)
                        : item("Focus", "timer", .focus, badge: state.focus))
        }
        work.append(item("Stretch with me", "figure.cooldown", .stretch))
        work.append(state.lofiOn ? item("Pause lofi", "pause.circle", .pauseLofi) : item("Play lofi", "headphones", .lofi, badge: state.lofi))
        work.append(item("Add a note…", "signpost.right", .askSign))
        if state.note { work.append(item("Done with this note", "checkmark.circle", .dropSign)) }
        groups.append(PetMenuGroup(title: "Work", items: work))

        // Meetings: joining one, today's list, and the pet's notes of one.
        var meetings: [PetMenuEntry] = []
        if state.join { meetings.append(item("Join the next meeting", "video", .droppyTool, represented: "joinMeeting")) }
        if state.todaysMeetings { meetings.append(item("Today's meetings", "calendar", .droppyTool, represented: "todaysMeetings")) }
        if state.takesNotes {
            meetings.append(state.notes != nil ? item("Stop meeting notes", "stop.circle", .meetingNotes, badge: state.notes)
                            : item("Take meeting notes", "waveform.badge.mic", .meetingNotes))
            if state.notes != nil, state.transcriptHidden { meetings.append(item("Show live transcript", "captions.bubble", .showTranscript)) }
            if state.notesKept, state.notes == nil { meetings.append(item("Open the last meeting notes", "doc.text", .openNotes)) }
        }
        if !meetings.isEmpty { groups.append(PetMenuGroup(title: "Meetings", items: meetings)) }

        // Home: the nap that brings it out, and putting it away.
        if state.home {
            var home = [state.asleep ? item("Wake up", "sun.max", .wake) : item("Nap", "house", .nap)]
            if let decorate = decorate(state) { home.append(decorate) }
            if state.homeOut { home.append(item("Put the home away", "house.slash", .putHomeAway)) }
            groups.append(PetMenuGroup(title: "Home", items: home))
        }

        var captures = [item("Photo", "camera", .photo), item("GIF", "film", .recordGIF)]
        // Droppy's: you pick the window or area, and it scrolls it.
        if state.scrollingCapture { captures.append(item("Scrolling capture", "camera.viewfinder", .capturePage)) }
        else if state.wholePage { captures.append(item("Whole page", "camera.viewfinder", .capturePage)) }

        // A submenu per place on the pet: what's yours, then the one you're nearest to.
        let places = state.places.map { place in
            var things = [PetMenuEntry(title: place.none, action: .wearItem, represented: place.noneID, checked: !place.things.contains(where: \.worn))]
            things += place.things.map { PetMenuEntry(title: $0.title, action: .wearItem, represented: $0.id, checked: $0.worn) }
            if let next = place.next { things += [.separator, PetMenuEntry(title: next, enabled: false)] }
            return submenu(place.title, place.symbol, things)
        }
        let wardrobe = submenu("Wardrobe", "tshirt", badge: "\(state.stars) ★",
                               places + [.separator, PetMenuEntry(title: "Open Wardrobe…", action: .openWardrobe)])
        // How it looks together: its colour beside what it wears.
        var look = [wardrobe]
        if !state.colours.isEmpty {
            look.insert(submenu("Colour", "paintpalette", state.colours.map {
                PetMenuEntry(title: $0.title, action: .setColour, represented: $0.id, checked: $0.worn)
            }), at: 0)
        }
        if state.hasFineArt {
            var sizes = [PetMenuEntry(title: "Fine (HD)", action: .setPixels, represented: "fine", checked: !state.classicPixels),
                         PetMenuEntry(title: "Chunky (classic)", action: .setPixels, represented: "classic", checked: state.classicPixels)]
            if state.isFriend { sizes += [.separator, PetMenuEntry(title: "For both pets", enabled: false)] }
            look.append(submenu("Pixel size", "square.grid.3x3", sizes))
        }
        groups.append(PetMenuGroup(title: "Look", items: look))
        groups.append(PetMenuGroup(title: nil, items: [submenu("Capture", "camera", captures)]))
        // Always last: the way to everything else, in Droppy's Settings.
        groups.append(PetMenuGroup(title: nil, items: [item("Pixpaw settings…", "gearshape", .openSettings)]))
        return groups
    }
}

extension PetMenu {
    /// Decorate ▸ Left / Right / Doormat (what's yours to put there), then
    /// Buy ▸ each one not yours yet; one more click on it to spend the stars.
    static func decorate(_ state: PetMenuState) -> PetMenuEntry? {
        guard !state.decor.isEmpty else { return nil }
        var items: [PetMenuEntry] = []
        for (spot, title, symbol) in [("left", "Left", "arrow.left.to.line"), ("right", "Right", "arrow.right.to.line"),
                                      ("front", "Doormat", "rectangle.bottomhalf.filled")] {
            let fitting = state.decor.filter { $0.owned && $0.spots.contains(spot) }
            guard !fitting.isEmpty else { continue }
            var things = [PetMenuEntry(title: "Nothing", action: .placeDecor, represented: "\(spot)=",
                                       checked: !fitting.contains { $0.placed == spot })]
            things += fitting.map { PetMenuEntry(title: $0.title, picture: $0.id, action: .placeDecor, represented: "\(spot)=\($0.id)",
                                                 checked: $0.placed == spot) }
            items.append(PetMenuEntry(title: title, symbol: symbol, children: things))
        }
        let shop = state.decor.filter { !$0.owned }
        if !shop.isEmpty {
            // Owned things carry over to every pet, drawn as its own version.
            var buy = [PetMenuEntry(title: "To spend: \(state.wallet) ★", enabled: false),
                       PetMenuEntry(title: "Changes with your pet", enabled: false), .separator]
            buy += shop.map { thing in
                let short = thing.price - state.wallet
                guard short <= 0 else { return PetMenuEntry(title: "\(thing.title) · \(short) ★ more", picture: thing.id, enabled: false) }
                return PetMenuEntry(title: "\(thing.title) · \(thing.price) ★", picture: thing.id, children: [
                    PetMenuEntry(title: "Buy for \(thing.price) ★", action: .buyDecor, represented: thing.id),
                    PetMenuEntry(title: "Leaves \(state.wallet - thing.price) ★ to spend", enabled: false),
                ])
            }
            if !items.isEmpty { items.append(.separator) }
            items.append(PetMenuEntry(title: "Buy", symbol: "cart", children: buy))
        }
        return PetMenuEntry(title: "Decorate", symbol: "sofa", badge: "\(state.wallet) ★", children: items)
    }
}

/// The card, cut from the same groups: its six big buttons and the Right
/// now line on top, the header's Talk to me and What can I do?, and every
/// other item in the menu's own groups and order below.
struct PetCardLayout {
    /// Feed, Play, Nap (or Wake up), Focus, Lofi, Note.
    var tiles: [PetMenuEntry]
    /// The first suggestion, on its own line under the header.
    var rightNow: PetMenuState.Suggestion?
    var talk: PetMenuEntry?
    var ask: PetMenuEntry?
    /// The menu's groups less what's above; a group left empty is left out.
    var groups: [PetMenuGroup]

    init(_ menu: [PetMenuGroup], suggestions: [PetMenuState.Suggestion]) {
        let all = menu.flatMap(\.items)
        func first(_ test: (PetMenuEntry) -> Bool) -> PetMenuEntry? { all.first(where: test) }
        tiles = [first { $0.action == .feed },
                 first { $0.title == "Play" && $0.children != nil },
                 first { $0.action == .nap || $0.action == .wake },
                 first { $0.action == .focus },
                 first { $0.action == .lofi || $0.action == .pauseLofi },
                 first { $0.action == .askSign }].compactMap { $0 }
        talk = first { $0.action == .talk }
        ask = first { $0.action == .ask }
        rightNow = suggestions.first
        let onTop = Set((rightNow?.buttons ?? []).map(\.id))
        // A row that says what a Right now button already says ("Stretch
        // with me") would be the same thing twice.
        let onTopTitles = Set((rightNow?.buttons ?? []).flatMap { [$0.button, $0.menu] })
        let shown = tiles + [talk, ask].compactMap { $0 }
        // A big button's action is never a row too, whatever its title or
        // badge reads by then ("Stop focus" is the Focus button).
        let tileActions = Set(tiles.compactMap(\.action))
        groups = menu.compactMap { group in
            let items = group.items.filter { item in
                !shown.contains(item) && !(item.action == .runSuggestion && item.represented.map(onTop.contains) == true)
                    && !(item.action.map(tileActions.contains) == true && item.children == nil)
                    && !onTopTitles.contains(item.title)
            }
            return items.isEmpty ? nil : PetMenuGroup(title: group.title, items: items)
        }
    }

    /// A big button's label: one or two short words, so it fits the 77pt
    /// tile at 11pt. The full title stays its VoiceOver label and the row's.
    static func tileTitle(_ entry: PetMenuEntry) -> String {
        switch entry.action {
        case .feed: "Feed"
        case .nap: "Nap"
        case .wake: "Wake up"
        case .focus:
            entry.title == "Stop focus" ? "Stop focus" : entry.title == "Skip the break" ? "Skip break"
                : entry.title == "Focusing with Droppy" ? "Focusing" : "Focus"
        case .lofi: "Lofi"
        case .pauseLofi: "Pause lofi"
        case .askSign: "Note"
        default: entry.title.count <= 10 ? entry.title : String(entry.title.prefix(while: { $0 != " " }))
        }
    }

    /// Every item of the menu the card's rows leave out, by its path.
    static func leftOut(menu: [PetMenuGroup], card: PetCardLayout) -> [String] {
        let rows = Set(card.groups.flatMap(\.items).flatMap(\.leaves))
        return menu.flatMap(\.items).flatMap(\.leaves).filter { !rows.contains($0) }
    }
}
