//
//  PowerSaverRule.swift
//  Pixpaw
//
//  When battery saver is on, and how a CPU share reads (PowerSaver.swift).
//

import Foundation

/// When the saver is on, and how a CPU share reads. Pure, so
/// .droppykit/Tools/power-saver-check.swift can run it.
enum PowerSaverRule {
    /// The switch is the user's; battery or Low Power Mode is the moment.
    static func active(switchOn: Bool, onBattery: Bool, lowPowerMode: Bool) -> Bool {
        switchOn && (onBattery || lowPowerMode)
    }

    /// Share of one core, in percent, between two readings; nil until the
    /// readings are far enough apart to mean something.
    static func percent(busySeconds: Double, overSeconds: Double) -> Double? {
        guard overSeconds >= 1, busySeconds >= 0 else { return nil }
        return busySeconds / overSeconds * 100
    }

    /// "0.3%", "<0.1%", "12%": one decimal below ten, none above.
    static func text(_ percent: Double) -> String {
        if percent < 0.1 { return "<0.1%" }
        if percent < 10 { return String(format: "%.1f%%", percent) }
        return "\(Int(percent.rounded()))%"
    }
}
