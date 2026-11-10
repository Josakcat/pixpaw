// droppykit-lint: allow-file own-window: the Give your pet a note prompt, a small non-activating panel with a native text field in place of a modal NSAlert, so Droppy's main run loop never stops while it waits; opened only from the shortcut, the pet's menu or Settings, and closed in deactivate(); the same panel asks How should I sum it up? only after the user presses Stop on meeting notes, answers itself with the usual notes after 30 seconds, and is closed as cancelled in deactivate() (no summary runs); agreed by Droppy for the Store, 2026-11-05
//
//  NotePrompt.swift
//  Pixpaw
//
//  Asks for a note to add to the pet's sign, and how to sum up a meeting
//  after Stop. A modal alert would spin a modal
//  run loop on Droppy's main thread until it was answered, and the notch,
//  its timers and everything else in Droppy would wait with it. This panel
//  only shows and calls back: nothing waits for it.
//

import AppKit
import SwiftUI
import DroppyKit

@MainActor
final class NotePrompt {
    private var panel: NotePromptPanel?
    private var expiry: Timer?
    /// The angle prompt's answer for when it goes away unanswered.
    private var onAbandon: (() -> Void)?
    /// The angle prompt's way out when it is called off (`cancel()`).
    private var onCancelled: (() -> Void)?

    /// Shows the prompt on the screen with the pointer; `onAdd` gets the
    /// text when it is added. A prompt already up comes to the front.
    func show(full: Bool, limit: Int, onAdd: @escaping (String) -> Void) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let view = NotePromptView(
            full: full,
            limit: limit,
            add: { [weak self] text in
                self?.close()
                onAdd(text)
            },
            cancel: { [weak self] in self?.close() }
        )
        present(view)
    }

    /// Asks how to sum up the meeting just stopped. `onAnswer` is called
    /// exactly once: with the angle, or nil for the usual notes on Usual notes,
    /// Esc, closing, `close()` or 30 seconds without an answer (the clock
    /// stops once you start typing, so a half-typed angle is never lost);
    /// or `onCancel` instead, once, on `cancel()`.
    func askAngle(recent: [String], onAnswer: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        close()
        var answered = false
        let answer: (String?) -> Void = { [weak self] angle in
            guard !answered else { return }
            answered = true
            self?.close()
            onAnswer(angle)
        }
        present(AnglePromptView(recent: recent, deadline: Date().addingTimeInterval(30), pick: answer,
                                onTyping: { [weak self] in self?.expiry?.invalidate(); self?.expiry = nil }))
        panel?.onClose = { [weak self] in
            self?.panel = nil
            answer(nil)
        }
        onAbandon = { answer(nil) }
        onCancelled = {
            guard !answered else { return }
            answered = true
            onCancel()
        }
        expiry = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func present(_ view: some View) {
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        let panel = NotePromptPanel(contentRect: CGRect(origin: .zero, size: size))
        panel.contentView = hosting
        panel.onClose = { [weak self] in self?.panel = nil }
        // Where an alert would be: centred, a little above the middle.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            panel.setFrameOrigin(CGPoint(x: (area.midX - size.width / 2).rounded(),
                                         y: (area.minY + area.height * 0.62 - size.height / 2).rounded()))
        }
        self.panel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes it as called off: an angle prompt answers `onCancel`, never the
    /// usual notes, so nothing is summed up after deactivate().
    func cancel() {
        let cancelled = onCancelled
        onAbandon = nil
        close()
        cancelled?()
    }

    func close() {
        expiry?.invalidate()
        expiry = nil
        let abandon = onAbandon
        onAbandon = nil
        onCancelled = nil
        if let panel {
            self.panel = nil
            panel.onClose = nil
            panel.orderOut(nil)
            panel.close()
        }
        abandon?()
    }
}

/// A floating utility panel that takes the keyboard without making Droppy
/// the frontmost app's window in its place.
private final class NotePromptPanel: NSPanel {
    var onClose: (() -> Void)?

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { close() }

    override func close() {
        let onClose = self.onClose
        self.onClose = nil
        super.close()
        onClose?()
    }
}

private struct NotePromptView: View {
    let full: Bool
    let limit: Int
    let add: (String) -> Void
    let cancel: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Give your pet a note")
                .font(.headline)
            Text(full
                 ? "Its list is full (\(limit) notes). Click the sign when one is done to make room."
                 : "It holds the first note up on its sign until you click it done, then the next. Add a time like “in 10 min” or “at 5pm” and it comes over to remind you.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !full {
                TextField("Note", text: $text, prompt: Text("Buy milk"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .focused($focused)
                    .onSubmit { add(text) }
            }
            HStack {
                Spacer()
                if full {
                    Button("OK", action: cancel)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel", action: cancel)
                        .keyboardShortcut(.cancelAction)
                    Button("Add") { add(text) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
        .padding(.bottom, 16)
        .frame(width: 340)
        .onAppear { focused = true }
    }
}

private struct AnglePromptView: View {
    let recent: [String]
    /// When it answers itself with the usual notes; shown as a quiet countdown.
    let deadline: Date
    let pick: (String?) -> Void
    /// The first keystroke: stop the clock.
    let onTyping: () -> Void
    /// Offered on first use, before there are any recent angles.
    private static let starters = ["Action items", "Decisions", "For my manager"]
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var typing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How should I sum it up?")
                .font(.headline)
            TextField("Angle", text: $text, prompt: Text("e.g. action items for me · for my manager · in Thai"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .focused($focused)
                .onSubmit { pick(text) }
                .onChange(of: text) {
                    guard !typing, !text.isEmpty else { return }
                    typing = true
                    onTyping()
                }
            // The last three angles as chips, or a few starters on first use.
            HStack(spacing: 8) {
                ForEach(Array((recent.isEmpty ? Self.starters : recent).prefix(3)), id: \.self) { angle in
                    Button(angle) { pick(angle) }
                        .buttonStyle(DroppyQuietButtonStyle(size: .small))
                        .lineLimit(1)
                        .help(angle)
                }
            }
            HStack {
                // Says when the panel will answer for you, so it closing isn't a surprise.
                // Typing stops it: the panel then waits for you.
                if !typing {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(deadline.timeIntervalSince(context.date).rounded(.up)))
                        Text("Usual notes in \(left) s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Usual notes in \(left) seconds")
                    }
                }
                Spacer()
                Button("Usual notes") { pick(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Sum up") { pick(text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
        .padding(.bottom, 16)
        .frame(width: 340)
        .onAppear { focused = true }
    }
}
