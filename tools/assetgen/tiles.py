"""Tilesets (16x16) per biome, plus props and projectile / FX sheets.

Atlas layout (8 columns x 10 rows, shared by every biome; mirrored in src/world/tiles.gd):
  row 0      floor variants 0-7
  row 1      floor-with-shadow 0-3 (under a wall face) | floor decals 4-7
  row 2      wall face variants: 0-3 bricks, 4 torch bracket, 5 cracked, 6-7 biome specials
  row 3      wall top base 0-3 | rubble 4-5 (obstacles) | door bars 6 | spare 7
  rows 4-5   wall-top rim overlays for neighbour masks 0-15 (bit 1=N 2=E 4=S 8=W open)
  row 6      face side shading overlays: 0 left, 1 right, 2 both
  rows 7-8   stairs (2x2) at columns 0-1
  rows 7-9   carpet 3x3 at columns 2-4
"""

import math
import os
import random

from canvas import Canvas, Sheet, col, preview

T = 16

BIOMES = {
    "moss": {
        "floor": ["stone1", "stone2", "stone0", "stone3"],      # base, light, seam, highlight
        "accent": ["moss1", "moss2", "moss3"],
        "brick": ["stone2", "stone3", "stone1", "stone4"],      # base, light, mortar, rim
        "top": ["night1", "ink", "night2"],
        "rim": "stone3",
    },
    "ash": {
        "floor": ["brown1", "brown2", "brown0", "brown3"],
        "accent": ["bone0", "bone1", "stone2"],
        "brick": ["bone1", "bone2", "bone0", "bone3"],
        "top": ["brown0", "ink", "brown1"],
        "rim": "bone1",
    },
    "sanctum": {
        "floor": ["night2", "night3", "night1", "night4"],
        "accent": ["violet1", "violet2", "teal2"],
        "brick": ["night3", "night4", "night1", "mist"],
        "top": ["violet0", "ink", "violet1"],
        "rim": "violet2",
    },
    "camp": {
        "floor": ["brown1", "brown2", "brown0", "brown3"],
        "accent": ["brown1", "bone1", "moss2"],
        "brick": ["stone2", "stone3", "stone1", "stone4"],
        "top": ["night1", "ink", "night2"],
        "rim": "stone3",
    },
}


def mix(c1, c2, t):
    a, b = col(c1), col(c2)
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


# ---------------------------------------------------------------------------
# floors
# ---------------------------------------------------------------------------
def floor_tile(b, seed, planks=False):
    rnd = random.Random(seed)
    base, light, seam, hi = b["floor"]
    c = Canvas(T, T)
    c.rect(0, 0, T, T, base)
    if planks:
        # wooden planks: horizontal boards 4px tall with staggered joints
        for row in range(4):
            y = row * 4
            c.rect(0, y, T, 1, seam)
            joint = (rnd.randrange(3, 13) + row * 5) % 16
            c.rect(joint, y, 1, 4, seam)
            c.rect(0, y + 1, T, 1, light)
            for _ in range(2):
                c.put(rnd.randrange(T), y + rnd.randrange(2, 4), mix(base, seam, 0.5))
        return c
    # stone slabs: choose a layout of rectangles that tiles seamlessly (seams on top/left edges)
    layouts = [
        [(0, 0, 16, 16)],
        [(0, 0, 8, 16), (8, 0, 8, 16)],
        [(0, 0, 16, 8), (0, 8, 16, 8)],
        [(0, 0, 8, 8), (8, 0, 8, 8), (0, 8, 8, 8), (8, 8, 8, 8)],
        [(0, 0, 10, 7), (10, 0, 6, 7), (0, 7, 6, 9), (6, 7, 10, 9)],
        [(0, 0, 6, 10), (6, 0, 10, 10), (0, 10, 16, 6)],
    ]
    for (x, y, w, h) in layouts[seed % len(layouts)]:
        tone = rnd.choice([base, base, mix(base, light, 0.35), mix(base, seam, 0.25)])
        c.rect(x, y, w, h, tone)
        c.rect(x, y, w, 1, seam)
        c.rect(x, y, 1, h, seam)
        c.rect(x + 1, y + 1, w - 1, 1, mix(tone, hi, 0.35))     # top-left bevel
        c.rect(x + 1, y + 1, 1, h - 1, mix(tone, hi, 0.2))
        for _ in range(w * h // 18):
            c.put(x + rnd.randrange(1, w), y + rnd.randrange(1, h), mix(tone, seam, 0.45))
        if rnd.random() < 0.35:
            c.put(x + rnd.randrange(2, max(3, w)), y + rnd.randrange(2, max(3, h)), mix(tone, hi, 0.6))
    return c


def floor_decal(b, kind, seed):
    rnd = random.Random(seed)
    c = floor_tile(b, seed + 11)
    a0, a1, a2 = b["accent"]
    if kind == 0:     # crack
        x, y = rnd.randrange(3, 7), rnd.randrange(3, 6)
        for _ in range(9):
            c.put(x, y, b["floor"][2])
            x += rnd.choice([1, 1, 0])
            y += rnd.choice([1, 0, 1])
            if rnd.random() < 0.3:
                c.put(x + 1, y - 1, b["floor"][2])
    elif kind == 1:   # moss / ash patch
        for _ in range(26):
            ang, r = rnd.uniform(0, 6.28), rnd.uniform(0, 5)
            c.put(8 + math.cos(ang) * r, 9 + math.sin(ang) * r * 0.7, rnd.choice([a0, a1, a1, a2]))
    elif kind == 2:   # bones
        c.rect(4, 9, 7, 1, "bone2")
        c.rect(3, 8, 2, 3, "bone3")
        c.rect(10, 8, 2, 3, "bone3")
        c.rect(9, 4, 4, 3, "bone3")    # small skull
        c.put(10, 5, "ink")
        c.put(12, 5, "ink")
        c.rect(10, 7, 2, 1, "bone1")
    else:             # pebbles / candle stub
        for _ in range(4):
            px, py = rnd.randrange(2, 14), rnd.randrange(3, 14)
            c.rect(px, py, 2, 1, b["floor"][3])
            c.put(px, py + 1, b["floor"][2])
        c.rect(11, 6, 2, 3, "bone3")
        c.put(11, 5, "amber")
    return c


def shadow_floor(b, seed):
    c = floor_tile(b, seed)
    dark = col("ink")
    for y in range(6):
        t = [0.62, 0.5, 0.38, 0.26, 0.15, 0.07][y]
        for x in range(T):
            p = c.get(x, y)
            c.put(x, y, mix(p, dark, t))
    return c


# ---------------------------------------------------------------------------
# walls
# ---------------------------------------------------------------------------
def face_tile(b, variant, biome, seed):
    rnd = random.Random(seed)
    base, light, mortar, rim = b["brick"]
    c = Canvas(T, T)
    c.rect(0, 0, T, T, mortar)
    # bricks: rows 4px tall, staggered
    for row in range(4):
        y = row * 4
        off = 0 if row % 2 == 0 else 4
        for bx in range(-8, 16, 8):
            x = bx + off
            tone = rnd.choice([base, base, mix(base, light, 0.4), mix(base, mortar, 0.3)])
            c.rect(x + 1, y + 1, 7, 3, tone)
            c.rect(x + 1, y + 1, 7, 1, mix(tone, light, 0.55))
            if rnd.random() < 0.3:
                c.put(x + rnd.randrange(2, 7), y + 2, mix(tone, mortar, 0.6))
    c.rect(0, 0, T, 1, rim)                                  # top edge catches the light
    c.rect(0, 15, T, 1, mix(mortar, "ink", 0.5))            # base shadow
    if variant == 4:   # torch bracket
        c.rect(7, 6, 2, 6, "stone1")
        c.rect(6, 10, 4, 2, "stone0")
        c.rect(6, 5, 4, 1, "stone3")
    elif variant == 5:  # cracked
        x, y = 4, 1
        for _ in range(12):
            c.put(x, y, "ink")
            x += rnd.choice([0, 1])
            y += 1
    elif variant in (6, 7):
        if biome == "moss":     # hanging vines
            for vx in ([3, 8, 12] if variant == 6 else [5, 10]):
                ln = rnd.randrange(6, 14)
                for vy in range(ln):
                    c.put(vx + (1 if vy % 5 == 4 else 0), vy, "moss2" if vy % 3 else "moss3")
                c.put(vx, ln, "moss4")
        elif biome == "ash":    # bookshelf
            c.rect(1, 1, 14, 14, "brown1")
            c.rect(1, 1, 14, 1, "brown3")
            c.rect(1, 8, 14, 1, "brown2")
            books = ["blood2", "teal2", "moss2", "violet2", "amber", "bone2", "brown3"]
            for shelf_y in (2, 9):
                x = 2
                while x < 14:
                    w = rnd.choice([1, 1, 2])
                    h = rnd.choice([5, 6, 6])
                    c.rect(x, shelf_y + (6 - h), w, h, rnd.choice(books))
                    x += w + (1 if rnd.random() < 0.2 else 0)
        elif biome == "sanctum":
            if variant == 6:    # banner
                c.rect(4, 0, 8, 13, "violet1")
                c.rect(5, 0, 6, 12, "violet2")
                c.rect(7, 3, 2, 5, "amber")
                c.rect(6, 5, 4, 1, "amber")
                c.put(4, 13, "violet1")
                c.put(11, 13, "violet1")
            else:               # stained glass window
                c.rect(4, 2, 8, 11, "ink")
                c.rect(5, 3, 6, 9, "teal3")
                c.rect(5, 3, 3, 4, "violet3")
                c.rect(8, 7, 3, 5, "amber")
                c.rect(7, 3, 1, 9, "ink")
                c.rect(5, 7, 6, 1, "ink")
        else:                   # camp: lantern hook / cloth
            c.rect(6, 2, 4, 9, "blood2")
            c.rect(6, 2, 4, 1, "blood3")
            c.rect(7, 4, 2, 4, "amber")
    return c


def top_base(b, seed):
    rnd = random.Random(seed)
    t0, t1, t2 = b["top"]
    c = Canvas(T, T)
    c.rect(0, 0, T, T, t0)
    for _ in range(14):
        c.put(rnd.randrange(T), rnd.randrange(T), rnd.choice([t1, t2]))
    return c


def rim_overlay(b, mask):
    c = Canvas(T, T)
    r = b["rim"]
    d = mix(b["top"][2], r, 0.4)
    if mask & 1:
        c.rect(0, 0, T, 1, r)
        c.rect(0, 1, T, 1, d)
    if mask & 2:
        c.rect(15, 0, 1, T, r)
        c.rect(14, 0, 1, T, d)
    if mask & 4:
        c.rect(0, 15, T, 1, r)
        c.rect(0, 14, T, 1, d)
    if mask & 8:
        c.rect(0, 0, 1, T, r)
        c.rect(1, 0, 1, T, d)
    return c


def face_side(which):
    c = Canvas(T, T)
    sh = (0, 0, 0, 110)
    if which in (0, 2):
        c.rect(0, 0, 2, T, sh)
    if which in (1, 2):
        c.rect(14, 0, 2, T, sh)
    return c


def rubble(b, seed):
    rnd = random.Random(seed)
    c = Canvas(T, T)
    base, light, mortar, rim = b["brick"]
    for _ in range(5):
        cx, cy = rnd.uniform(4, 12), rnd.uniform(6, 12)
        r = rnd.uniform(2.2, 4.2)
        c.ellipse(cx, cy, r, r * 0.8, base)
        c.ellipse(cx - 0.8, cy - 0.8, r * 0.6, r * 0.45, light)
    c.outline()
    return c


def door_bars(b):
    c = Canvas(T, T)
    c.rect(0, 12, T, 3, "stone0")
    c.rect(0, 12, T, 1, "stone3")
    for x in (2, 6, 10, 14):
        c.rect(x - 1, 0, 2, 13, "stone1")
        c.rect(x - 1, 0, 1, 13, "stone3")
        c.rect(x - 1, 0, 2, 1, "amber")
    c.rect(0, 4, T, 1, "stone1")
    return c


def stairs(b):
    c = Canvas(32, 32)
    base, light, seam, hi = b["floor"]
    c.rect(0, 0, 32, 32, seam)
    for i in range(6):
        y = 4 + i * 4
        shade = mix(light, "ink", i / 6.5)
        c.rect(3 + i, y, 26 - 2 * i, 4, shade)
        c.rect(3 + i, y, 26 - 2 * i, 1, mix(shade, hi, 0.5))
    c.rect(0, 0, 32, 3, mix(base, seam, 0.3))
    c.rect(0, 0, 3, 32, mix(base, seam, 0.3))
    c.rect(29, 0, 3, 32, mix(base, seam, 0.3))
    c.rect(9, 28, 14, 4, "ink")
    return c


def carpet(b):
    c = Canvas(48, 48)
    c.rect(0, 0, 48, 48, "blood2")
    c.frame(1, 1, 46, 46, "amber")
    c.frame(3, 3, 42, 42, "blood1")
    for y in range(6, 42, 6):
        for x in range(6, 42, 6):
            c.put(x, y, "blood3")
    c.frame(0, 0, 48, 48, "blood1")
    return c


def build_biome(name, out, manifest, previews_dir):
    b = BIOMES[name]
    atlas = Canvas(8 * T, 10 * T)
    planks = name == "camp"
    for i in range(8):
        atlas.blit(floor_tile(b, i * 7 + 1, planks), i * T, 0)
    for i in range(4):
        atlas.blit(shadow_floor(b, i * 7 + 1) if not planks else shadow_floor_planks(b, i), i * T, T)
        atlas.blit(floor_decal(b, i, i * 13 + 5) if not planks else floor_tile(b, 40 + i, True), (4 + i) * T, T)
    for v in range(8):
        atlas.blit(face_tile(b, v, name, v * 17 + 3), v * T, 2 * T)
    for i in range(4):
        atlas.blit(top_base(b, i * 5 + 2), i * T, 3 * T)
    atlas.blit(rubble(b, 1), 4 * T, 3 * T)
    atlas.blit(rubble(b, 2), 5 * T, 3 * T)
    atlas.blit(door_bars(b), 6 * T, 3 * T)
    for m in range(16):
        atlas.blit(rim_overlay(b, m), (m % 8) * T, (4 + m // 8) * T)
    for s in range(3):
        atlas.blit(face_side(s), s * T, 6 * T)
    atlas.blit(stairs(b), 0, 7 * T)
    atlas.blit(carpet(b), 2 * T, 7 * T)
    atlas.save(os.path.join(out, f"tiles_{name}.png"))
    manifest[f"tiles_{name}"] = {"file": f"tiles_{name}.png", "w": T, "h": T, "cols": 8, "rows": 10}
    # composed preview: a little room so the tiles can be judged together
    room = sample_room(atlas)
    preview([atlas, room], os.path.join(previews_dir, f"tiles_{name}.png"), scale=4)


def shadow_floor_planks(b, i):
    c = floor_tile(b, i * 7 + 1, True)
    dark = col("ink")
    for y in range(6):
        t = [0.62, 0.5, 0.38, 0.26, 0.15, 0.07][y]
        for x in range(T):
            c.put(x, y, mix(c.get(x, y), dark, t))
    return c


def sample_room(atlas):
    """Assemble a 12x9 tile mock room from the atlas (preview only)."""
    W, H = 12, 9
    grid = [[1 if (x in (0, W - 1) or y in (0, 1, H - 1)) else 0 for x in range(W)] for y in range(H)]
    grid[4][4] = grid[4][7] = 1
    grid[3][4] = grid[3][7] = 1
    out = Canvas(W * T, H * T)

    def tile(cx, cy):
        c = Canvas(T, T)
        c.a = atlas.a[cy * T:(cy + 1) * T, cx * T:(cx + 1) * T].copy()
        return c

    rnd = random.Random(4)
    for y in range(H):
        for x in range(W):
            wall = grid[y][x]
            below = grid[y + 1][x] if y + 1 < H else 1
            above = grid[y - 1][x] if y > 0 else 1
            if not wall:
                if above and grid[y - 1][x] and (y - 1 >= 0):
                    out.blit(tile(rnd.randrange(4), 1), x * T, y * T)
                else:
                    out.blit(tile(rnd.randrange(8), 0), x * T, y * T)
            elif not below:
                out.blit(tile(rnd.choice([0, 1, 2, 3, 4, 6]), 2), x * T, y * T)
            else:
                out.blit(tile(rnd.randrange(4), 3), x * T, y * T)
                m = 0
                for bit, (dx, dy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0))):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H:
                        n_wall = grid[ny][nx]
                        n_face = n_wall and (ny + 1 < H and not grid[ny + 1][nx])
                        if not n_wall or n_face:
                            m |= bit
                out.blit(tile(m % 8, 4 + m // 8), x * T, y * T)
    return out


# ---------------------------------------------------------------------------
# props
# ---------------------------------------------------------------------------
def build_props(out, manifest, previews):
    # torch flame (8x12, 4 frames)
    torch = Sheet("torch", 8, 12)
    frames = []
    for i in range(4):
        c = Canvas(8, 12)
        sway = [0, 1, 0, -1][i]
        h = [0, 1, 0, 1][i]
        c.poly([(4 + sway, 1 + h), (7, 7), (6, 11), (2, 11), (1, 7)], "orange")
        c.poly([(4 + sway * 0.5, 4 + h), (6, 8), (5, 10.5), (3, 10.5), (2, 8)], "amber")
        c.rect(3, 8, 2, 2, "cream")
        frames.append(c)
    torch.add("burn", frames, fps=9)
    torch.build(out, manifest)
    previews += frames

    camp = Sheet("campfire", 24, 24)
    cf = []
    for i in range(4):
        c = Canvas(24, 24)
        # logs + stones
        for k, (x, y) in enumerate(((3, 19), (7, 21), (12, 22), (17, 21), (20, 19))):
            c.ellipse(x + 0.5, y + 0.5, 2.2, 1.6, "stone2" if k % 2 else "stone3")
        c.line(5, 20, 18, 16, "brown2")
        c.line(5, 21, 18, 17, "brown1")
        c.line(6, 16, 19, 20, "brown2")
        c.line(6, 17, 19, 21, "brown1")
        sway = [0, 1, 0, -1][i]
        c.poly([(12 + sway, 3 + (i % 2)), (17, 12), (16, 18), (8, 18), (7, 12)], "orange")
        c.poly([(12 + sway, 8), (15, 13), (14, 17), (10, 17), (9, 13)], "amber")
        c.rect(11, 14, 3, 3, "cream")
        c.put(8 + (i * 3) % 7, 4 + i, "amber")
        c.outline()
        cf.append(c)
    camp.add("burn", cf, fps=8)
    camp.build(out, manifest)
    previews += cf

    props = Sheet("props", 16, 16)

    def mk(fn):
        c = Canvas(16, 16)
        fn(c)
        return c.outline()

    def altar(c):
        c.rect(2, 10, 12, 5, "stone2")
        c.rect(2, 10, 12, 1, "stone4")
        c.rect(3, 6, 10, 4, "stone3")
        c.rect(3, 6, 10, 1, "stone4")
        c.rect(6, 7, 4, 2, "violet3")
        c.rect(7, 7, 2, 1, "violet4")

    def altar_used(c):
        altar(c)
        c.rect(6, 7, 4, 2, "stone1")

    def shrine(c, lit=True):
        c.rect(3, 11, 10, 4, "bone1")
        c.rect(3, 11, 10, 1, "bone2")
        for x, h in ((4, 5), (7, 7), (10, 4)):
            c.rect(x, 11 - h, 2, h, "bone3")
            if lit:
                c.rect(x, 11 - h - 2, 2, 2, "amber")
                c.put(x, 11 - h - 3, "orange")

    def pot(c):
        c.ellipse(8, 10, 5, 4.5, "brown2")
        c.ellipse(7, 9, 3.5, 3, "brown3")
        c.rect(5, 4, 6, 2, "brown1")
        c.rect(6, 4, 4, 1, "brown3")
        c.rect(5, 11, 6, 1, "brown1")

    def pot_broken(c):
        c.rect(3, 12, 4, 2, "brown2")
        c.rect(9, 11, 3, 3, "brown3")
        c.rect(6, 13, 3, 1, "brown1")

    def skulls(c):
        for x, y in ((3, 9), (8, 10), (6, 6)):
            c.rect(x, y, 5, 4, "bone3")
            c.put(x + 1, y + 1, "ink")
            c.put(x + 3, y + 1, "ink")
            c.rect(x + 1, y + 3, 3, 1, "bone1")

    def stall(c):
        c.rect(0, 8, 16, 7, "brown2")
        c.rect(0, 8, 16, 1, "brown3")
        c.rect(0, 9, 16, 2, "blood2")
        c.rect(2, 4, 3, 4, "amber")
        c.rect(7, 5, 2, 3, "teal3")
        c.rect(11, 3, 3, 5, "violet3")
        c.put(12, 2, "violet4")

    def pedestal(c):
        c.rect(4, 11, 8, 4, "stone2")
        c.rect(4, 11, 8, 1, "stone4")
        c.rect(5, 9, 6, 2, "stone3")

    def sign(c):
        c.rect(7, 8, 2, 7, "brown1")
        c.rect(2, 3, 12, 6, "brown2")
        c.rect(2, 3, 12, 1, "brown3")
        c.rect(4, 5, 8, 1, "brown0")
        c.rect(4, 7, 5, 1, "brown0")

    def bedroll(c):
        c.rect(2, 7, 12, 7, "teal2")
        c.rect(2, 7, 12, 1, "teal3")
        c.rect(2, 7, 4, 7, "bone2")
        c.rect(2, 7, 4, 1, "bone3")

    def barrel(c):
        c.ellipse(8, 9.5, 5.5, 6, "brown2")
        c.rect(3, 6, 11, 1, "stone2")
        c.rect(3, 12, 11, 1, "stone2")
        c.ellipse(8, 4.5, 4.5, 1.6, "brown3")
        c.rect(5, 8, 1, 3, "brown3")

    items = [("altar", altar), ("altar_used", altar_used), ("shrine", shrine),
             ("shrine_out", lambda c: shrine(c, False)), ("pot", pot), ("pot_broken", pot_broken),
             ("skulls", skulls), ("stall", stall), ("pedestal", pedestal), ("sign", sign),
             ("bedroll", bedroll), ("barrel", barrel)]
    for name, fn in items:
        f = mk(fn)
        props.add(name, [f], fps=1)
        previews.append(f)
    props.build(out, manifest)


# ---------------------------------------------------------------------------
# projectiles + FX
# ---------------------------------------------------------------------------
def build_fx(out, manifest, previews):
    def bolt(c, core, mid, edge, i):
        c.circle(4, 4, 3.4 if i == 0 else 3.0, edge)
        c.circle(4, 4, 2.4, mid)
        c.circle(4, 4, 1.2, core)
        if i == 1:
            c.put(1, 4, edge)
            c.put(7, 4, edge)

    sheets = {
        "bolt": [("orange", "amber", "cream")],
        "orb_violet": [("violet2", "violet3", "violet4")],
        "orb_red": [("blood2", "blood3", "blood4")],
        "orb_green": [("moss3", "moss4", "cream")],
        "orb_blue": [("teal2", "teal3", "teal4")],
    }
    for name, ((edge, mid, core),) in sheets.items():
        s = Sheet(name, 8, 8)
        fr = []
        for i in range(2):
            c = Canvas(8, 8)
            bolt(c, core, mid, edge, i)
            fr.append(c)
        s.add("spin", fr, fps=12)
        s.build(out, manifest)
        previews += fr

    arrow = Sheet("arrow", 12, 5)
    a = Canvas(12, 5)
    a.line(1, 2, 9, 2, "bone2")
    a.rect(9, 1, 2, 3, "stone4")
    a.put(11, 2, "white")
    a.rect(0, 1, 2, 1, "blood3")
    a.rect(0, 3, 2, 1, "blood3")
    arrow.add("fly", [a.outline()], fps=1)
    arrow.build(out, manifest)
    previews.append(a)

    wax = Sheet("wax", 8, 8)
    w = Canvas(8, 8)
    w.poly([(4, 0.5), (6.5, 5), (5, 7.5), (3, 7.5), (1.5, 5)], "bone3")
    w.rect(3, 4, 2, 2, "cream")
    wax.add("fall", [w.outline()], fps=1)
    wax.build(out, manifest)
    previews.append(w)

    shard = Sheet("shard", 6, 6)
    sh = Canvas(6, 6)
    sh.poly([(3, 0.5), (5.5, 3), (3, 5.5), (0.5, 3)], "amber")
    sh.put(3, 2, "cream")
    shard.add("spin", [sh], fps=1)
    shard.build(out, manifest)
    previews.append(sh)

    # hit spark 9x9, 4 frames
    spark = Sheet("spark", 9, 9)
    sf = []
    for i in range(4):
        c = Canvas(9, 9)
        r = 1 + i * 1.2
        colr = ["cream", "gold", "amber", "orange"][i]
        for k in range(8):
            ang = k * math.pi / 4
            x = 4 + math.cos(ang) * r
            y = 4 + math.sin(ang) * r
            c.put(round(x), round(y), colr)
        if i < 2:
            c.rect(3, 3, 3, 3, "cream" if i == 0 else "gold")
        sf.append(c)
    spark.add("pop", sf, fps=20, loop=False)
    spark.build(out, manifest)
    previews += sf

    # death puff 16x16, 5 frames
    puff = Sheet("puff", 16, 16)
    pf = []
    rnd = random.Random(9)
    blobs = [(rnd.uniform(-3, 3), rnd.uniform(-3, 3), rnd.uniform(2, 3.5)) for _ in range(6)]
    for i in range(5):
        c = Canvas(16, 16)
        grow = 1 + i * 0.55
        for bx, by, br in blobs:
            r = br * (1.25 - i * 0.18)
            if r <= 0.4:
                continue
            c.circle(8 + bx * grow, 8 + by * grow, r, ["fog", "mist", "night4", "night3", "night2"][i])
            c.circle(8 + bx * grow - 0.6, 8 + by * grow - 0.6, r * 0.5, ["white", "fog", "mist", "night4", "night3"][i])
        pf.append(c)
    puff.add("pop", pf, fps=14, loop=False)
    puff.build(out, manifest)
    previews += pf

    # explosion 32x32, 6 frames
    boom = Sheet("boom", 32, 32)
    bf = []
    for i in range(6):
        c = Canvas(32, 32)
        r = 5 + i * 2.4
        cols = [("cream", "gold"), ("gold", "amber"), ("amber", "orange"), ("orange", "blood3"),
                ("blood2", "night3"), ("night2", "night1")][i]
        c.circle(16, 16, r, cols[1])
        c.circle(16, 16, r * 0.6, cols[0])
        if i >= 3:
            c.circle(16, 16, r * 0.55, (0, 0, 0, 0))
            for k in range(10):
                ang = k * 0.63
                c.circle(16 + math.cos(ang) * r * 0.8, 16 + math.sin(ang) * r * 0.8, 1.8, cols[1])
        bf.append(c)
    boom.add("pop", bf, fps=16, loop=False)
    boom.build(out, manifest)
    previews += bf

    # dust 8x8, 3 frames
    dust = Sheet("dust", 8, 8)
    df = []
    for i in range(3):
        c = Canvas(8, 8)
        c.circle(4, 5, 2.6 - i * 0.6, ["fog", "mist", "night4"][i])
        c.circle(3.4, 4.4, 1.2 - i * 0.3, "white" if i == 0 else "fog")
        df.append(c)
    dust.add("pop", df, fps=12, loop=False)
    dust.build(out, manifest)
    previews += df

    # pickups: ember shard (8x8, 4 spin frames) and oil drop (8x8, 2 frames)
    ember = Sheet("ember", 8, 8)
    ef = []
    for i in range(4):
        c = Canvas(8, 8)
        w = [3, 2, 1, 2][i]
        c.poly([(4, 0.5), (4 + w, 4), (4, 7.5), (4 - w, 4)], "orange")
        if w > 1:
            c.poly([(4, 2), (4 + w - 1, 4), (4, 6), (4 - w + 1, 4)], "amber")
        c.put(4, 2, "cream")
        ef.append(c.outline(col("brown0")))
    ember.add("spin", ef, fps=10)
    ember.build(out, manifest)
    previews += ef

    oil = Sheet("oil", 10, 10)
    of = []
    for i in range(2):
        c = Canvas(10, 10)
        c.poly([(5, 0.5 + i * 0.5), (8.5, 6), (7.5, 9), (2.5, 9), (1.5, 6)], "amber")
        c.ellipse(5, 6.5, 2.5, 2, "gold")
        c.put(4, 5, "cream")
        of.append(c.outline(col("brown0")))
    oil.add("bob", of, fps=4)
    oil.build(out, manifest)
    previews += of


def build_all(out, manifest, previews, previews_dir):
    for name in BIOMES:
        build_biome(name, out, manifest, previews_dir)
    p = []
    build_props(out, manifest, p)
    build_fx(out, manifest, p)
    preview(p, os.path.join(previews_dir, "props_fx.png"), scale=5)
