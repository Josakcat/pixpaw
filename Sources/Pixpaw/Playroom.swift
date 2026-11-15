//
//  Playroom.swift
//  Pixpaw
//
//  The playroom: Droppy's whole shelf as one room to throw the pet's toys,
//  dress it and arrange its home, in place of three trips into the menu.
//  It is Droppy's own takeover surface (`expanded-surface`), no window of
//  ours. Every row is an item of the pet's menu (PetMenu.swift), read and
//  run through the pet the way a click on the menu runs it, so the two
//  can't drift apart, and the menu and card keep working as they were.
//

import AppKit
import DroppyKit
import SwiftUI

extension PixpawDroplet: ExpandedSurfaceHosting {
    public var expandedSurfaceProvider: (any ExpandedSurfaceProviding)? { self }
}

extension PixpawDroplet: ExpandedSurfaceProviding {
    static let playroomID: ExpandedSurfaceID = "playroom"

    public var expandedSurfaces: [ExpandedSurfaceDescriptor] {
        // The widgets stand down so the room has the shelf; a click outside
        // or a swipe still closes it, and so does its own ×. It's opened from
        // the pet, down on the desktop, with the pointer nowhere near the
        // notch: without `.autoCollapse` Droppy closed the shelf again before
        // the pointer got there, and the teddy bear seemed to do nothing.
        [ExpandedSurfaceDescriptor(id: Self.playroomID, title: "Playroom", systemImage: "teddybear",
                                   suppresses: [.shelfWidgets, .autoCollapse])]
    }

    public func makeExpandedSurfaceView(_ id: ExpandedSurfaceID, context: ExpandedSurfaceContext) -> AnyView {
        AnyView(PlayroomView(room: playroom, close: { [weak self] in self?.closePlayroom() }))
    }

    public func expandedSurfaceSize(_ id: ExpandedSurfaceID, fitting proposal: ExpandedSurfaceSizeProposal) -> CGSize? {
        // With the pet put away there's only a line to read.
        let height = playroom.state == nil ? PlayroomView.awayHeight : PlayroomView.height
        return CGSize(width: max(proposal.standardSize.width, min(PlayroomView.width, proposal.maximumSize.width)),
                      height: max(proposal.standardSize.height, min(height, proposal.maximumSize.height)))
    }

    public func expandedSurfaceDidDismiss(_ id: ExpandedSurfaceID, presentation: ExpandedSurfacePresentation,
                                          reason: ExpandedSurfaceDismissalReason) {
        // A late teardown of an earlier one leaves a fresh room alone.
        guard playroomShown?.id == presentation.id else { return }
        playroomShown = nil
    }

    /// The widget's teddy bear and the menu's Playroom: up comes the room.
    /// Droppy can say no (the shelf busy, another room up); then the pet
    /// says so, and its menu and card still have everything.
    func openPlayroom() {
        guard let surfaces = notchSurfaces else { return }
        playroom.refresh()
        if let shown = surfaces.presentExpandedSurface(ExpandedSurfacePresentationRequest(surfaceID: Self.playroomID)) {
            playroomShown = shown
            // The pet is down on the desktop and the room is up at the notch.
            cat?.say(CatLine(text: "The playroom is open, up at the top!", symbol: "teddybear"))
        } else {
            cat?.say(CatLine(text: "The shelf is busy just now. Try the playroom again in a moment.", symbol: "teddybear"))
        }
    }

    func closePlayroom() {
        guard playroomShown != nil else { return }
        playroomShown = nil
        notchSurfaces?.dismissExpandedSurface(Self.playroomID)
    }
}

/// What the room shows: the pet's menu as it is now, read again after
/// every click, and running an item of it.
@MainActor
final class PlayroomModel: ObservableObject {
    @Published private(set) var state: PetMenuState?
    @Published private(set) var face: CGImage?
    @Published private(set) var name = "Your pet"
    weak var cat: CatController?
    /// The decorations' pictures, in the pet's own look.
    var picture: (String) -> CGImage? = { _ in nil }
    private var later: DispatchWorkItem?

    func refresh() {
        guard let cat else {
            state = nil
            face = nil
            return
        }
        state = cat.menuNow
        name = cat.title
        face = CatSprites.shared.menuImage(cat.kind, coat: cat.coat, points: 2).flatMap { $0.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    }

    /// Runs it, then reads the menu again now and once things have settled
    /// (a toy thrown, the home popping up).
    func run(_ action: PetMenuAction, _ value: String? = nil) {
        cat?.runMenu(action, value)
        refresh()
        later?.cancel()
        let again = DispatchWorkItem { [weak self] in self?.refresh() }
        later = again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: again)
    }

    /// The room went away or Pixpaw did: nothing more to read.
    func stop() {
        later?.cancel()
        later = nil
        cat = nil
        state = nil
    }
}

struct PlayroomView: View {
    static let width: CGFloat = 560
    static let height: CGFloat = 250
    static let awayHeight: CGFloat = 80

    @ObservedObject var room: PlayroomModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            header
            if let state = room.state {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DroppySpacing.md) {
                        play(state)
                        dress(state)
                        home(state)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .droppyScrollEdgeFade(.vertical)
            } else {
                away
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
    }

    private var header: some View {
        HStack(spacing: DroppySpacing.xsm) {
            if let face = room.face {
                Image(decorative: face, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 12)
            } else {
                Image(systemName: "teddybear")
                    .font(.system(size: 12, weight: .medium))
            }
            Text("\(room.name)'s playroom")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let stars = room.state?.stars {
                Text("\(stars) ★")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    .accessibilityLabel("\(stars) stars")
            }
            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(DroppyWashCircleButtonStyle(diameter: DroppyWashSize.row))
            .help("Close the playroom")
            .accessibilityLabel("Close the playroom")
        }
    }

    private var away: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            Text("Your pet is inside")
                .font(.system(size: 13, weight: .semibold))
            Text("Let it out from the widget, then come back here to play, dress up and arrange its home.")
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Rows

    /// A row: its name on the left, its choices in a line that scrolls sideways.
    private func row<Content: View>(_ title: String, _ symbol: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: DroppySpacing.sm) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DroppyWashChoiceButtonStyle.spacing) { content() }
            }
        }
    }

    private func choice(_ title: String, chosen: Bool = false, enabled: Bool = true, picture: CGImage? = nil,
                        _ action: PetMenuAction, _ value: String? = nil) -> some View {
        Button {
            room.run(action, value)
        } label: {
            HStack(spacing: DroppySpacing.xs) {
                if let picture {
                    Image(decorative: picture, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
                Text(title).lineLimit(1)
            }
        }
        .buttonStyle(DroppyWashChoiceButtonStyle(isSelected: chosen, accent: .accentColor))
        .disabled(!enabled)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    // MARK: Sections

    /// Its own toys first, a treat, and stopping a game under way.
    @ViewBuilder private func play(_ state: PetMenuState) -> some View {
        section("Play")
        row("Toys", "gamecontroller") {
            ForEach(state.games, id: \.id) { game in
                choice(game.title, .playGame, game.id)
            }
            choice("Give a treat", .treat)
            if state.friend { choice("Rock, paper, scissors", .playHands) }
            if state.playing { choice("Stop playing", .stopPlaying) }
        }
    }

    /// Its colour, then a line per place on it: what's yours to wear there.
    @ViewBuilder private func dress(_ state: PetMenuState) -> some View {
        section("Dress up")
        if !state.colours.isEmpty {
            row("Colour", "paintpalette") {
                ForEach(state.colours, id: \.id) { colour in
                    choice(colour.title, chosen: colour.worn, .setColour, colour.id)
                }
            }
        }
        ForEach(state.places, id: \.title) { place in
            row(place.title, place.symbol) {
                choice(place.none, chosen: !place.things.contains(where: \.worn), .wearItem, place.noneID)
                ForEach(place.things, id: \.id) { thing in
                    choice(thing.title, chosen: thing.worn, .wearItem, thing.id)
                }
                if let next = place.next {
                    Text(next)
                        .font(.system(size: 11))
                        .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }

    /// Bringing the home out or away, and what stands beside it.
    @ViewBuilder private func home(_ state: PetMenuState) -> some View {
        section("Home")
        if state.home {
            row("Home", "house") {
                choice(state.homeOut ? "Put it away" : "Bring it out", state.homeOut ? .putHomeAway : .bringHomeOut)
                choice(state.asleep ? "Wake up" : "Nap", state.asleep ? .wake : .nap)
            }
            ForEach([("left", "Left", "arrow.left.to.line"), ("right", "Right", "arrow.right.to.line"),
                     ("front", "Doormat", "rectangle.bottomhalf.filled")], id: \.0) { spot, title, symbol in
                let fitting = state.decor.filter { $0.owned && $0.spots.contains(spot) }
                if !fitting.isEmpty {
                    row(title, symbol) {
                        choice("Nothing", chosen: !fitting.contains { $0.placed == spot }, .placeDecor, "\(spot)=")
                        ForEach(fitting, id: \.id) { thing in
                            choice(thing.title, chosen: thing.placed == spot, picture: room.picture(thing.id), .placeDecor, "\(spot)=\(thing.id)")
                        }
                    }
                }
            }
            if state.decor.contains(where: { !$0.owned }) {
                Text("More to put beside it in the pet's menu, Home ▸ Decorate ▸ Buy: \(state.wallet) ★ to spend.")
                    .font(.system(size: 11))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            }
        } else {
            Text("A home of its own comes at 500 ★, then it's arranged here.")
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }
}
