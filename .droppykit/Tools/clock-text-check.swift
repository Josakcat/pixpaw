// Checks the focus and break clock's text beside the notch, no Droppy needed:
//   cp .droppykit/Tools/clock-text-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/ClockText.swift /tmp/main.swift -o /tmp/clock-check && /tmp/clock-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
check(ClockText.left(from: now, to: now.addingTimeInterval(25 * 60)) == "25:00", "25 minutes")
check(ClockText.left(from: now, to: now.addingTimeInterval(25 * 60 - 0.4)) == "25:00", "a part second rounds up")
check(ClockText.left(from: now, to: now.addingTimeInterval(59)) == "0:59", "under a minute")
check(ClockText.left(from: now, to: now.addingTimeInterval(3900)) == "1:05:00", "over an hour")
check(ClockText.left(from: now, to: now.addingTimeInterval(-5)) == "0:00", "never below zero")
check(ClockText.spoken(from: now, to: now.addingTimeInterval(30)) == "under a minute left", "spoken, seconds")
check(ClockText.spoken(from: now, to: now.addingTimeInterval(61)) == "1 minute left", "spoken, one")
check(ClockText.spoken(from: now, to: now.addingTimeInterval(24 * 60 + 5)) == "24 minutes left", "spoken, many")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
