// Checks what of the on-device model's answer becomes a bubble, how often it
// is asked, and the prompt, on its own, no Droppy or model needed:
//   cp .droppykit/Tools/pet-lines-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/PetLineRules.swift /tmp/main.swift -o /tmp/pet-lines-check && /tmp/pet-lines-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// What is kept.
check(PetLineRules.clean("  \"All done, Claude did great!\"  ", gist: "Claude is done!", keep: ["Claude"]) == "All done, Claude did great!", "quotes and spaces trimmed")
check(PetLineRules.clean("Yay, all done!", gist: "Claude is done!", keep: ["Claude"]) == nil, "dropping the agent's name says the usual line")
check(PetLineRules.clean("Battery is low, plug me in?", gist: "Battery at 12%. Plug me in?") == nil, "dropping a number says the usual line")
check(PetLineRules.clean("Only 12% left, a charger please?", gist: "Battery at 12%. Plug me in?") == "Only 12% left, a charger please?", "keeping the number is fine")
check(PetLineRules.clean("", gist: "Sniff sniff.") == nil, "empty answer")
check(PetLineRules.clean("One.\nTwo.", gist: "Sniff sniff.") == nil, "two lines")
check(PetLineRules.clean(String(repeating: "a", count: 91), gist: "Sniff sniff.") == nil, "too long")
check(PetLineRules.clean(String(repeating: "a", count: 90), gist: "Sniff sniff.") != nil, "90 is fine")
check(PetLineRules.clean("Line: hi there", gist: "Sniff sniff.") == nil, "echoing the prompt")
check(PetLineRules.clean("Nap time #cozy", gist: "Sniff sniff.") == nil, "hashtags")
check(PetLineRules.keptTokens("Sniff sniff. Not hungry yet.").isEmpty, "a capital that starts a sentence is not a name")
check(PetLineRules.keptTokens("Your app is up at localhost:3000. Open it from my menu.") == ["localhost:3000"], "numbers kept, sentence starts not")
check(PetLineRules.keptTokens("Time to ask Mochi about it") == ["Mochi"], "a name mid-sentence is kept")
check(PetLineRules.keptTokens("I caught it!").isEmpty, "the first word and I are not names")

// How often.
let now = Date()
check(PetLineRules.mayAsk(lastAsked: nil, now: now, busy: false), "first time asks")
check(!PetLineRules.mayAsk(lastAsked: nil, now: now, busy: true), "never two at once")
check(!PetLineRules.mayAsk(lastAsked: now.addingTimeInterval(-44), now: now, busy: false), "not within 45 s")
check(PetLineRules.mayAsk(lastAsked: now.addingTimeInterval(-45), now: now, busy: false), "after 45 s")
check(PetLineRules.timeout <= 3, "short timeout")

// The prompt.
check(PetLineRules.partOfDay(hour: 7) == "morning" && PetLineRules.partOfDay(hour: 13) == "afternoon"
      && PetLineRules.partOfDay(hour: 19) == "evening" && PetLineRules.partOfDay(hour: 2) == "late at night", "part of day")
let prompt = PetLineRules.prompt(gist: "Claude is done!", doing: "Coding along", hour: 20)
check(prompt.contains("Claude is done!") && prompt.contains("Coding along") && prompt.contains("evening"), "prompt carries the line, the mood and the time")
let rules = PetLineRules.instructions(pet: "cat")
check(rules.contains("pixel cat") && rules.contains("guilty"), "instructions name the pet and rule out guilt")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
