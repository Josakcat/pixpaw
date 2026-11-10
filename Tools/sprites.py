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
from collections import Counter
import sys
import zlib
from pathlib import Path

from fine_extras import (FINE_ACCESSORIES, FINE_ACCESSORY_COLORS, FINE_AGENT, FINE_EFFECTS, FINE_EFFECT_COLORS,
                         FINE_DECOR, FINE_HOME_COLORS, FINE_HOMES, FINE_TOYS)

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
    # Code floating up from the laptop while it works with you.
    # A bead of sweat, for a Mac working hard.
    "sweat": [
        "..c.",
        ".cc.",
        "cbhc",
        "cbbc",
        ".cc.",
    ],
    "code": [
        ".c...c.c.",
        "c...c...c",
        ".c.c...c.",
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

for _effects in (EFFECTS, FINE_EFFECTS):
    _effects["yarn2"] = [
        "".join(_effects["yarn1"][len(_effects["yarn1"]) - 1 - r][c] for r in range(len(_effects["yarn1"])))
        for c in range(len(_effects["yarn1"][0]))
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
    # A laptop in front of it while you focus together: the lid seen from
    # behind, a glowing logo, the base on the floor. Not worn; drawn over
    # the frame's front, under its head.
    "laptop": [
        ".kkkkkkk.",
        ".kgGGGgk.",
        ".kGGwGGk.",
        ".kgGGGgk.",
        "kkkkkkkkk",
    ],
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
    # The Wardrobe's later things. Hats: a ring of flowers on a green band,
    # a knit beanie with a pompom, an acorn's cap (for the small ones), a
    # sprout for a week of care, and a pencil tucked behind the ear, tip
    # down, beside the head rather than on it.
    "flowerCrown": [
        ".t.y.t.",
        "nnnnnnn",
    ],
    "beanie": [
        "..w..",
        ".bbb.",
        "bbbbb",
        "BBBBB",
    ],
    "acornCap": [
        "..A..",
        ".AaA.",
        "AaAaA",
    ],
    "sprout": [
        "nn.nn",
        ".nNn.",
        "..N..",
    ],
    "pencil": [
        "...t",
        "..y.",
        ".y..",
        "k...",
    ],
    # At the neck, from the collar row down: a tie under a dark collar band,
    # and a badge on a lanyard.
    "workTie": [
        "kkkkk",
        "..b..",
        ".bbb.",
        ".bBb.",
        "..b..",
    ],
    "nameBadge": [
        "BBBBBBB",
        ".B...B.",
        "..www..",
        "..wkw..",
        "..www..",
    ],
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
ACCESSORY_LIFT = {"crown": 1, "bow": 1, "pencil": -1}
# Columns to move an accessory from the centre of the head, towards the face.
ACCESSORY_SHIFT = {"pencil": 3}
ACCESSORY_COLORS = dict(r="e8404a", b="4f86e8", y="ffd34d", Y="ffd34d", w="ffffff", k="2a2533", p="9b6bff", t="ff8fb1", l="7fd1ff",
                        g="c9cdd6", G="9196a3",
                        # Colours the pets already wear: the parrot's greens and blue, the
                        # dog's brown, the orange cat's stripe.
                        n="5aa838", N="2f7d2c", B="2b4a8c", A="8a5a2b", a="c8661e")

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
    # The three-headed dragon: a caramel body whose three heads are the body's
    # own colour (R back, Y middle, M front; one blue step apart so each keeps
    # a letter of its own in the sheet), with a red, a gold and a turquoise
    # horn per head (r, y, m), p a gold sparkle. E is the middle head's eye,
    # the same colour as e but a letter of its own, so the glasses finder
    # never takes two heads for one face.
    "dragon": dict(o="3a2214", f="d9975f", s="b5733f", w="fbebc8", l="b5733f", e="2a160c", E="2a160d",
                   R="d9975e", Y="d9975d", M="d9975c", p="ffd34d", r="e5484d", y="f6c445", m="2fc1b5"),
    "dog": dict(o="2b1a10", f="e0a35a", s="8a5a2b", w="fff3dd", p="ff7f9a", e="1a1110"),
    "hamster": dict(o="3a2414", f="f2a65a", s="d4823a", w="fff6ea", p="ff9fb2", e="1a1110"),
    "chicken": dict(o="3a2a20", f="fbf7f0", s="ddd5c8", w="fff1c4", p="e8432c", e="111111", b="f5a623"),
    "giraffe": dict(o="3a2412", f="f2c14e", s="b5652a", w="fbe7b5", p="e59a6a", e="1d140c"),
    "hippo": dict(o="2b2436", f="a196bd", s="857aa3", w="d6cde6", p="f4a3b6", e="1a1520"),
    "rabbit": dict(o="3b2a24", f="c79a6b", s="a8784b", w="f7efe4", p="f3a3b3", e="1d1412"),
    "shark": dict(o="1c2b3b", f="7a96b4", s="5b7795", w="eef3f8", p="f08ca3", e="0f1418"),
    # Drawn from the hippo: pink, a snout round the nostrils, a curly tail.
    "pig": dict(o="4a2a33", f="f7b3c2", s="e8909f", w="ffdbe3", p="e0718b", e="2a1418"),
}


# Colourways for every built-in pet but the cat, after real animals; palette
# only, no new pixels. Each pet's letters are grouped into roles (fur, patch,
# white, ...): a base letter and the shades painted against it, as (fine base,
# fine shades, classic base, classic shades). A colourway gives a role a new
# base; every shade keeps its step from the base, so the shading survives.
PET_ROLES = {
    "dog": dict(fur=("f", "oFh", "f", "o"), patch=("S", "st", "s", ""), white=("w", "xvu", "w", ""),
                eye=("e", "g", None, "")),
    "rabbit": dict(fur=("f", "oFh", "f", "o"), patch=("S", "st", "s", ""), white=("w", "xvu", "w", ""),
                   ear=("p", "qmrk", "p", ""), eye=("e", "g", "e", "")),
    "hamster": dict(fur=("f", "oFh", "f", "o"), patch=("S", "st", "s", ""), white=("w", "xvu", "w", "")),
    "chicken": dict(fur=("f", "oghstu", "f", "os"), comb=("p", "qrc", "p", ""), beak=("b", "anx", "b", "")),
    "bee": dict(fur=("f", "ogh", "f", "o"), stripe=("s", "td", "s", "")),
    "dino": dict(fur=("f", "oFhn", "f", "os"), belly=("w", "xvu", "w", ""), spines=("p", "mq", "p", "")),
    "giraffe": dict(fur=("f", "oFh", "f", "o"), patch=("S", "st", "s", ""), white=("w", "xvu", "w", "")),
    "hippo": dict(fur=("f", "oFhst", "f", "os"), white=("w", "xv", "w", "")),
    "shark": dict(fur=("f", "oFh", "f", "o"), patch=("S", "stg", "s", ""), white=("w", "xv", "w", "")),
    "pig": dict(fur=("f", "oFh", "f", "os"), snout=("N", "nsm", "p", ""), white=("v", "", "w", "")),
    "parrot": dict(body=("f", "ghG", "G", ""), wing=("D", "dj", "D", ""), head=("H", "nm", "H", ""),
                   crown=("C", "c", "C", ""), patch=("P", "rq", "P", ""), belly=("L", "il", "L", ""),
                   throat=("T", "t", "T", ""), flight=("B", "zAb", "B", ""), tail=("O", "uU", "O", ""),
                   beak=("W", "xvw", "W", ""), ring=("E", "", "E", "")),
    "dragon": dict(fur=("f", "Fho", "f", "oRYM"), scales=("s", "S", "s", "l"), belly=("w", "vk", "w", ""),
                   outline=("c", "", None, "")),
}

# The pet's own look first (the default), then real ones. Hex per role; a role
# left out keeps the art's colour.
PET_COATS = {
    "dog": [("Golden", {}),
            ("Cream lab", dict(fur="ecd2a0", patch="cfa66c", white="fffaf0")),
            ("Chocolate lab", dict(fur="7a4b2c", patch="5c3520", white="9c6a46")),
            ("Black lab", dict(fur="34302f", patch="242120", white="4a4543")),
            ("Husky", dict(fur="8c929c", patch="4f5560", white="f4f4f4", eye="4a90d8"))],
    "rabbit": [("Agouti", {}),
               ("White", dict(fur="f4f1ec", patch="e2ddd5", white="ffffff", eye="c8404a")),
               ("Black", dict(fur="302b2b", patch="221e1e", white="4a4444")),
               ("Chinchilla", dict(fur="9c9ca2", patch="7a7a82", white="eeeeee")),
               ("Fawn", dict(fur="e4b578", patch="c9944f"))],
    "hamster": [("Golden", {}),
                ("Roborovski", dict(fur="dcbb8a", patch="c4a070", white="ffffff")),
                ("Winter white", dict(fur="eeece8", patch="b8b4ae", white="ffffff")),
                ("Black bear", dict(fur="322d2b", patch="231f1e", white="4c4644"))],
    "chicken": [("Leghorn", {}),
                ("Rhode Island Red", dict(fur="a8452a")),
                ("Australorp", dict(fur="2c2e36")),
                ("Buff Orpington", dict(fur="eab86a"))],
    "bee": [("Bumblebee", {}),
            ("Honeybee", dict(fur="d99a34", stripe="4a3220")),
            ("Carpenter bee", dict(fur="453f52", stripe="1b1922")),
            ("Orchid bee", dict(fur="3fae6a", stripe="1f6a4a"))],
    "dino": [("Green", {}),
             ("Desert", dict(fur="c9a46a", belly="f2e2bc", spines="8a5a2c")),
             ("Slate", dict(fur="7d8ca0", belly="dde3ea", spines="d9643a")),
             ("Crimson", dict(fur="b5503a", belly="f0d6b0", spines="f2c94c"))],
    "giraffe": [("Reticulated", {}),
                ("Masai", dict(fur="e8c88e", patch="6e3a1a")),
                ("Rothschild", dict(fur="f2ddb0", patch="a8642e")),
                ("White", dict(fur="f4efe4", patch="e4dccb", white="ffffff"))],
    "hippo": [("Lavender", {}),
              ("Common", dict(fur="8f8682", white="e2b9b0")),
              ("Pygmy", dict(fur="645d68", white="b0948f")),
              ("Pink", dict(fur="e8b2a8", white="f8d8d0"))],
    "shark": [("Blue shark", {}),
              ("Gray reef", dict(fur="80898f", patch="5f686f")),
              ("Great white", dict(fur="5f6a76", patch="46505b", white="f6f7f8")),
              ("Lemon", dict(fur="c2ae7a", patch="a08d5c", white="f4efe0")),
              ("Bronze hammerhead", dict(fur="9c7c5c", patch="7a5f45", white="efe8de"))],
    "pig": [("Pink", {}),
            ("Berkshire", dict(fur="332e33", snout="f0e6e2", white="f0e6e2")),
            ("Tamworth", dict(fur="cf8446", snout="b8683a")),
            ("Mangalica", dict(fur="efd8a6", snout="d9b98a"))],
    "parrot": [("Green conure", {}),
               ("Blue-and-yellow macaw", dict(body="2f80d2", wing="1f5eaa", head="2f80d2", crown="4fae4a",
                                              patch="f2efe8", belly="f4b81c", throat="f4b81c", flight="1e3f8a",
                                              tail="2a6cc2", beak="2e2c2c", ring="f2efe8")),
               ("Scarlet macaw", dict(body="e0352c", wing="f2c230", head="e0352c", crown="e0352c",
                                      patch="f2efe8", belly="e0352c", throat="e0352c", flight="2a5ab0",
                                      tail="e0352c", ring="f2efe8")),
               ("African grey", dict(body="8e9296", wing="6f7378", head="a2a6aa", crown="9a9ea2",
                                     patch="eeeeee", belly="aeb2b6", throat="959a9e", flight="5c6064",
                                     tail="c8282e", beak="2e2c2c", ring="eeeeee")),
               ("Blue budgie", dict(body="6cb4e8", wing="3c3c44", head="f4f4ee", crown="f4f4ee",
                                    patch="f4f4ee", belly="6cb4e8", throat="f4f4ee", flight="2a4a9c",
                                    tail="2a4a9c", beak="e8c870", ring="f4f4ee"))],
    "dragon": [("Original", {}),
               ("Komodo", dict(fur="7a7262", scales="5a5448", belly="a89a7a")),
               ("Bearded", dict(fur="d4a05a", scales="b07a3a", belly="f0d8a8")),
               ("Water dragon", dict(fur="4f9a5a", scales="3a7a48", belly="e8e0b0"))],
}



def coat_id(name):
    """"Blue-and-yellow macaw" -> "blueAndYellowMacaw", the colourway's stored value."""
    words = name.replace("-", " ").split()
    return words[0].lower() + "".join(w[:1].upper() + w[1:].lower() for w in words[1:])


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return "".join(f"{max(0, min(255, round(v))):02x}" for v in c)


def lum(c):
    r, g, b = c
    return 0.299 * r + 0.587 * g + 0.114 * b


def shade(orig_base, orig, new_base):
    """`orig` was painted as a step from `orig_base`; take the same step from `new_base`."""
    b, c, n = rgb(orig_base), rgb(orig), rgb(new_base)
    lb, lc = max(lum(b), 1), lum(c)
    if lc <= lb:
        k = lc / lb
        return hexs(v * k for v in n)
    a = (lc - lb) / max(255 - lb, 1)
    return hexs(v + (255 - v) * a for v in n)


def pet_coat(pet, palette, coat, fine):
    out = dict(palette)
    for role, (fb, fs, cb, cs) in PET_ROLES[pet].items():
        if role not in coat:
            continue
        base, shades = (fb, fs) if fine else (cb, cs)
        if base is None or base not in palette:
            continue
        new = coat[role]
        for letter in shades:
            if letter in palette:
                out[letter] = shade(palette[base], palette[letter], new)
        out[base] = new
    if pet == "dragon" and not fine and coat:
        # The heads keep a letter each: the body's colour one blue step apart.
        f = rgb(out["f"])
        for i, letter in enumerate("RYM", 1):
            out[letter] = hexs((f[0], f[1], max(0, f[2] - i)))
    return out


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

# Homes, unlocked at 500 stars: Art/homes.png, one 34 x 26 cell per
# character in HOME_ORDER, each after where the animal really lives: a box
# for the cat, a beehive, a tree to roost in, a cave, a kennel, a cage, a
# coop, an acacia, a pond, a hutch, a reef, a mud wallow. A doorway (d) is dark while the
# home is empty and open while its pet sleeps inside.
HOME_W, HOME_H = 34, 26
# Where the pet sleeps: the left column of its frame, how many rows above
# the bottom its feet are, and whether the home is drawn over it (in a box,
# behind bars, in the water, the bee inside its hive peeping out of the slot)
# or behind it (on a branch, under a tree).
HOME_SPOTS = {
    "cat": (7, 0, True), "bee": (7, 4, True), "parrot": (2, 10, False), "dino": (7, 0, True),
    "dog": (7, 0, True), "hamster": (4, 4, True), "chicken": (7, 0, True), "giraffe": (2, 0, False),
    "hippo": (7, 4, True), "rabbit": (3, 5, True), "shark": (7, 0, True), "pig": (7, 4, True),
    "dragon": (7, 0, True),
}
HOME_ORDER = ["cat", "bee", "parrot", "dino", "dog", "hamster", "chicken", "giraffe", "hippo", "rabbit", "shark", "pig", "dragon"]
HOME_COLORS = dict(o="2a1e1a", d="2e2226", r="c94f45", R="9c3a33", w="f3e3c4", W="d9c29c", k="a0693d", K="6e4526",
                   g="6fb05a", G="4a8a3c", y="f5c542", Y="d79a25", b="6aa8d8", B="3f78a8", p="f2a2b5", P="d97f95",
                   s="a7a9b0", S="7d808a", n="fff2b0", t="5fb3a8", T="3f8a80", c="d9a96b", C="b9854a", m="8a6a4a",
                   a="f7f4ec", A="d8d2c4", l="7fc4e8", L="4f9cc8")


# Home decorations, bought with stars: things that stand beside the home (a 20 x 16
# slot left or right of it, bottom row on the floor) or the doormat in front of the
# doorway. Letters of HOME_COLORS only, drawn like homes.png. Order = price order.
DECOR_SLOT_W, DECOR_SLOT_H = 20, 16
DECOR = {
    'rug': [
        '..oooooooooooooooooooo..',
        'yorrwrrwrrwrrwrrwrrwrroy',
        'yoRRRRRRRRRRRRRRRRRRRRoy',
        '..oooooooooooooooooooo..',
    ],
    'plant': [
        '...oo..oo...',
        '..oggoogGo..',
        '.oggGoogGGo.',
        'oggggogggGGo',
        'ogGgggggoGGo',
        'oggGgGggGGGo',
        '.ooggGGgGGo.',
        '..oooGGGoo..',
        '.oooooooooo.',
        '.orrrrrrrRo.',
        '.oRRRRRRRRo.',
        '..orrrrrRo..',
        '..orrrrrRo..',
        '...oooooo...',
    ],
    'bowls': [
        '..ocCcCo.....oooo...',
        '.obbbbbBo..ollllLo..',
        '.oaabbbBo..oarrrRo..',
        '..obbbBo....orrRo...',
        '...oooo......ooo....',
    ],
    'cushion': [
        '..oooooooooooo..',
        '.oppppppppppppo.',
        'oppppppPppppppPo',
        'opppppPPPpppppPo',
        'oPPPPPPPPPPPPPPo',
        'y.oooooooooooo.y',
    ],
    'lamp': [
        '...oooo...',
        '..owwwWo..',
        '..owwwWo..',
        '.owwwwwWo.',
        '.owwwwwWo.',
        'oonnnnnnoo',
        '....oo....',
        '....oo....',
        '....oo....',
        '....oo....',
        '....oo....',
        '....oo....',
        '....oo....',
        '...okKo...',
        '..okkkKo..',
        '..oooooo..',
    ],
    'basket': [
        '......oo.......',
        '.....orro.oo...',
        '....orrwRoyyo..',
        '....oRrRRoYyo..',
        '.oooooooooooooo',
        '.ocCcCcCcCcCcCo',
        '.oCcCcCcCcCcCCo',
        '.ocCcCcCcCcCcCo',
        '..oCCCCCCCCCCo.',
        '...oooooooooo..',
    ],
    'books': [
        'oooooooooooo',
        'okkkkkkkkkKo',
        'oKoooooooKKo',
        'oKorobogoKKo',
        'oKorobogoKKo',
        'oKoRoBoGoKKo',
        'okkkkkkkkkKo',
        'oKooooo.oKKo',
        'oKoyopoooKKo',
        'oKoyopotoKKo',
        'oKoYoPoToKKo',
        'okkkkkkkkkKo',
        'oKKKKKKKKKKo',
        'oo........oo',
    ],
    'mailbox': [
        '........oo..',
        '...oooooyyo.',
        '..orrrrrRyo.',
        '.orrrrrrRoo.',
        '.orwwwwrRRo.',
        '.orrrrrrRRo.',
        '.oRRRRRRRRo.',
        '..ooooooooo.',
        '.....okKo...',
        '.....okKo...',
        '.....okKo...',
        '.....okKo...',
        '....ookKoo..',
        '...ogGgGGgo.',
    ],
}

# Each pet's own version of a decoration (`HomeDecor.variants` in Swift): same slot, price
# and save key, drawn the way that animal really lives. "<slot>.<kind>"; Seed dish/cup
# and Hay rack/feeder share one picture. Drafted in pixpaw-extras/home-decor/species.
DECOR.update({
    'plant.cat': [
        '..o...o..o..',
        '.ogo.oGo.go.',
        '.ogo.ogo.go.',
        'o.go.og.ogGo',
        'og.gogGogGo.',
        '.ogggGgGgGo.',
        '.oooooooooo.',
        '.owwwwwwwWo.',
        '.owwwwwwwWo.',
        '..oWWWWWWo..',
        '...oooooo...',
    ],
    'bowls.cat': [
        '....ocCcCcCco.......',
        '..oobbbbbbbbboo..oo.',
        '.obabbbbbbbbbbBooBo.',
        '..oobbbbbbbbBoo..oo.',
        '....ooooooooo.......',
    ],
    'cushion.cat': [
        '..oooo....oooo..',
        '.oppppoooopppPo.',
        'oppppPwwwwPpppPo',
        'oPppppppppppppPo',
        'oPPPPPPPPPPPPPPo',
        '.oooooooooooooo.',
    ],
    'basket.cat': [
        '.oooooooooo.',
        '.opppppppPo.',
        '.oPPPPPPPPo.',
        '..oooooooo..',
        '....ocCo.o..',
        '....oCco.o..',
        '....ocCo.o..',
        '....oCcooyo.',
        '....ocCooYo.',
        '....oCco.oo.',
        '....ocCo....',
        '....oCco....',
        'oooooooooooo',
        'opppppppppPo',
        'oooooooooooo',
    ],
    'plant.bee': [
        '.ooo....ooo.',
        'opypo..obybo',
        '.ooo....ooo.',
        '..g..ooo.g..',
        '..g.owywog..',
        '..g..ooo.g..',
        '.Gg...g..gG.',
        '..g..Gg..g..',
        '.oooooooooo.',
        '.orrrrrrrRo.',
        '.oRRRRRRRRo.',
        '..orrrrrRo..',
        '..orrrrrRo..',
        '...oooooo...',
    ],
    'bowls.bee': [
        '..oo...oo..oo..',
        '.osSollsSollsSo',
        'oblllllllllllBo',
        '.obbbbbbbbbbBo.',
        '..ooooooooooo..',
    ],
    'books.bee': [
        'oooooooooooo',
        'okkkkkkkkkKo',
        'okyYoyYoyYKo',
        'okoyYonYoyKo',
        'okyYoyYoyYKo',
        'okoyYoyYoyKo',
        'oknYoyYoyYKo',
        'okoyYoyYoyKo',
        'okyYoyYonYKo',
        'okoyYoyYoyKo',
        'okyYoyYoyYKo',
        'okkkkkkkkkKo',
        'oKKKKKKKKKKo',
        'oo........oo',
    ],
    'bowls.seed': [
        '..oykayykayo..',
        '.oyaykyakykyo.',
        'obbbbbbbbbbbBo',
        '.obbbbbbbbbBo.',
        '..oooooooooo..',
    ],
    'cushion.parrot': [
        '.oooooooooooooo.',
        '.okkkkkkkkkkkKo.',
        '.oKo.o....o.oKo.',
        '.oKo.y....y.oKo.',
        '.oKo.y....y.oKo.',
        '.oKo.y....y.oKo.',
        '.oKo.y....y.oKo.',
        '.oKo.y....y.oKo.',
        '.oKo.oooooo.oKo.',
        '.oKo.okkkKo.oKo.',
        '.oKo.oooooo.oKo.',
        '.oKo........oKo.',
        'ooKoo......ooKoo',
        'okkkKo....okkkKo',
        'oooooo....oooooo',
    ],
    'basket.parrot': [
        '..ooo.ooo.ooo..',
        '..oro.obo.oyo..',
        '..oRo.oBo.oYo..',
        '.oooooooooooooo',
        '.ocCcCcCcCcCcCo',
        '.oCcCcCcCcCcCCo',
        '.ocCcCcCcCcCcCo',
        '..oCCCCCCCCCCo.',
        '...oooooooooo..',
    ],
    'plant.dino': [
        '......oo......',
        '..o..ogGo..o..',
        '.ogo.ogGo.ogo.',
        'ogGgoogGoogGgo',
        '..oogGgGgGoo..',
        '.ogGgogGogGgo.',
        'ogGo.oGgGo.oGo',
        '.oo..oGgo..oo.',
        '..oooooooooo..',
        '..osssssssSo..',
        '..osSsssssSo..',
        '...oSSSSSSo...',
        '...oooooooo...',
    ],
    'basket.dino': [
        '...oo....oo....',
        '..otto..otto...',
        '..otTo..otTo...',
        '.ocCcCcCcCcCco.',
        'ocCCcCcCcCcCcCo',
        'oCcCcCcCcCcCcCo',
        '.oCCCCCCCCCCCo.',
        '..ooooooooooo..',
    ],
    'books.dino': [
        'oooooooooooo',
        'okkkkkkkkkKo',
        'oKddddddddKo',
        'oKaddddddaKo',
        'oKaaaaaaaaKo',
        'oKaddddddaKo',
        'okkkkkkkkkKo',
        'oKdoodooddKo',
        'oKocCoyYodKo',
        'oKoCcoyyodKo',
        'oKdoodooddKo',
        'okkkkkkkkkKo',
        'oKKKKKKKKKKo',
        'oo........oo',
    ],
    'bowls.dog': [
        '....ocCcCcCo........',
        '..obbbbbbbbbBo......',
        '..oawbbbwbbbBo.oo.oo',
        '...obbbbbbbBo.oaaaao',
        '....oooooooo...oo.oo',
    ],
    'cushion.dog': [
        '.oooooooooooooo.',
        'obbbboooooobbbBo',
        'obBbowwwwwWobbBo',
        'obbbbbbbbbbbbbBo',
        'oBBBBBBBBBBBBBBo',
        '.oooooooooooooo.',
    ],
    'basket.dog': [
        '..oo.......oo..',
        '.oaaoooooooaao.',
        '.oaaaaaaaaaaAo.',
        '.oaAoooooooAAo.',
        '.oooooooooooooo',
        '.ocCcCcCcCcCcCo',
        '.oCcCcCcCcCcCCo',
        '.ocCcCcCcCcCcCo',
        '..oCCCCCCCCCCo.',
        '...oooooooooo..',
    ],
    'cushion.hamster': [
        '.....oooo.....',
        '...oocCcCoo...',
        '..ocCcCcCcCo..',
        '.ocCcCcCcCcCo.',
        '.okkoddddokKo.',
        '.okkoddddokKo.',
        '.okkoddddokKo.',
        '.oKKoddddoKKo.',
        '.oooooooooooo.',
    ],
    'lamp.hamster': [
        '...oooo...',
        '..oaaaAo..',
        '..olllLo..',
        '..olalLo..',
        '..olllLo..',
        '..olllLo..',
        '..oLLLLo..',
        '...osSo...',
        '..oosSoo..',
        '..okkkKo..',
        '..okkkKo..',
        '..okkkKo..',
        '.okkkkkKo.',
        '.oooooooo.',
    ],
    'basket.hamster': [
        '....ooooooo....',
        '..oosssssssoo..',
        '.osSo.....oSSo.',
        '.osoo..o..ooSo.',
        'osSo...o...oSSo',
        'oso.ooooooo.oSo',
        'osSo...o...oSSo',
        '.osoo..o..ooSo.',
        '.osSo.....oSSo.',
        '..ooSSSSSSSoo..',
        '....ooooooo....',
        '......oKo......',
        '.....okKKo.....',
        '....ooooooo....',
    ],
    'bowls.chicken': [
        '..oooooooo..',
        '..osssssSo..',
        '..oyyyyyYo..',
        '..oyYyyyYo..',
        '..oyyyYyYo..',
        '..oyyyyyYo..',
        '..oyYyyyYo..',
        '..osssssSo..',
        '.ooyoyyoyoo.',
        'oyYyyyyYyyYo',
        'osssssssssSo',
        '.oooooooooo.',
    ],
    'cushion.chicken': [
        '.oooooooooooooo.',
        '.okkkkkkkkkkkKo.',
        '.okoddddddddoKo.',
        '.okoddaaddddoKo.',
        '.okoyyaAyyyyoKo.',
        '.okoyYyyyYyyoKo.',
        '.okkkkkkkkkkkKo.',
        '.oKKKKKKKKKKKKo.',
        '.oooooooooooooo.',
    ],
    'basket.chicken': [
        '..oo...oo..oo..',
        '.oaao.oaWo.oaao',
        '.oaAo.oWWo.oaAo',
        '.oooooooooooooo',
        '.ocCcCcCcCcCcCo',
        '.oCcCcCcCcCcCCo',
        '.ocCcCcCcCcCcCo',
        '..oCCCCCCCCCCo.',
        '...oooooooooo..',
    ],
    'plant.giraffe': [
        '.oooooooooooo.',
        'oggGggGggGggGo',
        'oGgGGgGgGGgGGo',
        '.oooKoooKoooo.',
        '....oKoKo.....',
        '.....oKko.....',
        '.....okKo.....',
        '.....okKo.....',
        '.....okKo.....',
        '.....okKo.....',
        '.....okKo.....',
        '.....okKo.....',
        '....okkKKo....',
        '...oooooooo...',
        '...osssssSo...',
        '...oooooooo...',
    ],
    'bowls.giraffe': [
        '.oooooooo.',
        '.oppppppPo',
        '.oppppPPPo',
        '.oPPPPPPPo',
        'oooooooooo',
        'okkkkkkkKo',
        'oooooooooo',
    ],
    'hay.rack': [
        '..oyoyyoyoyo..',
        '.oyYyyYyyYyyo.',
        'okkkkkkkkkkkKo',
        'okoyoyoyoyoyKo',
        'okoYoyoYoyoYKo',
        'okoyoYoyoYoyKo',
        'okkkkkkkkkkkKo',
        '.oKo......oKo.',
        '.oKo......oKo.',
        'oyyyyYyyyYyyyo',
        '.oooooooooooo.',
    ],
    'hay.feeder': [
        '..oyoyyoyo..',
        '.oyYyyYyyYo.',
        'okkkkkkkkkKo',
        'okoyoYoyoYKo',
        'okoYoyoYoyKo',
        '.okkkkkkkKo.',
        '....okKo....',
        '....okKo....',
        '....okKo....',
        '....okKo....',
        '....okKo....',
        '....okKo....',
        '....okKo....',
        '...okkKKo...',
        '..okkkkKKo..',
        '..oooooooo..',
    ],
    'plant.hippo': [
        '...o....o...',
        '..ogo..ogo..',
        '..ogo.oGgo.o',
        '.ogGoogGgoog',
        '.ogGgogGgogG',
        'oggGggGgggGo',
        'oGgGgGgGgGGo',
        '.oooooooooo.',
    ],
    'bowls.hippo': [
        '..oooooooo..',
        '.orrrrrrrRo.',
        'orkrrrkrrrRo',
        'orrrkrrrkrRo',
        'oaaaaaaaaaAo',
        'oGgGgGgGgGGo',
        '.oooooooooo.',
    ],
    'basket.hippo': [
        '....ok.........',
        '..oooKooo......',
        '.oyYyyYyYo.....',
        'oyYyyYyyYYo.ok.',
        'oyYyyYyyYYooooo',
        'oyYyyYyyYYoyYYo',
        '.oYYYYYYYoyYYYo',
        '..ooooooo.ooooo',
    ],
    'cushion.rabbit': [
        '....oooooooo....',
        '..occCcCcCcCco..',
        '.occCcCcCcCcCCo.',
        'oddddcCcCcCcCCCo',
        'oddddCcCcCcCCCCo',
        'oddddCCCCCCCCCCo',
        'oooooooooooooooo',
    ],
    'basket.rabbit': [
        '...oooo...',
        '.oocCcCoo.',
        '.ocCooCco.',
        'ocCoCcoCCo',
        'oCcoCCoCco',
        'ocCoCcoCCo',
        '.oCcooCCo.',
        '.ooCCCCoo.',
        '...oooo...',
    ],
    'plant.shark': [
        '..o......o..',
        '.ogo....ogo.',
        '.oGgo...oGo.',
        '..ogGo.ogo..',
        '...oGo.oGgo.',
        '..ogo...oGo.',
        '.oGgo..ogo..',
        '.ogGo..oGgo.',
        '..oGgo..oGo.',
        '...ogo.ogGo.',
        '..oGgo.oGo..',
        '..oooooooo..',
        '.occccccCCo.',
        'oooooooooooo',
    ],
    'basket.shark': [
        '...ooooooooo...',
        '..okkkkkkkkKo..',
        '.okkkkkkkkkkKo.',
        '.oyyyyyyyyyyYo.',
        '.okkkkkoookkKo.',
        '.oyyyyyoYoyyYo.',
        '.okkkkkkokkkKo.',
        '.okkkkkkkkkkKo.',
        '.oyyyyyyyyyyYo.',
        '.oooooooooooo..',
    ],
    'books.shark': [
        '.oo..oo..oo.',
        'oppo.opo.opo',
        'opPo.oPo.oPo',
        '.oPpoopooPo.',
        '..oPpPpPpo..',
        '...oPpPPo...',
        '....oPPo....',
        '....oPpo....',
        '..oooooooo..',
        '.ossssssSSo.',
        'osSssssSSSSo',
        'oooooooooooo',
    ],
    'mailbox.shark': [
        '..ooooooooo.....',
        '.olawwwwwllLoo..',
        'olllWWWWWlllLkKo',
        '.oLLLLLLLLLLoo..',
        '..ooooooooooo...',
        'occcccccccccccCo',
        'oooooooooooooooo',
    ],
    'bowls.pig': [
        'oooooooooooooooooooo',
        'osyyCyyCyyyCyyCyyySo',
        'ossssssssssssssssSSo',
        '.oSSSSSSSSSSSSSSSSo.',
        '.oo..............oo.',
    ],
    'cushion.pig': [
        '....oooooooo....',
        '..ooyYyyyYyyoo..',
        '.oyyYyyYyyyYyyo.',
        'oyYyyyYyyYyyyYyo',
        'oYYYYYYYYYYYYYYo',
        '.oooooooooooooo.',
    ],
    'basket.pig': [
        '..oo..ooo...o..',
        '.ogGo.ogGgo.oko',
        '.oro..oGgGo.oro',
        '.oro..ooooo.oRo',
        '.oooooooooooooo',
        '.okkkkkkkkkkkKo',
        '.oKKKKKKKKKKKKo',
        '.okkkkkkkkkkkKo',
        '.oKKKKKKKKKKKKo',
        '.oooooooooooooo',
    ],
    'cushion.dragon': [
        '......oooo......',
        '....ooyYyyoo....',
        '..ooyyYyyrYyoo..',
        '.oyYyyyYybyyYyo.',
        'oyyYyYyyyYyyYYYo',
        'oooooooooooooooo',
    ],
    'lamp.dragon': [
        '....oo....',
        '...oyyo...',
        '..oynyyo..',
        '.oyynnyro.',
        '.oryynyro.',
        '.orrrrrRo.',
        'oossssssoo',
        '.osssssSo.',
        '..oSSSSo..',
        '....oo....',
        '....oo....',
        '....oo....',
        '....oo....',
        '...osSo...',
        '..osssSo..',
        '..oooooo..',
    ],
    'basket.dragon': [
        '...o......o....',
        '..obo....opo...',
        '..obBo..opPo.o.',
        '.obbBo.opPPoogo',
        '.obBBoooopPPoGo',
        'ossssssssssssSo',
        '.ooooooooooooo.',
    ],
})


def load_homes():
    path = ART / "homes.png"
    width, height, pixels = read_png(path)
    assert (width, height) == (HOME_W * len(HOME_ORDER), HOME_H), f"{path}: should be {HOME_W * len(HOME_ORDER)} x {HOME_H}"
    letters = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)): k for k, v in HOME_COLORS.items()}
    homes = {}
    for n, kind in enumerate(HOME_ORDER):
        rows = []
        for y in range(HOME_H):
            row = ""
            for x in range(HOME_W):
                r, g, b, a = pixels[y][n * HOME_W + x]
                assert a < 128 or (r, g, b) in letters, f"{path}: {kind}'s home has #{r:02x}{g:02x}{b:02x} at ({x}, {y})"
                row += "." if a < 128 else letters[(r, g, b)]
            rows.append(row)
        homes[kind] = rows
    return homes


HOMES = load_homes()

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
# Where the newer characters' hats go, read off their sheets: the middle of
# the head and its top row (the giraffe's horns, the hippo's ears, the
# rabbit's head between its ears). Headphones sit over the same spot.
_HATS = {
    "giraffe": {"sit": (15.5, 0), "blink": (15.5, 0), "happy": (15.5, 0), "walk1": (15.5, 0), "walk2": (15.5, 0), "walk3": (15.5, 0),
                "run1": (16.0, 1), "run2": (16.0, 1), "groom1": (16.0, 1), "groom2": (16.0, 1), "sleep1": (16.0, 6), "sleep2": (16.0, 6),
                "eat1": (17.0, 9), "eat2": (17.0, 9), "crouch1": (16.0, 2), "crouch2": (16.0, 2), "held1": (15.5, 0), "held2": (15.5, 0)},
    "hippo": {"sit": (13.5, 3), "blink": (13.5, 3), "happy": (13.5, 3), "walk1": (13.5, 3), "walk2": (13.5, 3), "walk3": (13.5, 3),
              "run1": (13.5, 4), "run2": (13.5, 3), "groom1": (13.5, 4), "groom2": (13.5, 4), "sleep1": (13.5, 6), "sleep2": (13.5, 6),
              "eat1": (14.0, 7), "eat2": (14.0, 6), "crouch1": (13.5, 4), "crouch2": (13.5, 4), "held1": (13.5, 3), "held2": (13.5, 3)},
    "rabbit": {"sit": (13.5, 5), "blink": (13.5, 5), "happy": (13.5, 4), "walk1": (13.5, 5), "walk2": (14.5, 3), "walk3": (13.5, 5),
               "run1": (14.5, 3), "run2": (13.5, 5), "groom1": (13.5, 5), "groom2": (13.5, 6), "sleep1": (13.5, 8), "sleep2": (13.5, 8),
               "eat1": (15.0, 9), "eat2": (15.0, 8), "crouch1": (13.5, 6), "crouch2": (13.5, 6), "held1": (13.5, 5), "held2": (13.5, 5)},
    "shark": {"sit": (15.5, 6), "blink": (15.5, 6), "happy": (15.5, 6), "walk1": (15.5, 6), "walk2": (15.5, 6), "walk3": (15.5, 6),
              "run1": (15.5, 6), "run2": (15.5, 6), "groom1": (15.5, 6), "groom2": (15.5, 6), "sleep1": (15.5, 8), "sleep2": (15.5, 8),
              "eat1": (15.5, 7), "eat2": (15.5, 7), "crouch1": (15.5, 7), "crouch2": (15.5, 7), "held1": (15.5, 6), "held2": (15.5, 6)},
}
# Off while asleep, and while the head is down in the bowl where it would be lost.
_HATS["pig"] = _HATS["hippo"]  # the same head, where the pig was drawn from
_NO_PHONES = {"giraffe": ("sleep", "eat"), "hippo": ("sleep",), "rabbit": ("sleep", "eat"), "shark": ("sleep",), "pig": ("sleep",)}
KIND_ANCHORS = {
    "bee": {f: (14.5, 6 + _bee_dy(f), None, None) for f in BEE_FRAMES},
    "parrot": {f: (*_parrot_head(f), None, None) for f in PARROT_FRAMES},
    "dino": {f: (15.5, 2 + _dino_head(f), None, None) for f in DINO_FRAMES},
    "dog": {f: (14.5, 2 + _dog_head(f), None, None) for f in DOG_FRAMES},
    "hamster": {f: (13.0, _hamster_top(f), None, None) for f in HAMSTER_FRAMES},
    "chicken": {f: (_chicken_comb(f)[0] + 0.5, _chicken_comb(f)[1] + 1, None, None) for f in CHICKEN_FRAMES},
}
KIND_ANCHORS.update({kind: {f: (x, y, None, None) for f, (x, y) in spots.items()} for kind, spots in _HATS.items()})
# The dragon's hat sits on its middle head, as drawn in the design: the head
# follows the groom, sleep and crouch poses, so the spot does too. It wears
# no headphones and no glasses (its heads are too small for either).
_DRAGON_HAT = {"sit": (9.5, 1), "blink": (9.5, 1), "happy": (9.5, 1), "walk1": (9.5, 1), "walk2": (9.5, 1), "walk3": (9.5, 1),
               "run1": (10.5, 2), "run2": (10.5, 2), "groom1": (8.5, 4), "groom2": (8.5, 5), "sleep1": (9.5, 7), "sleep2": (9.5, 8),
               "eat1": (9.5, 1), "eat2": (9.5, 1), "crouch1": (10.5, 4), "crouch2": (10.5, 4), "held1": (9.5, 1), "held2": (9.5, 1)}
KIND_ANCHORS["dragon"] = {f: (x, y, None, None) for f, (x, y) in _DRAGON_HAT.items()}
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
KIND_HEADPHONES_AT["dragon"] = {}
KIND_HEADPHONES_AT.update({kind: {f: ("side", round(x - 3.5), y - 1) for f, (x, y) in spots.items() if not f.startswith(_NO_PHONES[kind])}
                           for kind, spots in _HATS.items()})


# Finer art for the desktop. A look (a kind, and for the cat its coat:
# "cat.gray") can have a second sheet at twice the resolution in
# Art/fine/<look>.png: 18 cells of 40 x 40, each frame 40 x 32 at the bottom
# of its cell (carried frames held up from the front, `tall`, 32 x 40 from the left). Pixpaw draws
# it at 1.5 pt a pixel on the desktop in place of the 20 x 16 art, in the
# same 60 x 48 pt frame, unless Classic pixels is on; the notch, menus and
# cards keep the 20 x 16 art. Hats, collars and the laptop are the 20 x 16
# art drawn 2x; glasses ring the eye boxes below by the same rule as the
# 20 x 16 art; headphones are FINE_HEADPHONES. To give another look finer
# art: draw its sheet and add its entry here, nothing else.
FINE_SCALE = 2
FINE_CELL = CELL * FINE_SCALE
# Head-on headphones for a 40 x 32 head: a band over the crown and a cup
# over each cheek, a light line along the band and a cushion towards the face.
FINE_HEADPHONES = {
    "front": [
        ".......bbbbbbbbbb.......",
        ".....bbllllllllllbb.....",
        "....bll..........llb....",
        "...bl..............lb...",
        "..bl................lb..",
        "..b..................b..",
        ".bl..................lb.",
        ".b....................b.",
        "bbB..................Bbb",
        "blB..................Blb",
        "blB..................Blb",
        "blB..................Blb",
        "blB..................Blb",
        "bbB..................Bbb",
        ".bb..................bb.",
    ],
    # Side on, for every pet seen from the side: the 20 x 16 side pair at twice
    # the pixels, a band arching back over the head and one cup on the near
    # cheek, its cushion towards the face.
    "side": [
        "....bbbbbb....",
        "..bbllllllbb..",
        ".bll......llb.",
        ".bl........lb.",
        "bl..........b.",
        "b.............",
        "bbbB..........",
        "blbB..........",
        "blbB..........",
        "blbB..........",
        "bbbB..........",
        ".bb...........",
    ],
    # Side on, seen from behind (the parrot grooming or crouched with its back turned): the same pair mirrored, its
    # cup on the far side of the head.
    "sideBack": [
        "....bbbbbb....",
        "..bbllllllbb..",
        ".bll......llb.",
        ".bl........lb.",
        ".b..........lb",
        ".............b",
        "..........Bbbb",
        "..........Bblb",
        "..........Bblb",
        "..........Bblb",
        "..........Bbbb",
        "...........bb.",
    ],
}
FINE = {
    # The gray tabby, drawn in pixpaw-extras/hd-pets/cat-v1.
    "cat.gray": dict(
        # Fur o line, F shadow, f base, h light; stripe S, s, t; white x line,
        # v shadow, w base, u light; pink m line, q, p, r; eyes d dark,
        # y catchlight, e iris, g light iris; l lids and mouth, n nose, k blush.
        colours=dict(o="464b5a", F="767c89", f="8d939e", h="a9afba", S="5d636e", s="6a707c", t="7a808c",
                     x="5a6070", v="cdd1d8", w="e9ecf0", u="fafbfc", m="9c5a6a", q="e08e9e", p="f0a0ae", r="f8bcc6",
                     d="262a33", y="ffffff", e="4fb05e", g="8edc8f", l="3a3e4a", n="e2808f", k="f2a9b6"),
        tall={"held1", "held2"},
        # (hat centre x, hat bottom row, collar centre x, collar row); None for
        # no collar, where the 20 x 16 cat has none (and crouching, chin down).
        anchors={
            **{f: (24, 4, 24, 20) for f in ("sit", "blink", "happy")},
            # Walking and running, the collar sits where the chin meets the chest.
            "walk1": (30, 4, 22, 19), "walk2": (30, 3, 22, 18), "walk3": (30, 4, 22, 19),
            "run1": (30, 3, 22, 18), "run2": (30, 4, 22, 19),
            "groom1": (24, 4, None, None), "groom2": (24, 4, None, None),
            "sleep1": (28, 13, None, None), "sleep2": (28, 14, None, None),
            "eat1": (30, 7, None, None), "eat2": (30, 8, None, None),
            "crouch1": (30, 13, None, None), "crouch2": (30, 13, None, None),
            "held1": (16, 4, 16, 20), "held2": (16, 4, 16, 20),
        },
        # Eye boxes (x0, x1, y0, y1), open or shut, for the glasses; none asleep or carried.
        eyes={
            **{f: ((16, 20, 10, 15), (27, 31, 10, 15)) for f in ("sit", "blink", "happy", "groom1", "groom2")},
            **{f: ((22, 26, 10, 15), (33, 37, 10, 15)) for f in ("walk1", "walk3", "run2")},
            **{f: ((22, 26, 9, 14), (33, 37, 9, 14)) for f in ("walk2", "run1")},
            "eat1": ((22, 26, 13, 18), (33, 37, 13, 18)), "eat2": ((22, 26, 14, 19), (33, 37, 14, 19)),
            **{f: ((22, 26, 18, 23), (33, 37, 18, 23)) for f in ("crouch1", "crouch2")},
        },
        # Headphones (view, left, top); none asleep or eating, as for the 20 x 16 cat.
        headphones_at={
            **{f: ("front", 12, 2) for f in ("sit", "blink", "happy", "groom1", "groom2")},
            **{f: ("front", 16, 2) for f in ("walk1", "walk3", "run2")},
            **{f: ("front", 16, 1) for f in ("walk2", "run1")},
            **{f: ("front", 16, 11) for f in ("crouch1", "crouch2")},
            **{f: ("front", 4, 2) for f in ("held1", "held2")},
        },
        # Every other coat (and the one from a photo) wears this sheet in
        # colours worked out from its 20 x 16 ones (o, f, s, w, p, e): each
        # letter is (from, times, toward, amount), the `from` colour times
        # `times`, then `amount` of the way to `toward` ("*" is white). Fitted
        # to the drawn gray, which keeps its own colours above.
        coats=dict(o=("o", 1, "f", .37), F=("f", .84, "*", 0), f=("f", 1, "*", 0), h=("f", 1.2, "*", 0),
                   S=("s", 1, "*", 0), s=("s", 1, "f", .27), t=("s", 1, "f", .6),
                   x=("o", 1, "w", .3), v=("w", .88, "*", 0), w=("w", 1, "*", 0), u=("w", 1.07, "*", 0),
                   m=("o", 1, "p", .52), q=("p", .91, "*", 0), p=("p", 1, "*", 0), r=("p", 1, "*", .3),
                   d=("o", 1, "f", .06), y=("e", 1, "*", 1), e=("e", .9, "*", 0), g=("e", 1, "*", .3),
                   l=("o", 1, "f", .2), n=("p", .88, "*", 0), k=("p", 1, "*", .08)),
    ),
    # The other kinds, one look each and no coats. Drawn in pixpaw-extras/hd-pets/<kind>.
    "dog": dict(
        # Fur o line, F shadow, f base, h light; patches S, s, t; white x line,
        # v shadow, w base, u light; pink m line, q, p, r; eyes d dark,
        # y catchlight, e iris, g light iris; l lids and mouth, n nose, k blush.
        colours=dict(o="6e4d2b", F="bc894c", f="e0a35a", h="ffc46c", S="8a5a2b", s="a16e38", t="be8647", x="6b5b4e",
                     v="e0d6c2", w="fff3dd", u="ffffec", m="994f58", q="e8748c", p="ff7f9a", r="ffa5b8", d="362214",
                     y="ffffff", e="4c321c", g="794f27", l="4f351f", n="3a2a24", k="ff89a2"),
        tall={"held1", "held2"},
        anchors={
            **{f: (27, 4, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "run2")},
            **{f: (27, 3, None, None) for f in ("walk2", "run1")},
            **{f: (27, 6, None, None) for f in ("groom1", "groom2")}, "sleep1": (27, 14, None, None),
            "sleep2": (27, 15, None, None), "eat1": (28, 8, None, None), "eat2": (28, 9, None, None),
            **{f: (27, 11, None, None) for f in ("crouch1", "crouch2")},
            **{f: (16, 4, None, None) for f in ("held1", "held2")},
        },
        eyes={
            **{f: ((19, 23, 10, 15), (30, 34, 10, 15)) for f in ("sit", "blink", "happy", "walk1", "walk3", "run2")},
            **{f: ((19, 23, 9, 14), (30, 34, 9, 14)) for f in ("walk2", "run1")},
            **{f: ((19, 23, 12, 17), (30, 34, 12, 17)) for f in ("groom1", "groom2")},
            "eat1": ((22, 26, 13, 18), (33, 37, 13, 18)), "eat2": ((22, 26, 14, 19), (33, 37, 14, 19)),
            **{f: ((19, 23, 17, 22), (30, 34, 17, 22)) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("front", 15, 2) for f in ("sit", "blink", "happy", "walk1", "walk3", "run2")},
            **{f: ("front", 15, 1) for f in ("walk2", "run1")},
            **{f: ("front", 15, 4) for f in ("groom1", "groom2")}, "eat1": ("front", 16, 6),
            "eat2": ("front", 16, 7), **{f: ("front", 15, 9) for f in ("crouch1", "crouch2")},
            **{f: ("front", 4, 2) for f in ("held1", "held2")},
        },
    ),
    "rabbit": dict(
        # Fur o line, F shadow, f base, h light; patches S, s, t; white x line,
        # v shadow, w base, u light; pink m line, q, p, r; eyes d dark,
        # y catchlight, e iris, g light iris; l lids and mouth, n nose, k blush.
        colours=dict(o="6f533e", F="a7815a", f="c79a6b", h="efb980", S="a8784b", s="b08154", t="bb8c5e", x="73655e",
                     v="d9d2c9", w="f7efe4", u="fffff4", m="9b696e", q="dd94a3", p="f3a3b3", r="f7bfca", d="433128",
                     y="ffffff", e="5c412c", g="936942", l="574032", n="d68f9e", k="f4aab9"),
        tall={"held1", "held2"},
        anchors={
            **{f: (26, 11, None, None) for f in ("sit", "blink", "happy", "walk3", "groom1", "groom2")},
            **{f: (27, 13, None, None) for f in ("walk1", "run2")}, "walk2": (27, 7, None, None),
            "run1": (27, 6, None, None), **{f: (27, 15, None, None) for f in ("sleep1", "crouch1")},
            "sleep2": (27, 16, None, None), "eat1": (28, 14, None, None), "eat2": (28, 15, None, None),
            "crouch2": (27, 14, None, None), **{f: (16, 10, None, None) for f in ("held1", "held2")},
        },
        eyes={
            **{f: ((18, 22, 16, 21), (29, 33, 16, 21)) for f in ("sit", "blink", "happy", "walk3", "groom1", "groom2")},
            **{f: ((19, 23, 18, 23), (30, 34, 18, 23)) for f in ("walk1", "run2")},
            "walk2": ((19, 23, 13, 18), (30, 34, 13, 18)), "run1": ((19, 23, 12, 17), (30, 34, 12, 17)),
            "eat1": ((22, 26, 19, 24), (33, 37, 19, 24)), "eat2": ((22, 26, 20, 25), (33, 37, 20, 25)),
            "crouch1": ((19, 23, 20, 25), (30, 34, 20, 25)), "crouch2": ((19, 23, 19, 24), (30, 34, 19, 24)),
        },
        headphones_at={
            **{f: ("front", 14, 9) for f in ("sit", "blink", "happy", "walk3", "groom1", "groom2")},
            **{f: ("front", 15, 11) for f in ("walk1", "run2")}, "walk2": ("front", 15, 5), "run1": ("front", 15, 4),
            "crouch1": ("front", 15, 13), "crouch2": ("front", 15, 12),
            **{f: ("front", 4, 8) for f in ("held1", "held2")},
        },
    ),
    "hamster": dict(
        # Fur o line, F shadow, f base, h light; patches S, s, t; white x line,
        # v shadow, w base, u light; pink m line, q, p, r; eyes d dark,
        # y catchlight, e iris, g light iris; l lids and mouth, n nose, k blush.
        colours=dict(o="7e542e", F="cb8b4c", f="f2a65a", h="ffc76c", S="d4823a", s="dc8c43", t="e6984d", x="756354",
                     v="e0d8ce", w="fff6ea", u="fffffa", m="a06466", q="e891a2", p="ff9fb2", r="ffbcc9", d="452c18",
                     y="ffffff", e="6e4423", g="b87134", l="5f3e22", n="e08c9d", k="ffa7b8"),
        tall={"held1", "held2"},
        anchors={
            **{f: (25, 11, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "run1", "groom1", "groom2")},
            **{f: (25, 10, None, None) for f in ("walk2", "run2")}, "sleep1": (25, 16, None, None),
            "sleep2": (25, 17, None, None), **{f: (28, 13, None, None) for f in ("eat1", "eat2")},
            **{f: (25, 15, None, None) for f in ("crouch1", "crouch2")},
            **{f: (16, 9, None, None) for f in ("held1", "held2")},
        },
        eyes={
            **{f: ((17, 21, 15, 20), (28, 32, 15, 20)) for f in ("sit", "blink", "happy", "walk1", "walk3", "run1", "groom1", "groom2")},
            **{f: ((17, 21, 14, 19), (28, 32, 14, 19)) for f in ("walk2", "run2")},
            **{f: ((22, 26, 18, 23), (33, 37, 18, 23)) for f in ("eat1", "eat2")},
            **{f: ((17, 21, 19, 24), (28, 32, 19, 24)) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("front", 13, 9) for f in ("sit", "blink", "happy", "walk1", "walk3", "run1", "groom1", "groom2")},
            **{f: ("front", 13, 8) for f in ("walk2", "run2")}, **{f: ("front", 16, 11) for f in ("eat1", "eat2")},
            **{f: ("front", 13, 13) for f in ("crouch1", "crouch2")},
            **{f: ("front", 4, 7) for f in ("held1", "held2")},
        },
    ),
    "chicken": dict(
        # White f/g/h, wing s/t/u, comb and wattle p/q/r/c, beak and legs b/a/n/x, o line (warm brown); e eye, y catchlight, k blush.
        colours=dict(o="7a6352", f="fbf7f0", g="e3dacb", h="fffdf8", s="ddd5c8", t="c4b9a8", u="ebe5dc", p="e8432c",
                     q="c93424", r="f46b55", c="a3281c", b="f5a623", a="dc8c14", n="ffc85e", x="b06a12", e="1f1712",
                     y="ffffff", k="f7a8a8"),
        tall=set(),
        anchors={
            **{f: (27.5, 4, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            **{f: (28.5, 3, None, None) for f in ("walk2", "run2")}, "run1": (28.5, 4, None, None),
            "groom1": (26.0, 6, None, None), "groom2": (25.5, 7, None, None), "sleep1": (26.5, 9, None, None),
            "sleep2": (26.5, 10, None, None), "eat1": (30.0, 15, None, None), "eat2": (30.0, 14, None, None),
            **{f: (27.5, 6, None, None) for f in ("crouch1", "crouch2")},
        },
        eyes={
            **{f: ((27, 30, 6, 9),) for f in ("sit", "blink", "happy", "walk1", "walk3")},
            "walk2": ((29, 32, 6, 9),), "run1": ((29, 32, 7, 10),), "run2": ((29, 32, 5, 8),),
            "groom1": ((26, 29, 10, 13),), "groom2": ((26, 29, 11, 14),), "eat1": ((30, 33, 19, 22),),
            "eat2": ((30, 33, 18, 21),), **{f: ((28, 31, 9, 12),) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("side", 19, 3) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            **{f: ("side", 20, 2) for f in ("walk2", "run2")}, "run1": ("side", 20, 3), "groom1": ("side", 18, 5),
            "groom2": ("side", 17, 6), "eat1": ("side", 22, 14), "eat2": ("side", 22, 13),
            **{f: ("side", 19, 5) for f in ("crouch1", "crouch2")},
        },
    ),
    "bee": dict(
        # Yellow f/g/h with a warm o line, stripes s/t/d, wings w/v/u with a blue line z, l shine and catchlight, e eye, p blush.
        colours=dict(o="6b4a1e", f="ffcf3a", g="eab02a", h="ffe27a", d="241c28", s="2f2733", t="463d4c", z="7d9bb3",
                     v="bcdcf2", w="d9f0ff", u="f2faff", l="ffffff", e="1d140c", p="ff8fa3"),
        tall=set(),
        anchors={
            **{f: (23.0, 14, None, None) for f in ("sit", "blink", "happy", "walk1", "walk2", "walk3", "run1", "run2")},
            **{f: (23.0, 12, None, None) for f in ("groom1", "groom2", "held1", "held2")},
            **{f: (23.0, 16, None, None) for f in ("sleep1", "sleep2", "eat1", "crouch1")},
            **{f: (23.0, 15, None, None) for f in ("eat2", "crouch2")},
        },
        eyes={
            **{f: ((25, 29, 15, 20),) for f in ("sit", "blink", "happy", "walk1", "walk2", "walk3", "run1", "run2")},
            **{f: ((25, 29, 13, 18),) for f in ("groom1", "groom2")},
            **{f: ((25, 29, 17, 22),) for f in ("eat1", "crouch1")},
            **{f: ((25, 29, 16, 21),) for f in ("eat2", "crouch2")},
        },
        headphones_at={
            **{f: ("side", 19, 12) for f in ("sit", "blink", "happy", "walk1", "walk2", "walk3", "run1", "run2")},
            **{f: ("side", 19, 10) for f in ("groom1", "groom2", "held1", "held2")},
            **{f: ("side", 19, 14) for f in ("eat1", "crouch1")},
            **{f: ("side", 19, 13) for f in ("eat2", "crouch2")},
        },
    ),
    "dino": dict(
        # Fur o green line, F shadow, f base, h light; belly x line, v shadow, w base,
        # u light; spikes and tongue m line, q shadow, p base; eye d dark, y catchlight, e iris;
        # l lids and mouth, n nostril, k blush. Drawn in pixpaw-extras/hd-pets/dino.
        colours=dict(o="2f5d2b", F="58a83c", f="6cc24a", h="8ed66a", x="6f9a45", v="bfdc86", w="d8f0a0", u="ecf9c6",
                     m="b8641c", q="e8892a", p="ffa53c", d="1c2618", y="ffffff", e="4c5e3a", l="24331f", n="3e7a2e",
                     k="ff9d7a"),
        tall=set(),
        anchors={
            **{f: (30.0, 4, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            "walk2": (30.0, 3, None, None), "run1": (31.0, 3, None, None), "run2": (31.0, 4, None, None),
            **{f: (30.0, 6, None, None) for f in ("groom1", "groom2")},
            **{f: (30.5, 18, None, None) for f in ("sleep1", "sleep2")}, "eat1": (28.0, 12, None, None),
            "eat2": (28.0, 13, None, None), **{f: (30.5, 9, None, None) for f in ("crouch1", "crouch2")},
        },
        eyes={
            **{f: ((29, 32, 6, 10),) for f in ("sit", "blink", "happy", "walk1", "walk3")},
            "walk2": ((29, 32, 5, 9),), "run1": ((30, 33, 4, 8),), "run2": ((30, 33, 5, 9),),
            **{f: ((29, 32, 8, 12),) for f in ("groom1", "groom2")}, "eat1": ((27, 30, 13, 17),),
            "eat2": ((27, 30, 14, 18),), **{f: ((29, 32, 10, 14),) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("side", 23, 1) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            "walk2": ("side", 23, 0), "run1": ("side", 24, 0), "run2": ("side", 24, 1),
            **{f: ("side", 23, 3) for f in ("groom1", "groom2")}, "eat1": ("side", 21, 9), "eat2": ("side", 21, 10),
            **{f: ("side", 24, 6) for f in ("crouch1", "crouch2")},
        },
    ),
    "giraffe": dict(
        # Fur o brown line, F shadow, f base, h light; patches, horns, mane and hooves
        # S, s, t; socks and muzzle x line, v shadow, w base, u light; ear and tongue
        # m line, p base; eye d dark, y catchlight, e iris; l lids and mouth, n nostril,
        # k blush. Drawn in pixpaw-extras/hd-pets/giraffe.
        colours=dict(o="7a4a1c", F="d9a63a", f="f2c14e", h="f8d77c", S="96501f", s="b5652a", t="c67a3c", x="a87a48",
                     v="eed39a", w="fbe7b5", u="fff4dc", m="a45a36", p="e59a6a", d="2a1a0e", y="ffffff", e="6a4422",
                     l="4a2c12", n="a0603a", k="f4a088"),
        tall=set(),
        anchors={
            **{f: (31.4, 4, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            **{f: (31.4, 5, None, None) for f in ("walk2", "run1")}, "run2": (31.9, 6, None, None),
            **{f: (31.4, 6, None, None) for f in ("groom1", "groom2")},
            **{f: (29.9, 11, None, None) for f in ("sleep1", "sleep2")}, "eat1": (26.4, 15, None, None),
            "eat2": (26.4, 16, None, None), **{f: (31.4, 7, None, None) for f in ("crouch1", "crouch2")},
        },
        eyes={
            **{f: ((30, 33, 4, 8),) for f in ("sit", "blink", "happy", "walk1", "walk3")},
            **{f: ((30, 33, 5, 9),) for f in ("walk2", "run1")},
            **{f: ((30, 33, 6, 10),) for f in ("run2", "groom1", "groom2")}, "eat1": ((25, 28, 15, 19),),
            "eat2": ((25, 28, 16, 20),), **{f: ((30, 33, 8, 12),) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("side", 24, 1) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            **{f: ("side", 24, 2) for f in ("walk2", "run1")}, "run2": ("side", 25, 3),
            **{f: ("side", 24, 3) for f in ("groom1", "groom2")},
            **{f: ("side", 24, 4) for f in ("crouch1", "crouch2")},
        },
    ),
    "hippo": dict(
        # Fur o purple line, F shadow, f base, h light; back s, t; belly and teeth
        # x line, v shadow, w base; ears, tongue m line, p base; eye d dark,
        # y catchlight, e iris; l lids and mouth, n nostrils, k blush (cheek).
        # Drawn in pixpaw-extras/hd-pets/hippo.
        colours=dict(o="514470", F="8a7ea8", f="a196bd", h="b8afd2", s="857aa3", t="938aaf", x="8c80ab", v="c4bad9",
                     w="d6cde6", m="b0607a", p="f4a3b6", d="1f1a2a", y="ffffff", e="4e4268", l="3a3052", n="463a62",
                     k="f7b2c2"),
        tall=set(),
        anchors={
            **{f: (26.8, 8, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            "walk2": (26.8, 7, None, None), "run1": (27.3, 6, None, None), "run2": (27.8, 8, None, None),
            **{f: (26.8, 10, None, None) for f in ("groom1", "groom2")},
            **{f: (27.3, 15, None, None) for f in ("sleep1", "sleep2")}, "eat1": (24.3, 12, None, None),
            "eat2": (24.3, 13, None, None), **{f: (27.3, 10, None, None) for f in ("crouch1", "crouch2")},
        },
        eyes={
            **{f: ((28, 31, 9, 13),) for f in ("sit", "blink", "happy", "walk1", "walk3")},
            "walk2": ((28, 31, 8, 12),), "run1": ((28, 31, 7, 11),), "run2": ((29, 32, 9, 13),),
            **{f: ((28, 31, 11, 15),) for f in ("groom1", "groom2")}, "eat1": ((25, 28, 13, 17),),
            "eat2": ((25, 28, 14, 18),), **{f: ((28, 31, 12, 16),) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("side", 22, 5) for f in ("sit", "blink", "happy", "walk1", "walk3", "held1", "held2")},
            "walk2": ("side", 22, 4), "run1": ("side", 22, 3), "run2": ("side", 23, 5),
            **{f: ("side", 22, 7) for f in ("groom1", "groom2", "crouch1", "crouch2")}, "eat1": ("side", 19, 9),
            "eat2": ("side", 19, 10),
        },
    ),
    "shark": dict(
        colours=dict(o="3f5368", F="667e97", f="7a96b4", h="92b4d8", S="4c6683", s="5b7795", t="6d8aa8", x="5b6774",
                     v="d1d6da", w="eef3f8", d="0f1418", y="ffffff", e="2a3a4e", g="4a6684", l="26303c", k="f5a6b8",
                     p="f08ca3"),
        tall=set(),
        anchors={
            **{f: (30.5, 11, None, None) for f in ("sit", "blink", "walk1", "walk3", "run2", "groom1", "groom2", "held1", "held2")},
            **{f: (30.5, 10, None, None) for f in ("happy", "walk2")}, "run1": (29.5, 9, None, None),
            **{f: (30.5, 17, None, None) for f in ("sleep1", "sleep2", "crouch1", "crouch2")},
            "eat1": (31.5, 14, None, None), "eat2": (31.5, 15, None, None),
        },
        eyes={
            **{f: ((26, 30, 11, 16),) for f in ("sit", "blink", "walk1", "walk3", "run2", "groom1", "groom2")},
            **{f: ((26, 30, 10, 15),) for f in ("happy", "walk2", "run1")}, "eat1": ((27, 31, 14, 19),),
            "eat2": ((27, 31, 15, 20),), **{f: ((26, 30, 16, 21),) for f in ("crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("side", 20, 9) for f in ("sit", "blink", "walk1", "walk3", "run2", "groom1", "groom2", "held1", "held2")},
            **{f: ("side", 20, 8) for f in ("happy", "walk2")}, "run1": ("side", 20, 7), "eat1": ("side", 21, 12),
            "eat2": ("side", 21, 13), **{f: ("side", 20, 15) for f in ("crouch1", "crouch2")},
        },
    ),
    "pig": dict(
        colours=dict(o="8a5d68", F="e39aab", f="f7b3c2", h="ffcbd8", N="d97d90", s="e8909f", n="f2a7b4", v="f0c3cd",
                     p="e0718b", d="2a1418", y="ffffff", e="5a3440", g="8a5a66", l="4a2a33", k="f27f97", m="7a3a4c"),
        tall=set(),
        anchors={
            **{f: (28.5, 7, None, None) for f in ("sit", "blink", "walk1", "walk3", "groom1", "groom2")},
            **{f: (28.5, 6, None, None) for f in ("happy", "walk2", "run2")},
            **{f: (28.5, 5, None, None) for f in ("run1", "held1", "held2")},
            **{f: (28.5, 15, None, None) for f in ("sleep1", "sleep2")}, "eat1": (28.5, 11, None, None),
            **{f: (28.5, 12, None, None) for f in ("eat2", "crouch1", "crouch2")},
        },
        eyes={
            **{f: ((20, 24, 9, 14), (32, 36, 9, 14)) for f in ("sit", "blink", "walk1", "walk3", "run2", "groom1", "groom2")},
            **{f: ((20, 24, 8, 13), (32, 36, 8, 13)) for f in ("happy", "walk2")},
            "run1": ((20, 24, 7, 12), (32, 36, 7, 12)), "eat1": ((20, 24, 13, 18), (32, 36, 13, 18)),
            **{f: ((20, 24, 14, 19), (32, 36, 14, 19)) for f in ("eat2", "crouch1", "crouch2")},
        },
        headphones_at={
            **{f: ("front", 16, 5) for f in ("sit", "blink", "walk1", "walk3", "groom1", "groom2")},
            **{f: ("front", 16, 4) for f in ("happy", "walk2", "run2")},
            **{f: ("front", 16, 3) for f in ("run1", "held1", "held2")}, "eat1": ("front", 16, 9),
            **{f: ("front", 16, 10) for f in ("eat2", "crouch1", "crouch2")},
        },
    ),
    "dragon": dict(
        # Drawn in pixpaw-extras/hd-pets/dragon-fierce (opt2), coloured caramel like the
        # 20 x 16 dragon (ux-v2 option B) so it is one character in both styles and reads
        # on black, the notch and light; c, the outer rim, is the dark outline.
        # A hat on the middle head only: no eye boxes, no headphones, as for the 20 x 16 dragon.
        colours=dict(o="3a2214", F="b5733f", f="d9975f", h="ecb987", S="8f5530", s="b5733f", k="fbebc8", v="d9bd86",
                     w="f0d9a8", R="7a1f24", A="b8333a", r="e5484d", Y="8a6618", M="156a63", m="2fc1b5", d="2a160c",
                     e="ff5a1a", E="ffc04a", g="ff8a1a", G="fff3a0", x="f4ead2", c="3a2214"),
        # The hexes Art/fine/dragon.png is painted in (the dark first draft): only used to
        # read the sheet into letters, so the art stays as drawn.
        drawn=dict(o="171211", F="392e28", f="58463a", h="806650", S="3e231d", s="5c322a", k="b08a44", v="6e5534",
                   w="8f7044", d="0e0a09", c="6e4428"),
        tall=set(),
        anchors={
            **{f: (19.5, 2, None, None) for f in ("sit", "blink", "happy", "walk1", "walk3", "groom1", "eat1", "eat2", "held1", "held2")},
            "walk2": (19.5, 1, None, None), "run1": (20.5, 2, None, None), "run2": (20.5, 3, None, None),
            "groom2": (19.5, 3, None, None), "sleep1": (20.5, 15, None, None), "sleep2": (20.5, 16, None, None),
            **{f: (22.5, 7, None, None) for f in ("crouch1", "crouch2")},
        },
        eyes={
        },
        headphones_at={
        },
    ),
    # Drawn in pixpaw-extras/hd-pets/parrot-v2: a side-view conure, one K eye, held in side view.
    "parrot": dict(
        # Body f/g/h, wing D/d/j, head H/n/m, crown C/c, orange P/r/q, beak W/v/w/x, belly L/i/l, throat T/t, blue B/A/b/z, tail O/u/U, feet F/s/p/a, o line; K eye, y catchlight, E eye ring.
        colours=dict(o="1f3d24", f="5aa838", g="46902d", h="78c24e", D="2f7d2c", d="24642a", j="3f9439", H="3b8540", n="30733a", m="4c9a4c", C="2f7a62", c="3d917a", P="f26a3d", r="d9552b", q="f78a5e", x="6b5648", v="c9b5a2", W="ead9c8", w="f7efe6", L="bccf3a", i="a3b62f", l="d2e26a", T="7c8a3a", t="6c7a31", z="1f2f5c", A="22407a", B="2b4a8c", b="3b62ad", O="4f9a30", u="3f7f27", U="62ad3e", a="5c5856", s="77726f", F="8f8a86", p="a7a29e", K="16161a", y="ffffff", E="f1e9a6"),
        tall=set(),
        # (hat centre x, hat bottom row, collar centre x, collar row): no collar, as today.
        anchors={
            "sit": (27.5, 5, None, None),
            "blink": (27.5, 5, None, None),
            "happy": (27.5, 5, None, None),
            "walk1": (28.5, 9, None, None),
            "walk2": (28.5, 9, None, None),
            "walk3": (28.5, 9, None, None),
            "run1": (28.5, 9, None, None),
            "run2": (28.5, 9, None, None),
            "groom1": (28.5, 6, None, None),
            "groom2": (25.5, 8, None, None),
            "sleep1": (27.0, 14, None, None),
            "sleep2": (27.5, 15, None, None),
            "eat1": (27.5, 19, None, None),
            "eat2": (27.5, 18, None, None),
            "crouch1": (28.5, 13, None, None),
            "crouch2": (29.5, 12, None, None),
            "held1": (26.5, 3, None, None),
            "held2": (26.5, 2, None, None),
        },
        # Eye boxes (x0, x1, y0, y1) for the glasses; none asleep or carried (glasses come off then).
        eyes={
            "sit": ((29, 31, 8, 10),),
            "blink": ((29, 31, 8, 10),),
            "happy": ((29, 31, 8, 10),),
            "walk1": ((30, 32, 12, 14),),
            "walk2": ((30, 32, 12, 14),),
            "walk3": ((30, 32, 12, 14),),
            "run1": ((30, 32, 12, 14),),
            "run2": ((30, 32, 12, 14),),
            "groom1": ((25, 27, 9, 11),),
            "groom2": ((24, 26, 12, 14),),
            "eat1": ((28, 30, 23, 25),),
            "eat2": ((28, 30, 22, 24),),
            "crouch1": ((30, 32, 16, 18),),
            "crouch2": ((26, 28, 15, 17),),
        },
        # Headphones (view, left, top); none where today has none.
        headphones_at={
            "sit": ("side", 24, 3),
            "blink": ("side", 24, 3),
            "happy": ("side", 24, 3),
            "walk1": ("side", 25, 7),
            "walk2": ("side", 25, 7),
            "walk3": ("side", 25, 7),
            "run1": ("side", 25, 7),
            "run2": ("side", 25, 7),
            "groom1": ("sideBack", 17, 2),
            "groom2": ("sideBack", 14, 4),
            "crouch1": ("side", 25, 11),
            "crouch2": ("sideBack", 18, 8),
            "held1": ("side", 23, 1),
            "held2": ("side", 23, 0),
        },
    ),
}
# The gray tabby with folded ears, like a Scottish Fold's: the same frames
# with each ear's tip folded down into a little cap, its pink hidden.
# `python3 Tools/sprites.py fold` draws Art/fine/cat.gray.folded.png from
# cat.gray.png; touch it up by hand after, if you like.
FINE["cat.gray.folded"] = dict(FINE["cat.gray"], folds="cat.gray")


def load_fine_sheet(look, spec):
    """A look's finer frames from Art/fine/<look>.png, as letter grids."""
    path = ART / "fine" / f"{look}.png"
    width, height, pixels = read_png(path)
    assert (width, height) == (FINE_CELL * len(FRAME_ORDER), FINE_CELL), \
        f"{path}: should be {FINE_CELL * len(FRAME_ORDER)} x {FINE_CELL}, is {width} x {height}"
    letters = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)): k
               for k, v in {**spec["colours"], **spec.get("drawn", {})}.items()}
    frames = {}
    for n, name in enumerate(FRAME_ORDER):
        w, h = (16 * FINE_SCALE, FINE_CELL) if name in spec["tall"] else (W * FINE_SCALE, H * FINE_SCALE)
        rows = []
        for y in range(FINE_CELL - h, FINE_CELL):
            row = ""
            for x in range(w):
                r, g, b, a = pixels[y][n * FINE_CELL + x]
                assert a < 128 or (r, g, b) in letters, f"{path}: {name} has #{r:02x}{g:02x}{b:02x} at ({x}, {y})"
                row += "." if a < 128 else letters[(r, g, b)]
            rows.append(row)
        for y in range(FINE_CELL):
            for x in range(FINE_CELL):
                if y < FINE_CELL - h or x >= w:
                    assert pixels[y][n * FINE_CELL + x][3] < 128, f"{path}: {name} has a pixel at ({x}, {y}), outside its {w} x {h} frame"
        frames[name] = rows
    return frames


# A folded sheet not drawn yet (see `fold`) is left out.
FINE_FRAMES = {look: load_fine_sheet(look, spec) for look, spec in FINE.items()
               if "folds" not in spec or (ART / "fine" / f"{look}.png").exists()}


def fine_ears(rows):
    """The two ears' pink, as lists of (x, y): the largest pink patches at the top of the head."""
    pink = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c in "prqm"}
    patches, seen = [], set()
    for start in sorted(pink, key=lambda p: (p[1], p[0])):
        if start in seen:
            continue
        patch, todo = [], [start]
        seen.add(start)
        while todo:
            x, y = todo.pop()
            patch.append((x, y))
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in pink and n not in seen:
                    seen.add(n)
                    todo.append(n)
        if len(patch) >= 5:
            patches.append(patch)
    top = min(min(y for _, y in p) for p in patches)
    ears = sorted((p for p in patches if min(y for _, y in p) <= top + 1), key=lambda p: min(x for x, _ in p))
    assert len(ears) == 2, "two ears"
    return ears


def fold_fine(rows):
    """Each ear's tip folded down: the point gone, a cap of outline one row
    over the ear's old top, fur inside it, its fold a line of outline, and
    the pink below covered in the fur beside it."""
    g = [list(r) for r in rows]
    for side, ear in enumerate(fine_ears(rows)):
        x0, x1 = min(x for x, _ in ear), max(x for x, _ in ear)
        y0 = min(y for _, y in ear)
        for y in range(y0):
            for x in range(x0 - 1, x1 + 2):
                g[y][x] = "."
        for x in range(x0 + 1, x1):
            g[y0 - 1][x] = "o"
            g[y0][x] = "h" if side == 0 else "f"
        g[y0][x0] = g[y0][x1] = "o"
        for x, y in ear:
            if y == y0 + 1:
                g[y][x] = "o"
        for x, y in sorted((p for p in ear if p[1] > y0 + 1), key=lambda p: p[1]):
            near = Counter(g[b][a] for a, b in ((x - 1, y), (x + 1, y), (x, y + 1), (x - 1, y + 1), (x + 1, y + 1))
                           if 0 <= b < len(g) and 0 <= a < len(g[b]) and g[b][a] not in "prqmo.")
            g[y][x] = near.most_common(1)[0][0] if near else ("h" if side == 0 else "F")
    # A stray inner-ear pixel (one only touching an ear by a corner) is covered too.
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c in "rq":
                near = Counter(g[b][a] for a, b in ((x - 1, y), (x + 1, y), (x, y + 1), (x, y - 1))
                               if 0 <= b < len(g) and 0 <= a < len(g[b]) and g[b][a] not in "prqmo.")
                g[y][x] = near.most_common(1)[0][0] if near else "f"
    return ["".join(r) for r in g]


def fold():
    """Draws every folded sheet from the sheet it folds."""
    for look, spec in FINE.items():
        if "folds" not in spec:
            continue
        source, colours = FINE_FRAMES[spec["folds"]], spec["colours"]
        width, height = FINE_CELL * len(FRAME_ORDER), FINE_CELL
        px = bytearray(width * height * 4)
        for n, name in enumerate(FRAME_ORDER):
            rows = fold_fine(source[name])
            for y, row in enumerate(rows):
                for x, c in enumerate(row):
                    if c != ".":
                        k = ((FINE_CELL - len(rows) + y) * width + n * FINE_CELL + x) * 4
                        px[k:k + 4] = bytes(int(colours[c][i:i + 2], 16) for i in (0, 2, 4)) + b"\xff"
        png(ART / "fine" / f"{look}.png", width, height, px)
        print("drew", ART / "fine" / f"{look}.png")


def fine_coat(spec, coat):
    """A look's finer colours for a 20 x 16 coat, by its `coats` recipe."""
    out = {}
    for letter, (source, times, toward, amount) in spec["coats"].items():
        a = [min(255, round(int(coat[source][i:i + 2], 16) * times)) for i in (0, 2, 4)]
        b = [255] * 3 if toward == "*" else [int(coat[toward][i:i + 2], 16) for i in (0, 2, 4)]
        out[letter] = "".join(f"{round(u + (v - u) * amount):02x}" for u, v in zip(a, b))
    return out


def check():
    for name, rows in DECOR.items():
        assert all(len(r) == len(rows[0]) for r in rows), f"decor {name}: ragged"
        assert name == "rug" or len(rows[0]) <= DECOR_SLOT_W, f"decor {name}: wider than its slot"
        assert len(rows) <= DECOR_SLOT_H, f"decor {name}: taller than its slot"
    # The doormat, a little wider than the pet asleep on it, centred under it, inside every home's width.
    for kind, (x, _, _) in HOME_SPOTS.items():
        left = x + (W - len(DECOR["rug"][0])) // 2
        assert 0 <= left and left + len(DECOR["rug"][0]) <= HOME_W, f"the doormat sticks out of {kind}'s home"
        assert {c for r in rows for c in r} <= set(HOME_COLORS) | {"."}, f"decor {name}: a letter not in HOME_COLORS"
    assert len(DECOR["rug"]) <= 4, "the doormat stays 4 rows, under the feet of a pet asleep a few rows up"
    # Every coat has to be able to paint the cat.
    for name, rows in FRAMES.items():
        for i, r in enumerate(rows):
            assert set(r) <= set(".ofswpe"), (name, i, r)
    for look, spec in FINE.items():
        assert set(spec["anchors"]) == set(FRAME_ORDER), f"{look}: an anchor for every frame"
        assert "f" in spec["colours"], f"{look}: f is the fur, for glasses on dark fur"
    # Every colourway names known roles, and every role's base is a letter of the art.
    for pet, coats in PET_COATS.items():
        assert not coats[0][1], f"{pet}: its own look first"
        for name, coat in coats:
            assert set(coat) <= set(PET_ROLES[pet]), (pet, name)
        for role, (fb, _, cb, _) in PET_ROLES[pet].items():
            assert fb in FINE[pet]["colours"] and (cb is None or cb in KIND_COLORS[pet]), (pet, role)


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
    out += ["    ]", "", "    static let accessoryShift: [String: Int] = ["]
    out += [f'        "{k}": {v},' for k, v in ACCESSORY_SHIFT.items()]
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
    out += ["    ]", "", f"    static let homeWidth = {HOME_W}", f"    static let homeHeight = {HOME_H}",
            "", "    /// Where the pet sleeps: frame's left column, rows above the bottom, home drawn over it.",
            "    static let homeSpots: [String: (Int, Int, Bool)] = ["]
    out += [f'        "{k}": ({x}, {y}, {"true" if front else "false"}),' for k, (x, y, front) in HOME_SPOTS.items()]
    out += ["    ]", "", "    static let homes: [String: [String]] = ["]
    for kind, rows in HOMES.items():
        out.append(f'        "{kind}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    /// d is the doorway: dark while the home is empty.", "    static let homeColors: [Character: UInt32] = ["]
    out += [f'        "{k}": 0x{v},' for k, v in HOME_COLORS.items()]
    out += ["    ]", "", "    /// Home decorations by `HomeDecor` raw value, in `homeColors`; bottom row on the floor.",
            f"    static let decorSlotWidth = {DECOR_SLOT_W}", "    static let decor: [String: [String]] = ["]
    for name, rows in DECOR.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    /// Palette per coat: outline, fur, stripe, white, pink, eye.",
            "    static let coats: [String: [Character: UInt32]] = ["]
    for coat, pal in list(COATS.items()) + list(KIND_COLORS.items()):
        items = ", ".join(f'"{k}": 0x{v}' for k, v in pal.items())
        out.append(f'        "{coat}": [{items}],')
    out += ["    ]", "", "    /// Each pet's colourways in order, id and title; the first is its own look.",
            "    static let petCoats: [String: [(id: String, title: String)]] = ["]
    for pet, coats in PET_COATS.items():
        out.append(f'        "{pet}": [' + ", ".join(f'("{coat_id(n)}", "{n}")' for n, _ in coats) + "],")
    out += ["    ]", "", "    /// A colourway's palette, as \"<kind>.<id>\" (the pet's own look is `coats`).",
            "    static let petCoatPalettes: [String: [Character: UInt32]] = ["]
    for pet, coats in PET_COATS.items():
        for n, coat in coats[1:]:
            items = ", ".join(f'"{k}": 0x{v}' for k, v in pet_coat(pet, KIND_COLORS[pet], coat, False).items())
            out.append(f'        "{pet}.{coat_id(n)}": [{items}],')
    out += ["    ]", "}", ""]
    dest = Path(__file__).resolve().parent.parent / "Sources/Pixpaw/CatSprites.generated.swift"
    dest.write_text("\n".join(out))
    print("wrote", dest)
    fine_swift()


def fine_swift():
    out = ["// Generated by Tools/sprites.py from Art/fine/. Edit the art there, then run `python3 Tools/sprites.py swift`.", "",
           "/// Finer art for the desktop, at `scale` times the pixels of `CatArt`, by",
           "/// look: \"<kind>\", or for the cat \"cat.<coat>\". Frames, anchors, eyes and",
           "/// headphone spots are keyed \"<look>.<frame>\".",
           "enum FineArt {", f"    static let scale = {FINE_SCALE}", "",
           "    static let palettes: [String: [Character: UInt32]] = ["]
    looks = {look: FINE[look] for look in FINE_FRAMES}
    for look, spec in looks.items():
        items = ", ".join(f'"{k}": 0x{v}' for k, v in spec["colours"].items())
        out.append(f'        "{look}": [{items}],')
    out += ["    ]", "", "    /// A pet's colourway, as \"<kind>.<id>\" (see `CatArt.petCoats`).",
            "    static let petCoatPalettes: [String: [Character: UInt32]] = ["]
    for pet, coats in PET_COATS.items():
        for n, coat in coats[1:]:
            items = ", ".join(f'"{k}": 0x{v}' for k, v in pet_coat(pet, FINE[pet]["colours"], coat, True).items())
            out.append(f'        "{pet}.{coat_id(n)}": [{items}],')
    out += ["    ]", "", "    /// The cat's other coats: each letter from the 20 x 16 coat's (see `FineMix`).",
            "    static let coatMix: [Character: FineMix] = ["]
    for letter, (source, times, toward, amount) in FINE["cat.gray"]["coats"].items():
        out.append(f'        "{letter}": FineMix(from: "{source}", times: {float(times)}, toward: "{toward}", amount: {float(amount)}),')
    out += ["    ]", "", "    static let frames: [String: [String]] = ["]
    for look, frames in FINE_FRAMES.items():
        for name, rows in frames.items():
            out.append(f'        "{look}.{name}": [')
            out += [f'            "{r}",' for r in rows]
            out.append("        ],")
    out += ["    ]", "", "    /// Frame: hat centre x, hat bottom row, collar centre x, collar row (-1 = none).",
            "    static let anchors: [String: (Double, Int, Double, Int)] = ["]
    for look, spec in looks.items():
        for name, (hx, hy, cx, cy) in spec["anchors"].items():
            out.append(f'        "{look}.{name}": ({float(hx)}, {hy}, {float(cx) if cx is not None else -1}, {cy if cy is not None else -1}),')
    out += ["    ]", "", "    /// Frame: the eyes the glasses go round, open or shut.", "    static let eyes: [String: [EyeBox]] = ["]
    for look, spec in looks.items():
        for name, boxes in spec["eyes"].items():
            items = ", ".join(f"EyeBox(x0: {a}, x1: {b}, y0: {c}, y1: {d})" for a, b, c, d in boxes)
            out.append(f'        "{look}.{name}": [{items}],')
    out += ["    ]", "", "    static let headphones: [String: [String]] = ["]
    for name, rows in FINE_HEADPHONES.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    /// Frame: headphones view, left column, top row.",
            "    static let headphonesAt: [String: (String, Int, Int)] = ["]
    for look, spec in looks.items():
        for name, (view, left, top) in spec["headphones_at"].items():
            out.append(f'        "{look}.{name}": ("{view}", {left}, {top}),')
    out += ["    ]", "", "    /// HD hats, collars and the laptop: `CatArt.accessories` at twice the grid.",
            "    static let accessories: [String: [String]] = ["]
    for name, rows in FINE_ACCESSORIES.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    static let accessoryColors: [Character: UInt32] = ["]
    out += [f'        "{k}": 0x{v},' for k, v in {**ACCESSORY_COLORS, **FINE_ACCESSORY_COLORS}.items()]
    out += ["    ]", "", "    /// HD `CatArt.effects`: props at twice the grid; effects over the head at 4/3 (drawn at 1.5 pt).",
            "    static let effects: [String: [String]] = ["]
    for name, rows in FINE_EFFECTS.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    static let effectColors: [Character: UInt32] = ["]
    out += [f'        "{k}": 0x{v},' for k, v in {**EFFECT_COLORS, **FINE_EFFECT_COLORS}.items()]
    out += ["    ]", "", "    /// HD `ToyArt` toys by `PetGame`; `o` is ink.",
            "    static let toys: [String: (rows: [String], palette: [Character: UInt32])] = ["]
    for name, (rows, pal) in FINE_TOYS.items():
        out.append(f'        "{name}": ([')
        out += [f'            "{r}",' for r in rows]
        out.append("        ], [" + ", ".join(f'"{k}": 0x{v}' for k, v in pal.items()) + "]),")
    out += ["    ]", "", "    /// HD `AgentArt` pictures by name (twice the grid, or 4/3 for the head effects); `o` is ink.",
            "    static let agent: [String: (frames: [[String]], palette: [Character: UInt32])] = ["]
    for name, (frames, pal) in FINE_AGENT.items():
        out.append(f'        "{name}": ([')
        for rows in frames:
            out.append("            [")
            out += [f'                "{r}",' for r in rows]
            out.append("            ],")
        out.append("        ], [" + ", ".join(f'"{k}": 0x{v}' for k, v in pal.items()) + "]),")
    out += ["    ]", "", "    /// HD homes: `CatArt.homes` at twice the grid; d is the doorway.",
            "    static let homes: [String: [String]] = ["]
    for kind, rows in FINE_HOMES.items():
        out.append(f'        "{kind}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "", "    static let homeColors: [Character: UInt32] = ["]
    out += [f'        "{k}": 0x{v},' for k, v in {**HOME_COLORS, **FINE_HOME_COLORS}.items()]
    out += ["    ]", "", "    /// HD home decorations: `CatArt.decor` at twice the grid, in `homeColors`.",
            "    static let decor: [String: [String]] = ["]
    for name, rows in FINE_DECOR.items():
        out.append(f'        "{name}": [')
        out += [f'            "{r}",' for r in rows]
        out.append("        ],")
    out += ["    ]", "}", ""]
    dest = Path(__file__).resolve().parent.parent / "Sources/Pixpaw/CatSprites.fine.generated.swift"
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
        left = int(round(ax - len(art[0]) / 2)) + ACCESSORY_SHIFT.get(name, 0)
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


def preview_fine(path, scale=3):
    """Every finer look in every coat: the gray as drawn, then the others
    by its `coats` recipe."""
    rows_of = []
    for look, frames in FINE_FRAMES.items():
        spec = FINE[look]
        rows_of.append((frames, spec["colours"]))
        if "coats" in spec:
            rows_of += [(frames, fine_coat(spec, COATS[coat])) for coat in COATS if coat != "gray"]
    cell = (FINE_CELL + 2) * scale
    width, height = cell * len(FRAME_ORDER), cell * len(rows_of)
    px = bytearray([40, 44, 52, 255] * width * height)
    for j, (frames, pal) in enumerate(rows_of):
        for i, name in enumerate(FRAME_ORDER):
            rows = frames[name]
            for y, row in enumerate(rows):
                for x, c in enumerate(row):
                    if c == ".":
                        continue
                    rgb = bytes(int(pal[c][k:k + 2], 16) for k in (0, 2, 4)) + b"\xff"
                    for dy in range(scale):
                        for dx in range(scale):
                            X = i * cell + (x + 1) * scale + dx
                            Y = j * cell + cell - (len(rows) - y + 1) * scale + dy
                            k = (Y * width + X) * 4
                            px[k:k + 4] = rgb
    png(path, width, height, px)


if __name__ == "__main__":
    check()
    if sys.argv[1:2] == ["preview"]:
        preview(sys.argv[2])
    elif sys.argv[1:2] == ["wear"]:
        preview_accessories(sys.argv[2])
    elif sys.argv[1:2] == ["fine"]:
        preview_fine(sys.argv[2])
    elif sys.argv[1:2] == ["fold"]:
        fold()
    elif sys.argv[1:2] == ["swift"]:
        swift()
