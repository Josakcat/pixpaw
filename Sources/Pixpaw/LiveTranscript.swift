// droppykit-lint: allow-file own-window: the live transcript of meeting notes, a small non-activating panel on the card's own surface that opens only when the user starts Take meeting notes (never from a URL), shows the words already being transcribed on the Mac, never takes the keyboard, says it stays visible in a screen share, and closes and forgets its words on Stop, on an error and in deactivate()
//
//  LiveTranscript.swift
//  Pixpaw
//
//  What meeting notes hears, while it hears it: the last lines (You and
//  Them when both sides are heard) and the line being made out now, in a
//  small floating panel. It only shows; it never takes the keyboard from
//  the call. It asks to be left out of screen sharing (sharingType .none),
//  but macOS doesn't always honour that, so it says it may be visible.
//
//  Cheap by design: the transcriber hands its words over on main already
//  (an async hop off the recogniser's queue), this keeps them in plain
//  values and publishes at most four times a second.
//

import AppKit
import SwiftUI
import DroppyKit

@MainActor
final class LiveTranscript {
    struct Row: Identifiable, Equatable {
        let id: Int
        let you: Bool
        let text: String
    }

    struct Snapshot: Equatable {
        var rows: [Row] = []
        /// What each side is making out now, you first.
        var partials: [(you: Bool, text: String)] = []
        var bothSides = false

        static func == (a: Snapshot, b: Snapshot) -> Bool {
            a.rows == b.rows && a.bothSides == b.bothSides
                && a.partials.map(\.text) == b.partials.map(\.text) && a.partials.map(\.you) == b.partials.map(\.you)
        }
    }

    final class Model: ObservableObject {
        @Published var snapshot = Snapshot()
    }

    /// Where the panel was left, kept by the droplet.
    var savedOrigin: (() -> CGPoint?)?
    var saveOrigin: ((CGPoint) -> Void)?

    private var panel: LiveTranscriptPanel?
    private let model = Model()
    private var rows: [Row] = []
    private var partial: [Bool: String] = [:]
    private var bothSides = false
    private var nextID = 0
    private var flushQueued = false
    private static let keep = 200

    var isOpen: Bool { panel != nil }
    var isShowing: Bool { panel?.isVisible ?? false }

    /// Closes and forgets the meeting's words: as one starts, and on Stop,
    /// an error and deactivate().
    func reset() {
        close()
        rows = []
        partial = [:]
        bothSides = false
        nextID = 0
        model.snapshot = Snapshot()
    }

    /// Shows the transcript of the meeting under way, its lines so far too.
    func open(title: String?, startedAt: Date, look: PetCardLook, level: Double, onStop: @escaping () -> Void) {
        close()
        let view = LiveTranscriptView(model: model, title: title ?? "Meeting notes", startedAt: startedAt, look: look, level: level,
                                      stop: onStop, hide: { [weak self] in self?.hide() })
        let panel = LiveTranscriptPanel(LiveTranscriptView.size)
        panel.contentView = NSHostingView(rootView: view)
        panel.animationBehavior = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .none : .utilityWindow
        if let origin = savedOrigin?(), NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: -40, dy: -40).contains(origin) }) {
            panel.setFrameOrigin(origin)
        } else if let area = (NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
            // Top right, under the menu bar, out of the call's way.
            panel.setFrameOrigin(CGPoint(x: area.maxX - LiveTranscriptView.size.width - 20,
                                         y: area.maxY - LiveTranscriptView.size.height - 20))
        }
        self.panel = panel
        flush()
        // In front, but the call keeps the keyboard.
        panel.orderFrontRegardless()
    }

    /// Brings a hidden transcript back.
    func show() {
        guard let panel else { return }
        flush()
        panel.orderFrontRegardless()
    }

    /// The ×: hides it; the notes go on.
    func hide() {
        guard let panel, panel.isVisible else { return }
        saveOrigin?(panel.frame.origin)
        panel.orderOut(nil)
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        saveOrigin?(panel.frame.origin)
        panel.orderOut(nil)
        panel.close()
    }

    /// Which sides are heard, once the recorder knows.
    func setBothSides(_ both: Bool) {
        bothSides = both
        queueFlush()
    }

    /// The words one side is making out now.
    func heard(you: Bool, _ text: String) {
        partial[you] = text
        queueFlush()
    }

    /// A line one side finished.
    func line(_ line: MeetingLine) {
        partial[line.you] = nil
        rows.append(Row(id: nextID, you: line.you, text: line.text))
        nextID += 1
        if rows.count > Self.keep { rows.removeFirst(rows.count - Self.keep) }
        queueFlush()
    }

    /// At most four updates a second, and none while it's hidden.
    private func queueFlush() {
        guard !flushQueued, isShowing else { return }
        flushQueued = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            MainActor.assumeIsolated {
                self?.flushQueued = false
                self?.flush()
            }
        }
    }

    private func flush() {
        let partials = [true, false].compactMap { side in
            partial[side].flatMap { $0.isEmpty ? nil : (you: side, text: $0) }
        }
        let next = Snapshot(rows: rows, partials: partials, bothSides: bothSides)
        if next != model.snapshot { model.snapshot = next }
    }
}

/// A floating panel that takes clicks but never the keyboard (it can't
/// become key, and nothing in it is selectable), on every Space, dragged by
/// its background. It asks to be left out of screen sharing, as best effort:
/// ScreenCaptureKit may still show it.
private final class LiveTranscriptPanel: NSPanel {
    init(_ size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
        sharingType = .none // Best effort only; not a promise.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        setAccessibilityTitle("Live transcript")
    }

    override var canBecomeKey: Bool { false }
}

private struct LiveTranscriptView: View {
    static let size = CGSize(width: 340, height: 230)
    private static let radius: CGFloat = 16

    @ObservedObject var model: LiveTranscript.Model
    let title: String
    let startedAt: Date
    let look: PetCardLook
    let level: Double
    let stop: () -> Void
    let hide: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Off once the user scrolls up to read back; on again at the bottom.
    @State private var following = true

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            header
            transcript
            footer
        }
        .padding(DroppySpacing.md)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(PetCardSurface(look: look, level: level, radius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.xs) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("Taking notes")
            Spacer(minLength: DroppySpacing.xs)
            Button(action: hide) {
                Image(systemName: "xmark")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 20))
            .help("Hide the transcript (notes go on)")
            .accessibilityLabel("Hide transcript")
            .accessibilityHint("The notes go on. Show it again from your pet's menu.")
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if model.snapshot.rows.isEmpty, model.snapshot.partials.isEmpty {
                        Text("Listening…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.snapshot.rows) { row in
                        line(you: row.you, row.text, live: false)
                    }
                    ForEach(model.snapshot.partials, id: \.you) { partial in
                        line(you: partial.you, partial.text, live: true)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // One text area for VoiceOver: the finished lines, never each
                // word as it's made out.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Transcript")
                .accessibilityValue(spoken)
            }
            .modifier(FollowsBottom(following: $following))
            .onChange(of: model.snapshot) {
                guard following else { return }
                if reduceMotion {
                    proxy.scrollTo("end", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !following {
                    Button {
                        following = true
                        proxy.scrollTo("end", anchor: .bottom)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 24))
                    .help("Jump to the latest")
                    .accessibilityLabel("Jump to the latest line")
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func line(you: Bool, _ text: String, live: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DroppySpacing.sm) {
            if model.snapshot.bothSides {
                Text(you ? "You" : "Them")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(you ? Color.accentColor : Color.secondary)
                    .frame(width: 34, alignment: .leading)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(live ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Text("Visible if you share your screen")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: DroppySpacing.xs)
            Button("Stop and write up", action: stop)
                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                .accessibilityHint("Stops listening and writes up the notes")
        }
    }

    private var spoken: String {
        let rows = model.snapshot.rows.suffix(30)
        guard !rows.isEmpty else { return "Nothing yet" }
        return rows.map { model.snapshot.bothSides ? "\($0.you ? "You" : "Them"): \($0.text)" : $0.text }.joined(separator: "\n")
    }
}

/// Follows new lines while the transcript is at its bottom. Only the
/// user's own scrolling up stops that (new lines grow the content without
/// moving it); back at the bottom it follows again. macOS 15; before that
/// it always follows.
private struct FollowsBottom: ViewModifier {
    @Binding var following: Bool

    private struct Place: Equatable {
        let offset: CGFloat
        let atBottom: Bool
    }

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.onScrollGeometryChange(for: Place.self) { geometry in
                Place(offset: geometry.contentOffset.y,
                      atBottom: geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 24)
            } action: { old, new in
                if new.atBottom {
                    if !following { following = true }
                } else if new.offset < old.offset - 1, following {
                    following = false
                }
            }
        } else {
            content
        }
    }
}
