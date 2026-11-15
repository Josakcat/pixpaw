// droppykit-lint: allow-file own-window: the pet's card, a small non-activating panel on Droppy's own panel surface that opens over the pet on a long press, a right-click or a click (the user's choice), with its submenus as panels beside it; closes on Escape, a click elsewhere (it stops being the key window, or the pet's own windows are clicked; no event monitor) or once something in it is chosen (a letter typed hands over to the What can I do? box); never opened by itself, and closed in deactivate()
//
//  PetCard.swift
//  Pixpaw
//
//  Hold on your pet or right-click it (or click it, in Settings) and its
//  card opens over it, wide: who it is and how it's doing, the six things
//  you do most as big buttons, rows for the rest beside them, and chips
//  along the bottom. A row with more opens it beside the card as you point
//  at it, a chip above itself when clicked, and so on for a menu inside
//  that. VoiceOver's show-menu (VO-Shift-M on the pet) gives the full menu,
//  every item in it; the card's rows are that menu's own
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
    /// A decoration's own art, drawn in place of `symbol` (scale 2).
    var picture: CGImage?
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
    /// A big button's short label; `title` stays what VoiceOver reads.
    var tileTitle: String?

    static let separator = PetCardItem(title: "", symbol: nil, isSeparator: true)

    /// An item of the pet's menu, submenus included.
    init(_ entry: PetMenuEntry) { self.init(entry, picture: { _ in nil }) }

    /// The same, with `picture` drawing an entry's decoration art.
    init(_ entry: PetMenuEntry, picture: (String) -> CGImage?) {
        if entry.isSeparator { self = .separator; return }
        self.init(title: entry.title, symbol: entry.symbol, action: entry.action.map { $0.selector },
                  represented: entry.represented, badge: entry.badge, shortcut: entry.shortcut?.text,
                  enabled: entry.enabled, checked: entry.checked, children: entry.children?.map { PetCardItem($0, picture: picture) })
        self.picture = entry.picture.flatMap(picture)
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
    /// go to `target`, the pet's view, once the menu has closed. `picture`
    /// draws a decoration's art (scale 2) for an entry that names one.
    static func pet(_ groups: [PetMenuGroup], target: AnyObject, picture: (String) -> CGImage? = { _ in nil }) -> NSMenu {
        func menuItem(_ entry: PetMenuEntry) -> NSMenuItem {
            if entry.isSeparator { return .separator() }
            let item = PetMenuItem(title: entry.title, action: entry.action.map { _ in #selector(PetMenuRelay.fire(_:)) },
                                   keyEquivalent: entry.shortcut?.key ?? "")
            item.petAction = entry.action.map { $0.selector }
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
            if let art = entry.picture.flatMap(picture) {
                // Scale 2: one screen pixel a bitmap pixel on Retina, crisp.
                item.image = NSImage(cgImage: art, size: NSSize(width: CGFloat(art.width) / 2, height: CGFloat(art.height) / 2))
            } else if let symbol = entry.symbol {
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
    /// The pet's face, in its colours, before the title.
    var face: NSImage?
    /// The header's buttons: Talk to me (when it talks), What can I do?.
    let talk: PetCardItem?
    let ask: PetCardItem?
    let suggestion: PetCardSuggestion?
    let tiles: [PetCardItem]
    let groups: [PetCardGroup]

    init(_ layout: PetCardLayout, name: String, status: String, stars: Int, picture: (String) -> CGImage? = { _ in nil }) {
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
        tiles = layout.tiles.map { entry in
            var tile = PetCardItem(entry)
            tile.tileTitle = PetCardLayout.tileTitle(entry)
            return tile
        }
        groups = layout.groups.map { PetCardGroup(title: $0.title, items: $0.items.map { PetCardItem($0, picture: picture) }) }
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
    /// The card's and each submenu's didResignKey observer, removed in close().
    private var keyWatch: [ObjectIdentifier: NSObjectProtocol] = [:]
    /// The card's activation, left running for the "What can I do?" box it
    /// just handed over to, so Droppy doesn't hand the foreground away and
    /// straight back; the box takes it, or it's finished a turn later.
    private var handedOver: DroppyPanelActivation?
    private weak var target: NSView?
    /// The open flyout is a bar chip's, `barItem`'s.
    private var barOpen = false
    private var barItem: UUID?
    private var look = PetCardLook.droppy
    private var level = 0.5
    /// Draws the open card for a model (and a capped height), the same
    /// actions wired in: `refresh` cuts it again in place with it.
    private var make: ((PetCardModel, CGFloat?) -> PetCardView)?

    var isOpen: Bool { panel != nil }
    /// Open, over the pet whose view is `target`.
    func isOpen(over target: NSView) -> Bool { panel != nil && self.target === target }
    /// The app the card last opened over, for the box it hands over to.
    private(set) var openedOver: NSRunningApplication?
    private var closedAt = Date.distantPast
    /// Closed a moment ago, by the very click now arriving at the pet.
    var justClosed: Bool { Date().timeIntervalSince(closedAt) < 0.4 }

    /// Opens the card over `petFrame` (screen coordinates); actions go to
    /// `target`, the pet's view, exactly as its menu's do.
    /// A letter typed while it's open closes it and goes to `type`, the
    /// "What can I do?" box, with that letter in it.
    /// `menu` pops up the full menu, for the header's ⋯ button.
    func show(_ model: PetCardModel, over petFrame: CGRect, target: NSView, look: PetCardLook, level: Double,
              menu: @escaping () -> Void, type: @escaping (String) -> Void) {
        close()
        self.target = target
        self.look = look
        self.level = level
        let previous = NSWorkspace.shared.frontmostApplication
        openedOver = previous
        let make: (PetCardModel, CGFloat?) -> PetCardView = { [weak self] model, height in
            PetCardView(model: model, look: look, level: level, height: height,
                        run: { [weak self] item, frame in self?.run(item, at: frame, depth: 0) },
                        hover: { [weak self] item, frame in self?.hover(item, at: frame, depth: 0) },
                        chip: { [weak self] item, frame, clicked in self?.chip(item, at: frame, clicked: clicked) },
                        menu: { [weak self] in
                            self?.close()
                            // Once the card has gone, as a menu item's action runs.
                            DispatchQueue.main.async { menu() }
                        })
        }
        self.make = make
        let panel = Self.fitted(on: petFrame) { make(model, $0) }
        panel.onCancel = { [weak self] in self?.close() }
        panel.onType = { [weak self] text in
            self?.close(handingOver: true)
            type(text)
        }
        panel.setFrameOrigin(Self.origin(for: panel.frame.size, over: petFrame))
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        activation = DroppyPanelActivation.begin(for: panel, returningTo: previous)
        // A click anywhere else closes it, as a menu would: another app, the
        // desktop or a Droppy window takes the keyboard from it. The pet's own
        // windows never take it: CatPanel closes the card on their clicks.
        watchKey(panel)
    }

    /// The card or one of its submenus stopped being the key window: once
    /// the new one is settled, close unless it's the card or a submenu.
    private func watchKey(_ window: NSWindow) {
        keyWatch[ObjectIdentifier(window)] = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, let panel = self.panel else { return }
                    let key = NSApp.keyWindow
                    if key === panel || self.flyouts.contains(where: { $0 === key }) { return }
                    self.close()
                }
            }
        }
    }

    private func unwatchKey(_ window: NSWindow) {
        if let token = keyWatch.removeValue(forKey: ObjectIdentifier(window)) { NotificationCenter.default.removeObserver(token) }
    }

    /// The card's activation, when it just handed over to the box.
    func takeHandedOver() -> DroppyPanelActivation? {
        defer { handedOver = nil }
        return handedOver
    }

    /// `handingOver`: the "What can I do?" box opens next, in this same turn,
    /// and takes the activation over (`takeHandedOver`).
    func close(handingOver: Bool = false) {
        for token in keyWatch.values { NotificationCenter.default.removeObserver(token) }
        keyWatch = [:]
        closeFlyouts(from: 0)
        barOpen = false
        if handingOver, let activation {
            handedOver?.finish()
            handedOver = activation
            DispatchQueue.main.async { [weak self] in self?.takeHandedOver()?.finish() }
        } else {
            activation?.finish()
            takeHandedOver()?.finish()
        }
        activation = nil
        make = nil
        guard let panel else { return }
        closedAt = Date()
        self.panel = nil
        panel.onCancel = nil
        panel.orderOut(nil)
        panel.close()
    }

    /// The open card cut again from `model` (the pet's state changed under
    /// it: the home came out or went), in place over `petFrame`; an open
    /// flyout of the old rows closes.
    func refresh(_ model: PetCardModel, over petFrame: CGRect) {
        guard let panel, let make else { return }
        closeFlyouts(from: 0)
        barOpen = false
        var hosting = NSHostingView(rootView: make(model, nil))
        let cap = Self.cap(on: petFrame)
        if hosting.fittingSize.height > cap { hosting = NSHostingView(rootView: make(model, cap)) }
        panel.contentView = hosting
        let size = hosting.fittingSize
        panel.setFrame(CGRect(origin: Self.origin(for: size, over: petFrame), size: size), display: true)
    }

    /// The panel at a depth: 0 the card, 1 the first submenu beside it.
    private func panel(at depth: Int) -> PetCardPanel? { depth == 0 ? panel : flyouts.indices.contains(depth - 1) ? flyouts[depth - 1] : nil }

    /// Pointing at a row: its submenu opens beside the panel it's in, and
    /// any deeper one closes.
    private func hover(_ item: PetCardItem, at frame: CGRect, depth: Int) {
        // A clicked tile's or chip's menu stays open while the pointer crosses the card's rows to reach it.
        if depth == 0, barOpen { return }
        closeFlyouts(from: depth)
        barOpen = false
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
        watchKey(flyout)
    }

    /// A chip in the card's bar: clicked, its items open above it (or it
    /// runs); pointed at while another chip's are open, its open instead.
    private func chip(_ item: PetCardItem, at frame: CGRect, clicked: Bool) {
        guard clicked || barOpen, let panel else { return }
        guard let children = item.children, item.enabled else {
            if clicked { run(item, at: frame, depth: 0) } else { closeFlyouts(from: 0); barOpen = false }
            return
        }
        if clicked, barOpen, barItem == item.id { closeFlyouts(from: 0); barOpen = false; return }
        if !clicked, barOpen, barItem == item.id { return }
        closeFlyouts(from: 0)
        let look = look, level = level
        let flyout = Self.fitted(on: panel.frame) { height in
            PetCardMenuView(items: children, look: look, level: level, height: height,
                            run: { [weak self] child, rect in self?.run(child, at: rect, depth: 1) },
                            hover: { [weak self] child, rect in self?.hover(child, at: rect, depth: 1) },
                            heading: item)
        }
        flyout.onCancel = { [weak self] in self?.close() }
        flyout.setFrameOrigin(Self.above(panel.frame, chip: frame, size: flyout.frame.size))
        flyouts.append(flyout)
        flyout.orderFront(nil)
        watchKey(flyout)
        barOpen = true
        barItem = item.id
    }

    private func closeFlyouts(from depth: Int) {
        while flyouts.count > depth {
            let flyout = flyouts.removeLast()
            unwatchKey(flyout)
            // A clicked submenu has the keyboard: back to the card (or the
            // submenu under it) first, so the card stays open.
            if flyout.isKeyWindow { (flyouts.last ?? panel)?.makeKey() }
            flyout.onCancel = nil
            flyout.orderOut(nil)
            flyout.close()
        }
    }

    /// Runs an item: its action on the pet's view, or (a tile, clicked) its
    /// items beside the card.
    private func run(_ item: PetCardItem, at frame: CGRect, depth: Int) {
        guard item.enabled, let target else { return }
        if item.children != nil { return depth == 0 ? chip(item, at: frame, clicked: true) : hover(item, at: frame, depth: depth) }
        guard let action = item.action else { return }
        close(handingOver: action == PetMenuAction.ask.selector)
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

    /// Above a chip of the card's bar (`chip` in the card's own top-left
    /// coordinates), its leading edge at the chip's, on screen.
    private static func above(_ parent: CGRect, chip: CGRect, size: CGSize) -> CGPoint {
        let area = screen(for: parent)?.visibleFrame ?? parent.insetBy(dx: -800, dy: -800)
        var x = parent.minX + chip.minX
        var y = parent.maxY - chip.minY + 4
        x = min(max(x, area.minX + 8), area.maxX - size.width - 8)
        y = min(max(y, area.minY + 8), area.maxY - size.height - 8)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    /// A panel no taller than the screen it opens on: one that would be is
    /// made again at that height, its rows scrolling.
    private static func fitted<V: View>(on rect: CGRect, _ make: (CGFloat?) -> V) -> PetCardPanel {
        let panel = PetCardPanel(make(nil))
        let cap = cap(on: rect)
        guard panel.frame.height > cap else { return panel }
        return PetCardPanel(make(cap))
    }

    /// The tallest a panel on `rect`'s screen may be.
    private static func cap(on rect: CGRect) -> CGFloat {
        ((screen(for: rect)?.visibleFrame.height ?? .greatestFiniteMagnitude) - 16).rounded(.down)
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

/// The card, wide: on the left who it is, Right now and the big buttons,
/// four across; on the right the menu's groups as rows; along the bottom
/// Ask me's Droppy, Look and Capture as chips that open above themselves,
/// and the settings gear.
private struct PetCardView: View {
    let model: PetCardModel
    let look: PetCardLook
    let level: Double
    /// Set when the card would be taller than its screen: it's this tall,
    /// and its two columns scroll between the header and the bar.
    let height: CGFloat?
    let run: (PetCardItem, CGRect) -> Void
    let hover: (PetCardItem, CGRect) -> Void
    /// A bar chip clicked, or pointed at: its items open above it.
    let chip: (PetCardItem, CGRect, Bool) -> Void
    /// The ⋯ button: the full menu, every item in it.
    let menu: () -> Void
    private static let radius: CGFloat = 20
    static let width: CGFloat = 560

    var body: some View {
        let split = PetCardSplit(model.groups)
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            if height != nil {
                ScrollView { columns(split) }.frame(maxHeight: .infinity)
            } else {
                columns(split)
            }
            Divider()
            bar(split)
        }
        .padding(DroppySpacing.lg)
        .frame(width: Self.width, height: height)
        .background(PetCardSurface(look: look, level: level, radius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    private func columns(_ split: PetCardSplit) -> some View {
        HStack(alignment: .top, spacing: DroppySpacing.lg) {
            VStack(alignment: .leading, spacing: DroppySpacing.md) {
                header
                if model.suggestion != nil || !split.rightNow.isEmpty {
                    VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                        if let suggestion = model.suggestion { rightNow(suggestion) }
                        ForEach(split.rightNow) { PetCardRow(item: $0, accent: false, height: 24, run: run, hover: hover) }
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DroppySpacing.sm), count: 4), spacing: DroppySpacing.sm) {
                    ForEach(model.tiles) { tile($0) }
                }
            }
            .frame(width: 272)
            VStack(alignment: .leading, spacing: DroppySpacing.xsm) {
                ForEach(split.columns) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = group.title {
                            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, DroppySpacing.sm)
                                .accessibilityAddTraits(.isHeader)
                        }
                        ForEach(group.items) { item in
                            if item.isSeparator {
                                Divider().padding(.vertical, 2).padding(.horizontal, DroppySpacing.sm)
                            } else {
                                PetCardRow(item: item, accent: false, height: 24, run: run, hover: hover)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.sm) {
            if let face = model.face {
                Image(nsImage: face)
                    .interpolation(.none)
                    .accessibilityHidden(true)
            }
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
            // Side by side when both fit ("To the shelf", "Show in Finder"),
            // one under the other when they don't, never cut short.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DroppySpacing.xs) { suggestionButtons(suggestion) }
                VStack(alignment: .leading, spacing: DroppySpacing.xs) { suggestionButtons(suggestion) }
            }
        }
    }

    @ViewBuilder private func suggestionButtons(_ suggestion: PetCardSuggestion) -> some View {
        ForEach(suggestion.buttons) { item in
            Button { run(item, .zero) } label: {
                Label(item.title, systemImage: item.symbol ?? "circle").lineLimit(1).fixedSize()
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
            .disabled(!item.enabled)
        }
    }

    private func tile(_ item: PetCardItem) -> some View {
        GeometryReader { geo in
            Button { run(item, geo.frame(in: .global)) } label: {
                // Every tile the same fixed size; its icon and words centred in it, badge or not.
                VStack(spacing: 2) {
                    Image(systemName: item.symbol ?? "circle").font(.system(size: 16)).frame(height: 20)
                    Text(item.tileTitle ?? item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    if let badge = item.badge {
                        Text(badge).font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PetTileStyle())
            .disabled(!item.enabled)
            .accessibilityLabel(item.spoken)
        }
        .frame(height: 56)
    }

    /// The chips with their titles; when a Colour chip makes that too wide,
    /// symbols and badges only (each still says its title on hover and to VoiceOver).
    private func bar(_ split: PetCardSplit) -> some View {
        ViewThatFits(in: .horizontal) {
            barRow(split, titled: true)
            barRow(split, titled: false)
        }
    }

    private func barRow(_ split: PetCardSplit, titled: Bool) -> some View {
        HStack(spacing: DroppySpacing.xsm) {
            ForEach(split.bar) { PetCardChip(item: $0, titled: titled, chip: chip) }
            Spacer(minLength: 0)
            if let settings = split.settings { PetCardChip(item: settings, titled: false, chip: chip) }
        }
    }
}

/// The card's groups, placed: Right now's rows under its line, the titled
/// groups in the right column, Ask me, Look, Capture and the gear in the bar.
private struct PetCardSplit {
    var rightNow: [PetCardItem] = []
    var columns: [PetCardGroup] = []
    var bar: [PetCardItem] = []
    var settings: PetCardItem?

    init(_ groups: [PetCardGroup]) {
        for group in groups {
            switch PetCardLayout.slot(group.title) {
            case .rightNow: rightNow += group.items.filter { !$0.isSeparator }
            case .column: columns.append(group)
            case .bar:
                for item in group.items where !item.isSeparator {
                    if item.children == nil, item.symbol == "gearshape" { settings = item } else { bar.append(item) }
                }
            }
        }
    }
}

/// A chip in the card's bar: a click opens its items above it, and once one
/// is open, pointing at another chip opens that one's instead.
private struct PetCardChip: View {
    let item: PetCardItem
    let titled: Bool
    let chip: (PetCardItem, CGRect, Bool) -> Void
    @State private var frame = CGRect.zero

    var body: some View {
        Button { chip(item, frame, true) } label: {
            HStack(spacing: 5) {
                Image(systemName: item.symbol ?? "circle").foregroundStyle(.secondary)
                if titled { Text(item.title).lineLimit(1) }
                if let badge = item.badge { Text(badge).foregroundStyle(.secondary).lineLimit(1) }
                if item.children != nil {
                    Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, titled ? DroppySpacing.smd : DroppySpacing.sm)
            .frame(minWidth: 28, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PetChipStyle())
        .disabled(!item.enabled)
        .frame(height: 28)
        .fixedSize(horizontal: true, vertical: false)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { frame = geo.frame(in: .global) }
                .onChange(of: geo.frame(in: .global)) { _, new in frame = new }
        })
        .onHover { inside in if inside { chip(item, frame, false) } }
        .accessibilityLabel(item.spoken)
        .accessibilityHint(item.children != nil ? "Opens above the card's bar" : "")
        .help(item.title)
    }
}

/// A chip: the row's wash, resting a little lit so it reads as a button.
private struct PetChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PetWash(pressed: configuration.isPressed, radius: 8, resting: 0.07) { configuration.label }
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
    /// A bar chip's menu: its chip's symbol and title on top and a clear edge,
    /// so it reads as that chip's menu over the card, not part of it.
    var heading: PetCardItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let heading {
                Label(heading.title, systemImage: heading.symbol ?? "circle")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, DroppySpacing.sm).padding(.top, 2)
                    .accessibilityAddTraits(.isHeader)
            }
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
        .overlay {
            if heading != nil {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
        }
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
    /// 28 in a submenu, 24 in the card's right column.
    var height: CGFloat = 28
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
                    if let picture = item.picture {
                        // A decoration's own art, beside the check column as the menu draws it.
                        Image(decorative: picture, scale: 2).interpolation(.none)
                            .opacity(item.enabled ? 1 : 0.5)
                            .accessibilityHidden(true)
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
        .frame(height: height)
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

/// The wide card in miniature, in the look picked, over a colourful desktop,
/// so Settings shows what the glass and its level do before you open the
/// real one. Drawn at the card's own size (560 × 359) and scaled to fit.
struct PetCardPreview: View {
    let look: PetCardLook
    let level: Double

    private static let card = CGSize(width: 560, height: 359)
    private static let margin: CGFloat = 24
    private static let scene = CGSize(width: card.width + margin * 2, height: card.height + margin * 2)

    var body: some View {
        GeometryReader { geo in
            backdrop
                .frame(width: Self.scene.width, height: Self.scene.height)
                .scaleEffect(geo.size.width / Self.scene.width, anchor: .topLeading)
        }
        .aspectRatio(Self.scene.width / Self.scene.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A preview of your pet's card in \(look.title.lowercased())")
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.17, green: 0.18, blue: 0.48), Color(red: 0.42, green: 0.29, blue: 0.72),
                                    Color(red: 0.91, green: 0.55, blue: 0.48)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Something behind the glass to see through it.
            Circle().fill(Color.yellow.opacity(0.9)).frame(width: 180).offset(x: -190, y: -110)
            RoundedRectangle(cornerRadius: 14).fill(Color.teal).frame(width: 220, height: 64).offset(x: 200, y: 140)
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            HStack(alignment: .top, spacing: DroppySpacing.lg) {
                VStack(alignment: .leading, spacing: DroppySpacing.md) {
                    header
                    rightNow
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DroppySpacing.sm), count: 4), spacing: DroppySpacing.sm) {
                        ForEach(Self.tiles, id: \.0) { tile($0.0, $0.1) }
                    }
                }
                .frame(width: 272)
                VStack(alignment: .leading, spacing: DroppySpacing.xsm) {
                    ForEach(Self.groups, id: \.0) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, DroppySpacing.sm)
                            ForEach(group.1, id: \.0) { row($0.0, $0.1) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Divider()
            HStack(spacing: DroppySpacing.xsm) {
                ForEach(Self.chips, id: \.0) { chip($0.0, $0.1) }
                Spacer(minLength: 0)
                chip(nil, "gearshape")
            }
        }
        .padding(DroppySpacing.lg)
        .frame(width: Self.card.width, height: Self.card.height)
        .background(PetCardSurface(look: look, level: level, radius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your pet").font(.system(size: 14, weight: .semibold))
                Text("Doing fine · 185 ★").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "mic").font(.system(size: 12))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(0.1)))
        }
    }

    private var rightNow: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            HStack(spacing: DroppySpacing.xs) {
                Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(.tint)
                Text("Right now: a screenshot just landed").font(.system(size: 12, weight: .medium)).lineLimit(1)
            }
            Label("To the shelf", systemImage: "tray.and.arrow.down").font(.system(size: 11))
                .padding(.horizontal, DroppySpacing.sm).frame(height: 22)
                .background(Capsule().fill(Color.primary.opacity(0.1)))
        }
    }

    private func tile(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 16)).frame(height: 20)
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.08)))
    }

    private func row(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 12)).lineLimit(1)
            .padding(.horizontal, DroppySpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
    }

    private func chip(_ title: String?, _ symbol: String) -> some View {
        Group {
            if let title { Label(title, systemImage: symbol) } else { Image(systemName: symbol) }
        }
        .font(.system(size: 11))
        .padding(.horizontal, DroppySpacing.sm)
        .frame(minWidth: 24, minHeight: 24)
        .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    private static let tiles = [("Feed", "fork.knife"), ("Play", "gamecontroller"), ("Nap", "moon.zzz"), ("Pet", "hand.raised"),
                                ("Fetch", "tennisball"), ("Ask", "bubble.left"), ("Focus", "timer"), ("Notes", "note.text")]
    private static let groups = [("Desktop", [("Follow the cursor", "cursorarrow.motionlines"), ("Go home", "house")]),
                                 ("Focus", [("Pomodoro", "timer"), ("Lofi", "music.note")]),
                                 ("Tells you", [("Calendar events", "calendar"), ("Battery", "battery.75percent")])]
    private static let chips = [("Droppy", "drop"), ("Wardrobe", "tshirt"), ("Pixel size", "square.grid.3x3"), ("Capture", "camera")]
}
