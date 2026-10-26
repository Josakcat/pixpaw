//
//  ToyArt.swift
//  Pixpaw
//
//  The pixel art for each animal's own toy: a toy mouse for the cat, a
//  frisbee for the dog, a carrot for the rabbit and so on. Drawn as text
//  grids like the sprites, three points a pixel; `.` is see-through.
//

import AppKit

enum ToyArt {
    private static let ink: UInt32 = 0x2A2420

    private static let art: [PetGame: (rows: [String], palette: [Character: UInt32])] = [
        .mouse: ([
            "...oo.......",
            "..oGGooo....",
            ".oGkGGGGo...",
            "oPGGGGGGGo.o",
            ".ooooooooooo",
        ], ["G": 0xA7A7B3, "k": ink, "P": 0xF29BB0]),
        .frisbee: ([
            "..oooooo..",
            ".oRRRRRRo.",
            "oRRWWWWRRo",
            ".oooooooo.",
        ], ["R": 0xE8453C, "W": 0xF7A49E]),
        .bigBone: ([
            ".oo........oo.",
            "oWWooooooooWWo",
            ".oWWWWWWWWWWo.",
            "oWWooooooooWWo",
            ".oo........oo.",
        ], ["W": 0xF2EAD8]),
        .seed: ([
            "..o..",
            ".oBo.",
            "oBWBo",
            "oBWBo",
            "oBWBo",
            ".oBo.",
            "..o..",
        ], ["B": 0x5A5048, "W": 0xEDE6D6]),
        .carrot: ([
            "..gg.g",
            "...gg.",
            "..oOo.",
            ".oOOo.",
            ".oOOo.",
            ".oOo..",
            "oOOo..",
            "oOo...",
            "oo....",
        ], ["g": 0x4CAF50, "O": 0xF28C28]),
        .worm: ([
            "..oo.",
            ".oPko",
            ".oPPo",
            "oPPo.",
            "oPo..",
            "oPPo.",
            ".oPPo",
            "..oPo",
            "..oo.",
        ], ["P": 0xF4A3B4, "k": ink]),
        .bell: ([
            "...o...",
            "..oYo..",
            ".oYYYo.",
            ".oYWYo.",
            ".oYYYo.",
            "oYYYYYo",
            "ooooooo",
            "...Y...",
        ], ["Y": 0xF5C542, "W": 0xFFF1B8]),
        .flower: ([
            "...ooo...",
            "..oPPPo..",
            ".ooPYPoo.",
            "oPPYYYPPo",
            ".ooPYPoo.",
            "..oPPPo..",
            "...ooo...",
            "....g....",
            "....g....",
        ], ["P": 0xFF7EB6, "Y": 0xFFD23F, "g": 0x4CAF50]),
        .leaves: ([
            ".gg...gg..",
            "gLLg.gLLg.",
            ".gLLgLLg..",
            "..gBBBg...",
            "...oBo....",
            "...oBo....",
        ], ["g": 0x2E7D32, "L": 0x7BC96F, "B": 0x8B5A2B]),
        .watermelon: ([
            "..oooooo..",
            ".oGgGgGgo.",
            "oGgGgGgGgo",
            "oGgGgGgGgo",
            "oGgGgGgGgo",
            ".oGgGgGgo.",
            "..oooooo..",
        ], ["G": 0x2E8B3A, "g": 0x6CC46A]),
        .fish: ([
            "...ooo....",
            ".ooBBBo.oo",
            "oBkBBBBoBo",
            "oBBBBBBBo.",
            ".ooBBBo.oo",
            "...ooo....",
        ], ["B": 0x5BB8E8, "k": ink]),
    ]

    /// The toy's picture, and the same turned the other way (for one that
    /// rolls); nil for the toys drawn elsewhere (yarn, teaser, laser, ball).
    static func frames(_ game: PetGame) -> [CGImage]? {
        guard let art = art[game] else { return nil }
        let mirrored = art.rows.map { String($0.reversed()) }
        return [image(art.rows, art.palette), image(mirrored, art.palette)].compactMap { $0 }
    }

    private static func image(_ rows: [String], _ palette: [Character: UInt32]) -> CGImage? {
        let w = rows.map(\.count).max() ?? 0, h = rows.count
        guard w > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for (y, row) in rows.enumerated() {
            for (x, key) in row.enumerated() {
                guard let color = key == "o" ? ink : palette[key] else { continue }
                let i = (y * w + x) * 4
                bytes[i] = UInt8(color >> 16 & 0xFF); bytes[i + 1] = UInt8(color >> 8 & 0xFF); bytes[i + 2] = UInt8(color & 0xFF); bytes[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
