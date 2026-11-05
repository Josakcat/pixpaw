// droppykit-lint: allow-file own-window: the Give your pet a note prompt, a small non-activating panel with a native text field in place of a modal NSAlert, so Droppy's main run loop never stops while it waits; opened only from the shortcut, the pet's menu or Settings, and closed in deactivate(); agreed by Droppy for the Store, 2026-11-05
//
//  NotePrompt.swift
//  Pixpaw
//
//  Asks for a note to add to the pet's sign. A modal alert would spin a modal
//  run loop on Droppy's main thread until it was answered, and the notch,
//  its timers and everything else in Droppy would wait with it. This panel
//  only shows and calls back: nothing waits for it.
//

import AppKit
import SwiftUI

@MainActor
final class NotePrompt {
    private var panel: NotePromptPanel?

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

    func close() {
        guard let panel else { return }
        self.panel = nil
        panel.onClose = nil
        panel.orderOut(nil)
        panel.close()
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
