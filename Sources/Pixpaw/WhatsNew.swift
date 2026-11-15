//
//  WhatsNew.swift
//  Pixpaw
//
//  After an update (never a fresh install) the pet says what's new, once,
//  in one bubble. DroppyKit's installState only says what is switched on,
//  not whether this is an update, so the last version the pet ran is kept
//  in its own preferences. Pure, so .droppykit/Tools/whats-new-check.swift
//  can check it without Droppy.
//

import Foundation

enum WhatsNew {
    /// One kind line per release with something to tell, by major.minor.
    static let lines: [String: String] = [
        "2.2": "I'm updated! I eat from my own bowls now, and Playroom… in my menu opens a room across the shelf.",
    ]

    /// What to say on this launch: `previous` is the version the pet last
    /// ran (nil before this was kept), `freshInstall` whether nothing at all
    /// was saved before. Nil: nothing to say.
    static func line(previous: String?, current: String, freshInstall: Bool) -> String? {
        if freshInstall { return nil }
        if let previous {
            if !isNewer(current, than: previous) { return nil }
            // A patch of a release already told about: once is enough.
            if majorMinor(previous) == majorMinor(current) { return nil }
        }
        return lines[majorMinor(current)]
    }

    static func majorMinor(_ version: String) -> String {
        version.split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Compares numbered versions part by part, "2.10.0" after "2.9.3".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
