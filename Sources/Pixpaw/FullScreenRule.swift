//
//  FullScreenRule.swift
//  Pixpaw
//
//  When the app in front fills a display, the pet keeps quiet (QuietWatcher).
//

import CoreGraphics

/// Whether the app in front covers a display, from window bounds alone.
/// Pure, so .droppykit/Tools/quiet-check.swift can run it.
enum FullScreenRule {
    struct Window: Equatable {
        var pid: Int32
        var layer: Int
        var alpha: Double
        var bounds: CGRect
    }

    /// Only the front app counts (an overlay utility's clear window spans
    /// displays too), never this process (Droppy and the pet), only a
    /// visible window, and only at an app's own levels: the menu bar, Dock
    /// and screen savers sit far above them.
    static func fills(_ windows: [Window], front: Int32, own: Int32, displays: [CGRect]) -> Bool {
        guard front != own else { return false }
        return windows.contains { window in
            window.pid == front && window.alpha > 0.01 && (0..<1000).contains(window.layer)
                && displays.contains { covers(window.bounds, $0) }
        }
    }

    /// Within a point on every edge: some apps round their frame.
    static func covers(_ bounds: CGRect, _ display: CGRect) -> Bool {
        guard display.width > 0, display.height > 0 else { return false }
        return bounds.minX <= display.minX + 1 && bounds.minY <= display.minY + 1
            && bounds.maxX >= display.maxX - 1 && bounds.maxY >= display.maxY - 1
    }
}
