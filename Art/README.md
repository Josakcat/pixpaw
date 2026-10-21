# Art

Every character is one sprite sheet here: a PNG with a row of 18 cells,
each 20 x 20 pixels, 360 x 20 in all. Open it in any pixel editor
(Aseprite, Piskel, LibreSprite…) with a 20 x 20 grid.

- Each pet faces **right**. Pixpaw flips it when it walks the other way.
- A frame is 20 x 16 at the **bottom** of its cell; the top 4 rows stay
  empty. The cat's carried frames are the exception: seen from the front,
  16 wide and the full 20 tall, from the cell's left edge.
- Paint only with that character's colours below, fully opaque.
  Transparent is empty. Any other colour stops the build with the frame
  and pixel to fix.
- The cat is painted in the orange coat. The other coats reuse its
  colours by role, so one cat sheet makes all six.

Then:

```
python3 Tools/sprites.py preview out.png   # every cat frame in every coat
python3 Tools/sprites.py swift             # writes Sources/Pixpaw/CatSprites.generated.swift
```

and build the droplet. Hats sit where the head was before, so keep heads
roughly where they are. Effects, hats and headphones are small text grids
in `Tools/sprites.py`.

## Cells, left to right

1. `sit`: sitting, the resting pose
2. `blink`: sit with eyes closed
3. `happy`: pleased (petted, fed, a toy caught)
4. `walk1`: walk cycle, played 1-2-3-2
5. `walk2`
6. `walk3`
7. `run1`: run cycle
8. `run2`
9. `groom1`: washing
10. `groom2`
11. `sleep1`: asleep, breathing
12. `sleep2`
13. `eat1`: head in the bowl
14. `eat2`: chewing
15. `crouch1`: low before a pounce
16. `crouch2`
17. `held1`: carried
18. `held2`: carried, swinging

## Colours

| | cat | bee | parrot | dino | dog | hamster | chicken |
|---|---|---|---|---|---|---|---|
| `o` outline | `#2b1a10` | `#2a1d16` | `#1f2a1a` | `#1d2b1a` | `#2b1a10` | `#3a2414` | `#3a2a20` |
| `f` fur / main colour | `#f2a03d` | `#ffcf3a` | `#5dbb3c` | `#6cc24a` | `#e0a35a` | `#f2a65a` | `#fbf7f0` |
| `s` stripes, patches, shading | `#c8661e` | `#2f2733` | `#2e7d32` | `#4a9a33` | `#8a5a2b` | `#d4823a` | `#ddd5c8` |
| `w` white (chest, belly) | `#fff3e0` | `#d9f0ff` | `#b9e45f` | `#d8f0a0` | `#fff3dd` | `#fff6ea` | `#fff1c4` |
| `p` pink (ears, nose, comb) | `#f59aa8` | `#ff8fa3` | `#e8432c` | `#ffa53c` | `#ff7f9a` | `#ff9fb2` | `#e8432c` |
| `e` eyes | `#1d140c` | `#1d140c` | `#111111` | `#111111` | `#1a1110` | `#1a1110` | `#111111` |
| `l` wing shine |  | `#ffffff` |  |  |  |  |  |
| `b` beak, legs |  |  | `#f5a623` |  |  |  | `#f5a623` |
| `g` feet |  |  | `#8a8f99` |  |  |  |  |
| `t` tail feathers |  |  | `#2f9e8f` |  |  |  |  |

A brand-new character needs a sheet here, a palette in `KIND_COLORS`, hat
spots in `KIND_ANCHORS` and `KIND_HEADPHONES_AT` (`Tools/sprites.py`) and
a case in `PetKind` (`Sources/Pixpaw/CatSprites.swift`).
