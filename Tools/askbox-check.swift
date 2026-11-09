// Checks the "What can I do?" box's ranking and filters and the card's
// Right now suggestions on their own, no Droppy needed:
//   cp Tools/askbox-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/AskRanking.swift Sources/Pixpaw/Suggestions.swift /tmp/main.swift -o /tmp/askbox-check && /tmp/askbox-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

func droppy(_ title: String, kind: String = "command", section: String = "Commands", keywords: [String] = [],
            destructive: Bool = false, search: Bool = false, relevance: Double = 0) -> AskCandidate {
    AskCandidate(key: "droppy:\(title)", source: .droppy, title: title, symbol: "drop", kind: kind, section: section,
                 keywords: keywords, destructive: destructive, relevance: relevance, fromSearch: search)
}
func pet(_ key: String, _ title: String, keywords: [String] = []) -> AskCandidate {
    AskCandidate(key: "pet:\(key)", source: .pet, title: title, symbol: "pawprint", keywords: keywords)
}

// The dangerous-item filter.
check(AskRanking.isDangerous(droppy("Turn Off Meetings")), "Turn off… is dangerous")
check(AskRanking.isDangerous(droppy("Remove Droplet")), "Remove… is dangerous")
check(AskRanking.isDangerous(droppy("Put Display to Sleep")), "Sleep is dangerous")
check(AskRanking.isDangerous(droppy("Quit Droppy")), "Quit is dangerous")
check(AskRanking.isDangerous(droppy("Show Notes", destructive: true)), "a destructive action is dangerous")
check(!AskRanking.isDangerous(droppy("Show Notes")), "Show notes is fine")
check(!AskRanking.isDangerous(droppy("Sleepy cat facts")), "a word that only starts with sleep is fine")
check(!AskRanking.isAllowed(droppy("Ask the web", kind: "web"), quiet: false), "a web answer never shows")
check(!AskRanking.isAllowed(droppy("Install Pomodoro", kind: "droplet"), quiet: false), "a Store droplet never shows")
check(!AskRanking.isAllowed(droppy("Agents", kind: "surface"), quiet: false), "a surface (presentDetail) never shows")
check(AskRanking.isAllowed(droppy("Weekly plan", kind: "content", search: true), quiet: false), "a note found by search shows")
check(!AskRanking.isAllowed(droppy("Copied link", kind: "clipboard"), quiet: true), "clipboard rows hide on a shared screen")
check(!AskRanking.isAllowed(droppy("Clipboard history"), quiet: true), "the clipboard command hides on a shared screen")
check(AskRanking.isAllowed(droppy("Clipboard history"), quiet: false), "the clipboard command shows otherwise")

// Ranking.
let catalog = [droppy("New note"), droppy("Show Notes"), droppy("Turn Off Notes"), droppy("Clipboard history"),
               droppy("Join Next Meeting"), droppy("Put Display to Sleep"),
               pet("addNote", "Add a note to my sign…", keywords: ["note", "remind"]), pet("meetingNotes", "Take meeting notes"),
               pet("openNotes", "Open the last meeting notes"), pet("feed", "Feed", keywords: ["food"])]
let noted = AskRanking.rank(catalog + [droppy("Weekly plan", kind: "content", keywords: ["note"], search: true, relevance: 0.9)],
                            query: "note", quiet: false)
check(noted.first?.title == "New note", "\"note\": New note first")
check(!noted.contains { $0.title == "Turn Off Notes" }, "\"note\": Turn off notes never shows")
check(noted.last?.title == "Weekly plan", "\"note\": the found note comes after the commands")
check(noted.count <= AskRanking.limit, "six rows at most")
check(AskRanking.rank(catalog, query: "shut down", quiet: false).isEmpty, "\"shut down\": nothing")
check(AskRanking.rank(catalog, query: "sleep", quiet: false).isEmpty, "\"sleep\": Droppy's sleep never shows")
check(AskRanking.rank(catalog, query: "join meet", quiet: false).first?.title == "Join Next Meeting", "\"join meet\" finds Join next meeting")
let parsed = AskCandidate(key: "pet:parsed", source: .pet, title: "Put “Buy milk” on my sign", symbol: "signpost.right", parsed: true)
check(AskRanking.rank(catalog + [parsed], query: "note buy milk", quiet: false).first == parsed, "\"note buy milk\": the note itself first")
let many = (1...10).map { droppy("Notes \($0)") }
check(AskRanking.rank(many, query: "notes", quiet: false).count == 6, "ten matches: six rows")
let used = AskRanking.rank([droppy("Show Notes"), droppy("Show Nothing")], query: "show", quiet: false, uses: ["droppy:Show Nothing": 9])
check(used.first?.title == "Show Nothing", "what you run most comes up among equals")
check(AskRanking.rank([pet("notes", "Notes"), droppy("Notes")], query: "notes", quiet: false).count == 1, "the same title once")
check(!AskRanking.searches("n") && AskRanking.searches("no"), "search from two characters")
check(!AskRanking.counts(droppy("Weekly plan", kind: "content", search: true)), "a found note is never counted as used")

// With nothing typed.
let nowRow = AskCandidate(key: "now:screenshot.toShelf", source: .now, title: "Screenshot to the shelf", symbol: "tray")
let empty = AskRanking.empty(now: [nowRow], all: catalog, defaults: ["pet:feed", "droppy:Show Notes", "droppy:Clipboard history"],
                             quiet: true, uses: ["pet:meetingNotes": 3, "droppy:Turn Off Notes": 50])
check(empty.first == nowRow, "empty: suggestions first")
check(empty.dropFirst().first?.key == "pet:meetingNotes", "empty: then the most used")
check(!empty.contains { $0.title == "Turn Off Notes" }, "empty: a dangerous one never, however used")
check(!empty.contains { $0.title == "Clipboard history" }, "empty: no clipboard on a shared screen")

// Suggestions.
let t0 = Date(timeIntervalSince1970: 1_000_000)
let shot = PetSuggestions.screenshot(URL(fileURLWithPath: "/tmp/shot.png"), at: t0)
let all: (PetSuggestionAction) -> Bool = { _ in true }
check(PetSuggestions.choose([], now: t0, carriesScreenshots: false, canRun: all).isEmpty, "no event, no row")
check(PetSuggestions.choose([shot], now: t0 + 60, carriesScreenshots: false, canRun: all).first?.actions == [.toShelf, .showInFinder], "screenshot: to the shelf, show in Finder")
check(PetSuggestions.choose([shot], now: t0 + 60, carriesScreenshots: true, canRun: all).isEmpty, "screenshot: none while carried to the shelf")
check(PetSuggestions.choose([shot], now: t0 + 181, carriesScreenshots: false, canRun: all).isEmpty, "screenshot: gone after 3 min")
check(PetSuggestions.line(shot, now: t0 + 20) == "Screenshot just now", "screenshot: just now")
check(PetSuggestions.left(shot, now: t0 + 20) == "3 min", "screenshot: 3 min left")
let download = PetSuggestions.download(URL(fileURLWithPath: "/tmp/a.zip"), at: t0)
check(PetSuggestions.choose([download], now: t0 + 299, carriesScreenshots: true, canRun: all).count == 1, "download: up within 5 min")
check(PetSuggestions.choose([download], now: t0 + 300, carriesScreenshots: true, canRun: all).isEmpty, "download: gone at 5 min")
let meeting = PetSuggestions.meeting("Team standup", start: t0 + 120, at: t0)
check(PetSuggestions.line(meeting, now: t0) == "“Team standup” in 2 min", "meeting: in 2 min")
check(PetSuggestions.choose([meeting], now: t0 + 120 + 599, carriesScreenshots: false, canRun: all).count == 1, "meeting: up until 10 min after it starts")
check(PetSuggestions.choose([meeting], now: t0 + 120 + 600, carriesScreenshots: false, canRun: all).isEmpty, "meeting: gone 10 min after")
let agent = PetSuggestions.agent("Claude", failed: false, at: t0)
check(PetSuggestions.choose([agent], now: t0, carriesScreenshots: false, canRun: { $0 != .agents }).isEmpty, "agent: no row when Agents can't open here")
check(PetSuggestions.choose([agent], now: t0 + 599, carriesScreenshots: false, canRun: all).count == 1, "agent: 10 min")
check(PetSuggestions.choose([PetSuggestions.pomodoro(at: t0)], now: t0, carriesScreenshots: false, canRun: all).first?.actions == [.focusAgain, .stretch], "pomodoro: focus again, stretch")
check(PetSuggestions.choose([PetSuggestions.meetingNotes(at: t0)], now: t0 + 899, carriesScreenshots: false, canRun: all).count == 1, "notes: 15 min")
let server = PetSuggestions.server(3000, at: t0)
check(PetSuggestions.choose([server], now: t0 + 86_400, carriesScreenshots: false, canRun: all).count == 1, "server: as long as it is up")
check(PetSuggestions.left(server, now: t0) == nil, "server: no end time")
let ordered = PetSuggestions.choose([shot, PetSuggestions.ci("pixpaw", at: t0 - 50), meeting, server], now: t0 + 1, carriesScreenshots: false, canRun: all)
check(ordered.map(\.kind) == [.meeting, .ci, .server, .screenshot], "meeting, then CI, then server, then the rest")
let twice = PetSuggestions.record(PetSuggestions.screenshot(URL(fileURLWithPath: "/tmp/2.png"), at: t0 + 10), into: [shot], now: t0 + 10)
check(twice.count == 1 && twice[0].file?.lastPathComponent == "2.png", "one of each kind, the newest")
check(PetSuggestions.choose([meeting], now: t0, carriesScreenshots: false, canRun: { $0 != .takeNotes }).first?.actions == [.join], "a button that can't run is left out")

print(failures == 0 ? "All good." : "\(failures) failed.")
exit(failures == 0 ? 0 : 1)
