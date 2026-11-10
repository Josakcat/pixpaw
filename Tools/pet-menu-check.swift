// Checks that the pet's card shows everything its full menu (⋯) does,
// both cut from the same model (PetMenu.swift), no Droppy needed:
//   cp Tools/pet-menu-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/PetMenu.swift /tmp/main.swift -o /tmp/pet-menu-check && /tmp/pet-menu-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let key = PetMenuShortcut(key: "/", control: true, option: true)
let screenshot = PetMenuState.Suggestion(line: "Screenshot just now", left: "3 min", buttons: [
    .init(menu: "Put the screenshot on the shelf", button: "To the shelf", symbol: "tray.and.arrow.up", id: "screenshot.toShelf"),
    .init(menu: "Show the screenshot in Finder", button: "Show in Finder", symbol: "folder", id: "screenshot.showInFinder"),
])
let ci = PetMenuState.Suggestion(line: "CI failed", left: nil, buttons: [
    .init(menu: "See why pixpaw's CI failed", button: "See why CI failed", symbol: "xmark.octagon", id: "ci.openCI"),
])
let head = PetMenuState.Place(title: "Head", symbol: "crown", none: "No hat", noneID: "hat:",
                              things: [.init(title: "Party hat", id: "hat:partyHat", worn: true)], next: "Next: Beanie, 15 ★ to go")
let face = PetMenuState.Place(title: "Face", symbol: "eyeglasses", none: "No glasses", noneID: "face:", things: [], next: nil)

/// A pet with everything on: every group and every item the menu can show.
func everything(home: Bool, asleep: Bool = false) -> PetMenuState {
    var s = PetMenuState()
    s.suggestions = [screenshot, ci]
    s.hasFineArt = true
    s.talks = true
    s.talkKey = PetMenuShortcut(key: "t", control: true, option: true)
    s.askKey = key
    s.droppy = [.init(title: "Notes", symbol: "note.text", id: "notes"), .init(title: "Tasks", symbol: "checklist", id: "tasks")]
    s.hungry = true
    s.asleep = asleep
    s.home = home
    s.homeOut = home
    if home {
        s.wallet = 150
        s.decor = [.init(title: "Doormat rug", id: "rug", price: 60, spots: ["front"], placed: "front", owned: true),
                   .init(title: "Potted plant", id: "plant", price: 80, spots: ["left", "right"], placed: nil, owned: true),
                   .init(title: "Floor lamp", id: "lamp", price: 140, spots: ["left", "right"]),
                   .init(title: "Mailbox", id: "mailbox", price: 220, spots: ["left", "right"])]
    }
    s.games = [.init(title: "Yarn", symbol: "circle.dotted", id: "yarn")]
    s.friend = true
    s.playing = true
    s.focusing = true
    s.focus = "25 min"
    s.lofi = "YouTube"
    s.note = true
    s.join = true
    s.todaysMeetings = true
    s.takesNotes = true
    s.notesKept = true
    s.scrollingCapture = true
    s.places = [head, face]
    s.colours = [.init(title: "Golden", id: "golden", worn: true), .init(title: "Husky", id: "husky", worn: false)]
    s.stars = 185
    return s
}

/// What the card may leave out of its rows: what it already shows on top.
let allowed: Set<String> = ["Feed", "Play", "Play ▸ Yarn", "Play ▸ Rock, paper, scissors", "Play ▸ Stop playing",
                            "Nap", "Wake up", "Stop focus", "Focus", "Focusing with Droppy",
                            "Play lofi", "Pause lofi", "Add a note…", "Talk to me", "What can I do?…",
                            "Put the screenshot on the shelf", "Show the screenshot in Finder"]

func checkSame(_ state: PetMenuState, _ name: String) {
    let menu = PetMenu.groups(state)
    let card = PetCardLayout(menu, suggestions: state.suggestions)
    let missing = PetCardLayout.leftOut(menu: menu, card: card).filter { !allowed.contains($0) }
    check(missing.isEmpty, "\(name): every menu item is on the card" + (missing.isEmpty ? "" : " (missing \(missing))"))
    // Same groups, same order; a group the card empties is the only one it drops.
    let cardTitles = card.groups.map { $0.title ?? "—" }
    let menuTitles = menu.map { $0.title ?? "—" }.filter(cardTitles.contains)
    check(cardTitles == menuTitles, "\(name): card groups in the menu's order \(cardTitles)")
    // Each row is the menu's own item: badge, shortcut, switched off, ticked.
    let items = menu.flatMap(\.items)
    check(card.groups.flatMap(\.items).allSatisfy(items.contains), "\(name): card rows are the menu's items, unchanged")
    check(card.tiles.allSatisfy(items.contains), "\(name): big buttons are the menu's items, unchanged")
}

checkSame(everything(home: false), "no home")
checkSame(everything(home: true), "home, out")
checkSame(everything(home: true, asleep: true), "home, asleep")
checkSame(PetMenuState(), "nothing on")
var droppyFocus = everything(home: false)
droppyFocus.droppyFocus = true
checkSame(droppyFocus, "Droppy's Pomodoro")

// The menu's groups and order.
let full = PetMenu.groups(everything(home: true))
check(full.map { $0.title ?? "—" } == ["Right now", "Ask me", "Care", "Work", "Meetings", "Home", "Look", "—", "—"], "menu groups in order")
let look = full.first { $0.title == "Look" }
check(look?.items.map(\.title) == ["Colour", "Wardrobe", "Pixel size"], "Colour beside Wardrobe, then Pixel size")
check(full.dropLast().last?.items.map(\.title) == ["Capture"], "Capture after the separator")
check(full.last?.items.map(\.title) == ["Pixpaw settings…"], "Pixpaw settings… last of all")
check(PetMenu.groups(PetMenuState()).map { $0.title ?? "—" } == ["Ask me", "Care", "Work", "Look", "—", "—"], "no Right now, Meetings or Home when empty")
check(PetMenu.groups(PetMenuState()).first { $0.title == "Look" }?.items.map(\.title) == ["Wardrobe"], "no colours (a pet you drew), no Colour, no fine art, no Pixel size")
var friendMenu = everything(home: false)
friendMenu.isFriend = true
let friendSizes = PetMenu.groups(friendMenu).first { $0.title == "Look" }?.items.last?.children ?? []
check(friendSizes.first?.title == "Fine (HD)" && friendSizes.last?.title == "For both pets",
      "the friend's Pixel size says it's for both pets")
let colours = look?.items[0].children ?? []
check(colours.map(\.title) == ["Golden", "Husky"] && colours[0].checked && !colours[1].checked && colours[1].represented == "husky",
      "Colour: the one on ticked, each by its id")

// The card: six big buttons in their order, the header, Right now.
let noHome = PetMenu.groups(everything(home: false))
let card = PetCardLayout(noHome, suggestions: everything(home: false).suggestions)
check(card.tiles.map(\.title) == ["Feed", "Play", "Nap", "Stop focus", "Play lofi", "Add a note…"], "six big buttons in order")
check(card.tiles.map(PetCardLayout.tileTitle) == ["Feed", "Play", "Nap", "Stop focus", "Lofi", "Note"], "short tile labels")
check(!card.groups.flatMap(\.items).contains { $0.action == .focus }, "Stop focus is the big button, not a Work row too")
check(PetCardLayout.tileTitle(PetMenuEntry(title: "Focusing with Droppy", action: .focus)) == "Focusing", "Droppy's Pomodoro tile is short")
check(card.tiles.first?.badge == "Hungry" && card.tiles[3].badge == "25 min" && card.tiles[4].badge == "YouTube", "badges on the big buttons")
check(card.talk?.shortcut?.text == "⌃⌥T" && card.ask?.shortcut?.text == "⌃⌥/", "the header's buttons carry the user's keys")
check(card.rightNow?.line == "Screenshot just now", "Right now: the first suggestion")
check(card.groups.first?.title == "Right now" && card.groups.first?.items.map(\.title) == ["See why pixpaw's CI failed"],
      "the other suggestions stay as Right now rows")
let homeCard = PetCardLayout(full, suggestions: [])
check(homeCard.tiles.contains { $0.title == "Nap" && $0.symbol == "house" }, "with a home, Nap is the home's: short, with the home icon")
check(homeCard.groups.first { $0.title == "Home" }?.items.map(\.title) == ["Decorate", "Put the home away"], "Decorate and Put the home away stay rows")
check(homeCard.groups.map { $0.title ?? "—" } == ["Right now", "Ask me", "Care", "Work", "Meetings", "Home", "Look", "—", "—"], "card groups with a home")
let pomodoro = PetCardLayout(PetMenu.groups(droppyFocus), suggestions: [])
check(pomodoro.tiles[3].title == "Focusing with Droppy" && !pomodoro.tiles[3].enabled, "Droppy's Pomodoro: the Focus button is off on both")

// Wardrobe: ticks, the next one switched off, the stars.
let wardrobe = look!.items[1]
check(wardrobe.badge == "185 ★", "Wardrobe shows the stars")
let hats = wardrobe.children![0].children!
check(hats.map(\.title) == ["No hat", "Party hat", "", "Next: Beanie, 15 ★ to go"] && hats[1].checked && !hats[0].checked && !hats[3].enabled,
      "Head: worn ticked, next switched off")
check(wardrobe.children![1].children!.first?.checked == true, "Face: nothing worn ticks No glasses")

// Decorate: in the Home group, just before Look; pickers of what's yours, then Buy.
let decorate = full.first { $0.title == "Home" }!.items.first { $0.title == "Decorate" }!
check(decorate.badge == "150 ★", "Decorate shows the stars to spend")
check(decorate.children!.map(\.title) == ["Left", "Right", "Doormat", "", "Buy"], "pickers for the spots something owned fits, then Buy")
let left = decorate.children![0].children!
check(left.map(\.title) == ["Nothing", "Potted plant"] && left[0].checked && left[1].represented == "left=plant", "Left: owned side things, Nothing ticked")
check(decorate.children![2].children!.map(\.title) == ["Nothing", "Doormat rug"] && decorate.children![2].children![1].checked, "Doormat: the rug ticked")
let shop = decorate.children![4].children!
check(shop.map(\.title) == ["To spend: 150 ★", "Changes with your pet", "", "Floor lamp · 140 ★", "Mailbox · 70 ★ more"],
      "Buy: only what's not owned, price or what's short, and that each looks like the pet's own")
check(!shop[0].enabled && !shop[1].enabled && !shop[4].enabled && shop[4].children == nil, "short one switched off")
check(shop[3].children?.first?.action == .buyDecor && shop[3].children?.first?.represented == "lamp"
      && shop[3].children?[1].title == "Leaves 10 ★ to spend", "buying takes one more click: the confirm")
// Each decoration row carries its own art (by id); the other rows keep their symbols.
check(left[0].picture == nil && left[1].picture == "plant" && left[1].symbol == nil, "Left: the plant row shows the plant's art")
check(shop[0].picture == nil && shop[3].picture == "lamp" && shop[4].picture == "mailbox", "Buy: every item row shows its art, short ones too")
check(shop[3].children!.allSatisfy { $0.picture == nil }, "the confirm flyout is unchanged: no big preview in the menu")
check(decorate.picture == nil && decorate.symbol == "sofa", "Decorate keeps its symbol")
let decorCard = PetCardLayout(full, suggestions: [])
check(decorCard.groups.flatMap(\.items).first { $0.title == "Decorate" } == decorate, "the card's Decorate is the menu's, pictures and all")
var nothingOwned = everything(home: true)
nothingOwned.decor = nothingOwned.decor.map { var d = $0; d.owned = false; d.placed = nil; return d }
check(PetMenu.decorate(nothingOwned)?.children?.map(\.title) == ["Buy"], "nothing owned: only Buy")
check(PetMenu.groups(everything(home: false)).allSatisfy { $0.items.allSatisfy { $0.title != "Decorate" } }, "no home, no Decorate")

// The shortcut, spelled as the menu draws it.
check(PetMenuShortcut(key: "k", shift: true, command: true).text == "⇧⌘K", "shortcut text")

// Live transcript: only while taking notes with it hidden, right under Stop.
var recording = PetMenuState()
recording.takesNotes = true
recording.notes = "12 min"
func meetingTitles(_ s: PetMenuState) -> [String] {
    PetMenu.groups(s).first { $0.title == "Meetings" }?.items.map(\.title) ?? []
}
check(meetingTitles(recording) == ["Stop meeting notes"], "no Show live transcript while it's up")
recording.transcriptHidden = true
check(meetingTitles(recording) == ["Stop meeting notes", "Show live transcript"], "Show live transcript under Stop when hidden")
var idle = PetMenuState()
idle.takesNotes = true
idle.transcriptHidden = true
check(!meetingTitles(idle).contains("Show live transcript"), "no Show live transcript when not taking notes")

print(failures == 0 ? "\nAll good." : "\n\(failures) failed.")
exit(failures == 0 ? 0 : 1)
