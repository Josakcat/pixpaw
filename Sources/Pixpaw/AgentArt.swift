//
//  AgentArt.swift
//  Pixpaw
//
//  The little pictures over a pet's head while a coding agent keeps it
//  waiting, and for the games it plays with its friend: popcorn, an
//  hourglass, cobwebs, confetti, a rain cloud, a parcel, and a hand for
//  rock, paper or scissors. Drawn as text grids like the toys; `o` is ink,
//  `.` see-through.
//

import AppKit

enum AgentArt: String {
    case popcorn, hourglass, cobweb, confetti, rainCloud, parcel, rock, paper, scissors, bug, squashed

    private static let red: UInt32 = 0xE8453C, white: UInt32 = 0xF7F3EA, corn: UInt32 = 0xFFE9A8
    private static let sand: UInt32 = 0xF2C14E, glass: UInt32 = 0xCFE6F2, grey: UInt32 = 0xC9CDD4
    private static let cloud: UInt32 = 0x8E96A3, drop: UInt32 = 0x5AA9E6, card: UInt32 = 0xC8935A, tape: UInt32 = 0xF2D49B
    private static let paw: UInt32 = 0xF6D7B8
    private static let shell: UInt32 = 0x6BBF59, spot: UInt32 = 0x2F6B2A

    /// Its frames, played in turn.
    private var art: (frames: [[String]], palette: [Character: UInt32]) {
        switch self {
        case .popcorn:
            // A kernel pops out of the bucket now and then.
            return ([[
                ".........",
                "..yy.y...",
                ".yyyyyy..",
                ".oyyyyo..",
                ".oRWRWo..",
                ".oRWRWo..",
                "..oRWo...",
            ], [
                "......y..",
                "..yy.....",
                ".yyyyyy..",
                ".oyyyyo..",
                ".oRWRWo..",
                ".oRWRWo..",
                "..oRWo...",
            ], [
                ".....y...",
                "..yy..y..",
                ".yyyyyy..",
                ".oyyyyo..",
                ".oRWRWo..",
                ".oRWRWo..",
                "..oRWo...",
            ]], ["y": Self.corn, "R": Self.red, "W": Self.white])
        case .hourglass:
            // Upright, then turned over: the sand runs again.
            return ([[
                "ooooooo",
                ".oGGGo.",
                "..oSo..",
                "...o...",
                "..oGo..",
                ".oSSSo.",
                "ooooooo",
            ], [
                "ooooooo",
                ".oSSSo.",
                "..oSo..",
                "...S...",
                "..oSo..",
                ".oGGGo.",
                "ooooooo",
            ]], ["S": Self.sand, "G": Self.glass])
        case .cobweb:
            return ([[
                "g.g.g.g.g",
                ".g.ggg.g.",
                "..ggggg..",
                ".g.ggg.g.",
                "g...g...g",
                "....o....",
            ], [
                "g.g.g.g.g",
                ".g.ggg.g.",
                "..ggggg..",
                ".g.ggg.g.",
                "g...g...g",
                ".........",
                "....o....",
            ]], ["g": Self.grey])
        case .confetti:
            return ([[
                "r...b...y..",
                "..g...p...r",
                ".y..r..b...",
                "...b...g..y",
            ], [
                "..b...y...g",
                "r...p...r..",
                "..y...g...b",
                ".g..r...y..",
            ], [
                ".y...r..b..",
                "...g...y...",
                "b...r...p..",
                "..y...b...r",
            ]], ["r": Self.red, "b": Self.drop, "y": Self.sand, "g": 0x5CC48A, "p": 0xE07BC4])
        case .rainCloud:
            return ([[
                "..oooo...",
                ".occcco..",
                "occccccoo",
                "occcccccc",
                ".ooooooo.",
                ".d..d..d.",
                ".........",
            ], [
                "..oooo...",
                ".occcco..",
                "occccccoo",
                "occcccccc",
                ".ooooooo.",
                "...d..d..",
                ".d.....d.",
            ]], ["c": Self.cloud, "d": Self.drop])
        case .parcel:
            return ([[
                "ooooooo",
                "oCCtCCo",
                "ottttto",
                "oCCtCCo",
                "oCCtCCo",
                "ooooooo",
            ]], ["C": Self.card, "t": Self.tape])
        case .bug:
            // A beetle scuttling, its legs in turn.
            return ([[
                "..o.o...",
                "...ooo..",
                ".oGsGGo.",
                "oGGGsGGo",
                ".oooooo.",
                "o..o..o.",
            ], [
                "..o.o...",
                "...ooo..",
                ".oGsGGo.",
                "oGGGsGGo",
                ".oooooo.",
                ".o..o..o",
            ]], ["G": Self.shell, "s": Self.spot])
        case .squashed:
            return ([[
                ".y...y..",
                "...y...y",
                "y.oooo..",
                ".oGsGGo.",
                "..y...y.",
            ]], ["G": Self.shell, "s": Self.spot, "y": Self.sand])
        case .rock:
            // A round fist, the thumb across it.
            return ([[
                "..ooooo..",
                ".oPPPPPo.",
                "oPPPPPPPo",
                "oPoooooPo",
                "oPPPPPPPo",
                ".oPPPPPo.",
                "..ooooo..",
            ]], ["P": Self.paw])
        case .paper:
            // An open hand: four tall fingers and a thumb out.
            return ([[
                ".o.o.o.o..",
                "oPoPoPoPo.",
                "oPoPoPoPo.",
                "oPoPoPoPo.",
                "oPoPoPoPoo",
                "oPPPPPPPPo",
                "oPPPPPPPo.",
                ".oPPPPPo..",
                "..ooooo...",
            ]], ["P": Self.paw])
        case .scissors:
            // A fist with two fingers up in a V.
            return ([[
                "oo.....oo",
                "oPo...oPo",
                ".oPo.oPo.",
                "..oPoPo..",
                "..oPPPo..",
                ".oPPPPPo.",
                "oPPPPPPPo",
                "oPoooooPo",
                ".oPPPPPo.",
                "..ooooo..",
            ]], ["P": Self.paw])
        }
    }

    @MainActor private static var cache: [AgentArt: [CGImage]] = [:]

    @MainActor
    var frames: [CGImage] {
        if let hit = Self.cache[self] { return hit }
        let drawn = art.frames.compactMap { ToyArt.image($0, art.palette) }
        Self.cache[self] = drawn
        return drawn
    }

    /// The frame for a tick of the pet's clock, a few ticks each.
    @MainActor
    func frame(at tick: Int, every ticks: Int = 4) -> CGImage? {
        let frames = frames
        return frames.isEmpty ? nil : frames[(tick / ticks) % frames.count]
    }

    static let hands: [AgentArt] = [.rock, .paper, .scissors]

    /// How this hand beats that one: "Paper covers rock".
    func beating(_ other: AgentArt) -> String {
        switch self {
        case .rock: "Rock crushes \(other.rawValue)"
        case .paper: "Paper covers \(other.rawValue)"
        default: "Scissors cut \(other.rawValue)"
        }
    }

    /// Whether this hand beats that one.
    func beats(_ other: AgentArt) -> Bool {
        (self, other) == (.rock, .scissors) || (self, other) == (.paper, .rock) || (self, other) == (.scissors, .paper)
    }
}
