// droppykit-lint: allow-file own-window: the pet's card, a small non-activating panel on Droppy's own panel surface that opens over the pet on a long press, a right-click or a click (the user's choice), with its submenus as panels beside it; closes on Escape, a click elsewhere (a mouse-click monitor, only while it is open) or once something in it is chosen (a letter typed hands over to the What can I do? box); never opened by itself, and closed in deactivate()
//
//  PetCard.swift
//  Pixpaw
//
//  Hold on your pet or right-click it (or click it, in Settings) and its
//  card opens over it: who it is and how it's doing, the six things you
//  do most as big buttons, and rows for the rest. A row with more opens
//  it beside the card as you point at it, never over it, and so on for a
//  menu inside that. Its ⋯ button gives the full menu, every item in it,
//  for the keyboard and VoiceOver; the card's rows are that menu's own
//  groups and items (PetMenu.swift), less what's on top.
//

import AppKit
import DroppyKit
import SwiftUI

/// One thing the card offers: an action on the pet's view, or more items.
struct PetCardItem: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String?
    var action: Selector?
    /// What the action reads off its sender, as a menu item's would.
    var represented: String?
    var badge: String?
    /// The key the user set for it: "⌃⌥/".
    var shortcut: String?
    var enabled = true
    var checked = false
    var isSeparator = false
    var children: [PetCardItem]?

    static let separator = PetCardItem(title: "", symbol: nil, isSeparator: true)

    /// An item of the pet's menu, submenus included.
    init(_ entry: PetMenuEntry) {
        if entry.isSeparator { self = .separator; return }
        self.init(title: entry.title, symbol: entry.symbol, action: entry.action.map { NSSelectorFromString($0.rawValue) },
                  represented: entry.represented, badge: entry.badge, shortcut: entry.shortcut?.text,
                  enabled: entry.enabled, checked: entry.checked, children: entry.children?.map(PetCardItem.init))
    }

    init(title: String, symbol: String?, action: Selector? = nil, represented: String? = nil, badge: String? = nil, shortcut: String? = nil,
         enabled: Bool = true, checked: Bool = false, isSeparator: Bool = false, children: [PetCardItem]? = nil) {
        self.title = title
        self.symbol = symbol
        self.action = action
        self.represented = represented
        self.badge = badge
        self.shortcut = shortcut
        self.enabled = enabled
        self.checked = checked
        self.isSeparator = isSeparator
        self.children = children
    }

    /// What VoiceOver reads: the title, then what it's at, then its key.
    var spoken: String { [title, badge, shortcut].compactMap { $0 }.joined(separator: ", ") }
}

/// One of the menu's groups, as rows: its header, or a divider for the
/// ones after the menu's separator.
struct PetCardGroup: Identifiable {
    let id = UUID()
    let title: String?
    let items: [PetCardItem]
}

/// An item of the pet's full menu: what it runs, and on what.
private final class PetMenuItem: NSMenuItem {
    var petAction: Selector?
    weak var petTarget: AnyObject?
}

/// Runs a menu item's action once the menu has gone, on the next turn of
/// the main loop, not inside its tracking: the menu fades out first and
/// the action (a toy, a panel, the pet setting off) starts on a quiet loop.
private final class PetMenuRelay: NSObject, @unchecked Sendable {
    /// Holds nothing: one for every menu.
    static let shared = PetMenuRelay()

    @MainActor @objc func fire(_ sender: NSMenuItem) {
        guard let item = sender as? PetMenuItem, let action = item.petAction else { return }
        // The item is held here: the menu is gone by the time this runs.
        DispatchQueue.main.async {
            guard let target = item.petTarget else { return }
            NSApp.sendAction(action, to: target, from: item)
        }
    }
}

extension NSMenu {
    /// The pet's full menu, built item by item from its menu model; actions
    /// go to `target`, the pet's view, once the menu has closed.
    static func pet(_ groups: [PetMenuGroup], target: AnyObject) -> NSMenu {
        func menuItem(_ entry: PetMenuEntry) -> NSMenuItem {
            if entry.isSeparator { return .separator() }
            let item = PetMenuItem(title: entry.title, action: entry.action.map { _ in #selector(PetMenuRelay.fire(_:)) },
                                   keyEquivalent: entry.shortcut?.key ?? "")
            item.petAction = entry.action.map { NSSelectorFromString($0.rawValue) }
            item.petTarget = target
            if let key = entry.shortcut {
                var mask = NSEvent.ModifierFlags()
                if key.control { mask.insert(.control) }
                if key.option { mask.insert(.option) }
                if key.shift { mask.insert(.shift) }
                if key.command { mask.insert(.command) }
                item.keyEquivalentModifierMask = mask
            }
            item.target = PetMenuRelay.shared
            if let symbol = entry.symbol {
                item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                item.identifier = NSUserInterfaceItemIdentifier(symbol)
            }
            item.representedObject = entry.represented
            if let badge = entry.badge { item.badge = NSMenuItemBadge(string: badge) }
            item.isEnabled = entry.enabled
            item.state = entry.checked ? .on : .off
            if let children = entry.children {
                let inner = NSMenu()
                inner.autoenablesItems = false
                children.map(menuItem).forEach(inner.addItem)
                item.submenu = inner
            }
            return item
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for group in groups {
            menu.addItem(group.title.map { NSMenuItem.sectionHeader(title: $0) } ?? .separator())
            group.items.map(menuItem).forEach(menu.addItem)
        }
        return menu
    }
}

/// Right now, under the card's header: what just happened, and a button
/// or two for it.
struct PetCardSuggestion {
    /// "Screenshot just now".
    let line: String
    /// How long it stays, "3 min".
    let left: String?
    let symbol: String
    let buttons: [PetCardItem]
}

/// What the card shows, built by the pet's view from its current state.
struct PetCardModel {
    let name: String
    let status: String
    let stars: Int
    /// The header's buttons: Talk to me (when it talks), What can I do?.
    let talk: PetCardItem?
    let ask: PetCardItem?
    let suggestion: PetCardSuggestion?
    let tiles: [PetCardItem]
    let groups: [PetCardGroup]

    init(_ layout: PetCardLayout, name: String, status: String, stars: Int) {
        self.name = name
        self.status = status
        self.stars = stars
        talk = layout.talk.map(PetCardItem.init)
        ask = layout.ask.map(PetCardItem.init)
        suggestion = layout.rightNow.map { first in
            PetCardSuggestion(line: first.line, left: first.left, symbol: first.buttons.first?.symbol ?? "sparkles",
                              buttons: first.buttons.map {
                                  PetCardItem(PetMenuEntry(title: $0.button, symbol: $0.symbol, action: .runSuggestion, represented: $0.id))
                              })
        }
        tiles = layout.tiles.map(PetCardItem.init)
        groups = layout.groups.map { PetCardGroup(title: $0.title, items: $0.items.map(PetCardItem.init)) }
    }
}

/// How the card looks: Droppy's own theme, or a glass of your own.
enum PetCardLook: String, CaseIterable, Identifiable {
    case droppy, clear, tinted, frosted, solid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .droppy: "Droppy's theme"
        case .clear: "Clear glass"
        case .tinted: "Tinted glass"
        case .frosted: "Frosted glass"
        case .solid: "Solid"
        }
    }
}

/// How the card opens.
enum PetCardOpening: String, CaseIterable, Identifiable {
    case hold, click
    var id: String { rawValue }
    var title: String { self == .hold ? "Hold on your pet" : "Click your pet" }
}

@MainActor
final class PetCard {
    static let shared = PetCard()
    private var panel: PetCardPanel?
    /// The submenus open beside it, outermost last.
    private var flyouts: [PetCardPanel] = []
    private var activation: DroppyPanelActivation?
    private var clickAway: Any?
    private var clickInside: Any?
    private weak var target: NSView?
    private var look = PetCardLook.droppy
    private var level = 0.5

    var isOpen: Bool { panel != nil }
    /// The app the card last opened over, for the box it hands over to.
    private(set) var openedOver: NSRunningApplication?
    private var closedAt = Date.distantPast
    /// Closed a moment ago, by the very click now arriving at the pet.
    var justClosed: Bool { Date().timeIntervalSince(closedAt) < 0.4 }

    /// Opens the card over `petFrame` (screen coordinates); actions go to
    /// `target`, the pet's view, exactly as its menu's do.
    /// A letter typed while it's open closes it and goes to `type`, the
    /// "What can I do?" box, with that letter in it.
    func show(_ model: PetCardModel, over petFrame: CGRect, target: NSView, look: PetCardLook, level: Double,
              type: @escaping (String) -> Void) {
        close()
        self.target = target
        self.look = look
        self.level = level
        let previous = NSWorkspace.shared.frontmostApplication
        openedOver = previous
        let panel = Self.fitted(on: petFrame) { height in
            PetCardView(model: model, look: look, level: level, height: height,
                        run: { [weak self] item, frame in self?.run(item, at: frame, depth: 0) },
                        hover: { [weak self] item, frame in self?.hover(item, at: frame, depth: 0) })
        }
        panel.onCancel = { [weak self] in self?.close() }
        panel.onType = { [weak self] text in
            self?.close()
            type(text)
        }
        panel.setFrameOrigin(Self.origin(for: panel.frame.size, over: petFrame))
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        activation = DroppyPanelActivation.begin(for: panel, returningTo: previous)
        // A click anywhere else closes it, as a menu would: in other apps,
        // and in Droppy's own windows (the pet included).
        clickAway = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        clickInside = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                if event.window !== panel, !self.flyouts.contains(where: { $0 === event.window }) { self.close() }
            }
            return event
        }
    }

    func close() {
        if let clickAway { NSEvent.removeMonitor(clickAway) }
        if let clickInside { NSEvent.removeMonitor(clickInside) }
        clickAway = nil
        clickInside = nil
        closeFlyouts(from: 0)
        activation?.finish()
        activation = nil
        guard let panel else { return }
        closedAt = Date()
        self.panel = nil
        panel.onCancel = nil
        panel.orderOut(nil)
        panel.close()
    }

    /// The panel at a depth: 0 the card, 1 the first submenu beside it.
    private func panel(at depth: Int) -> PetCardPanel? { depth == 0 ? panel : flyouts.indices.contains(depth - 1) ? flyouts[depth - 1] : nil }

    /// Pointing at a row: its submenu opens beside the panel it's in, and
    /// any deeper one closes.
    private func hover(_ item: PetCardItem, at frame: CGRect, depth: Int) {
        closeFlyouts(from: depth)
        guard let children = item.children, item.enabled, let parent = panel(at: depth) else { return }
        let look = look, level = level
        let flyout = Self.fitted(on: parent.frame) { height in
            PetCardMenuView(items: children, look: look, level: level, height: height,
                            run: { [weak self] child, rect in self?.run(child, at: rect, depth: depth + 1) },
                            hover: { [weak self] child, rect in self?.hover(child, at: rect, depth: depth + 1) })
        }
        flyout.onCancel = { [weak self] in self?.close() }
        flyout.setFrameOrigin(Self.beside(parent.frame, rowTop: parent.frame.maxY - frame.minY, size: flyout.frame.size))
        flyouts.append(flyout)
        flyout.orderFront(nil)
    }

    private func closeFlyouts(from depth: Int) {
        while flyouts.count > depth {
            let flyout = flyouts.removeLast()
            flyout.onCancel = nil
            flyout.orderOut(nil)
            flyout.close()
        }
    }

    /// Runs an item: its action on the pet's view, or (a tile, clicked) its
    /// items beside the card.
    private func run(_ item: PetCardItem, at frame: CGRect, depth: Int) {
        guard item.enabled, let target else { return }
        if item.children != nil { return hover(item, at: frame, depth: depth) }
        guard let action = item.action else { return }
        close()
        let sender = NSMenuItem()
        sender.representedObject = item.represented
        NSApp.sendAction(action, to: target, from: sender)
    }

    /// Above the pet, centred on it, on its screen; below it when there's
    /// no room above.
    private static func origin(for size: CGSize, over pet: CGRect) -> CGPoint {
        let area = screen(for: pet)?.visibleFrame ?? pet.insetBy(dx: -400, dy: -400)
        var x = pet.midX - size.width / 2
        var y = pet.maxY + 6
        if y + size.height > area.maxY { y = pet.minY - size.height - 6 }
        x = min(max(x, area.minX + 8), area.maxX - size.width - 8)
        y = min(max(y, area.minY + 8), area.maxY - size.height - 8)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    /// To the right of `parent`, its top level with the row, on the left
    /// where the screen ends: never over the panel it came from.
    private static func beside(_ parent: CGRect, rowTop: CGFloat, size: CGSize) -> CGPoint {
        let area = screen(for: parent)?.visibleFrame ?? parent.insetBy(dx: -800, dy: -800)
        var x = parent.maxX + 6
        if x + size.width > area.maxX { x = parent.minX - size.width - 6 }
        var y = rowTop - size.height + 6
        y = min(max(y, area.minY + 8), area.maxY - size.height - 8)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    /// A panel no taller than the screen it opens on: one that would be is
    /// made again at that height, its rows scrolling.
    private static func fitted<V: View>(on rect: CGRect, _ make: (CGFloat?) -> V) -> PetCardPanel {
        let panel = PetCardPanel(make(nil))
        let cap = ((screen(for: rect)?.visibleFrame.height ?? .greatestFiniteMagnitude) - 16).rounded(.down)
        guard panel.frame.height > cap else { return panel }
        return PetCardPanel(make(cap))
    }

    private static func screen(for rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main
    }
}

/// Takes the keyboard (Tab moves between buttons, Escape closes) without
/// becoming the app the user was in.
private final class PetCardPanel: NSPanel {
    var onCancel: (() -> Void)?
    /// A letter or digit typed, no Command, Control or Option: the card
    /// hands over to the "What can I do?" box. Nil on its submenus.
    var onType: ((String) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let onType, event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let text = event.characters, text.count == 1, text.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains) {
            return onType(text)
        }
        super.sendEvent(event)
    }

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
    // DroppyPanelActivation makes the panel key and main; AppKit throws if it can't be main.
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// The card's surface: Droppy's own, or the glass picked in Settings.
struct PetCardSurface: View {
    let look: PetCardLook
    /// 0 lets the most of the desktop through, 1 the least.
    let level: Double
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch look {
        case .droppy:
            // Droppy's surface melts from black into clear glass, so the lowest rows
            // washed out over a light desktop; a dark layer under it keeps them readable.
            DroppyPanelSurface(cornerRadius: radius)
                .background(shape.fill(Color.black.opacity(0.9)))
        case .solid:
            shape.fill(Color(nsColor: .windowBackgroundColor))
        case .clear, .tinted, .frosted:
            if #available(macOS 26, *) {
                Color.clear.glassEffect(glass, in: shape)
            } else {
                shape.fill(look == .frosted ? .thickMaterial : look == .clear ? .ultraThinMaterial : .regularMaterial)
                    .overlay(shape.fill(Color.black.opacity(look == .tinted ? 0.15 + level * 0.5 : 0)))
            }
        }
    }

    @available(macOS 26, *)
    private var glass: Glass {
        switch look {
        case .clear: .clear.tint(.black.opacity(level * 0.25))
        case .frosted: .regular.tint(.white.opacity(0.06 + level * 0.2))
        default: .regular.tint(.black.opacity(0.15 + level * 0.5))
        }
    }
}

private struct PetCardView: View {
    let model: PetCardModel
    let look: PetCardLook
    let level: Double
    /// Set when the card would be taller than its screen: it's this tall,
    /// and its rows scroll under the header and tiles.
    let height: CGFloat?
    let run: (PetCardItem, CGRect) -> Void
    let hover: (PetCardItem, CGRect) -> Void
    private static let radius: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.md) {
            header
            if let suggestion = model.suggestion { rightNow(suggestion) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DroppySpacing.sm), count: 3), spacing: DroppySpacing.sm) {
                ForEach(model.tiles) { tile($0) }
            }
            if height != nil {
                ScrollView { rows }
            } else {
                rows
            }
        }
        .padding(DroppySpacing.lg)
        .frame(width: 280, height: height)
        .background(PetCardSurface(look: look, level: level, radius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            ForEach(model.groups) { group in
                if let title = group.title {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, DroppySpacing.sm).padding(.top, 2)
                        .accessibilityAddTraits(.isHeader)
                } else {
                    Divider().padding(.vertical, 2)
                }
                ForEach(group.items) { PetCardRow(item: $0, accent: false, run: run, hover: hover) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name).font(.system(size: 14, weight: .semibold))
                Text("\(model.status) · \(model.stars) ★")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            ForEach([model.ask, model.talk].compactMap { $0 }) { item in
                Button { run(item, .zero) } label: {
                    Image(systemName: item.symbol ?? "circle")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 28))
                .disabled(!item.enabled)
                .help(item.shortcut.map { "\(item.title) \($0)" } ?? item.title)
                .accessibilityLabel(item.spoken)
            }
        }
    }

    /// One line for what just happened, and its buttons. The pet only gets
    /// them ready: nothing here runs until it's clicked.
    private func rightNow(_ suggestion: PetCardSuggestion) -> some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            HStack(spacing: DroppySpacing.xs) {
                Image(systemName: suggestion.symbol).font(.system(size: 11)).foregroundStyle(.tint)
                Text(suggestion.line).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if let left = suggestion.left {
                    Text(left).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: DroppySpacing.xs) {
                ForEach(suggestion.buttons) { item in
                    Button { run(item, .zero) } label: {
                        Label(item.title, systemImage: item.symbol ?? "circle").lineLimit(1)
                    }
                    .buttonStyle(DroppyQuietButtonStyle(size: .small))
                    .disabled(!item.enabled)
                }
            }
        }
    }

    private func tile(_ item: PetCardItem) -> some View {
        GeometryReader { geo in
            Button { run(item, geo.frame(in: .global)) } label: {
                VStack(spacing: 4) {
                    Image(systemName: item.symbol ?? "circle").font(.system(size: 17))
                    Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                    if let badge = item.badge {
                        Text(badge).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PetTileStyle())
            .disabled(!item.enabled)
            .accessibilityLabel(item.spoken)
        }
        .frame(height: 62)
    }
}

/// A submenu beside the card, on the same surface.
private struct PetCardMenuView: View {
    let items: [PetCardItem]
    let look: PetCardLook
    let level: Double
    /// Set when the list would be taller than its screen; it scrolls.
    let height: CGFloat?
    let run: (PetCardItem, CGRect) -> Void
    let hover: (PetCardItem, CGRect) -> Void

    var body: some View {
        Group {
            if height != nil {
                ScrollView { list }
            } else {
                list
            }
        }
        .padding(DroppySpacing.sm)
        .frame(width: 230, height: height)
        .background(PetCardSurface(look: look, level: level, radius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                if item.isSeparator {
                    Divider().padding(.vertical, 3).padding(.horizontal, DroppySpacing.sm)
                } else {
                    PetCardRow(item: item, accent: false, run: run, hover: hover)
                }
            }
        }
    }
}

/// A row: pointing at one with more opens it beside its panel.
private struct PetCardRow: View {
    let item: PetCardItem
    let accent: Bool
    let run: (PetCardItem, CGRect) -> Void
    let hover: (PetCardItem, CGRect) -> Void

    var body: some View {
        GeometryReader { geo in
            Button { run(item, geo.frame(in: .global)) } label: {
                HStack(spacing: DroppySpacing.sm) {
                    if item.checked {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).frame(width: 18)
                    } else if let symbol = item.symbol {
                        Image(systemName: symbol).frame(width: 18)
                            .foregroundStyle(accent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    } else {
                        Color.clear.frame(width: 18, height: 1)
                    }
                    Text(item.title).lineLimit(1)
                    Spacer(minLength: 0)
                    if let badge = item.badge { Text(badge).foregroundStyle(.secondary).lineLimit(1) }
                    if let shortcut = item.shortcut { Text(shortcut).foregroundStyle(.tertiary).lineLimit(1) }
                    if item.children != nil { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary) }
                }
                .font(.system(size: 13))
                .padding(.horizontal, DroppySpacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PetRowStyle())
            .disabled(!item.enabled)
            .accessibilityLabel(item.spoken)
            .accessibilityValue(item.checked ? "Selected" : "")
            .accessibilityHint(item.children != nil ? "Opens beside the card" : "")
            .onHover { inside in if inside { hover(item, geo.frame(in: .global)) } }
        }
        .frame(height: 28)
    }
}

/// A tile: Droppy's own Liquid Glass control, in a rounded square.
private struct PetTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { PetTile(configuration: configuration) }
}

private struct PetTile: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        configuration.label
            .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .droppyGlassControlChrome(shape: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)),
                                      isHovering: hovering, isPressed: configuration.isPressed)
            .onHover { hovering = $0 && enabled }
    }
}

private struct PetRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PetWash(pressed: configuration.isPressed, radius: 8, resting: 0) { configuration.label }
    }
}

private struct PetWash<Label: View>: View {
    let pressed: Bool
    let radius: CGFloat
    var resting: Double = 0.06
    @ViewBuilder let label: () -> Label
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused

    var body: some View {
        label()
            .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.primary.opacity(pressed ? 0.18 : hovering || focused ? 0.12 : resting))
            )
            .onHover { hovering = $0 && enabled }
    }
}

/// A small card in the look picked, over a colourful desktop, so Settings
/// shows what the glass and its level do before you open the real one.
struct PetCardPreview: View {
    let look: PetCardLook
    let level: Double

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.17, green: 0.18, blue: 0.48), Color(red: 0.42, green: 0.29, blue: 0.72),
                                    Color(red: 0.91, green: 0.55, blue: 0.48)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Something behind the glass to see through it.
            Circle().fill(Color.yellow.opacity(0.9)).frame(width: 70).offset(x: -70, y: -28)
            RoundedRectangle(cornerRadius: 6).fill(Color.teal).frame(width: 90, height: 26).offset(x: 80, y: 40)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Your pet").font(.system(size: 12, weight: .semibold))
                        Text("Doing fine · 185 ★").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "mic.fill").font(.system(size: 11))
                }
                HStack(spacing: 6) {
                    ForEach(["fork.knife", "gamecontroller", "moon.zzz"], id: \.self) { symbol in
                        Image(systemName: symbol).font(.system(size: 13))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.08)))
                    }
                }
                Label("Droppy", systemImage: "drop.fill").font(.system(size: 11))
            }
            .padding(12)
            .frame(width: 190)
            .background(PetCardSurface(look: look, level: level, radius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A preview of your pet's card in \(look.title.lowercased())")
    }
}
