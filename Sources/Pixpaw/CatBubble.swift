//
//  CatBubble.swift
//  Pixpaw
//
//  The speech bubble the cat talks through: a small click-through panel that
//  sits over the cat's head (or under the notch while it sleeps there), shows
//  one line at a time and works through a short queue.
//

import AppKit
import SwiftUI

/// One thing the cat has to say.
struct CatLine: Equatable {
    var text: String
    /// An SF Symbol shown before the text, for alerts from outside the cat.
    var symbol: String?
    /// Lines with the same key replace each other in place instead of
    /// queuing, and show briefly: a volume level as the key is held.
    var key: String?
    /// How long it stays up, when two seconds is too short (a reminder).
    var seconds: Double?
}

@MainActor
final class CatBubble {
    private static let maxQueued = 3
    private static let maxWidth: CGFloat = 260

    private var panel: CatPanel?
    private var hosting: NSHostingView<CatBubbleView>?
    private var queue: [CatLine] = []
    private var current: CatLine?
    private var hideAt: Date?

    /// Where the bubble points: the top of the cat's head, or the bottom of
    /// the notch with `pointsUp`.
    struct Anchor {
        var point: CGPoint
        var pointsUp: Bool
    }

    var isShowing: Bool { current != nil }

    func say(_ line: CatLine) {
        if let key = line.key {
            if current?.key == key {
                // Same gauge: swap the text and restart its short timer.
                current = line
                hideAt = nil
                return
            }
            if let index = queue.firstIndex(where: { $0.key == key }) {
                queue[index] = line
                return
            }
        }
        if current == nil {
            current = line
            hideAt = nil
        } else if queue.count < Self.maxQueued, line != current, !queue.contains(line) {
            queue.append(line)
        }
    }

    /// Called every tick with where the cat is; shows, moves, times out.
    func update(anchor: Anchor?) {
        guard let anchor else {
            panel?.orderOut(nil)
            return
        }
        if let hideAt, Date() >= hideAt {
            current = queue.isEmpty ? nil : queue.removeFirst()
            self.hideAt = nil
        }
        guard let current else {
            panel?.orderOut(nil)
            return
        }
        if hideAt == nil {
            // About two seconds a line; a level being changed goes a bit sooner.
            let reading = current.seconds ?? (current.key == nil ? 2.0 : 1.5)
            hideAt = Date().addingTimeInterval(reading)
            show(current, pointsUp: anchor.pointsUp)
        }
        place(at: anchor)
    }

    func clear() {
        queue = []
        current = nil
        hideAt = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hosting = nil
    }

    private func show(_ line: CatLine, pointsUp: Bool) {
        // Measure the line so short ones hug their text and long ones wrap at
        // the bubble's widest.
        let font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        let natural = ceil((line.text as NSString).size(withAttributes: [.font: font]).width) + 4
        let room = Self.maxWidth - 20 - (line.symbol == nil ? 0 : 17)
        let view = CatBubbleView(line: line, pointsUp: pointsUp, textWidth: min(natural, room))
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            let panel = CatPanel(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10))
            panel.ignoresMouseEvents = true
            panel.level = .statusBar
            panel.contentView = hosting
            self.hosting = hosting
            self.panel = panel
        }
        let size = hosting?.fittingSize ?? .zero
        panel?.setContentSize(size)
        panel?.orderFrontRegardless()
    }

    private func place(at anchor: Anchor) {
        guard let panel else { return }
        let size = panel.frame.size
        var origin = CGPoint(
            x: anchor.point.x - size.width / 2,
            y: anchor.pointsUp ? anchor.point.y - size.height : anchor.point.y
        )
        if let area = NSScreen.screens.first(where: { NSMouseInRect(anchor.point, $0.frame, false) })?.frame {
            origin.x = min(max(origin.x, area.minX + 4), area.maxX - size.width - 4)
            origin.y = min(max(origin.y, area.minY + 4), area.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
    }
}

/// A white rounded bubble with a dark outline and a little tail.
struct CatBubbleView: View {
    let line: CatLine
    let pointsUp: Bool
    let textWidth: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let symbol = line.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(line.text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .lineLimit(3)
                .frame(width: textWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(white: 0.1))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .padding(pointsUp ? .top : .bottom, 7)
        .background(
            BubbleShape(pointsUp: pointsUp)
                .fill(Color.white)
                .overlay(BubbleShape(pointsUp: pointsUp).stroke(Color(white: 0.12), lineWidth: 2))
                .padding(1)
        )
        .fixedSize()
    }
}

struct BubbleShape: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 7
        let body = pointsUp
            ? CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
            : CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        var path = Path(roundedRect: body, cornerRadius: 10, style: .continuous)
        let mid = rect.midX
        if pointsUp {
            path.move(to: CGPoint(x: mid - 6, y: body.minY + 1))
            path.addLine(to: CGPoint(x: mid, y: rect.minY))
            path.addLine(to: CGPoint(x: mid + 6, y: body.minY + 1))
        } else {
            path.move(to: CGPoint(x: mid - 6, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: mid, y: rect.maxY))
            path.addLine(to: CGPoint(x: mid + 6, y: body.maxY - 1))
        }
        return path
    }
}
