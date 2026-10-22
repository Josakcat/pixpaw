# Art

Every character is one sprite sheet here (eleven of them): a PNG with a row of 18 cells,
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

### Your own pet, no build needed

Pixpaw can also bring a sheet in while it runs: Settings → Your own pets →
Choose PNG. There it is less strict:

- Only the first cell, `sit`, is needed. Leave any other cell empty (or
  leave it off the end) and Pixpaw makes it from the poses you drew: it
  hops to walk and run, and sinks down a pixel or two to sleep, eat and crouch.
- Any colours. A pixel more than half transparent is empty.
- Scaled up evenly is fine (a 200 × 200 export of one cell, say).
- A pet can use the top 4 rows of its cells too; it just stands taller.
- Hats go on the top of its head by themselves; it wears no collar or headphones.
- Its ⋯ menu takes sounds of its own: a call, a happy sound and an eating
  sound (short WAV, MP3, M4A or AIFF files). The rest are the voice of the
  character it acts like. Don't worry about how loud you record: Pixpaw
  evens every sound out to the level of its own voices (about -18 dBFS RMS,
  peaks under -1 dBFS) and cuts the silence off either end.

Start from a template (Settings → Your own pets → Start from a template
saves any character's sheet) and save your pet's sheet from its ⋯ menu to
share it.

To add a character to Pixpaw itself, then:

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

| | cat | bee | dino | dog | hamster | chicken | giraffe | hippo | rabbit | shark |
|---|---|---|---|---|---|---|---|---|---|---|
| `o` outline | `#2b1a10` | `#2a1d16` | `#1d2b1a` | `#2b1a10` | `#3a2414` | `#3a2a20` | `#3a2412` | `#2b2436` | `#3b2a24` | `#1c2b3b` |
| `f` fur / main colour | `#f2a03d` | `#ffcf3a` | `#6cc24a` | `#e0a35a` | `#f2a65a` | `#fbf7f0` | `#f2c14e` | `#a196bd` | `#c79a6b` | `#7a96b4` |
| `s` stripes, patches, shading | `#c8661e` | `#2f2733` | `#4a9a33` | `#8a5a2b` | `#d4823a` | `#ddd5c8` | `#b5652a` | `#857aa3` | `#a8784b` | `#5b7795` |
| `w` white (chest, belly) | `#fff3e0` | `#d9f0ff` | `#d8f0a0` | `#fff3dd` | `#fff6ea` | `#fff1c4` | `#fbe7b5` | `#d6cde6` | `#f7efe4` | `#eef3f8` |
| `p` pink (ears, nose, comb) | `#f59aa8` | `#ff8fa3` | `#ffa53c` | `#ff7f9a` | `#ff9fb2` | `#e8432c` | `#e59a6a` | `#f4a3b6` | `#f3a3b3` | `#f08ca3` |
| `e` eyes | `#1d140c` | `#1d140c` | `#111111` | `#1a1110` | `#1a1110` | `#111111` | `#1d140c` | `#1a1520` | `#1d1412` | `#0f1418` |
| `l` wing shine |  | `#ffffff` |  |  |  |  |  |  |  |  |
| `b` beak, legs |  |  |  |  |  | `#f5a623` |  |  |  |  |

The parrot (an orange-fronted conure) has letters of its own: `o` `#16201a`, `G` `#5aa838`, `D` `#2f7d2c`, `H` `#3b8540`, `C` `#2f7a62`, `P` `#f26a3d`, `E` `#f1e9a6`, `K` `#16161a`, `W` `#ead9c8`, `T` `#7c8a3a`, `L` `#bccf3a`, `B` `#2b4a8c`, `O` `#4f9a30`, `F` `#8f8a86`. See its comment in `KIND_COLORS` for what each one paints.

A brand-new character needs a sheet here, a palette in `KIND_COLORS`, hat
spots in `KIND_ANCHORS` and `KIND_HEADPHONES_AT` (`Tools/sprites.py`) and
a case in `PetKind` (`Sources/Pixpaw/CatSprites.swift`).
