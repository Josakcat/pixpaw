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
                     y="e8577a", l="ffa3bb", q="3fc4b8", d="8b5a2b", n="ffe08a", G="f4f4ff")


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


# Other characters, picked instead of the cat. Same 20 x 16 canvas and frame
# names, so the cat's moods drive them unchanged. Drawn from shapes rather
# than typed, so outlines stay even.
def _blank():
    return [["." for _ in range(W)] for _ in range(H)]


def inside_ellipse(x, y, cx, cy, rx, ry):
    return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1

def blob(g, cx, cy, rx, ry, fill, outline="o", paint=None):
    """Fill an ellipse; its edge pixels become outline."""
    pts = {(x, y) for y in range(H) for x in range(W) if inside_ellipse(x, y, cx, cy, rx, ry)}
    for (x, y) in pts:
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
        g[y][x] = outline if edge else (paint(x, y) if paint else fill)
    return pts

def bee(wings="up", eyes="open", dy=0, legs=False, antenna_up=True):
    """A round chibi bee: one body, the face on its right, wings on top."""
    g = _blank()
    cy = 10.2 + dy
    def wing(cx, wy, rx, ry, shine):
        blob(g, cx, wy, rx, ry, "w", paint=lambda x, y: "l" if (x, y) == shine else "w")
    if wings == "up":
        wing(7.6, 4.2 + dy, 2.7, 2.9, (6, int(3 + dy)))
        wing(11.0, 3.6 + dy, 2.7, 3.0, (10, int(2 + dy)))
    elif wings == "down":
        wing(5.6, 6.4 + dy, 3.4, 2.0, (4, int(6 + dy)))
        wing(9.6, 5.6 + dy, 3.0, 2.0, (9, int(5 + dy)))
    elif wings == "folded":
        wing(8.6, 6.6 + dy, 4.4, 1.6, (6, int(6 + dy)))
    # Antennae: a stalk and a knob, leaning forward.
    top = int(cy - 4.6)
    stalks = [(13, 14, 15), (15, 16, 17)] if antenna_up else [(14, 15, 16), (16, 17, 18)]
    for xs in stalks:
        for k, x in enumerate(xs[:-1]):
            y = top - k
            if 0 <= y < H and g[y][x] == ".": g[y][x] = "o"
        y = top - len(xs) + 1
        if 0 <= y < H: g[y][xs[-1]] = "s"
    # The body: stripes on the back half, the face clear.
    blob(g, 10.0, cy, 7.4, 5.0, "f", paint=lambda x, y: "s" if x in (6, 7, 10) else "f")
    # Stinger.
    sy = int(cy + 0.5)
    g[sy][1] = "o"; g[sy][2] = "o"
    ey = int(cy - 1)
    if eyes == "open":
        g[ey][14] = "e"; g[ey + 1][14] = "e"
    elif eyes == "closed":
        g[ey + 1][13] = "e"; g[ey + 1][14] = "e"
    elif eyes == "happy":
        g[ey][14] = "e"; g[ey + 1][13] = "e"; g[ey + 1][15] = "e"
    g[ey + 2][15] = "p"
    if legs:
        for x in (8, 11, 13):
            y = int(cy + 5)
            if y < H: g[y][x] = "o"
    return ["".join(r) for r in g]

BEE_FRAMES = {
    "sit": bee("up"), "blink": bee("up", "closed"), "happy": bee("up", "happy"),
    "walk1": bee("up"), "walk2": bee("down"), "walk3": bee("up"),
    "run1": bee("down"), "run2": bee("up"),
    "groom1": bee("up", legs=True), "groom2": bee("down", legs=True),
    "sleep1": bee("folded", "closed", dy=1), "sleep2": bee("folded", "closed", dy=1, antenna_up=False),
    "eat1": bee("down", dy=1), "eat2": bee("up", dy=1),
    "crouch1": bee("down", dy=1), "crouch2": bee("up", dy=1),
    "held1": bee("up", "happy", legs=True), "held2": bee("down", "happy", legs=True),
}

# The parrot: perched upright, and level in flight for every moving frame.
def put(g, x, y, ch):
    if 0 <= x < W and 0 <= y < H: g[y][x] = ch

def line(g, x0, y0, x1, y1, ch):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        put(g, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), ch)

def beak(g, x, y):
    """A hooked beak, its top-left at (x, y): solid orange, the hook dark."""
    put(g, x, y, "b"); put(g, x + 1, y, "b"); put(g, x + 2, y, "o")
    put(g, x, y + 1, "b"); put(g, x + 1, y + 1, "b"); put(g, x + 2, y + 1, "b")
    put(g, x + 1, y + 2, "b"); put(g, x + 2, y + 2, "o")
    put(g, x + 1, y + 3, "o")

def perched(eyes="open", dy=0, wing="down", head_dy=0, beak_open=False):
    g = _blank()
    # Long tail, down and back to the left.
    line(g, 9, 12 + dy, 4, 15, "o"); line(g, 10, 12 + dy, 5, 15, "t"); line(g, 10, 13 + dy, 6, 15, "o")
    line(g, 9, 13 + dy, 5, 15, "t")
    # Body: a plump upright egg, belly lighter on the right.
    blob(g, 12.4, 9.8 + dy, 3.9, 4.4, "f", paint=lambda x, y: "w" if x >= 13 and y >= 9 + dy else "f")
    # Wing folded on its side, or lifted.
    if wing == "down":
        blob(g, 10.9, 10.2 + dy, 2.0, 3.0, "s")
    else:
        blob(g, 9.2, 7.6 + dy, 3.0, 2.0, "s")
    # Head with a red face.
    hy = 4.4 + dy + head_dy
    blob(g, 13.8, hy, 3.2, 3.0, "f", paint=lambda x, y: "p" if x >= 14 and y >= int(hy) - 1 else "f")
    ey = int(hy) - 1
    if eyes == "open": put(g, 14, ey, "e")
    elif eyes == "closed": put(g, 14, ey, "o"); put(g, 15, ey, "o")
    elif eyes == "happy": put(g, 14, ey, "e"); put(g, 15, ey - 1, "e")
    beak(g, 16, int(hy) - 1)
    if beak_open: put(g, 16, int(hy) + 1, ".")
    # Feet on the floor.
    fy = min(15, 14 + dy)
    for x in (11, 12, 14, 15): put(g, x, fy, "g")
    return ["".join(r) for r in g]

def flying(wings="up", eyes="open"):
    g = _blank()
    # Tail streaming back.
    line(g, 6, 9, 0, 11, "o"); line(g, 6, 10, 1, 12, "t"); line(g, 6, 11, 1, 13, "o")
    # Body, level and plump.
    blob(g, 10.0, 10.2, 5.2, 2.9, "f", paint=lambda x, y: "w" if y >= 11 and x >= 9 else "f")
    # Head with the red face, and the beak.
    blob(g, 15.2, 8.6, 2.9, 2.8, "f", paint=lambda x, y: "p" if x >= 15 and y >= 8 else "f")
    if eyes == "open": put(g, 15, 7, "e")
    else: put(g, 15, 7, "e"); put(g, 16, 6, "e")
    beak(g, 17, 7)
    # Wings: up, level, down.
    if wings == "up":
        blob(g, 9.0, 6.0, 4.0, 2.6, "s")
    elif wings == "mid":
        blob(g, 8.4, 8.6, 4.6, 1.6, "s")
    else:
        blob(g, 9.0, 13.4, 3.8, 2.2, "s")
    return ["".join(r) for r in g]

PARROT_FRAMES = {
    "sit": perched(), "blink": perched("closed"), "happy": perched("happy", wing="up"),
    "walk1": flying("up"), "walk2": flying("mid"), "walk3": flying("down"),
    "run1": flying("up"), "run2": flying("down"),
    "groom1": perched(head_dy=1), "groom2": perched(head_dy=1, wing="up"),
    "sleep1": perched("closed", dy=1, head_dy=1), "sleep2": perched("closed", dy=1, head_dy=2),
    "eat1": perched(dy=1, head_dy=3), "eat2": perched(dy=1, head_dy=2, beak_open=True),
    "crouch1": perched(dy=1), "crouch2": perched(dy=1, wing="up"),
    "held1": perched("happy", wing="up"), "held2": perched("happy"),
}

# The dinosaur: a little T-rex with spikes on its back, walking like the cat.
def dino(legs="stand", eyes="open", mouth="closed", dy=0, head_dy=0, head_dx=0, tail_up=0):
    g = _blank()
    # Tail, tapering back to the left (drawn first, under the body).
    # Tapers: a thick root, a thin tip curling up a little.
    blob(g, 5.8, 10.9 + dy - tail_up * 0.5, 3.4, 2.5, "f")
    blob(g, 2.8, 10.2 + dy - tail_up, 2.9, 1.7, "f")
    put(g, 0, int(9.2 + dy - tail_up * 1.5), "o")
    # Legs under the body: stout, two of them in view.
    feet = {"stand": [(6, 0), (11, 0)], "a": [(5, 0), (12, -1)], "b": [(7, -1), (10, 0)],
            "run": [(4, -1), (13, -1)], "tuck": []}[legs]
    for x, lift in feet:
        top = int(12 + dy)
        for y in range(top, 16 + lift):
            put(g, x, y, "o"); put(g, x + 1, y, "f"); put(g, x + 2, y, "f"); put(g, x + 3, y, "o")
        for k in range(4): put(g, x + k, 15 + lift, "o")
    # Body, belly lighter underneath.
    blob(g, 9.6, 10.2 + dy, 4.8, 3.4, "f", paint=lambda x, y: "w" if y >= 11 + dy and x >= 8 else "f")
    # Back spikes, standing on the outline of the back.
    for x in (6, 8, 10):
        top = next((y for y in range(H) if g[y][x] != "."), None)
        if top is not None:
            put(g, x, top, "p"); put(g, x, top - 1, "p")
    # Neck and big round head, facing right.
    blob(g, 13.0, 7.8 + dy + head_dy * 0.5, 2.2, 2.6, "f")
    hx, hy = 15.6 + head_dx, 5.2 + dy + head_dy
    blob(g, hx, hy, 3.8, 3.0, "f", paint=lambda x, y: "w" if y >= int(hy) + 1 and x >= int(hx) - 1 else "f")
    put(g, int(hx) - 2, int(hy - 3.0), "p")  # a spike on the head
    ex, ey = int(hx), int(hy) - 1
    if eyes == "open": put(g, ex, ey, "e"); put(g, ex, ey - 1, "e")
    elif eyes == "closed": put(g, ex, ey, "o"); put(g, ex + 1, ey, "o")
    elif eyes == "happy": put(g, ex, ey - 1, "e"); put(g, ex - 1, ey, "e"); put(g, ex + 1, ey, "e")
    # Mouth along the snout; a nostril.
    my = int(hy) + 1
    if mouth == "open":
        for x in range(ex + 1, ex + 4): put(g, x, my, "o"); put(g, x, my + 1, "p")
    else:
        for x in range(ex + 1, ex + 4): put(g, x, my, "o")
    put(g, int(hx + 3), ey, "o")
    # A tiny arm.
    put(g, 13, int(10 + dy), "o"); put(g, 14, int(10 + dy), "f"); put(g, 14, int(11 + dy), "o")
    return ["".join(r) for r in g]

DINO_POSES = {
    "sit": dict(), "blink": dict(eyes="closed"), "happy": dict(eyes="happy", mouth="open"),
    "walk1": dict(legs="a"), "walk2": dict(legs="stand", dy=-0.4), "walk3": dict(legs="b"),
    "run1": dict(legs="run", dy=0.4), "run2": dict(legs="stand", dy=-0.4, tail_up=1),
    "groom1": dict(head_dy=1, eyes="closed"), "groom2": dict(head_dy=1, eyes="closed", tail_up=1),
    "sleep1": dict(legs="tuck", eyes="closed", dy=2.2, head_dy=2.6), "sleep2": dict(legs="tuck", eyes="closed", dy=2.4, head_dy=2.6),
    "eat1": dict(head_dy=4, head_dx=0.6), "eat2": dict(head_dy=4, head_dx=0.6, mouth="open"),
    "crouch1": dict(legs="stand", dy=1), "crouch2": dict(legs="stand", dy=1, tail_up=1),
    "held1": dict(legs="stand", eyes="happy", mouth="open"), "held2": dict(legs="b", eyes="happy", mouth="open", tail_up=1),
}
DINO_FRAMES = {name: dino(**pose) for name, pose in DINO_POSES.items()}

def _dino_head(frame):
    """How far down a frame carries the head, in whole rows."""
    pose = DINO_POSES[frame]
    return round(pose.get("dy", 0) + pose.get("head_dy", 0))

# The dog: a beagle puppy, body, head and muzzle drawn as one shape so no
# outline cuts across it, with a floppy ear and a wagging tail.
def shape(g, parts, paint):
    """Fill a union of ellipses (cx, cy, rx, ry); only its outer edge is outline."""
    pts = set()
    for cx, cy, rx, ry in parts:
        pts |= {(x, y) for y in range(H) for x in range(W) if inside_ellipse(x, y, cx, cy, rx, ry)}
    for (x, y) in pts:
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
        g[y][x] = "o" if edge else paint(x, y)
    return pts

def patch(g, cx, cy, rx, ry, fill):
    """Paint an ellipse over what is there; outline only where it meets empty space."""
    pts = {(x, y) for y in range(H) for x in range(W) if inside_ellipse(x, y, cx, cy, rx, ry)}
    def empty(x, y):
        return not (0 <= x < W and 0 <= y < H) or ((x, y) not in pts and g[y][x] == ".")
    for (x, y) in pts:
        g[y][x] = "o" if any(empty(x + dx, y + dy) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))) else fill

def dog(legs="stand", eyes="open", mouth="closed", dy=0, head_dy=0, head_dx=0, tail="up", ear=0):
    g = _blank()
    # Tail first, under the body: up and curling forward, or wagging over.
    ty = int(9 + dy)
    tip = {"up": [(3, -1), (2, -2), (2, -3), (3, -4)], "wag": [(3, -1), (2, -2), (1, -3), (1, -4)],
           "down": [(3, 0), (2, 1), (1, 2)], "tuck": [(3, 0), (2, 1)]}[tail]
    for x, up in tip:
        put(g, x, ty + up, "o"); put(g, x + 1, ty + up, "f"); put(g, x + 2, ty + up, "o")
    # Legs: back pair on the left, front pair on the right, short and stout, white socks.
    feet = {"stand": [(5, 0), (11, 0)], "a": [(4, 0), (12, -1)], "b": [(6, -1), (10, 0)],
            "run": [(3, -1), (13, -1)], "tuck": []}[legs]
    for x, lift in feet:
        for y in range(int(11 + dy), 15 + lift):
            put(g, x, y, "o"); put(g, x + 1, y, "f"); put(g, x + 2, y, "f"); put(g, x + 3, y, "o")
        put(g, x + 1, 14 + lift, "w"); put(g, x + 2, 14 + lift, "w")
        for k in range(4): put(g, x + k, 15 + lift, "o")
    # Body, neck, head and muzzle; pale muzzle, chest and belly, a patch on the back.
    hx, hy = 14.2 + head_dx, 5.6 + dy + head_dy
    def paint(x, y):
        if x >= hx + 1.4 and y >= hy: return "w"
        if y > hy + 2 and x >= 11: return "w"
        if y >= 11.5 + dy and 6 <= x <= 12: return "w"
        if y <= 8.2 + dy and 6 <= x <= 9: return "s"
        return "f"
    shape(g, [(8.4, 10.0 + dy, 4.8, 3.0), (12.2, 8.4 + dy + head_dy * 0.5, 2.0, 2.4),
              (hx, hy, 3.5, 3.2), (hx + 3.0, hy + 1.3, 2.2, 1.6)], paint)
    put(g, int(hx + 4.6), int(hy + 0.4), "e")  # nose
    patch(g, hx - 1.6, hy + 0.6 + ear * 0.4, 1.25, 2.6 - ear * 0.5, "s")  # the ear, blown back when running
    ex, ey = int(hx) + 1, int(hy) - 1
    if eyes == "open": put(g, ex, ey, "e"); put(g, ex, ey + 1, "e")
    elif eyes == "closed": put(g, ex, ey + 1, "o"); put(g, ex + 1, ey + 1, "o")
    elif eyes == "happy": put(g, ex, ey, "e"); put(g, ex - 1, ey + 1, "e"); put(g, ex + 1, ey + 1, "e")
    if mouth == "open":  # tongue out
        my = int(hy + 2.4)
        put(g, int(hx + 2), my, "o"); put(g, int(hx + 3), my, "o")
        put(g, int(hx + 2), my + 1, "p"); put(g, int(hx + 3), my + 1, "p")
    return ["".join(r) for r in g]

DOG_POSES = {
    "sit": dict(), "blink": dict(eyes="closed"), "happy": dict(eyes="happy", mouth="open", tail="wag"),
    "walk1": dict(legs="a"), "walk2": dict(legs="stand", dy=-0.4, tail="wag"), "walk3": dict(legs="b"),
    "run1": dict(legs="run", dy=0.4, ear=1, mouth="open"), "run2": dict(legs="stand", dy=-0.4, tail="wag", mouth="open"),
    "groom1": dict(head_dy=1, eyes="closed"), "groom2": dict(head_dy=1, eyes="closed", tail="wag"),
    "sleep1": dict(legs="tuck", eyes="closed", dy=2.4, head_dy=2.2, tail="tuck"),
    "sleep2": dict(legs="tuck", eyes="closed", dy=2.6, head_dy=2.2, tail="tuck"),
    "eat1": dict(head_dy=4, head_dx=0.4), "eat2": dict(head_dy=4, head_dx=0.4, mouth="open", tail="wag"),
    "crouch1": dict(dy=1, tail="down"), "crouch2": dict(dy=1, tail="wag"),
    "held1": dict(eyes="happy", mouth="open", tail="wag"), "held2": dict(legs="b", eyes="happy", mouth="open"),
}
DOG_FRAMES = {name: dog(**pose) for name, pose in DOG_POSES.items()}

def _dog_head(frame):
    pose = DOG_POSES[frame]
    return round(pose.get("dy", 0) + pose.get("head_dy", 0))

# The hamster: a round golden ball with a big head, pink ears and feet,
# white cheeks that stuff out while it eats.
def hamster(feet="stand", eyes="open", dy=0, head_dy=0, cheeks=False, paws=False, curl=False, ears_back=False):
    g = _blank()
    # One round shape: body and a big head; golden on top, white below.
    hx, hy = 13.0, 8.6 + dy + head_dy
    body = (8.8, 11.0 + dy, 5.6, 3.6)
    if curl:
        hx, hy = 12.4, 10.2 + dy
        body = (9.2, 11.8 + dy, 6.0, 3.0)
    parts = [body, (hx, hy, 3.9, 3.6)]
    if cheeks: parts.append((hx + 0.6, hy + 2.3, 3.2, 2.3))  # stuffed cheeks
    def paint(x, y):
        if y >= hy + 0.4 and x >= hx - 1.2: return "w"   # cheek, muzzle and chin
        if y >= body[1] + 1.4: return "w"                # belly
        if y <= body[1] - 2.2 and 5 <= x <= 8: return "s"  # a darker saddle on the back
        return "f"
    shape(g, parts, paint)
    # Round ears on top of the head, pink inside.
    top = next(y for y in range(H) if g[y][int(hx)] != ".")
    for x in ((int(hx) - 2, int(hx) + 1) if not ears_back else (int(hx) - 3, int(hx))):
        put(g, x, top - 1, "o"); put(g, x + 1, top - 1, "o")
        put(g, x - 1, top, "o"); put(g, x, top, "p"); put(g, x + 1, top, "p"); put(g, x + 2, top, "o")
    # Little pink feet peeking out underneath.
    spots = {"stand": [(5, 0), (11, 0)], "a": [(4, 0), (12, -1)], "b": [(6, -1), (10, 0)],
             "run": [(3, -1), (13, -1)], "tuck": []}[feet]
    for x, lift in spots:
        base = int(body[1] + body[3]) + lift
        put(g, x, base, "o"); put(g, x + 1, base, "p"); put(g, x + 2, base, "p"); put(g, x + 3, base, "o")
        put(g, x + 1, base + 1, "o"); put(g, x + 2, base + 1, "o")
    # Eye, nose, blush.
    ex, ey = int(hx + 1), int(hy - 1)
    if eyes == "open": put(g, ex, ey, "e"); put(g, ex, ey + 1, "e")
    elif eyes == "closed": put(g, ex, ey + 1, "o"); put(g, ex + 1, ey + 1, "o")
    elif eyes == "happy": put(g, ex, ey, "e"); put(g, ex - 1, ey + 1, "e"); put(g, ex + 1, ey + 1, "e")
    ny = int(hy + 0.6)
    nx = max(x for x in range(W) if g[ny][x] != ".")
    put(g, nx, ny, "p")
    put(g, ex - 1, ey + 2, "p")
    if paws:  # tiny paws held up under the chin
        put(g, int(hx + 1), int(hy + 2.6), "p"); put(g, int(hx + 2), int(hy + 2.6), "p")
    return ["".join(r) for r in g]

HAMSTER_POSES = {
    "sit": dict(), "blink": dict(eyes="closed"), "happy": dict(eyes="happy", paws=True),
    "walk1": dict(feet="a"), "walk2": dict(feet="stand", dy=-0.4), "walk3": dict(feet="b"),
    "run1": dict(feet="run", dy=0.3, ears_back=True), "run2": dict(feet="stand", dy=-0.5, ears_back=True),
    "groom1": dict(eyes="closed", paws=True), "groom2": dict(eyes="closed", paws=True, head_dy=0.6),
    "sleep1": dict(feet="tuck", eyes="closed", curl=True, dy=0.6), "sleep2": dict(feet="tuck", eyes="closed", curl=True, dy=0.9),
    "eat1": dict(cheeks=True, head_dy=0.6), "eat2": dict(cheeks=True, eyes="happy", head_dy=0.6, paws=True),
    "crouch1": dict(dy=0.8, ears_back=True), "crouch2": dict(dy=0.8, ears_back=True, feet="b"),
    "held1": dict(eyes="happy", paws=True), "held2": dict(eyes="happy", paws=True, feet="b"),
}
HAMSTER_FRAMES = {name: hamster(**pose) for name, pose in HAMSTER_POSES.items()}

def _hamster_top(frame):
    """The row the ears start on, from the art itself."""
    return next(y for y, row in enumerate(HAMSTER_FRAMES[frame]) if row.strip("."))

# The chicken: a plump white hen with a red comb and wattle, an orange beak
# and legs. Pecks at the ground to eat, flaps when it is happy.
def chicken(legs="stand", eyes="open", beak_open=False, dy=0, head_dy=0, head_dx=0, wing="down", sitting=False):
    g = _blank()
    # Thin orange legs and three-toed feet.
    spots = {"stand": [(8, 0), (11, 0)], "a": [(7, 0), (12, -1)], "b": [(9, -1), (10, 0)],
             "run": [(6, -1), (13, -1)], "tuck": []}[legs]
    for x, lift in spots:
        for y in range(int(12 + dy), 15 + lift):
            put(g, x, y, "b")
        put(g, x - 1, 15 + lift, "b"); put(g, x, 15 + lift, "b"); put(g, x + 1, 15 + lift, "b")
    # Body, tail feathers, neck and head as one plump white shape.
    by = 9.6 + dy + (1.6 if sitting else 0)
    hx, hy = 13.8 + head_dx, 5.2 + dy + head_dy
    parts = [(9.0, by, 5.2, 3.6), (4.4, by - 2.6, 1.7, 2.4), (12.4, (by + hy) / 2 + 0.4, 1.9, 2.6), (hx, hy, 2.6, 2.6)]
    shape(g, parts, lambda x, y: "f")
    # Wing: tucked on the side, or raised and flapping; outlined only along
    # its lower edge, so it reads as a fold of feathers.
    def wing_at(cx, cy, rx, ry):
        pts = {(x, y) for y in range(H) for x in range(W) if inside_ellipse(x, y, cx, cy, rx, ry)}
        for (x, y) in pts:
            if g[y][x] == ".":
                g[y][x] = "o"
            elif g[y][x] != "o":
                g[y][x] = "o" if (x, y + 1) not in pts else "s"
    if wing == "down": wing_at(8.2, by - 0.4, 3.2, 1.6)
    else: wing_at(7.4, by - 2.4, 3.2, 1.9)
    # Comb on top.
    top = next(y for y in range(H) if g[y][int(hx)] != ".")
    put(g, int(hx) - 1, top - 1, "p"); put(g, int(hx), top - 2, "p"); put(g, int(hx), top - 1, "p"); put(g, int(hx) + 1, top - 1, "p")
    # Beak against the face, the wattle hanging under it.
    by0 = int(hy)
    bx = max(x for x in range(W) if g[by0][x] != ".") + 1
    put(g, bx, by0 - 1, "b"); put(g, bx + 1, by0 - 1, "b"); put(g, bx, by0, "b")
    if beak_open:
        put(g, bx, by0, "."); put(g, bx, by0 + 1, "b"); put(g, bx + 1, by0 + 1, "b")
    put(g, bx - 1, by0 + 1, "p"); put(g, bx - 1, by0 + 2, "p")
    ex, ey = bx - 3, by0 - 1
    if eyes == "open": put(g, ex, ey, "e"); put(g, ex, ey - 1, "e")
    elif eyes == "closed": put(g, ex, ey, "o"); put(g, ex - 1, ey, "o")
    elif eyes == "happy": put(g, ex, ey - 1, "e"); put(g, ex - 1, ey, "e"); put(g, ex + 1, ey, "e")
    return ["".join(r) for r in g]

CHICKEN_POSES = {
    "sit": dict(), "blink": dict(eyes="closed"), "happy": dict(eyes="happy", beak_open=True, wing="up"),
    "walk1": dict(legs="a"), "walk2": dict(legs="stand", dy=-0.4, head_dx=0.6), "walk3": dict(legs="b"),
    "run1": dict(legs="run", wing="up", head_dx=0.6), "run2": dict(legs="stand", dy=-0.5, wing="up", beak_open=True),
    "groom1": dict(eyes="closed", head_dy=1, head_dx=-1, wing="up"), "groom2": dict(eyes="closed", head_dy=1.4, head_dx=-1.4),
    "sleep1": dict(legs="tuck", eyes="closed", sitting=True, head_dy=2.4, head_dx=-0.6), "sleep2": dict(legs="tuck", eyes="closed", sitting=True, head_dy=2.6, head_dx=-0.6),
    "eat1": dict(head_dy=4.8, head_dx=1.4), "eat2": dict(head_dy=5.6, head_dx=1.6, beak_open=True),
    "crouch1": dict(dy=1), "crouch2": dict(dy=1, wing="up"),
    "held1": dict(eyes="happy", wing="up", beak_open=True), "held2": dict(eyes="happy", legs="b", beak_open=True),
}
CHICKEN_FRAMES = {name: chicken(**pose) for name, pose in CHICKEN_POSES.items()}

def _chicken_comb(frame):
    """Where the comb is: its middle column and its top row, from the art."""
    rows = CHICKEN_FRAMES[frame]
    y = next(y for y, row in enumerate(rows) if "p" in row)
    return rows[y].index("p"), y

KINDS = {"bee": BEE_FRAMES, "parrot": PARROT_FRAMES, "dino": DINO_FRAMES, "dog": DOG_FRAMES,
         "hamster": HAMSTER_FRAMES, "chicken": CHICKEN_FRAMES}
# Palette per character, in the coat letters plus l for a wing's shine.
KIND_COLORS = {
    "bee": dict(o="2a1d16", f="ffcf3a", s="2f2733", w="d9f0ff", l="ffffff", e="1d140c", p="ff8fa3"),
    "parrot": dict(o="1f2a1a", f="5dbb3c", s="2e7d32", w="b9e45f", p="e8432c", e="111111", b="f5a623", g="8a8f99", t="2f9e8f"),
    "dino": dict(o="1d2b1a", f="6cc24a", s="4a9a33", w="d8f0a0", p="ffa53c", e="111111"),
    "dog": dict(o="2b1a10", f="e0a35a", s="8a5a2b", w="fff3dd", p="ff7f9a", e="1a1110"),
    "hamster": dict(o="3a2414", f="f2a65a", s="d4823a", w="fff6ea", p="ff9fb2", e="1a1110"),
    "chicken": dict(o="3a2a20", f="fbf7f0", s="ddd5c8", w="fff1c4", p="e8432c", e="111111", b="f5a623"),
}
# Hat anchors (no collar: a bee has no neck) and headphones, per frame.
def _bee_dy(frame):
    return 1 if frame.startswith(("sleep", "eat", "crouch")) else 0
# Where the parrot's head is: how far each perched frame lowers it (body
# drop + head drop); flying frames carry it level at row 6.
_PARROT_HEAD_DROP = {"sleep1": 2, "sleep2": 3, "eat1": 4, "eat2": 3, "groom1": 1, "groom2": 1, "crouch1": 1, "crouch2": 1}
def _parrot_flying(frame):
    return frame.startswith(("walk", "run"))
KIND_ANCHORS = {
    "bee": {f: (14.5, 6 + _bee_dy(f), None, None) for f in BEE_FRAMES},
    "parrot": {f: (15.5, 6, None, None) if _parrot_flying(f) else (13.5, 2 + _PARROT_HEAD_DROP.get(f, 0), None, None)
               for f in PARROT_FRAMES},
    "dino": {f: (15.5, 2 + _dino_head(f), None, None) for f in DINO_FRAMES},
    "dog": {f: (14.5, 2 + _dog_head(f), None, None) for f in DOG_FRAMES},
    "hamster": {f: (13.0, _hamster_top(f), None, None) for f in HAMSTER_FRAMES},
    "chicken": {f: (_chicken_comb(f)[0] + 0.5, _chicken_comb(f)[1] + 1, None, None) for f in CHICKEN_FRAMES},
}
KIND_HEADPHONES_AT = {
    "bee": {f: ("bee", 11, 4 + _bee_dy(f)) for f in BEE_FRAMES if not f.startswith("sleep")},
    "parrot": {f: ("side", 12, 5) if _parrot_flying(f) else ("side", 11, _PARROT_HEAD_DROP.get(f, 0))
               for f in PARROT_FRAMES if not f.startswith("sleep")},
    "dino": {f: ("side", 12, 1 + _dino_head(f)) for f in DINO_FRAMES if not f.startswith("sleep")},
    "dog": {f: ("side", 11, 1 + _dog_head(f)) for f in DOG_FRAMES if not f.startswith("sleep")},
    "hamster": {f: ("side", 10, _hamster_top(f)) for f in HAMSTER_FRAMES if not f.startswith("sleep")},
    "chicken": {f: ("side", _chicken_comb(f)[0] - 3, _chicken_comb(f)[1]) for f in CHICKEN_FRAMES if not f.startswith("sleep")},
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
             (None, None, True), ("crown", "bellCollar", True)]
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
