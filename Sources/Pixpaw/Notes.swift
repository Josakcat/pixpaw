//
//  Notes.swift
//  Pixpaw
//
//  Your to-do list on the pet's sign: it holds up the first note until you
//  click it done, then the next. A note can carry a time ("Tea in 10 min",
//  "Call Mum at 5") and the pet comes over to remind you when it's up.
//

import AppKit

struct PetNote: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String
    /// When to come and remind you, if the note named a time.
    var due: Date?
    /// Whether it already came to remind you.
    var told = false

    static let limit = 10
}

/// Days in a row with at least one note done.
struct NoteStreak: Codable, Equatable {
    var day = ""
    var days = 0

    /// Counts today, and says whether that made the run longer.
    mutating func countToday() -> Bool {
        let today = StarDay.today
        guard day != today else { return false }
        days = day == Self.yesterday ? days + 1 : 1
        day = today
        return true
    }

    /// The run so far: still alive today or yesterday, otherwise over.
    var current: Int { day == StarDay.today || day == Self.yesterday ? days : 0 }

    private static var yesterday: String {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

enum NoteTime {
    /// The time a note names, if any: "in 10 min", "in 2 hours", "in 1h 30m",
    /// "at 5", "at 5pm", "at 5:30", "at 17:30". A bare hour is the next
    /// time that hour comes round on the clock, and a time already past
    /// today is tomorrow's.
    static func due(in text: String, now: Date = Date()) -> Date? {
        let lower = text.lowercased()
        if let match = lower.firstMatch(of: #/\bin\s+(\d{1,2})\s*(?:h|hr|hrs|hour|hours)\b(?:\s*(?:and\s*)?(\d{1,2})\s*(?:m|min|mins|minute|minutes)\b)?/#) {
            let minutes = (Int(match.1) ?? 0) * 60 + (match.2.flatMap { Int($0) } ?? 0)
            return minutes > 0 ? now.addingTimeInterval(TimeInterval(minutes * 60)) : nil
        }
        // "in 10" alone isn't a time; "in 10 min" is.
        if let match = lower.firstMatch(of: #/\bin\s+(\d{1,3})\s*(?:m|min|mins|minute|minutes)\b/#) {
            let minutes = Int(match.1) ?? 0
            return minutes > 0 ? now.addingTimeInterval(TimeInterval(minutes * 60)) : nil
        }
        guard let match = lower.firstMatch(of: #/\bat\s+(\d{1,2})(?:[.:](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?=\W|$)/#),
              var hour = Int(match.1), hour < 24 else { return nil }
        let minute = match.2.flatMap { Int($0) } ?? 0
        guard minute < 60 else { return nil }
        let calendar = Calendar.current
        func next(_ hour: Int) -> Date? {
            guard let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
            return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
        }
        if let meridiem = match.3 {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (meridiem.hasPrefix("p") ? 12 : 0)
            return next(hour)
        }
        // A 24-hour time, or an hour that could be either: the sooner one.
        guard (1...12).contains(hour) else { return next(hour) }
        return [next(hour % 12), next(hour % 12 + 12)].compactMap { $0 }.min()
    }
}

/// Notices, during a focus session only, that you have been somewhere you
/// said distracts you for a while: an app whose name, or a window whose
/// title (a browser tab), has one of your words in it. Only the frontmost
/// app's name and its front window's title are read, once every five
/// seconds while focusing, and nothing is kept.
@MainActor
final class DistractionWatcher {
    static let defaultWords = ["YouTube", "Netflix", "Reddit", "Facebook", "Instagram", "TikTok", "Twitch", "Steam", "X"]
    /// How long somewhere distracting before it comes over.
    static let grace: TimeInterval = 120
    /// And how long until it may come again.
    static let again: TimeInterval = 600

    var words: [String] = DistractionWatcher.defaultWords
    var onNudge: ((String) -> Void)?
    private var timer: Timer?
    private var since: Date?
    private var nudgedAt = Date.distantPast

    func start() {
        guard timer == nil else { return }
        since = nil
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        since = nil
    }

    private func check() {
        guard let found = distraction() else { since = nil; return }
        let now = Date()
        let start = since ?? now
        since = start
        guard now.timeIntervalSince(start) >= Self.grace, now.timeIntervalSince(nudgedAt) >= Self.again else { return }
        nudgedAt = now
        onNudge?(found)
    }

    /// The word that matched the app in front, or its front window.
    private func distraction() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        var places = [app.localizedName ?? ""]
        if let title = Self.frontWindowTitle(of: app.processIdentifier) { places.append(title) }
        return words.first { word in places.contains { Self.place($0, has: word) } }
    }

    /// A whole word, so "X" is the site and not the x in Xcode; a word of
    /// one or two letters must match its case too.
    nonisolated static func place(_ place: String, has word: String) -> Bool {
        let word = word.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return false }
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
        let options: NSRegularExpression.Options = word.count <= 2 ? [] : [.caseInsensitive]
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
        return regex.firstMatch(in: place, range: NSRange(place.startIndex..., in: place)) != nil
    }

    private static func frontWindowTitle(of pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }
}
