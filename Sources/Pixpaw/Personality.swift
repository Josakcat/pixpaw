//
//  Personality.swift
//  Pixpaw
//
//  Each pet has a character of its own, two traits drawn once and kept, and
//  a purse of make-believe coins it bets on rock, paper, scissors with its
//  friend. Nothing here is real money, and nothing leaves the Mac.
//

import Foundation

enum PetTrait: String, CaseIterable, Codable {
    case competitive, gambler, playful, sleepy, calm, thrifty

    var title: String {
        switch self {
        case .competitive: "competitive"
        case .gambler: "loves a bet"
        case .playful: "playful"
        case .sleepy: "sleepy"
        case .calm: "calm"
        case .thrifty: "thrifty"
        }
    }

    /// Two that don't fit one character.
    private func clashes(with other: PetTrait) -> Bool {
        let pair: Set = [self, other]
        return pair == [.gambler, .thrifty] || pair == [.calm, .competitive] || pair == [.sleepy, .playful]
    }

    /// Two traits that go together, the same every time for the same seed.
    static func drawn(from seed: UInt64) -> [PetTrait] {
        var state = seed | 1
        func next() -> Int {
            // xorshift: plain, and the same on every Mac.
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return Int(state % UInt64(allCases.count))
        }
        let first = allCases[next()]
        var second = allCases[next()]
        while second == first || second.clashes(with: first) { second = allCases[next()] }
        return [first, second]
    }
}

/// The two pets' characters, purses and score, kept in the droplet's
/// preferences as one value.
struct PetSocial: Codable, Equatable {
    var petSeed: UInt64
    var friendSeed: UInt64
    var petCoins = PetSocial.startingCoins
    var friendCoins = PetSocial.startingCoins
    var petWins = 0
    var friendWins = 0
    /// The day pocket money last came, so a pet that lost it all can play
    /// again tomorrow.
    var toppedUp = ""

    static let startingCoins = 100
    static let pocketMoney = 20

    static func fresh() -> PetSocial {
        PetSocial(petSeed: .random(in: 1 ... .max), friendSeed: .random(in: 1 ... .max))
    }

    var petTraits: [PetTrait] { PetTrait.drawn(from: petSeed) }
    var friendTraits: [PetTrait] { PetTrait.drawn(from: friendSeed) }

    /// Both have coins to put on a game.
    var canPlay: Bool { petCoins > 0 && friendCoins > 0 }

    /// What goes on a game: a lot for a gambler, a little when either is
    /// thrifty, never more than the poorer one has.
    func stake() -> Int {
        let traits = petTraits + friendTraits
        let range = traits.contains(.thrifty) ? 5 ... 10 : traits.contains(.gambler) ? 25 ... 50 : 10 ... 20
        return min(Int.random(in: range), petCoins, friendCoins)
    }

    /// A game played: the winner takes the stake from the other.
    mutating func settle(petWon: Bool, stake: Int) {
        if petWon {
            petCoins += stake; friendCoins -= stake; petWins += 1
        } else {
            friendCoins += stake; petCoins -= stake; friendWins += 1
        }
    }

    /// Once a day, a pet with next to nothing left gets a little to play with.
    mutating func topUp(today: String) {
        guard toppedUp != today else { return }
        toppedUp = today
        petCoins = max(petCoins, Self.pocketMoney)
        friendCoins = max(friendCoins, Self.pocketMoney)
    }

    /// A game asked for while one of them has nothing left: the other
    /// spots it some pocket money. Which one gave and how much, or nil when
    /// neither has enough to spare.
    mutating func share() -> (petGave: Bool, coins: Int)? {
        let coins = Self.pocketMoney
        if friendCoins == 0, petCoins > coins {
            petCoins -= coins; friendCoins += coins
            return (true, coins)
        }
        if petCoins == 0, friendCoins > coins {
            friendCoins -= coins; petCoins += coins
            return (false, coins)
        }
        return nil
    }
}
