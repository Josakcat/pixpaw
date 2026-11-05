//
//  DockDoorPro.swift
//  Pixpaw
//
//  DockDoor Pro (by ejbills) replaces the macOS Dock with its own: one
//  window at layer 18, above the pet's floating level, much taller than
//  the bar you see (the rest is room for magnified icons). While it runs,
//  the pet goes in front of it, and stands on the top of the bar
//  when the bar is along the bottom of a screen.
//

import AppKit
import ApplicationServices

@MainActor
enum DockDoorPro {
    static let bundleID = "com.ejbills.DockDoorPro"

    /// Whether it was running at the last look.
    private(set) static var running = false
    /// Its bar, in AppKit coordinates; nil when it isn't running, the bar is
    /// hidden or off screen, or Accessibility isn't allowed.
    private(set) static var bar: CGRect?
    private static var reading = false

    /// The status bar's level, like the pet's speech bubble: its Dock reports
    /// layer 18, yet a magnified icon covered the pet at 19 (seen live, 2026-11-05).
    static let aboveDock = NSWindow.Level.statusBar
    static var petLevel: NSWindow.Level { running ? aboveDock : .floating }

    /// Looks again, off the main thread.
    static func refresh() {
        guard !reading else { return }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            running = false
            bar = nil
            return
        }
        reading = true
        let pid = app.processIdentifier
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        Task.detached(priority: .utility) {
            let found = readBar(pid)
            await MainActor.run {
                reading = false
                // Top-left coordinates to AppKit's, and only while it is on a screen.
                let flipped = found.map { CGRect(x: $0.minX, y: primaryHeight - $0.maxY, width: $0.width, height: $0.height) }
                let onScreen = flipped.flatMap { rect in
                    NSScreen.screens.contains { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) } ? rect : nil
                }
                running = true
                bar = onScreen
            }
        }
    }

    /// The widest flat group in the window it draws its Dock in (the one
    /// above the normal window layer; its Settings window is a normal one).
    private nonisolated static func readBar(_ pid: pid_t) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let dockFrames = windows.compactMap { window -> CGRect? in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int ?? 0) > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
        guard !dockFrames.isEmpty else { return nil }

        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        var best: CGRect?
        for window in children(app, kAXWindowsAttribute) {
            guard let frame = frame(window), dockFrames.contains(where: { $0.insetBy(dx: -2, dy: -2).contains(frame) }) else { continue }
            for group in children(window, kAXChildrenAttribute) {
                for item in [group] + children(group, kAXChildrenAttribute) {
                    guard let rect = Self.frame(item), rect != frame,
                          rect.width > rect.height * 4, (20...160).contains(rect.height) else { continue }
                    if rect.width > best?.width ?? 0 { best = rect }
                }
            }
        }
        return best
    }

    private nonisolated static func children(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private nonisolated static func frame(_ element: AXUIElement) -> CGRect? {
        var position: AnyObject?, size: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: point, size: extent)
    }
}
