// Checks the focus session's body doubling (start → ask → halfway → end,
// Skip, Switch) and the one-line cleaning, on its own, no Droppy needed:
//   cp .droppykit/Tools/focus-buddy-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/FocusBuddy.swift Sources/Pixpaw/PlainText.swift /tmp/main.swift -o /tmp/focus-check && /tmp/focus-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

// Start
var buddy = FocusBuddy()
check(buddy.start(on: true, byHand: true) && buddy.stage == .asking, "a session you start asks what you're working on")
check(buddy.shownTask == nil, "nothing on the sign while it asks")
var off = FocusBuddy()
check(!off.start(on: false, byHand: true) && off.stage == .off, "Body doubling off: no question")
check(!off.start(on: true, byHand: false) && off.stage == .off, "a link or the next round never asks")

// Answer
buddy.answer("  Write the\nreport\t ")
check(buddy.stage == .working && buddy.task == "Write the report", "the answer, on one line, goes on the sign")
check(buddy.shownTask == "Write the report", "the sign shows it")

// Halfway
check(!buddy.wantsCheck(elapsed: 10 * 60, length: 25 * 60, quiet: false, busy: false), "not before halfway")
check(!buddy.wantsCheck(elapsed: 13 * 60, length: 25 * 60, quiet: true, busy: false), "never in a call or a shared screen")
check(!buddy.wantsCheck(elapsed: 13 * 60, length: 25 * 60, quiet: false, busy: true), "never over an agent's question")
check(buddy.wantsCheck(elapsed: 13 * 60, length: 25 * 60, quiet: false, busy: false), "halfway: still on it?")
buddy.check()
check(buddy.stage == .checking, "the halfway card is up")
buddy.stillOn()
check(buddy.stage == .working && buddy.task == "Write the report", "Yes keeps the task")
check(!buddy.wantsCheck(elapsed: 20 * 60, length: 25 * 60, quiet: false, busy: false), "asked once a session")

// Switch
var switching = FocusBuddy()
_ = switching.start(on: true, byHand: true)
switching.answer("Emails")
switching.check()
switching.switchTask()
check(switching.stage == .switching, "Switch opens the field")
switching.answer("Slides for Monday")
check(switching.stage == .working && switching.task == "Slides for Monday", "the new task goes on the sign")
var kept = FocusBuddy()
_ = kept.start(on: true, byHand: true)
kept.answer("Emails")
kept.check()
kept.switchTask()
kept.answer("   ")
check(kept.stage == .working && kept.task == "Emails", "an empty switch keeps the old task")

// End
check(buddy.end() && buddy.stage == .ending, "the end asks: did it get done?")
check(buddy.finish(done: true) == .star && buddy.stage == .off, "Done earns a star")
_ = switching.end()
check(switching.finish(done: false) == .kindWord && switching.stage == .off, "Not yet: a kind word, nothing lost")
_ = kept.end()
check(kept.finish(done: nil) == nil && kept.stage == .off, "unanswered: nothing said")

// Skip
var skipped = FocusBuddy()
_ = skipped.start(on: true, byHand: true)
skipped.answer(nil)
check(skipped.stage == .off && skipped.task == nil, "Skip: no task this session")
check(!skipped.wantsCheck(elapsed: 20 * 60, length: 25 * 60, quiet: false, busy: false), "Skip: no halfway question")
check(!skipped.end(), "Skip: no end question")
var unanswered = FocusBuddy()
_ = unanswered.start(on: true, byHand: true)
check(!unanswered.end() && unanswered.stage == .off, "stopped before answering: nothing asked")

// Done from the sign
var early = FocusBuddy()
_ = early.start(on: true, byHand: true)
early.answer("Fix the bug")
check(early.finish(done: true) == .star && early.stage == .off, "the sign clicked done earns the star early")
check(!early.end(), "and nothing is asked at the end")

// Cleaning
check(PlainText.line(String(repeating: "a", count: 60), limit: 40)?.count == 40, "capped at the limit")
check(PlainText.line("a\u{202E}b\u{200B}c", limit: 40) == "abc", "bidi overrides and zero-width characters out")
check(PlainText.line("\n\t \u{0007}", limit: 40) == nil, "nothing left: nil")

print(failures == 0 ? "All good." : "\(failures) failed.")
exit(failures == 0 ? 0 : 1)
