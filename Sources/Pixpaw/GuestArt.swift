//
//  GuestArt.swift
//  Pixpaw
//
//  Drawing the agents' guests (Guests.swift) in front of the home: small
//  ones of the other pets, in the home's own window, on its floor. No window
//  of their own. Redrawn twice a second while there are any.
//

import AppKit

extension HomeView {
    /// Points per pixel of the 20 x 16 art: half the pet's three.
    private static let guestPoints: CGFloat = 1.5
    private static var guestSize: CGSize { CGSize(width: 20 * guestPoints, height: 16 * guestPoints) }

    /// The layer holding the guests, made the first time.
    private var guestLayer: CALayer? {
        guard let root = layer else { return nil }
        if let found = root.sublayers?.first(where: { $0.name == "guests" }) { return found }
        let made = CALayer()
        made.name = "guests"
        made.zPosition = 5
        made.actions = ["sublayers": NSNull(), "contents": NSNull()]
        root.addSublayer(made)
        return made
    }

    /// Lays `guests` along the house's floor, `body` being the house's own
    /// rectangle in the view, each one of the other pets (never `owner`).
    /// `tick` counts half seconds, for a blink and a bob.
    @MainActor
    func showGuests(_ guests: [HomeGuest], owner: PetKind, body: CGRect, tick: Int) {
        guard let holder = guestLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        holder.frame = bounds
        let others = PetKind.builtIn.filter { $0 != owner }
        var layers = holder.sublayers ?? []
        while layers.count > guests.count { layers.removeLast().removeFromSuperlayer() }
        let size = Self.guestSize
        let step = guests.isEmpty ? 0 : body.width / CGFloat(guests.count)
        for (index, guest) in guests.enumerated() {
            let one: CALayer
            if index < layers.count { one = layers[index] } else {
                one = CALayer()
                one.magnificationFilter = .nearest
                one.actions = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull(), "transform": NSNull()]
                let mark = CALayer()
                mark.magnificationFilter = .nearest
                mark.actions = ["contents": NSNull(), "position": NSNull(), "hidden": NSNull()]
                one.addSublayer(mark)
                holder.addSublayer(one)
                layers.append(one)
            }
            guard let kind = HomeGuests.pick(guest.id, from: others) else { continue }
            // Its own little seed: guests don't blink in step.
            let beat = tick + index * 3
            let frame: CatFrame = switch guest.pose {
            case .working: beat % 9 == 0 ? .blink : .sit
            case .waiting: .sit
            case .done: beat % 12 < 2 ? .blink : .happy
            }
            one.contents = CatSprites.shared.image(frame, coat: .gray, kind: kind, laptop: guest.pose == .working)
            let middle = body.minX + step * (CGFloat(index) + 0.5)
            // Waiting, it hops on the spot now and then to be seen.
            let hop: CGFloat = guest.pose == .waiting && beat % 4 == 0 ? 2 : 0
            one.bounds = CGRect(origin: .zero, size: size)
            one.position = CGPoint(x: middle, y: size.height / 2 + hop)
            // Facing the middle of the house.
            let flip = middle > body.midX ? CGAffineTransform(scaleX: -1, y: 1) : .identity
            one.setAffineTransform(flip)
            if let mark = one.sublayers?.first {
                // Flipped back, so the "?" reads the right way round.
                mark.setAffineTransform(flip)
                mark.isHidden = guest.pose != .waiting
                mark.contents = Self.questionMark
                mark.bounds = CGRect(x: 0, y: 0, width: 8, height: 12)
                mark.position = CGPoint(x: size.width / 2, y: size.height + 7)
            }
        }
    }

    /// A small pixel "?" over a waiting guest, in the pet's sand yellow.
    @MainActor private static let questionMark: CGImage? = {
        let rows = [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."]
        let width = 5, height = rows.count
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1))
        for (y, row) in rows.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "#" {
                context.fill(CGRect(x: x, y: height - 1 - y, width: 1, height: 1))
            }
        }
        return context.makeImage()
    }()
}
