//
//  BreakHUD.swift
//  Pixpaw
//
//  A break reminder as Droppy's own HUD card (DroppyKit 1.23): the reminder
//  on top and two pill buttons under it, "Stretched" (or "Done") and
//  "Later", in the layout of Droppy's No Internet card. Droppy queues it
//  with its other HUDs, keeps it out of meetings and screen recordings and
//  takes it down after half a minute at most. The pet still comes over; the
//  card is where you answer it.
//

import SwiftUI
import DroppyKit

@MainActor
enum BreakHUD {
    /// One id for every break card: a new one replaces the last.
    static let id = "pixpaw.break"
    static let seconds: TimeInterval = 20
    /// How long "Later" puts a reminder off.
    static let laterMinutes = 10

    /// What the card says for a reminder: its title, a line under it, and
    /// what the main button reads.
    static func words(_ reminder: Reminder) -> (title: String, message: String?, done: String) {
        switch reminder.id {
        case Reminder.stretchID: ("Time for a stretch", "Stand up and stretch along with your pet.", "Stretched")
        case "water": ("Time for some water", "A few sips is plenty.", "Done")
        case "eyes": ("Rest your eyes", "Look far away for 20 seconds.", "Done")
        default: (reminder.text, nil, "Done")
        }
    }

    static func request(_ reminder: Reminder,
                        done: @escaping @MainActor @Sendable () -> Void,
                        later: @escaping @MainActor @Sendable () -> Void) -> DropletHUDRequest {
        let words = words(reminder)
        let symbol = reminder.symbol
        let short = reminder.id == Reminder.stretchID ? "Stretch" : (Reminder.builtInTitles[reminder.id] ?? "Reminder")
        return DropletHUDRequest(
            id: id,
            duration: seconds,
            priority: .normal,
            accessibilityLabel: words.title,
            card: DropletHUDCard(
                title: words.title,
                message: words.message,
                systemImage: symbol,
                actions: [
                    DropletHUDAction(id: "done", title: words.done, isPrimary: true, perform: done),
                    DropletHUDAction(id: "later", title: "Later", perform: later),
                ]
            ),
            isExpanded: true
        ) {
            Image(systemName: symbol)
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .accessibilityHidden(true)
        } trailing: {
            Text(verbatim: short)
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(1)
        }
    }
}
