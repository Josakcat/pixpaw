#!/usr/bin/env python3
"""Pixpaw sprite source.

Each frame is a 20x16 grid, facing right. `python3 Tools/sprites.py preview out.png`
draws every frame in every coat so the art can be checked by eye;
`python3 Tools/sprites.py swift` regenerates Sources/Pixpaw/CatSprites.generated.swift.

Legend: . clear  o outline  f fur  s stripe/patch  w white  p pink  e eye
"""
import struct
import sys
import zlib
from pathlib import Path

W, H = 20, 16

FRAMES = {
    "sit": [
        "....................",
        "....................",
        "....................",
        "...........o...o....",
        "..........opo.opo...",
        "..........offsfffo..",
        "..........offfffffo.",
        "..........ofefffefo.",
        "..........offfpfffo.",
        "...........offwwfo..",
        "..oo.......offwwfo..",
        ".offo.....offsswffo.",
        "..oso.....offsswffo.",
        "...ofo...offfswwffo.",
        "....offooffwfowwffo.",
        ".....oooooowoowwooo.",
    ],
    "blink": [
        "....................",
        "....................",
        "....................",
        "...........o...o....",
        "..........opo.opo...",
        "..........offsfffo..",
        "..........offfffffo.",
        "..........ooofffooo.",
        "..........offfpfffo.",
        "...........offwwfo..",
        "..oo.......offwwfo..",
        ".offo.....offsswffo.",
        "..oso.....offsswffo.",
        "...ofo...offfswwffo.",
        "....offooffwfowwffo.",
        ".....oooooowoowwooo.",
    ],
    "walk1": [
        "....................",
        "....................",
        "....................",
        "..............o...o.",
        ".............opo.opo",
        "..oo.........offsffo",
        ".ofo.........offfefo",
        ".ofo.........offffpo",
        "..ofo.......offffwo.",
        "...ooooooooofffwwo..",
        "...offsfsfsffffwo...",
        "...offsfsfsfffffo...",
        "...offfffffffffwo...",
        "...offoooooooofo....",
        "..ofo.......ofo.....",
        "..oo.........oo.....",
    ],
    "walk2": [
        "....................",
        "....................",
        "....................",
        "..............o...o.",
        ".............opo.opo",
        "..oo.........offsffo",
        ".ofo.........offfefo",
        ".ofo.........offffpo",
        "..ofo.......offffwo.",
        "...ooooooooofffwwo..",
        "...offsfsfsffffwo...",
        "...offsfsfsfffffo...",
        "...offfffffffffwo...",
        "....ofoooooooofo....",
        "....ofo......ofo....",
        "....oo........oo....",
    ],
    "run1": [
        "....................",
        "....................",
        "..............o...o.",
        ".............opo.opo",
        "oo...........offsffo",
        "ofoo.........offfefo",
        ".offooooooooooffffpo",
        "..offsfsfsfsffffffo.",
        "..offsfsfsfsfffffwo.",
        "..offfffffffffffwo..",
        "...ooffoooooooffo...",
        ".....offo....offo...",
        "......ofo....ofo....",
        "......oo.....oo.....",
        "....................",
        "....................",
    ],
    "run2": [
        "....................",
        "....................",
        "....................",
        "..............o...o.",
        ".............opo.opo",
        "ooo..........offsffo",
        "offoo........offfefo",
        ".ooffoooooooooffffpo",
        "...offsfsfsfsffffwo.",
        "...offsfsfsfsfffwo..",
        "..offfffffffffffo...",
        ".offoooooooooooffo..",
        "ofo.............offo",
        "oo...............oo.",
        "....................",
        "....................",
    ],
    "groom1": [
        "....................",
        "....................",
        "....................",
        "...........o...o....",
        "..........opo.opo...",
        "..........offsfffo..",
        "..........offfffffo.",
        "..........ooofffooo.",
        "..........offfpfffo.",
        "...........offwwpo..",
        "..oo.......offwowwo.",
        ".offo.....offssowwo.",
        "..oso.....offsswoo..",
        "...ofo...offfswwffo.",
        "....offooffwfowwffo.",
        ".....oooooowoowwooo.",
    ],
    "groom2": [
        "....................",
        "....................",
        "....................",
        "...........o...o....",
        "..........opo.opo...",
        "..........offsfffo..",
        "..........offfffffo.",
        "..........ooofffooo.",
        "..........offfpfwwo.",
        "...........offwwwwo.",
        "..oo.......offwwoo..",
        ".offo.....offsswo...",
        "..oso.....offsswffo.",
        "...ofo...offfswwffo.",
        "....offooffwfowwffo.",
        ".....oooooowoowwooo.",
    ],
    "sleep1": [
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "..........o...o.....",
        ".....ooooopo.opo....",
        "...ooffsfsfoofffo...",
        "..offsfsfsffffffoo..",
        ".offsfsfsfsoooffffo.",
        ".offfffffffffppfwwo.",
        ".offfoooooffffffwwo.",
        "..offsffssffoooooo..",
        "...ooooooooooo......",
    ],
    "sleep2": [
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "..........o...o.....",
        "...oooooooopo.opo...",
        "..offsfsfsfoofffoo..",
        ".offsfsfsfsoooffffo.",
        ".offfffffffffppfwwo.",
        ".offfoooooffffffwwo.",
        "..offsffssffoooooo..",
        "...ooooooooooo......",
    ],
    "happy": [
        "....................",
        "....................",
        "....................",
        "...........o...o....",
        "..........opo.opo...",
        "..........offsfffo..",
        "..........offfffffo.",
        "..........ofofffofo.",
        "..........offfpfffo.",
        "...........offwwfo..",
        ".oo........offwwfo..",
        "ofo.......offsswffo.",
        "ofo.......offsswffo.",
        ".ofo.....offfswwffo.",
        "..offoooffwfowwffo..",
        "...oooooowoowwooo...",
    ],
}

# Head down in the bowl. eat2 lifts the head a pixel: chewing.
EAT = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "..oo................",
    ".ofo................",
    ".ofo................",
    "..ofo...............",
    "...ooooooooooo.o..o.",
    "...offsfsfsfffopoopo",
    "...offsfsfsfffoffffo",
    "...offffffffffoffefo",
    "...offoooooooooffpfo",
    "..ofo.......of.owwo.",
    "..oo.........oo.oo..",
]


def lift_head(rows, first_col=14):
    out = [list(r) for r in rows]
    for y in range(len(rows)):
        for x in range(first_col, len(rows[0])):
            out[y][x] = rows[y + 1][x] if y + 1 < len(rows) else "."
    return ["".join(r) for r in out]


# The third step of the walk: legs swung in under the body, between walk1's
# stride and walk2's straight legs, so the cycle reads 1-2-3-2.
FRAMES["walk3"] = FRAMES["walk2"][:14] + [
    ".....ofo....ofo.....",
    ".....oo......oo.....",
]

# Low to the ground before a pounce: the walk without its legs. The second
# frame swishes the tip of the tail.
def crouch(walk):
    return ["." * W] * 5 + walk[3:14]


def swish(rows):
    out = list(rows)
    out[7] = "...oo" + rows[7][5:]
    out[8] = "..ofo" + rows[8][5:]
    return out


FRAMES["crouch1"] = crouch(FRAMES["walk1"])
FRAMES["crouch2"] = swish(crouch(FRAMES["walk1"]))

FRAMES["eat1"] = EAT
FRAMES["eat2"] = lift_head(EAT)

# Small effects drawn above the cat: a heart and a "z".
EFFECTS = {
    "heart": [
        ".rr.rr.",
        "rrrrrrr",
        "rrrrrrr",
        ".rrrrr.",
        "..rrr..",
        "...r...",
    ],
    "fish": [
        "..oooo...o",
        ".occcco.oo",
        "ococcccoo.",
        ".occcco.oo",
        "..oooo...o",
    ],
    "bowl": [
        "...kkkkkk...",
        ".kkkkkkkkkk.",
        "oooooooooooo",
        "obbbbbbbbbbo",
        ".obbhbbbbbo.",
        "..oooooooo..",
    ],
    "bowlEmpty": [
        "............",
        "............",
        "oooooooooooo",
        "obbbbbbbbbbo",
        ".obbhbbbbbo.",
        "..oooooooo..",
    ],
    "yarn1": [
        "..ooooo..",
        ".oyylyyo.",
        "oyyllyyyo",
        "oylyyylyo",
        "oyyyllyyo",
        "oyllyyyyo",
        "oyyyylyyo",
        ".oyyyyyo.",
        "..ooooo..",
    ],
    "teaser": [
        "...q...",
        "..qqq..",
        ".qqhqq.",
        ".qqhqq.",
        "qqqhqqq",
        ".qqhqq.",
        "..qhq..",
        "...d...",
        "...d...",
        "...d...",
    ],
    "zzz": [
        "zzzz",
        "...z",
        "..z.",
        ".z..",
        "zzzz",
    ],
}

# Coats: colours as RGBA hex for o, f, s, w, p, e.
COATS = {
    "orange": dict(o="2b1a10", f="f2a03d", s="c8661e", w="fff3e0", p="f59aa8", e="1d140c"),
    "black": dict(o="0b0b10", f="2b2b33", s="1a1a22", w="3a3a44", p="d97a8a", e="ffd34d"),
    "white": dict(o="5a5560", f="fbfbfb", s="e6e4ea", w="ffffff", p="f7a8b6", e="3aa0e8"),
    "gray": dict(o="1f2228", f="8d939e", s="5d636e", w="e9ecf0", p="f0a0ae", e="5bbf6a"),
    "siamese": dict(o="2a1d16", f="f3e6cf", s="6b4a36", w="fbf4e6", p="c9867a", e="3d8de0"),
    "calico": dict(o="2a1d16", f="ffffff", s="e3892e", w="ffffff", p="f59aa8", e="2a1d16"),
}
EFFECT_COLORS = dict(r="ff5b7f", z="cfd8ff", o="1d1a24", c="8fc3ff", b="4f86e8", h="a9c8ff", k="b9733a",
                     y="e8577a", l="ffa3bb", q="3fc4b8", d="8b5a2b")


def rotate_ccw(rows):
    """Head (right side) ends up on top: for climbing up a wall."""
    h, w = len(rows), len(rows[0])
    return ["".join(rows[r][w - 1 - y] for r in range(h)) for y in range(w)]


def rotate_cw(rows):
    """Head ends up at the bottom: for climbing down."""
    h, w = len(rows), len(rows[0])
    return ["".join(rows[h - 1 - r][y] for r in range(h)) for y in range(w)]


# Being carried: seen from the front, held up under the arms, front legs
# hanging at its sides, hind legs and tail dangling. held2 swings the bottom
# half a pixel over, so the dangling legs sway while you move it.
HELD = [
    "...o.......o....",
    "..opo.....opo...",
    "..offooooooffo..",
    ".offfsfsffffffo.",
    ".offffffffffffo.",
    ".ofooffffffoofo.",
    ".offfffppfffffo.",
    "..offwwwwwwffo..",
    "oofffwwwwwwfffoo",
    "offofwwwwwwfoffo",
    "offofwwwwwwfoffo",
    ".oo.ofwwwwfo.oo.",
    "....offwwffo....",
    "....offffffo....",
    "...ofo.oo.ofo...",
    "...ofo.ofo.ofo..",
    "...oo..ofo..oo..",
    ".......ofo......",
    "........oo......",
    "................",
]


def sway(rows, first=14):
    return rows[:first] + ["." + r[:-1] for r in rows[first:]]


ROTATED = {"held1": HELD, "held2": sway(HELD)}


EFFECTS["yarn2"] = [
    "".join(EFFECTS["yarn1"][len(EFFECTS["yarn1"]) - 1 - r][c] for r in range(len(EFFECTS["yarn1"])))
    for c in range(len(EFFECTS["yarn1"][0]))
]


# Things to wear. Hats sit on the head with their bottom row on `hat` row;
# collars go round the neck on `collar` row. Coordinates are art pixels in
# each frame, x the centre column.
ACCESSORIES = {
    "partyHat": [
        "..y..",
        "..r..",
        ".rbr.",
        ".brb.",
        "rbrbr",
        "brbrb",
    ],
    "bow": [
        "tt.tt",
        "ttktt",
        "tt.tt",
    ],
    "witchHat": [
        "....kk.",
        "...kk..",
        "..kkk..",
        "..kkk..",
        ".kkkkk.",
        ".ppppp.",
        "kkkkkkk",
    ],
    "santaHat": [
        "......w",
        "....rr.",
        "...rrr.",
        "..rrrr.",
        ".rrrrr.",
        "wwwwwww",
    ],
    "crown": [
        "y.y.y",
        "yyyyy",
        "ytylY",
    ],
    "redCollar": ["rrrrr"],
    "bellCollar": ["rrrrr", "..y.."],
}
# Rows to raise an accessory above its anchor.
ACCESSORY_LIFT = {"crown": 1, "bow": 1}
ACCESSORY_COLORS = dict(r="e8404a", b="4f86e8", y="ffd34d", Y="ffd34d", w="ffffff", k="2a2533", p="9b6bff", t="ff8fb1", l="7fd1ff")

# (hat centre x, hat bottom row, collar centre x, collar row) per frame;
# None where a collar would be hidden (eating, asleep).
ANCHORS = {
    "held1": (8.0, 2, 8.0, 7), "held2": (8.0, 2, 8.0, 7),
    "sit": (14.5, 5, 14.5, 9), "blink": (14.5, 5, 14.5, 9), "happy": (14.5, 5, 14.5, 9),
    "groom1": (14.5, 5, None, None), "groom2": (14.5, 5, None, None),
    "walk1": (16.5, 5, 15.5, 8), "walk2": (16.5, 5, 15.5, 8), "walk3": (16.5, 5, 15.5, 8),
    "run1": (16.5, 4, 15.5, 7), "run2": (16.5, 5, 15.5, 8),
    "crouch1": (16.5, 7, 15.5, 10), "crouch2": (16.5, 7, 15.5, 10),
    "eat1": (17, 11, None, None), "eat2": (17, 10, None, None),
    "sleep1": (13.5, 9, None, None), "sleep2": (13.5, 10, None, None),
}


def check():
    for name, rows in FRAMES.items():
        assert len(rows) == H, (name, len(rows))
        for i, r in enumerate(rows):
            assert len(r) == W, (name, i, len(r), r)
            assert set(r) <= set(".ofswpe"), (name, i, r)
    FRAMES.update(ROTATED)


def png(path, width, height, pixels):
    raw = b"".join(b"\x00" + bytes(pixels[y * width * 4:(y + 1) * width * 4]) for y in range(height))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(data)


def preview(path, scale=6):
    names = list(FRAMES)
    coats = list(COATS)
    side = max(W, H) + 2
    cw, ch = side * scale, side * scale
    width, height = cw * len(names), ch * len(coats)
    px = bytearray([40, 44, 52, 255] * width * height)
    for cy, coat in enumerate(coats):
        pal = COATS[coat]
        for cx, name in enumerate(names):
            for y, row in enumerate(FRAMES[name]):
                for x, c in enumerate(row):
                    if c == ".":
                        continue
                    hexc = pal[c]
                    rgb = [int(hexc[i:i + 2], 16) for i in (0, 2, 4)]
                    for dy in range(scale):
                        for dx in range(scale):
                            X = cx * cw + (x + 1) * scale + dx
                            Y = cy * ch + (y + 1) * scale + dy
                            k = (Y * width + X) * 4
                            px[k:k + 4] = bytes(rgb + [255])
    png(path, width, height, px)


def swift():
    out = ["// Generated by Tools/sprites.py. Edit the art there, then run `python3 Tools/sprites.py swift`.", "",
           "enum CatArt {", f"    static let width = {W}", f"    static let height = {H}", "",
           "    static let frames: [String: [String]] = ["]
    for name, rows in FRAMES.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    static let effects: [String: [String]] = ["]
    for name, rows in EFFECTS.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    static let effectColors: [Character: UInt32] = ["]
    out += [f'        "{k}": 0x{v},' for k, v in EFFECT_COLORS.items()]
    out += ["    ]", "", "    static let accessories: [String: [String]] = ["]
    for name, rows in ACCESSORIES.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    static let accessoryColors: [Character: UInt32] = ["]
    out += [f'        "{k}": 0x{v},' for k, v in ACCESSORY_COLORS.items()]
    out += ["    ]", "", "    static let accessoryLift: [String: Int] = ["]
    out += [f'        "{k}": {v},' for k, v in ACCESSORY_LIFT.items()]
    out += ["    ]", "", "    /// Frame: hat centre x, hat bottom row, collar centre x, collar row (-1 = none).",
            "    static let anchors: [String: (Double, Int, Double, Int)] = ["]
    for name, (hx, hy, cx, cy) in ANCHORS.items():
        out.append(f'        "{name}": ({hx}, {hy}, {cx if cx is not None else -1}, {cy if cy is not None else -1}),')
    out += ["    ]", "", "    /// Palette per coat: outline, fur, stripe, white, pink, eye.",
            "    static let coats: [String: [Character: UInt32]] = ["]
    for coat, pal in COATS.items():
        items = ", ".join(f'"{k}": 0x{v}' for k, v in pal.items())
        out.append(f'        "{coat}": [{items}],')
    out += ["    ]", "}", ""]
    dest = Path(__file__).resolve().parent.parent / "Sources/Pixpaw/CatSprites.generated.swift"
    dest.write_text("\n".join(out))
    print("wrote", dest)


def compose(frame, hat=None, collar=None, pad=8):
    """The frame as rows of (char, palette) with room above for a hat."""
    rows = [list("." * len(FRAMES[frame][0])) for _ in range(pad)] + [list(r) for r in FRAMES[frame]]
    over = [[None] * len(rows[0]) for _ in rows]
    hx, hy, cx, cy = ANCHORS[frame]
    for name, ax, ay in [(hat, hx, hy), (collar, cx, cy)]:
        if not name or ax is None:
            continue
        art = ACCESSORIES[name]
        left = int(round(ax - len(art[0]) / 2))
        top = (ay - len(art) + 1 - ACCESSORY_LIFT.get(name, 0) + pad) if name != collar else ay + pad
        for y, row in enumerate(art):
            for x, ch in enumerate(row):
                if ch != "." and 0 <= top + y < len(rows) and 0 <= left + x < len(rows[0]):
                    over[top + y][left + x] = ch
    return rows, over


def preview_accessories(path, scale=6):
    frames = ["sit", "walk1", "run1", "crouch1", "eat1", "sleep1", "held1", "held2"]
    looks = [("partyHat", "redCollar"), ("witchHat", "bellCollar"), ("santaHat", None), ("crown", "redCollar"), ("bow", "bellCollar")]
    pal = COATS["orange"]
    cell = 24
    width, height = cell * scale * len(frames), cell * scale * len(looks)
    px = bytearray([40, 44, 52, 255] * width * height)
    for ly, (hat, collar) in enumerate(looks):
        for fx, frame in enumerate(frames):
            rows, over = compose(frame, hat, collar)
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    o = over[y][x]
                    hexc = ACCESSORY_COLORS[o] if o else (pal[ch] if ch != "." else None)
                    if not hexc:
                        continue
                    rgb = [int(hexc[i:i + 2], 16) for i in (0, 2, 4)]
                    for dy in range(scale):
                        for dx in range(scale):
                            X = fx * cell * scale + (x + 1) * scale + dx
                            Y = ly * cell * scale + (y) * scale + dy
                            if X < width and Y < height:
                                k = (Y * width + X) * 4
                                px[k:k + 4] = bytes(rgb + [255])
    png(path, width, height, px)


if __name__ == "__main__":
    check()
    if sys.argv[1:2] == ["preview"]:
        preview(sys.argv[2])
    elif sys.argv[1:2] == ["wear"]:
        preview_accessories(sys.argv[2])
    elif sys.argv[1:2] == ["swift"]:
        swift()
