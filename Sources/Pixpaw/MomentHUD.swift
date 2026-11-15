//
//  MomentHUD.swift
//  Pixpaw
//
//  A short notch moment (an agent done or stuck, the late-night nudge) as
//  Droppy's own HUD strip: Droppy queues it with its other HUDs, lays it out
//  around the camera, keeps it out of meetings and screen recordings, and
//  takes it down after a few seconds. The pet in its moment's pose on one
//  side, the words on the other. When Droppy turns it down the moment goes
//  to the live activity row as before.
//

import SwiftUI
import DroppyKit

@MainActor
enum MomentHUD {
    /// One id for every moment: a new one replaces the last in place.
    static let id = "pixpaw.moment"
    static let seconds: TimeInterval = 4

    /// The pose a moment is drawn in, the same as the row's; nil for a
    /// moment that stays in the row (it lasts as long as what it shows).
    static func pose(_ scene: NotchScene) -> (frame: CatFrame, costume: String?)? {
        switch scene {
        case .agentDone: (.happy, "partyHat")
        case .agentSnag: (.groom1, nil)
        case .lateNight: (.sleep1, "nightcap")
        case .agentAsks, .meetingNotes, .focus, .longCommand: nil
        }
    }

    static func request(_ scene: NotchScene, text: String, cat: CatController) -> DropletHUDRequest? {
        guard let pose = pose(scene) else { return nil }
        let picture = PetPicture(image: CatSprites.shared.image(pose.frame, coat: cat.coat, hat: cat.hat, collar: cat.collar,
                                                                glasses: cat.glasses, headphones: false,
                                                                costume: pose.costume ?? cat.costume, kind: cat.kind, laptop: false),
                                 facesRight: cat.facesRight)
        return DropletHUDRequest(id: id, duration: seconds, priority: .normal, accessibilityLabel: "\(cat.title): \(text)") {
            picture
        } trailing: {
            Text(verbatim: text)
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// The pet's picture at wing size, drawn once when the HUD is asked for.
private struct PetPicture: View, @unchecked Sendable {
    let image: CGImage?
    let facesRight: Bool

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: facesRight ? 1 : -1, y: 1)
            }
        }
        .frame(width: 25, height: 20)
        .accessibilityHidden(true)
    }
}
