#!/usr/bin/env python3
"""Pixpaw sprite source.

The characters are sprite sheets in Art/ (see Art/README.md): one PNG each,
a row of frames facing right, painted in that character's palette below.
The small things drawn on top of them (effects, hats, headphones) are text
grids in this file. `python3 Tools/sprites.py preview out.png` draws every
cat frame in every coat so the art can be checked by eye;
`python3 Tools/sprites.py swift` regenerates Sources/Pixpaw/CatSprites.generated.swift.

Legend: . clear  o outline  f fur  s stripe/patch  w white  p pink  e eye
"""
import struct
import sys
import zlib
from pathlib import Path

W, H = 20, 16

ART = Path(__file__).resolve().parent.parent / "Art"
# The order of the cells in every sheet.
FRAME_ORDER = ["sit", "blink", "happy", "walk1", "walk2", "walk3", "run1", "run2", "groom1", "groom2",
               "sleep1", "sleep2", "eat1", "eat2", "crouch1", "crouch2", "held1", "held2"]
# Cells are 20 x 20 and frames sit at the bottom of them, 20 x 16; the
# cat's carried frames are seen from the front, 16 wide and the cell's height.
CELL = 20
TALL = {"cat": {"held1", "held2"}}

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
    # Loy Krathong: a krathong with its candle, and a sky lantern.
    "krathong": [
        ".....n.....",
        ".....G.....",
        "..r..G..r..",
        ".rrr.G.rrr.",
        "rrrrrrrrrrr",
        "qqqqqqqqqqq",
        ".qqqqqqqqq.",
    ],
    "skyLantern": [
        ".aaa.",
        "aAAAa",
        "aAAAa",
        "aAAAa",
        ".aaa.",
        "..n..",
    ],
    # Chinese New Year: a red lantern on its string.
    "redLantern": [
        "...d...",
        "...d...",
        "..nnn..",
        ".CCCCC.",
        "CCnCnCC",
        "CCnCnCC",
        "CCnCnCC",
        ".CCCCC.",
        "..nnn..",
        "..n.n..",
        "..n.n..",
    ],
    # Little gifts it leaves you now and then.
    "giftFlower": [
        ".rr.rr.",
        "rrnnnrr",
        ".rnnnr.",
        "rrnnnrr",
        ".rr.rr.",
        "...q...",
        "..qq...",
        "...q...",
    ],
    "giftBone": [
        "G.......GG.",
        ".G.G.G.GGGG",
        "GGGGGGGGGoG",
        ".G.G.G.GGGG",
        "G.......GG.",
    ],
    "giftBall": [
        ".oooo.",
        "obbhbo",
        "obhbbo",
        "obbbbo",
        "obbbbo",
        ".oooo.",
    ],
    "giftFeather": [
        "......qq",
        ".....qqq",
        "....qqq.",
        "...qqq..",
        "..qqq...",
        ".qqq....",
        "d.......",
    ],
    # A fish-shaped biscuit, on the bowl's canvas so it sits where a bowl would.
    "treat": [
        "............",
        "....ooo..o..",
        "...okkkooko.",
        "..okokkkkko.",
        "...okkkooko.",
        "....ooo..o..",
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
    # The laser pointer's dot: a hot centre in a red glow.
    "laser": [
        ".xxx.",
        "xRRRx",
        "xRWRx",
        "xRRRx",
        ".xxx.",
    ],
    "note": [
        "...nn.",
        "...nnn",
        "...n.n",
        "...n..",
        ".nnn..",
        "nnnn..",
        ".nn...",
    ],
    "ghost": [
        "....ooo....",
        "..ooGGGoo..",
        ".oGGGGGGGo.",
        ".oGGGGGGGo.",
        "oGGoGGGoGGo",
        "oGGoGGGoGGo",
        "oGlGGGGGlGo",
        "oGGGGoGGGGo",
        "oGGGGGGGGGo",
        "oGGGGGGGGGo",
        "oGoGGoGGoGo",
        ".o.oo.oo.o.",
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
                     y="e8577a", l="ffa3bb", q="3fc4b8", d="8b5a2b", n="ffe08a", G="f4f4ff",
                     R="f0141e", x="ff7a7a", W="fff0f0", a="ff9a3c", A="ffd27a", C="e0242e")


def rotate_ccw(rows):
    """Head (right side) ends up on top: for climbing up a wall."""
    h, w = len(rows), len(rows[0])
    return ["".join(rows[r][w - 1 - y] for r in range(h)) for y in range(w)]


def rotate_cw(rows):
    """Head ends up at the bottom: for climbing down."""
    h, w = len(rows), len(rows[0])
    return ["".join(rows[h - 1 - r][y] for r in range(h)) for y in range(w)]


# Dizzy: three little stars circling over the head, a step further round in
# each frame.
def _orbit(turn):
    import math
    rows = [["." for _ in range(13)] for _ in range(7)]
    for k in range(3):
        a = math.radians(turn + k * 120)
        x, y = round(6 + 5 * math.cos(a)), round(3 + 2 * math.sin(a))
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < 13 and 0 <= y + dy < 7:
                rows[y + dy][x + dx] = "n"
    return ["".join(r) for r in rows]


for _i, _turn in enumerate((0, 40, 80)):
    EFFECTS[f"dizzy{_i + 1}"] = _orbit(_turn)

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
    # Worn by itself late at night (not one to unlock): a floppy cap whose
    # tip droops over to one side, with a pompom.
    "nightcap": [
        "..bbbb...",
        ".bbbbbbb.",
        ".bbybbbbb",
        ".bbbbb.bw",
        "wwwwwww..",
    ],
    "crown": [
        "y.y.y",
        "yyyyy",
        "ytylY",
    ],
    "redCollar": ["rrrrr"],
    "bellCollar": ["rrrrr", "..y.."],
}
# Headphones, worn while a pair is connected: a band over the head and a cup
# each side, from the front; one cup and the band edge-on, from the side.
HEADPHONES = {
    "front": [
        "..bbbbbbb..",
        ".b.......b.",
        "b.........b",
        "b.........b",
        "bb.......bb",
        "bb.......bb",
        "bb.......bb",
    ],
    "side": [
        ".bbbbb.",
        "b.....b",
        "b.....b",
        "bbb....",
        "bbb....",
        "bbb....",
    ],
    # Over a small head seen from the front: the conure picked up.
    "small": [
        ".bbbbbbb.",
        "b.......b",
        "bb.....bb",
        "bb.....bb",
        "bb.....bb",
    ],
    "bee": [
        ".bbbb.",
        "b....b",
        "bb...b",
        "bb....",
        "bb....",
    ],
    "held": [
        "...bbbbbbbbbb...",
        "..b..........b..",
        ".b............b.",
        "b..............b",
        "bb............bb",
        "bb............bb",
        "bb............bb",
    ],
}
# Frame: (view, left column, top row); top may be above the art. Frames not
# listed (asleep, eating) tuck the head away and show none.
HEADPHONES_AT = {
    **{f: ("front", 9, 2) for f in ("sit", "blink", "happy", "groom1", "groom2")},
    **{f: ("side", 13, 2) for f in ("walk1", "walk2", "walk3", "run2")},
    "run1": ("side", 13, 1), "crouch1": ("side", 13, 4), "crouch2": ("side", 13, 4),
    "held1": ("held", 0, -1), "held2": ("held", 0, -1),
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


# Other characters, picked instead of the cat. Same canvas and frame names,
# so the cat's moods drive them unchanged.
# Palette per character, in the coat letters plus l for a wing's shine.
KIND_COLORS = {
    "bee": dict(o="2a1d16", f="ffcf3a", s="2f2733", w="d9f0ff", l="ffffff", e="1d140c", p="ff8fa3"),
    # An orange-fronted conure: G body, D wing, H head, C crown, P the orange
    # patch over the beak, E the pale ring round the eye, K the eye, W the
    # beak, T the olive throat, L the yellow-green belly, B the blue flight
    # feathers, O the tail, F the feet.
    "parrot": dict(o="16201a", G="5aa838", D="2f7d2c", H="3b8540", C="2f7a62", P="f26a3d", E="f1e9a6", K="16161a",
                   W="ead9c8", T="7c8a3a", L="bccf3a", B="2b4a8c", O="4f9a30", F="8f8a86"),
    "dino": dict(o="1d2b1a", f="6cc24a", s="4a9a33", w="d8f0a0", p="ffa53c", e="111111"),
    "dog": dict(o="2b1a10", f="e0a35a", s="8a5a2b", w="fff3dd", p="ff7f9a", e="1a1110"),
    "hamster": dict(o="3a2414", f="f2a65a", s="d4823a", w="fff6ea", p="ff9fb2", e="1a1110"),
    "chicken": dict(o="3a2a20", f="fbf7f0", s="ddd5c8", w="fff1c4", p="e8432c", e="111111", b="f5a623"),
}


def read_png(path):
    """Width, height and RGBA rows of an 8-bit PNG: true colour, with or
    without alpha, or indexed, as pixel editors save them."""
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: not a PNG"
    pos, idat, palette, alpha = 8, b"", [], b""
    while pos < len(data):
        size, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + size]
        pos += 12 + size
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and colour in (2, 3, 6) and not interlace, \
                f"{path}: save it as an 8-bit PNG (RGB, RGBA or indexed), not interlaced"
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            alpha = body
        elif kind == b"IDAT":
            idat += body
    step = {2: 3, 3: 1, 6: 4}[colour]
    raw, stride, rows, prev = zlib.decompress(idat), width * step, [], bytearray(width * step)
    for y in range(height):
        kind, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - step] if i >= step else 0
            b, c = prev[i], prev[i - step] if i >= step else 0
            if kind == 1: line[i] = (line[i] + a) & 255
            elif kind == 2: line[i] = (line[i] + b) & 255
            elif kind == 3: line[i] = (line[i] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        if colour == 3:
            rows.append([palette[i] + ((alpha[i] if i < len(alpha) else 255),) for i in line])
        else:
            rows.append([tuple(line[x * step:x * step + 3]) + ((line[x * step + 3],) if step == 4 else (255,))
                         for x in range(width)])
    return width, height, rows


def load_sheet(kind, palette):
    """A character's frames from Art/<kind>.png, as letter grids: each
    colour is matched back to its letter in the palette."""
    path = ART / f"{kind}.png"
    width, height, pixels = read_png(path)
    assert (width, height) == (CELL * len(FRAME_ORDER), CELL), \
        f"{path}: should be {CELL * len(FRAME_ORDER)} x {CELL} ({len(FRAME_ORDER)} cells of {CELL} x {CELL}), is {width} x {height}"
    letters = {tuple(int(hexc[i:i + 2], 16) for i in (0, 2, 4)): letter for letter, hexc in palette.items()}
    frames = {}
    for n, name in enumerate(FRAME_ORDER):
        w, h = (16, CELL) if name in TALL.get(kind, ()) else (W, H)
        rows = []
        for y in range(CELL):
            row = ""
            for x in range(CELL):
                r, g, b, a = pixels[y][n * CELL + x]
                if a < 128:
                    row += "."
                    continue
                inside = y >= CELL - h and x < w
                assert inside, f"{path}: {name} has a pixel at ({x}, {y}) of its cell, outside its {w} x {h} frame"
                assert (r, g, b) in letters, \
                    f"{path}: {name} has #{r:02x}{g:02x}{b:02x} at ({x}, {y}) of its cell; use a colour from its palette"
                row += letters[(r, g, b)]
            rows.append(row[:w])
        frames[name] = rows[CELL - h:]
    return frames


# The cat is painted in the orange coat; every coat shares its letters.
FRAMES = load_sheet("cat", COATS["orange"])
KINDS = {kind: load_sheet(kind, KIND_COLORS[kind]) for kind in KIND_COLORS}
BEE_FRAMES, PARROT_FRAMES, DINO_FRAMES, DOG_FRAMES, HAMSTER_FRAMES, CHICKEN_FRAMES = (
    KINDS[k] for k in ("bee", "parrot", "dino", "dog", "hamster", "chicken"))

# Hat anchors (no collar: a bee has no neck) and headphones, per frame.
def _bee_dy(frame):
    return 1 if frame.startswith(("sleep", "eat", "crouch")) else 0
# Where the conure's head is: its crown, or the orange patch where it faces
# you. A hat sits on the top row of it; headphones go over it from two rows
# higher, a cup behind the eye, or round its face when it is picked up.
def _parrot_head(frame):
    rows = PARROT_FRAMES[frame]
    top = min(y for y, row in enumerate(rows) if "C" in row or "P" in row)
    xs = [x for x, ch in enumerate(rows[top]) if ch in "CP"]
    return sum(xs) / len(xs) + 0.5, top
# How far down the dinosaur's and the dog's frames carry the head.
_HEAD_DROP = {"groom1": 1, "groom2": 1, "sleep1": 5, "sleep2": 5, "eat1": 4, "eat2": 4, "crouch1": 1, "crouch2": 1}
def _dino_head(frame):
    return _HEAD_DROP.get(frame, 0)
_dog_head = _dino_head
def _hamster_top(frame):
    """The row the ears start on, from the art itself."""
    return next(y for y, row in enumerate(HAMSTER_FRAMES[frame]) if row.strip("."))
def _chicken_comb(frame):
    """Where the comb is: its middle column and its top row, from the art."""
    rows = CHICKEN_FRAMES[frame]
    y = next(y for y, row in enumerate(rows) if "p" in row)
    return rows[y].index("p"), y
KIND_ANCHORS = {
    "bee": {f: (14.5, 6 + _bee_dy(f), None, None) for f in BEE_FRAMES},
    "parrot": {f: (*_parrot_head(f), None, None) for f in PARROT_FRAMES},
    "dino": {f: (15.5, 2 + _dino_head(f), None, None) for f in DINO_FRAMES},
    "dog": {f: (14.5, 2 + _dog_head(f), None, None) for f in DOG_FRAMES},
    "hamster": {f: (13.0, _hamster_top(f), None, None) for f in HAMSTER_FRAMES},
    "chicken": {f: (_chicken_comb(f)[0] + 0.5, _chicken_comb(f)[1] + 1, None, None) for f in CHICKEN_FRAMES},
}
KIND_HEADPHONES_AT = {
    "bee": {f: ("bee", 11, 4 + _bee_dy(f)) for f in BEE_FRAMES if not f.startswith("sleep")},
    # None while its head is down in the bowl, as for the cat.
    "parrot": {f: ("small" if f.startswith("held") else "side", round(_parrot_head(f)[0] - 4.5), _parrot_head(f)[1] - 2)
               for f in PARROT_FRAMES if not f.startswith(("sleep", "eat"))},
    "dino": {f: ("side", 12, 1 + _dino_head(f)) for f in DINO_FRAMES if not f.startswith("sleep")},
    "dog": {f: ("side", 11, 1 + _dog_head(f)) for f in DOG_FRAMES if not f.startswith("sleep")},
    "hamster": {f: ("side", 10, _hamster_top(f)) for f in HAMSTER_FRAMES if not f.startswith("sleep")},
    "chicken": {f: ("side", _chicken_comb(f)[0] - 3, _chicken_comb(f)[1]) for f in CHICKEN_FRAMES if not f.startswith("sleep")},
}


def check():
    # Every coat has to be able to paint the cat.
    for name, rows in FRAMES.items():
        for i, r in enumerate(rows):
            assert set(r) <= set(".ofswpe"), (name, i, r)


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
    # Other characters' frames, as "<kind>.<frame>".
    for kind, frames in KINDS.items():
        for name, rows in frames.items():
            out.append(f'        "{kind}.{name}": [')
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
    out += ["    ]", "", "    static let headphones: [String: [String]] = ["]
    for name, rows in HEADPHONES.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    /// Frame: headphones view, left column, top row.",
            "    static let headphonesAt: [String: (String, Int, Int)] = ["]
    for name, (view, left, top) in HEADPHONES_AT.items():
        out.append(f'        "{name}": ("{view}", {left}, {top}),')
    for kind, spots in KIND_HEADPHONES_AT.items():
        for name, (view, left, top) in spots.items():
            out.append(f'        "{kind}.{name}": ("{view}", {left}, {top}),')
    out += ["    ]", "", "    /// Frame: hat centre x, hat bottom row, collar centre x, collar row (-1 = none).",
            "    static let anchors: [String: (Double, Int, Double, Int)] = ["]
    for name, (hx, hy, cx, cy) in ANCHORS.items():
        out.append(f'        "{name}": ({hx}, {hy}, {cx if cx is not None else -1}, {cy if cy is not None else -1}),')
    for kind, anchors in KIND_ANCHORS.items():
        for name, (hx, hy, cx, cy) in anchors.items():
            out.append(f'        "{kind}.{name}": ({hx}, {hy}, {cx if cx is not None else -1}, {cy if cy is not None else -1}),')
    out += ["    ]", "", "    /// Palette per coat: outline, fur, stripe, white, pink, eye.",
            "    static let coats: [String: [Character: UInt32]] = ["]
    for coat, pal in list(COATS.items()) + list(KIND_COLORS.items()):
        items = ", ".join(f'"{k}": 0x{v}' for k, v in pal.items())
        out.append(f'        "{coat}": [{items}],')
    out += ["    ]", "}", ""]
    dest = Path(__file__).resolve().parent.parent / "Sources/Pixpaw/CatSprites.generated.swift"
    dest.write_text("\n".join(out))
    print("wrote", dest)


def compose(frame, hat=None, collar=None, pad=8, headphones=False, kind=None):
    """The frame as rows of (char, palette) with room above for a hat.
    Headphones take the hat's place."""
    art = KINDS[kind][frame] if kind else FRAMES[frame]
    anchors = KIND_ANCHORS[kind] if kind else ANCHORS
    spots = KIND_HEADPHONES_AT[kind] if kind else HEADPHONES_AT
    rows = [list("." * len(art[0])) for _ in range(pad)] + [list(r) for r in art]
    over = [[None] * len(rows[0]) for _ in rows]
    if headphones:
        hat = None
    if headphones and frame in spots:
        view, left, top = spots[frame]
        for y, row in enumerate(HEADPHONES[view]):
            for x, ch in enumerate(row):
                if ch != "." and 0 <= top + pad + y < len(rows) and 0 <= left + x < len(rows[0]):
                    over[top + pad + y][left + x] = ch
    hx, hy, cx, cy = anchors[frame]
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
    looks = [("partyHat", "redCollar"), ("witchHat", "bellCollar"), ("santaHat", None), ("crown", "redCollar"), ("bow", "bellCollar"),
             (None, None, True), ("crown", "bellCollar", True), ("nightcap", None)]
    pal = COATS["orange"]
    cell = 24
    width, height = cell * scale * len(frames), cell * scale * len(looks)
    px = bytearray([40, 44, 52, 255] * width * height)
    for ly, (hat, collar, *phones) in enumerate(looks):
        for fx, frame in enumerate(frames):
            rows, over = compose(frame, hat, collar, headphones=bool(phones))
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
