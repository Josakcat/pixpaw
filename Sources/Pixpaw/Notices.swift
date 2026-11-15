//
//  Notices.swift
//  Pixpaw
//
//  What Pixpaw puts in Droppy's notification stack (DroppyKit 1.23): only
//  what you'd want to read later, when nobody would see the bubble. A
//  meeting summary saved, a timed note or one of your reminders that came
//  due while you were away, a coding agent that finished, failed or needs
//  you while you were away, and the day's gift still waiting. Droppy queues
//  them, folds a thread into one row, honours Focus and the droplet's own
//  Show notifications switch. Live moments stay bubbles.
//

import DroppyKit
import Foundation

enum Notice {
    static let gift = "gift"
    static let meetingPrefix = "meeting-"

    /// The summary is saved and on the shelf; Open opens the file.
    static func meetingSaved(title: String?, summarised: Bool, at date: Date = Date()) -> DropletNotification {
        DropletNotification(
            id: meetingPrefix + String(Int(date.timeIntervalSince1970)),
            threadID: "meetings",
            title: summarised ? "Meeting notes are ready" : "Meeting transcript saved",
            body: clip(title ?? "") ?? (summarised ? "The summary is on your shelf." : "The summary didn't come; the transcript is on your shelf."),
            systemImage: "doc.text.fill",
            actions: [DropletNotificationAction(id: "open", title: "Open")]
        )
    }

    static let dayRecapID = "day-recap"

    /// The end-of-day recap, when you'd stepped away at your usual stop.
    static func dayRecap(_ line: String) -> DropletNotification {
        DropletNotification(id: dayRecapID, threadID: "day", title: "Today so far",
                            body: line, systemImage: "sun.horizon.fill")
    }

    static let wrappedID = "wrapped"

    /// Pixpaw Wrapped: last week or last month, when you'd stepped away.
    static func wrapped(_ title: String, _ line: String) -> DropletNotification {
        DropletNotification(id: wrappedID, threadID: "day", title: "\(title) with your pet",
                            body: line, systemImage: "calendar")
    }

    /// A timed note or one of your own reminders that came due while you were away.
    static func missedReminder(_ text: String, symbol: String = "bell.fill", id: String) -> DropletNotification {
        DropletNotification(id: "reminder-" + id, threadID: "reminders", title: "While you were away",
                            body: clip(text), systemImage: symbol)
    }

    /// A coding agent finished, failed or is waiting on you while you were away.
    static func agent(_ name: String, state: AgentStatus.State, detail: String?) -> DropletNotification? {
        let title: String, symbol: String
        switch state {
        case .done: (title, symbol) = ("\(name) finished", "checkmark.circle.fill")
        case .error: (title, symbol) = ("\(name) hit a snag", "exclamationmark.triangle.fill")
        case .waiting: (title, symbol) = ("\(name) needs you", "hand.raised.fill")
        case .working: return nil
        }
        // One row per agent: its newest news replaces the last.
        return DropletNotification(id: "agent-" + name, threadID: "agents", title: title, body: clip(detail ?? ""), systemImage: symbol)
    }

    /// Today's gift, left by the pet and still not picked up.
    static func giftWaiting(from name: String?) -> DropletNotification {
        DropletNotification(id: gift, title: "\(name ?? "Your pet") left you a gift",
                            body: "It's waiting by your pet: a star or three when you pick it up.",
                            systemImage: "gift.fill",
                            actions: [DropletNotificationAction(id: "take", title: "Take it")])
    }

    /// One line, at most 160 characters, nil when empty.
    static func clip(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }
        return line.count > 160 ? String(line.prefix(159)) + "…" : line
    }
}
