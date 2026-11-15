// Checks when battery saver is on and how the CPU share reads, on its own,
// no Droppy needed:
//   cp .droppykit/Tools/power-saver-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/PowerSaverRule.swift /tmp/main.swift -o /tmp/power-check && /tmp/power-check

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    if !ok { failures += 1; print("FAIL:", what) }
}

expect(!PowerSaverRule.active(switchOn: false, onBattery: true, lowPowerMode: true), "switch off: never saves")
expect(!PowerSaverRule.active(switchOn: true, onBattery: false, lowPowerMode: false), "switch on, plugged in: walks as usual")
expect(PowerSaverRule.active(switchOn: true, onBattery: true, lowPowerMode: false), "switch on, on battery: saves")
expect(PowerSaverRule.active(switchOn: true, onBattery: false, lowPowerMode: true), "switch on, Low Power Mode: saves")

expect(PowerSaverRule.percent(busySeconds: 0.05, overSeconds: 5) == 1, "0.05 s over 5 s is 1%")
expect(PowerSaverRule.percent(busySeconds: 1, overSeconds: 0.5) == nil, "too short a window says nothing")
expect(PowerSaverRule.percent(busySeconds: -1, overSeconds: 5) == nil, "a counter going back says nothing")

expect(PowerSaverRule.text(0.04) == "<0.1%", "tiny share")
expect(PowerSaverRule.text(0.34) == "0.3%", "one decimal under ten")
expect(PowerSaverRule.text(12.4) == "12%", "whole numbers from ten")

if failures == 0 { print("power-saver-check: all good") } else { print("power-saver-check: \(failures) failed"); exit(1) }
