//
//  PageCapture.swift
//  Pixpaw
//
//  A picture of the whole page open in Safari, top to bottom: the pet
//  scrolls it a screen at a time, takes the window each time, joins the
//  pieces into one tall PNG and puts the page back where it was. It sees
//  exactly what you see, signed in and all, so it needs Safari's
//  Settings → Developer → Allow JavaScript from Apple Events, and Screen Recording.
//

import AppKit
import ApplicationServices
@preconcurrency import ScreenCaptureKit
import UniformTypeIdentifiers

enum PageCaptureProblem: Error {
    /// Safari isn't open, or has no page up.
    case noPage
    /// Droppy may not control Safari (Privacy & Security → Automation).
    case notAllowed
    /// Settings → Developer → Allow JavaScript from Apple Events is off.
    case noJavaScript
    case noScreenRecording
    case failed
}

@MainActor
enum PageCapture {
    static let safari = "com.apple.Safari"
    /// The tallest picture it makes, in points; a page that goes on
    /// further (or for ever) is cut there.
    static let tallest: CGFloat = 24_000
    /// And the most pixels down it, so a long page doesn't need gigabytes.
    private static let tallestPixels: CGFloat = 32_000
    /// Time for a page to draw, and load what it loads as you scroll.
    private static let settle: Duration = .milliseconds(350)

    static var safariIsOpen: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: safari).isEmpty
    }

    /// Captures the page in Safari's front window and saves it where your
    /// screenshots go. Returns the file.
    static func capture() async throws -> URL {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: safari).first else { throw PageCaptureProblem.noPage }
        guard await mayControlSafari() else { throw PageCaptureProblem.notAllowed }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw PageCaptureProblem.noScreenRecording
        }
        // In front, so it draws as it scrolls.
        try script("tell application id \"\(safari)\" to activate")
        try await Task.sleep(for: settle)

        let start = try measure()
        guard let windowID = frontWindow(of: app.processIdentifier) else { throw PageCaptureProblem.noPage }
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        } catch {
            throw PageCaptureProblem.noScreenRecording
        }
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else { throw PageCaptureProblem.noPage }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true

        // Where the page shows in the window, and how many points to its
        // pixels (page zoom).
        let viewport = viewport(pid: app.processIdentifier, in: window.frame)
            ?? CGRect(x: window.frame.minX, y: window.frame.maxY - start.viewHeight * window.frame.width / start.viewWidth,
                      width: window.frame.width, height: start.viewHeight * window.frame.width / start.viewWidth)
        let points = viewport.height / start.viewHeight

        var frames: [(top: CGFloat, image: CGImage)] = []
        defer { _ = try? run(restore(x: start.x, y: start.y)) }
        var at = try scroll(to: 0, x: start.x)
        var height = at.height
        while true {
            try await Task.sleep(for: settle)
            let shot = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            frames.append((at.y * points, shot))
            if frames.count == 1 { try run(hideStuck) }
            height = max(height, at.height)
            let next = at.y + start.viewHeight
            guard next < height, next * points < tallest else { break }
            let moved = try scroll(to: next, x: start.x)
            // The page wouldn't go any further.
            guard moved.y > at.y else { break }
            at = moved
        }

        let tall = min(height * points, tallest)
        let outScale = max(1, min(scale, tallestPixels / tall))
        guard let image = stitch(frames, width: viewport.width, height: tall, viewHeight: viewport.height,
                                 crop: viewport.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY),
                                 shotScale: scale, outScale: outScale) else { throw PageCaptureProblem.failed }
        return try save(image, title: start.title)
    }

    // MARK: Safari

    /// Asks once for Droppy to control Safari, off the main thread, since
    /// the question waits for you.
    private static func mayControlSafari() async -> Bool {
        await Task.detached {
            let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.Safari")
            guard let desc = target.aeDesc else { return false }
            return AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, true) == noErr
        }.value
    }

    @discardableResult
    private static func script(_ source: String) throws -> String {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            let number = error?[NSAppleScript.errorNumber] as? Int
            let message = error?[NSAppleScript.errorMessage] as? String ?? ""
            if number == -1743 { throw PageCaptureProblem.notAllowed }
            if message.localizedCaseInsensitiveContains("JavaScript") { throw PageCaptureProblem.noJavaScript }
            if number == -1719 || number == -1728 || number == -600 { throw PageCaptureProblem.noPage }
            throw PageCaptureProblem.failed
        }
        return result.stringValue ?? ""
    }

    /// Runs JavaScript in the front tab.
    @discardableResult
    private static func run(_ javaScript: String) throws -> String {
        let quoted = javaScript.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return try script("tell application id \"\(safari)\" to do JavaScript \"\(quoted)\" in current tab of front window")
    }

    private struct Place: Decodable {
        var x: CGFloat
        var y: CGFloat
        var height: CGFloat
        var viewWidth: CGFloat
        var viewHeight: CGFloat
        var title: String
    }

    private static let place = "JSON.stringify({x: scrollX, y: scrollY, height: Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0), viewWidth: innerWidth, viewHeight: innerHeight, title: document.title})"

    private static func measure() throws -> Place {
        guard let data = try run(place).data(using: .utf8),
              let place = try? JSONDecoder().decode(Place.self, from: data),
              place.viewWidth > 0, place.viewHeight > 0 else { throw PageCaptureProblem.failed }
        return place
    }

    private static func scroll(to y: CGFloat, x: CGFloat) throws -> Place {
        try run("window.scrollTo({top: \(Int(y)), left: \(Int(x)), behavior: 'instant'})")
        return try measure()
    }

    /// Headers and buttons that stay put as you scroll would show on every
    /// screen: after the first, they are hidden until it's done.
    private static let hideStuck = """
    document.querySelectorAll('body *').forEach(function (e) { var p = getComputedStyle(e).position; if (p === 'fixed' || p === 'sticky') { e.setAttribute('data-pixpaw-hid', e.style.getPropertyValue('visibility') || '-'); e.style.setProperty('visibility', 'hidden', 'important'); } }); 0
    """

    private static func restore(x: CGFloat, y: CGFloat) -> String {
        """
        document.querySelectorAll('[data-pixpaw-hid]').forEach(function (e) { var v = e.getAttribute('data-pixpaw-hid'); if (v === '-') e.style.removeProperty('visibility'); else e.style.setProperty('visibility', v); e.removeAttribute('data-pixpaw-hid'); }); window.scrollTo({top: \(Int(y)), left: \(Int(x)), behavior: 'instant'}); 0
        """
    }

    // MARK: The window

    /// Safari's frontmost ordinary window on screen.
    private static func frontWindow(of pid: pid_t) -> CGWindowID? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in list where info[kCGWindowOwnerPID as String] as? pid_t == pid && info[kCGWindowLayer as String] as? Int == 0 {
            guard let bounds = info[kCGWindowBounds as String], let frame = CGRect(dictionaryRepresentation: bounds as! CFDictionary),
                  frame.height > 150, frame.width > 150 else { continue }
            return info[kCGWindowNumber as String] as? CGWindowID
        }
        return nil
    }

    /// The part of the window the page shows in, found through
    /// Accessibility; without it, the page is taken to fill the bottom of
    /// the window.
    private static func viewport(pid: pid_t, in window: CGRect) -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        guard let windows = value(app, kAXWindowsAttribute) as? [AXUIElement],
              let front = windows.first(where: { frame(of: $0).map { abs($0.minX - window.minX) < 2 && abs($0.minY - window.minY) < 2 } ?? false }) else { return nil }
        var queue = [(front, 0)]
        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            if value(element, kAXRoleAttribute) as? String == "AXWebArea" {
                // The scroll area around it is what's on screen.
                let parent = value(element, kAXParentAttribute).map { $0 as! AXUIElement }
                let shown = parent.flatMap { value($0, kAXRoleAttribute) as? String == kAXScrollAreaRole ? frame(of: $0) : nil } ?? frame(of: element)
                return shown?.intersection(window)
            }
            guard depth < 10, let children = value(element, kAXChildrenAttribute) as? [AXUIElement] else { continue }
            queue += children.map { ($0, depth + 1) }
        }
        return nil
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), let size = value(element, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    // MARK: The picture

    /// Lays the screens one under another, each adding only what the ones
    /// before it hadn't shown.
    private static func stitch(_ frames: [(top: CGFloat, image: CGImage)], width: CGFloat, height: CGFloat, viewHeight: CGFloat,
                               crop: CGRect, shotScale: CGFloat, outScale: CGFloat) -> CGImage? {
        let pixelWidth = Int((width * outScale).rounded()), pixelHeight = Int((height * outScale).rounded())
        guard pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        let source = CGRect(x: crop.minX * shotScale, y: crop.minY * shotScale, width: crop.width * shotScale, height: crop.height * shotScale).integral
        var shown: CGFloat = 0
        for frame in frames {
            guard let piece = frame.image.cropping(to: source) else { continue }
            let bottom = min(frame.top + viewHeight, height)
            guard bottom > shown else { continue }
            // Page points from the top, flipped for the context.
            let new = CGRect(x: 0, y: (height - bottom) * outScale, width: width * outScale, height: (bottom - max(shown, frame.top)) * outScale)
            context.saveGState()
            context.clip(to: new)
            context.draw(piece, in: CGRect(x: 0, y: (height - frame.top - viewHeight) * outScale, width: width * outScale, height: viewHeight * outScale))
            context.restoreGState()
            shown = bottom
        }
        return context.makeImage()
    }

    /// Where your screenshots go (Screenshot's Options), or the Desktop.
    static var folder: URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            var directory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue { return url }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    private static func save(_ image: CGImage, title: String) throws -> URL {
        let format = DateFormatter()
        format.calendar = Calendar(identifier: .gregorian)
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        var name = title.components(separatedBy: CharacterSet(charactersIn: "/:\\\n\r\t")).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if name.count > 60 { name = String(name.prefix(60)).trimmingCharacters(in: .whitespaces) + "…" }
        if name.isEmpty { name = "Safari page" }
        let url = folder.appendingPathComponent("\(name) \(format.string(from: Date())).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw PageCaptureProblem.failed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PageCaptureProblem.failed }
        return url
    }
}
