//
//  ClockText.swift
//  Pixpaw
//
//  The time left on a focus or break clock, as the notch row reads it:
//  "24:59", "1:05:00", never below "0:00". Pure, so
//  .droppykit/Tools/clock-text-check.swift can check it without Droppy.
//

import Foundation

enum ClockText {
    static func left(from now: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(now).rounded(.up)))
        let hours = total / 3600, minutes = total / 60 % 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
                         : String(format: "%d:%02d", minutes, seconds)
    }

    /// The same, spoken: "24 minutes left", "under a minute left".
    static func spoken(from now: Date, to end: Date) -> String {
        let minutes = Int(max(0, end.timeIntervalSince(now)) / 60)
        switch minutes {
        case 0: return "under a minute left"
        case 1: return "1 minute left"
        default: return "\(minutes) minutes left"
        }
    }
}
