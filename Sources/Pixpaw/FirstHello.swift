//
//  FirstHello.swift
//  Pixpaw
//
//  A fresh install's hello: three short bubbles that teach the pet's
//  gestures, each moving on once you do it or after six seconds. Only on a
//  first install (upgraders get Droppy's changelog popover instead), and
//  again from Settings › Say hello again. One timer, stopped in `stop()`.
//

import Foundation

@MainActor
final class FirstHello {
    enum Step: Int, CaseIterable {
        case pet, card, drag

        /// Worded for Settings › Your pet's card › Open it: with Click, a
        /// click opens the card and a pet is a stroke with the pointer.
        func line(cardOnClick: Bool) -> CatLine {
            switch self {
            case .pet: CatLine(text: cardOnClick ? "Stroke me with the pointer for a pet ♥" : "Click me for a pet ♥",
                               symbol: "hand.tap", key: FirstHello.key, seconds: FirstHello.wait)
            case .card: CatLine(text: cardOnClick ? "Click me (or right-click) for my card" : "Hold me (or right-click) for my card",
                                symbol: "hand.point.up.left", key: FirstHello.key, seconds: FirstHello.wait)
            case .drag: CatLine(text: "Drag me anywhere", symbol: "hand.draw", key: FirstHello.key, seconds: FirstHello.wait)
            }
        }
    }

    /// The bubbles share a key, so each replaces the last in place.
    nonisolated static let key = "hello"
    nonisolated static let wait: TimeInterval = 6

    private(set) var step: Step?
    private var timer: Timer?
    private let say: (CatLine) -> Void
    /// The last bubble is up: offer "Pick my colour" on the card.
    private let offerColour: () -> Void

    /// Whether a click opens the card (Settings › Your pet's card › Open it).
    private let cardOnClick: () -> Bool

    init(say: @escaping (CatLine) -> Void, cardOnClick: @escaping () -> Bool, offerColour: @escaping () -> Void) {
        self.say = say
        self.cardOnClick = cardOnClick
        self.offerColour = offerColour
    }

    /// Starts after `delay`, so the pet has walked out first.
    func start(after delay: TimeInterval = 2) {
        stop()
        schedule(delay) { [weak self] in self?.show(.pet) }
    }

    /// You did something: if it's the one being taught, on to the next.
    func did(_ gesture: Step) {
        guard gesture == step else { return }
        advance()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        step = nil
    }

    private func show(_ next: Step) {
        step = next
        say(next.line(cardOnClick: cardOnClick()))
        if next == .drag { offerColour() }
        schedule(Self.wait) { [weak self] in self?.advance() }
    }

    private func advance() {
        guard let step else { return }
        if let next = Step(rawValue: step.rawValue + 1) { show(next) } else { stop() }
    }

    private func schedule(_ seconds: TimeInterval, _ run: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated { run() }
        }
    }
}
