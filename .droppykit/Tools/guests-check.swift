// Checks who sits in front of the home for the agents' sessions, and in
// which pose, on its own, no Droppy needed:
//   cp .droppykit/Tools/guests-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/Guests.swift /tmp/main.swift -o /tmp/guests-check && /tmp/guests-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let now = Date(timeIntervalSince1970: 1_000_000)
func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }

// One per session, its pose from the log.
var list = HomeGuests.list(sessions: [GuestSeen(id: "b", agent: "Claude", busy: true, modified: ago(5)),
                                      GuestSeen(id: "a", agent: "Codex", busy: false, modified: ago(60))], heard: [], now: now)
check(list == [HomeGuest(id: "a", agent: "Codex", pose: .done), HomeGuest(id: "b", agent: "Claude", pose: .working)],
      "a session working and one done, in id order")

// Done goes home after ten minutes; unknown after ten too; a busy one forgotten after thirty.
list = HomeGuests.list(sessions: [GuestSeen(id: "a", agent: "Claude", busy: false, modified: ago(11 * 60)),
                                  GuestSeen(id: "b", agent: "Claude", busy: nil, modified: ago(9 * 60)),
                                  GuestSeen(id: "c", agent: "Claude", busy: true, modified: ago(31 * 60)),
                                  GuestSeen(id: "d", agent: "Claude", busy: true, modified: ago(29 * 60))], heard: [], now: now)
check(list.map(\.id) == ["b", "d"], "done leaves after 10 min, a silent busy one after 30")

// A hook's waiting lands on that agent's latest session.
list = HomeGuests.list(sessions: [GuestSeen(id: "a", agent: "Claude", busy: true, modified: ago(50)),
                                  GuestSeen(id: "b", agent: "Claude", busy: true, modified: ago(2))],
                       heard: [GuestHeard(agent: "Claude", pose: .waiting, at: ago(1))], now: now)
check(list.first { $0.id == "b" }?.pose == .waiting && list.first { $0.id == "a" }?.pose == .working, "waiting goes to the latest session")

// Hooks alone: one guest per agent; none for an agent whose logs are read.
list = HomeGuests.list(sessions: [GuestSeen(id: "s", agent: "Claude", busy: true, modified: ago(1))],
                       heard: [GuestHeard(agent: "Claude", pose: .working, at: ago(1)), GuestHeard(agent: "Cursor", pose: .working, at: ago(1)),
                               GuestHeard(agent: "Gemini", pose: .done, at: ago(11 * 60))], now: now)
check(list.map(\.id) == ["hook:Cursor", "s"], "hook guests only for agents not read from logs; old done gone")

// More than fit: waiting and working win, then put back in id order.
let many = (0..<5).map { GuestSeen(id: "s\($0)", agent: "Codex", busy: $0 >= 3, modified: ago(Double(10 - $0))) }
list = HomeGuests.list(sessions: many, heard: [], now: now)
check(list.count == HomeGuests.room && list.map(\.id) == ["s0", "s3", "s4"], "room for three: the working ones kept, in id order")

// The same session is the same pet every time, and never yours.
let pets = ["bee", "dog", "pig", "shark"]
check(HomeGuests.pick("abc", from: pets) == HomeGuests.pick("abc", from: pets), "a guest is the same pet every time")
check(HomeGuests.pick("x", from: [String]()) == nil, "no choices, no guest pet")
check(HomeGuests.label(HomeGuest(id: "a", agent: "Codex", pose: .waiting), agentName: "Codex") == "Codex guest, waiting for you", "VoiceOver label")

print(failures == 0 ? "All guests checks passed." : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
