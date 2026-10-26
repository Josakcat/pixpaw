//
//  Meetings.swift
//  Pixpaw
//
//  A calendar event's video call: the link to join it, found the way
//  MeetingBar finds one, in the event's URL, location or notes.
//

import AppKit
import EventKit

struct Meeting: Equatable {
    var title: String
    var start: Date
    var link: URL
}

enum MeetingLink {
    /// Hosts (and the start of the path, where the host alone isn't enough)
    /// of the video-call services a link can be joined at.
    private static let services: [(host: String, path: String)] = [
        ("zoom.us", "/j/"), ("zoom.us", "/my/"), ("zoom.us", "/w/"), ("zoomgov.com", "/j/"),
        ("meet.google.com", "/"),
        ("teams.microsoft.com", "/l/meetup-join"), ("teams.microsoft.com", "/meet/"), ("teams.live.com", "/meet"),
        ("webex.com", "/"), ("facetime.apple.com", "/join"),
        ("whereby.com", "/"), ("around.co", "/"), ("meet.jit.si", "/"), ("chime.aws", "/"),
        ("gotomeeting.com", "/join"), ("meet.goto.com", "/"), ("bluejeans.com", "/"), ("join.skype.com", "/"),
        ("app.slack.com", "/huddle"), ("discord.gg", "/"), ("discord.com", "/channels"), ("pop.com", "/"),
        ("meet.lync.com", "/"), ("vowel.com", "/"), ("livestorm.co", "/"), ("streamyard.com", "/"),
    ]

    /// The first call link in the event, looking at its URL, then where it
    /// is, then its notes.
    static func find(in event: EKEvent) -> URL? {
        if let url = event.url, isCall(url) { return url }
        return [event.location, event.notes].compactMap { $0 }.lazy.compactMap(find(inText:)).first
    }

    static func find(inText text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url).first(where: isCall)
    }

    static func isCall(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased() + "/"
        return services.contains { service in
            (host == service.host || host.hasSuffix("." + service.host)) && path.hasPrefix(service.path)
                && (service.path != "/" || path.count > 2)
        }
    }

    /// The call you'd want to join now: one under way that started in the
    /// last half hour, or the next to start in the coming quarter hour.
    @MainActor static func next(store: EKEventStore = EKEventStore()) -> Meeting? {
        guard CalendarWatcher.hasAccess else { return nil }
        let now = Date()
        let events = store.events(matching: store.predicateForEvents(withStart: now.addingTimeInterval(-30 * 60),
                                                                    end: now.addingTimeInterval(15 * 60), calendars: nil))
        return events
            .filter { !$0.isAllDay && ($0.endDate ?? .distantFuture) > now }
            .compactMap { event in
                guard let start = event.startDate, let link = find(in: event) else { return nil }
                return Meeting(title: event.title ?? "Meeting", start: start, link: link)
            }
            .min { abs($0.start.timeIntervalSince(now)) < abs($1.start.timeIntervalSince(now)) }
    }
}

/// A date it counts down to, on its sign: "Trip to Japan · 12 days".
struct Countdown: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    /// The day itself, at its start.
    var day: Date
    /// Whether it already celebrated the day.
    var celebrated = false

    static let limit = 5

    /// Whole days from today to the day; 0 on the day, below 0 after it.
    var daysLeft: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: day)).day ?? 0
    }

    var whenText: String {
        switch daysLeft {
        case ..<0: "done"
        case 0: "today!"
        case 1: "tomorrow"
        case let days: "\(days) days"
        }
    }
}
