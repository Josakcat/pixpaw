// droppykit-lint: allow-file own-window: the pet's card, a small non-activating panel on Droppy's own panel surface that opens over the pet on a long press or a click (the user's choice), with its submenus as panels beside it; closes on Escape, a click elsewhere (a mouse-click monitor, only while it is open) or once something in it is chosen; never opened by itself, and closed in deactivate()
//
//  PetCard.swift
//  Pixpaw
//
//  Hold on your pet (or click it, in Settings) and its card opens over it:
//  who it is and how it's doing, the six things you do most as big
//  buttons, and rows for the rest. A row with more opens it beside the
//  card as you point at it, never over it, and so on for a menu inside
//  that. A right-click still gives the plain menu.
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
    var enabled = true
    var checked = false
    var isSeparator = false
    var children: [PetCardItem]?

    static let separator = PetCardItem(title: "", symbol: nil, isSeparator: true)

    /// A menu, item by item, submenus included.
    static func items(of menu: NSMenu) -> [PetCardItem] {
        menu.items.map { item in
            if item.isSeparatorItem || item.isSectionHeader { return .separator }
            return PetCardItem(title: item.title, symbol: item.identifier?.rawValue, action: item.action,
                               represented: item.representedObject as? String, badge: item.badge?.stringValue,
                               enabled: item.isEnabled, checked: item.state == .on,
                               children: item.submenu.map(items(of:)))
        }
    }
}

/// What the card shows, built by the pet's view from its current state.
struct PetCardModel {
    let name: String
    let status: String
    let stars: Int
    let canTalk: Bool
    let urgent: [PetCardItem]
    let tiles: [PetCardItem]
    let rows: [PetCardItem]
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
    private var closedAt = Date.distantPast
    /// Closed a moment ago, by the very click now arriving at the pet.
    var justClosed: Bool { Date().timeIntervalSince(closedAt) < 0.4 }

    /// Opens the card over `petFrame` (screen coordinates); actions go to
    /// `target`, the pet's view, exactly as its menu's do.
    func show(_ model: PetCardModel, over petFrame: CGRect, target: NSView, talk: Selector, look: PetCardLook, level: Double) {
        close()
        self.target = target
        self.look = look
        self.level = level
        let previous = NSWorkspace.shared.frontmostApplication
        let view = PetCardView(model: model, talk: talk, look: look, level: level,
                               run: { [weak self] item, frame in self?.run(item, at: frame, depth: 0) },
                               hover: { [weak self] item, frame in self?.hover(item, at: frame, depth: 0) })
        let panel = PetCardPanel(view)
        panel.onCancel = { [weak self] in self?.close() }
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
        let view = PetCardMenuView(items: children, look: look, level: level,
                                   run: { [weak self] child, rect in self?.run(child, at: rect, depth: depth + 1) },
                                   hover: { [weak self] child, rect in self?.hover(child, at: rect, depth: depth + 1) })
        let flyout = PetCardPanel(view)
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

    private static func screen(for rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main
    }
}

/// Takes the keyboard (Tab moves between buttons, Escape closes) without
/// becoming the app the user was in.
private final class PetCardPanel: NSPanel {
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
            DroppyPanelSurface(cornerRadius: radius)
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
    let talk: Selector
    let look: PetCardLook
    let level: Double
    let run: (PetCardItem, CGRect) -> Void
    let hover: (PetCardItem, CGRect) -> Void
    private static let radius: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.md) {
            if !model.urgent.isEmpty {
                VStack(spacing: DroppySpacing.xs) {
                    ForEach(model.urgent) { PetCardRow(item: $0, accent: true, run: run, hover: hover) }
                }
            }
            header
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DroppySpacing.sm), count: 3), spacing: DroppySpacing.sm) {
                ForEach(model.tiles) { tile($0) }
            }
            VStack(spacing: DroppySpacing.xs) {
                ForEach(model.rows) { PetCardRow(item: $0, accent: false, run: run, hover: hover) }
            }
        }
        .padding(DroppySpacing.lg)
        .frame(width: 280)
        .background(PetCardSurface(look: look, level: level, radius: Self.radius))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
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
            if model.canTalk {
                Button { run(PetCardItem(title: "Talk to me", symbol: "mic.fill", action: talk), .zero) } label: {
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 28))
                .help("Talk to me")
                .accessibilityLabel("Talk to me")
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
            .accessibilityLabel(item.badge.map { "\(item.title), \($0)" } ?? item.title)
        }
        .frame(height: 62)
    }
}

/// A submenu beside the card, on the same surface.
private struct PetCardMenuView: View {
    let items: [PetCardItem]
    let look: PetCardLook
    let level: Double
    let run: (PetCardItem, CGRect) -> Void
    let hover: (PetCardItem, CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                if item.isSeparator {
                    Divider().padding(.vertical, 3).padding(.horizontal, DroppySpacing.sm)
                } else {
                    PetCardRow(item: item, accent: false, run: run, hover: hover)
                }
            }
        }
        .padding(DroppySpacing.sm)
        .frame(width: 230)
        .background(PetCardSurface(look: look, level: level, radius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    if item.children != nil { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary) }
                }
                .font(.system(size: 13))
                .padding(.horizontal, DroppySpacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PetRowStyle())
            .disabled(!item.enabled)
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
