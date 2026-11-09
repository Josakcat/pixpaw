// droppykit-lint: allow-file own-window: the pet's "What can I do?" box, a small non-activating panel on the card's own surface (PetCardSurface) over the pet, under the same waiver as its card; opened only by the user (its menu item, the 🔍 on the card, typing while the card is open, or its shortcut), closes on Escape, a click elsewhere (a mouse-click monitor, only while it is open) or once a row runs, and closed in deactivate()
//
//  AskBox.swift
//  Pixpaw
//
//  "What can I do?": type what you want and your pet finds it among its own
//  commands and Droppy's, Return runs it. Droppy's search is asked only
//  while you type, from two characters, 150 ms after the last key; the old
//  question is cancelled whenever the text changes, and the answers are
//  dropped when the box closes. Ranking and filters: AskRanking.swift.
//

import AppKit
import DroppyKit
import SwiftUI

/// What the box needs from the droplet, read each time it opens or changes.
@MainActor
struct AskBoxSource {
    /// The pet's commands and Droppy's catalog.
    var catalog: () -> [AskCandidate]
    /// What's happening right now: the Right now buttons, as rows.
    var now: () -> [AskCandidate]
    /// The typed text as one of the pet's commands ("note buy milk").
    var parse: (String) -> AskCandidate?
    /// Droppy's search, nil with no launcher.
    var search: ((String) async -> [AskCandidate])?
    var quiet: () -> Bool
    var uses: () -> [String: Int]
    /// Shown with nothing typed when little has been used yet.
    var defaults: [String]
    /// Runs a row, after the box has closed; `typed` is the text.
    var run: (AskCandidate, String) -> Void
    /// Nothing matched what's typed.
    var nothing: () -> Void
}

@MainActor
final class AskBoxModel: ObservableObject {
    @Published var text = "" { didSet { if text != oldValue { changed() } } }
    @Published private(set) var rows: [AskCandidate] = []
    @Published var selected = 0
    var source: AskBoxSource?
    var submit: ((AskCandidate) -> Void)?
    private var found: [AskCandidate] = []
    private var searching: Task<Void, Never>?
    private var saidNothing = false

    func start(_ source: AskBoxSource, text: String) {
        self.source = source
        found = []
        saidNothing = false
        if self.text == text { changed() } else { self.text = text }
    }

    /// Closed: no question left running, no answer kept.
    func reset() {
        searching?.cancel()
        searching = nil
        found = []
        rows = []
        source = nil
        submit = nil
        text = ""
        selected = 0
    }

    func move(_ by: Int) {
        guard !rows.isEmpty else { return }
        selected = (selected + by + rows.count) % rows.count
    }

    func runSelected() {
        guard rows.indices.contains(selected) else { return nothingFound(force: true) }
        submit?(rows[selected])
    }

    private func changed() {
        searching?.cancel()
        searching = nil
        found = []
        guard let source else { return }
        let query = text
        refresh(settled: !(AskRanking.searches(query) && source.search != nil))
        guard AskRanking.searches(query), let search = source.search else { return }
        searching = Task { [weak self] in
            try? await Task.sleep(for: AskRanking.debounce)
            guard !Task.isCancelled else { return }
            let answer = await search(query)
            guard !Task.isCancelled, let self, self.text == query else { return }
            self.found = answer
            self.refresh(settled: true)
        }
    }

    private func refresh(settled: Bool) {
        guard let source else { return }
        let quiet = source.quiet(), uses = source.uses()
        let query = text.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            rows = AskRanking.empty(now: source.now(), all: source.catalog(), defaults: source.defaults, quiet: quiet, uses: uses)
        } else {
            let parsed = source.parse(query).map { [$0] } ?? []
            rows = AskRanking.rank(parsed + source.catalog() + found, query: query, quiet: quiet, uses: uses)
        }
        selected = min(selected, max(0, rows.count - 1))
        if rows.isEmpty, !query.isEmpty { if settled { nothingFound(force: false) } } else { saidNothing = false }
    }

    /// "Hmm?" once, not at every key.
    private func nothingFound(force: Bool) {
        guard force || !saidNothing else { return }
        saidNothing = true
        source?.nothing()
    }
}

@MainActor
final class AskBox {
    private var panel: AskBoxPanel?
    private var activation: DroppyPanelActivation?
    private var clickAway: Any?
    private var clickInside: Any?
    private let model = AskBoxModel()

    var isOpen: Bool { panel != nil }

    /// Opens over `petFrame` (screen coordinates), or where an alert would
    /// be without one, with `text` already typed. Open already: comes to
    /// the front with the new text.
    func show(over petFrame: CGRect?, text: String, look: PetCardLook, level: Double, source: AskBoxSource) {
        model.submit = { [weak self] row in
            let typed = self?.model.text ?? ""
            self?.close()
            source.run(row, typed)
        }
        if let panel {
            model.start(source, text: text.isEmpty ? model.text : model.text + text)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        model.start(source, text: text)
        // From the card, Droppy is frontmost for a moment: hand back to the
        // app the card was opened over instead.
        let front = NSWorkspace.shared.frontmostApplication
        let previous = front == NSRunningApplication.current ? PetCard.shared.openedOver : front
        let view = AskBoxView(model: model, look: look, level: level, close: { [weak self] in self?.close() })
        let panel = AskBoxPanel(view)
        panel.onCancel = { [weak self] in self?.close() }
        panel.setFrameOrigin(Self.origin(for: panel.frame.size, over: petFrame))
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        activation = DroppyPanelActivation.begin(for: panel, returningTo: previous)
        clickAway = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        // And a click in Droppy's own windows, the pet included.
        clickInside = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                if let self, let panel = self.panel, event.window !== panel { self.close() }
            }
            return event
        }
    }

    func close() {
        if let clickAway { NSEvent.removeMonitor(clickAway) }
        if let clickInside { NSEvent.removeMonitor(clickInside) }
        clickAway = nil
        clickInside = nil
        activation?.finish()
        activation = nil
        model.reset()
        guard let panel else { return }
        self.panel = nil
        panel.onCancel = nil
        panel.orderOut(nil)
        panel.close()
    }

    /// Above the pet, centred on it, as its card is; below when there's no room.
    private static func origin(for size: CGSize, over pet: CGRect?) -> CGPoint {
        let screen = pet.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } }
            ?? NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        guard let pet else {
            return CGPoint(x: (area.midX - size.width / 2).rounded(), y: (area.minY + area.height * 0.62 - size.height / 2).rounded())
        }
        var x = pet.midX - size.width / 2
        var y = pet.maxY + 6
        if y + size.height > area.maxY { y = pet.minY - size.height - 6 }
        x = min(max(x, area.minX + 8), area.maxX - size.width - 8)
        y = min(max(y, area.minY + 8), area.maxY - size.height - 8)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }
}

/// Takes the keyboard without becoming the app the user was in.
private final class AskBoxPanel: NSPanel {
    var onCancel: (() -> Void)?

    init<Content: View>(_ content: Content) {
        let hosting = NSHostingView(rootView: content)
        super.init(contentRect: CGRect(origin: .zero, size: hosting.fittingSize), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        contentView = hosting
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

private struct AskBoxView: View {
    @ObservedObject var model: AskBoxModel
    let look: PetCardLook
    let level: Double
    let close: () -> Void
    @FocusState private var focused: Bool
    private static let radius: CGFloat = 16
    private static let rowHeight: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            HStack(spacing: DroppySpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("What can I do?", text: $model.text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($focused)
                    .onSubmit { model.runSelected() }
                    .onKeyPress(.upArrow) { model.move(-1); return .handled }
                    .onKeyPress(.downArrow) { model.move(1); return .handled }
                    .onKeyPress(.escape) { close(); return .handled }
                Text("esc").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DroppySpacing.xs)
            .frame(height: 28)
            VStack(spacing: 2) {
                if model.rows.isEmpty, !model.text.trimmingCharacters(in: .whitespaces).isEmpty {
                    nothing
                } else {
                    ForEach(Array(model.rows.enumerated()), id: \.element.key) { index, row in
                        rowView(row, selected: index == model.selected)
                            .onTapGesture { model.selected = index; model.runSelected() }
                            .onHover { if $0 { model.selected = index } }
                    }
                }
            }
            .frame(height: Self.rowHeight * CGFloat(AskRanking.limit) + 2 * CGFloat(AskRanking.limit - 1), alignment: .top)
            HStack(spacing: DroppySpacing.md) {
                hint("↑↓", "choose")
                hint("⏎", "run")
                hint("esc", "close")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, DroppySpacing.xs)
        }
        .padding(DroppySpacing.md)
        .frame(width: 300)
        .background(PetCardSurface(look: look, level: level, radius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .onAppear { focused = true }
    }

    private func rowView(_ row: AskCandidate, selected: Bool) -> some View {
        HStack(spacing: DroppySpacing.sm) {
            Image(systemName: row.symbol).frame(width: 18)
                .foregroundStyle(row.source == .now ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(row.title).lineLimit(1)
            Spacer(minLength: 0)
            Text(tag(row))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.08)))
        }
        .font(.system(size: 13))
        .padding(.horizontal, DroppySpacing.sm)
        .frame(height: Self.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(selected ? 0.12 : 0)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func tag(_ row: AskCandidate) -> String {
        switch row.source {
        case .pet: "Pixpaw"
        case .now: "Right now"
        case .droppy: row.fromSearch && row.kind == "content" ? "Droppy \(row.section.lowercased())".trimmingCharacters(in: .whitespaces) : "Droppy"
        }
    }

    private var nothing: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            Text("Nothing I can do for “\(model.text.trimmingCharacters(in: .whitespaces))”")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Text("I don't switch things off, sleep the Mac or delete anything. Try “notes”, “focus 25 min” or “feed”.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DroppySpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hint(_ key: String, _ what: String) -> some View {
        HStack(spacing: 3) {
            Text(key).fontWeight(.semibold)
            Text(what)
        }
    }
}
