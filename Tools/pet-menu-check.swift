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
    s.talks = true
    s.talkKey = PetMenuShortcut(key: "t", control: true, option: true)
    s.askKey = key
    s.droppy = [.init(title: "Notes", symbol: "note.text", id: "notes"), .init(title: "Tasks", symbol: "checklist", id: "tasks")]
    s.hungry = true
    s.asleep = asleep
    s.home = home
    s.homeOut = home
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
check(full.map { $0.title ?? "—" } == ["Right now", "Ask me", "Care", "Work", "Meetings", "Home", "—"], "menu groups in order")
check(full.last?.items.map(\.title) == ["Capture", "Wardrobe"], "Capture and Wardrobe after the separator")
check(PetMenu.groups(PetMenuState()).map { $0.title ?? "—" } == ["Ask me", "Care", "Work", "—"], "no Right now, Meetings or Home when empty")

// The card: six big buttons in their order, the header, Right now.
let noHome = PetMenu.groups(everything(home: false))
let card = PetCardLayout(noHome, suggestions: everything(home: false).suggestions)
check(card.tiles.map(\.title) == ["Feed", "Play", "Nap", "Stop focus", "Play lofi", "Add a note…"], "six big buttons in order")
check(card.tiles.first?.badge == "Hungry" && card.tiles[3].badge == "25 min" && card.tiles[4].badge == "YouTube", "badges on the big buttons")
check(card.talk?.shortcut?.text == "⌃⌥T" && card.ask?.shortcut?.text == "⌃⌥/", "the header's buttons carry the user's keys")
check(card.rightNow?.line == "Screenshot just now", "Right now: the first suggestion")
check(card.groups.first?.title == "Right now" && card.groups.first?.items.map(\.title) == ["See why pixpaw's CI failed"],
      "the other suggestions stay as Right now rows")
let homeCard = PetCardLayout(full, suggestions: [])
check(homeCard.tiles.contains { $0.title == "Nap" && $0.symbol == "house.fill" }, "with a home, Nap is the home's: short, with the home icon")
check(homeCard.groups.first { $0.title == "Home" }?.items.map(\.title) == ["Put the home away"], "Put the home away stays a row")
check(homeCard.groups.map { $0.title ?? "—" } == ["Right now", "Ask me", "Care", "Work", "Meetings", "Home", "—"], "card groups with a home")
let pomodoro = PetCardLayout(PetMenu.groups(droppyFocus), suggestions: [])
check(pomodoro.tiles[3].title == "Focusing with Droppy" && !pomodoro.tiles[3].enabled, "Droppy's Pomodoro: the Focus button is off on both")

// Wardrobe: ticks, the next one switched off, the stars.
let wardrobe = full.last!.items[1]
check(wardrobe.badge == "185 ★", "Wardrobe shows the stars")
let hats = wardrobe.children![0].children!
check(hats.map(\.title) == ["No hat", "Party hat", "", "Next: Beanie, 15 ★ to go"] && hats[1].checked && !hats[0].checked && !hats[3].enabled,
      "Head: worn ticked, next switched off")
check(wardrobe.children![1].children!.first?.checked == true, "Face: nothing worn ticks No glasses")

// The shortcut, spelled as the menu draws it.
check(PetMenuShortcut(key: "k", shift: true, command: true).text == "⇧⌘K", "shortcut text")

print(failures == 0 ? "\nAll good." : "\n\(failures) failed.")
exit(failures == 0 ? 0 : 1)
