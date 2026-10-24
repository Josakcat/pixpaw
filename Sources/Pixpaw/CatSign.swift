//
//  CatSign.swift
//  Pixpaw
//
//  A little wooden sign the pet holds up on a stick: a note you gave it
//  ("Buy milk", "Call Mum at 5"), carried about until you click it done.
//

import AppKit
import SwiftUI

@MainActor
final class CatSign {
    static let maxLength = 60
    private static let maxWidth: CGFloat = 170
    /// From the pet's paw to the bottom of the board, clear of its head.
    static let stick: CGFloat = 44

    private var panel: CatPanel?
    private var hosting: SignHostingView?
    private(set) var text: String?
    /// Clicked: whatever it said is done.
    var onClick: (() -> Void)?

    /// The top of the board on screen, while it is up.
    var top: CGFloat? { panel?.isVisible == true ? panel?.frame.maxY : nil }

    /// The note to hold up, or nil to put it down.
    func hold(_ text: String?) {
        guard text != self.text else { return }
        self.text = text
        guard let text else { return close() }
        let font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
        let natural = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 4
        let view = SignBoard(text: text, textWidth: min(natural, Self.maxWidth))
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = SignHostingView(rootView: view)
            hosting.onClick = { [weak self] in self?.onClick?() }
            let panel = CatPanel(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10))
            panel.contentView = hosting
            self.hosting = hosting
            self.panel = panel
        }
        panel?.setContentSize(hosting?.fittingSize ?? .zero)
    }

    /// Up with its stick in the pet's front paw, at `paw`; or out of sight.
    func place(paw: CGPoint?) {
        guard let panel, text != nil else { return }
        guard let paw else { return panel.orderOut(nil) }
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: (paw.x - size.width / 2).rounded(), y: paw.y.rounded()))
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hosting = nil
    }
}

/// Takes the click itself, first time, without making Droppy active.
final class SignHostingView: NSHostingView<SignBoard> {
    var onClick: (@MainActor () -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        MainActor.assumeIsolated { onClick?() }
    }
}

/// A cream board with a brown frame, the note in the middle, on a stick.
struct SignBoard: View {
    let text: String
    let textWidth: CGFloat

    private static let wood = Color(red: 0.42, green: 0.27, blue: 0.14)

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.29, green: 0.18, blue: 0.09))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: textWidth)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.97, green: 0.89, blue: 0.72))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Self.wood, lineWidth: 2.5))
                        .padding(1)
                )
            Rectangle()
                .fill(Self.wood)
                .frame(width: 4, height: CatSign.stick)
        }
        .fixedSize()
        .help("Click when it's done")
        .accessibilityLabel("Sign: \(text). Click when it's done.")
    }
}
