//
//  FineCoats.swift
//  Pixpaw
//
//  The cat's finer art is drawn once, as the gray tabby; every other coat,
//  the one from a photo too, wears it in colours worked out from its 20 x 16
//  ones by `FineArt.coatMix` (see `coats` in Tools/sprites.py).
//

/// One finer colour from a 20 x 16 coat's: its `from` colour times `times`,
/// then `amount` of the way to `toward`, a coat letter or "*" for white.
struct FineMix {
    let from: Character
    let times: Double
    let toward: Character
    let amount: Double
}

extension FineArt {
    /// The finer palette for a 20 x 16 coat (outline, fur, stripe, white, pink, eye).
    static func palette(coat: [Character: UInt32]) -> [Character: UInt32] {
        func channels(_ rgb: UInt32) -> [Double] { [16, 8, 0].map { Double((rgb >> UInt32($0)) & 0xFF) } }
        var out: [Character: UInt32] = [:]
        for (letter, mix) in coatMix {
            guard let source = coat[mix.from] else { continue }
            let start = channels(source).map { min(255, ($0 * mix.times).rounded()) }
            let end = mix.toward == "*" ? [255, 255, 255] : coat[mix.toward].map(channels) ?? start
            let rgb = zip(start, end).map { UInt32(($0 + ($1 - $0) * mix.amount).rounded()) }
            out[letter] = rgb[0] << 16 | rgb[1] << 8 | rgb[2]
        }
        return out
    }
}
