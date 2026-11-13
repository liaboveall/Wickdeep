"""Actor sprites: player, enemies, bosses, NPCs, portraits."""

import math
import random

from canvas import Canvas, Sheet, ascii_canvas, col
from palette import rgba

# --------------------------------------------------------------------------
# Player: the lamplighter (16x16, faces right; the engine flips for left)
# --------------------------------------------------------------------------
PLAYER_LEGEND = {
    "h": "teal2", "H": "teal3", "d": "teal1", "f": "ink", "e": "cream",
    "s": "orange", "S": "amber", "r": "brown2",
    "C": "teal2", "L": "teal3", "c": "teal1", "g": "bone2",
    "b": "brown1", "B": "brown3",
}

PLAYER_BODY = [
    "................",
    "................",
    "......hhhh......",
    ".....hHHHHh.....",
    "....hHHHhhhh....",
    "....hHhhffffh...",
    "....dhhfefefh...",
    "....ddhffffhh...",
    "...rsSSSSssr....",
    "..rsdCCLLCCc....",
    "..r.dCCLLCCcg...",
    "....dCCCLCCc....",
    "....dcCCCCcc....",
    ".....dccccc.....",
]

PLAYER_LEGS = {
    "stand": {14: ".....bB..bB.....", 15: ".....bb..bb....."},
    "strideA": {14: "....bB....bB....", 15: "...bb......bb..."},
    "pass": {13: "......bBb.......", 14: "......bBb.......", 15: "......bb........"},
    "strideB": {14: ".....Bb..bB.....", 15: "....bb....bb...."},
}


def player_frame(legs, body_dy=0, eyes=True, scarf_flip=False):
    c = Canvas(16, 16)
    rows = [""] * 16
    for y, r in PLAYER_LEGS[legs].items():
        rows[y] = r
    c.stamp(rows, PLAYER_LEGEND)
    body = list(PLAYER_BODY)
    if not eyes:
        body = [r.replace("e", "f") for r in body]
    if scarf_flip:
        body[9] = ".rsd" + body[9][4:]
        body[10] = "r..." + body[10][4:]
    c.stamp(body, PLAYER_LEGEND, 0, body_dy)
    return c.outline()


LANTERN_LEGEND = {"k": "bone1", "b": "brown1", "B": "brown3", "y": "amber", "o": "orange", "w": "gold", "W": "cream"}
LANTERN = [
    "...kkk...",
    "..k...k..",
    "..bBBBb..",
    ".bByyyBb.",
    ".bywWwyb.",
    ".byoWoyb.",
    ".byooyyb.",
    ".bBBBBBb.",
    "..bbbbb..",
]


def build_player(out, manifest, previews):
    s = Sheet("player", 16, 16)
    idle = [player_frame("stand"), player_frame("stand", 1)]
    run = [player_frame("strideA"), player_frame("pass", -1, scarf_flip=True),
           player_frame("strideB"), player_frame("pass", -1, scarf_flip=True)]
    hurt = [player_frame("stand", 1, eyes=False)]
    s.add("idle", idle, fps=3).add("run", run, fps=10).add("hurt", hurt, fps=1, loop=False)
    s.add("dash", [player_frame("strideA", 0, scarf_flip=True)], fps=1)
    previews += idle + run + hurt
    s.build(out, manifest)

    lan = Sheet("lantern", 9, 9)
    a = ascii_canvas(LANTERN, LANTERN_LEGEND)
    b_rows = [r.replace("W", "w") for r in LANTERN]
    b_rows[5] = ".byoWoyb."
    b_rows[4] = ".bywwwyb."
    b = ascii_canvas(b_rows, LANTERN_LEGEND)
    lan.add("burn", [a, b], fps=6)
    previews += [a, b]
    lan.build(out, manifest)


# --------------------------------------------------------------------------
# Enemies
# --------------------------------------------------------------------------
SLIME_LEGEND = {"a": "night3", "A": "night4", "W": "mist", "d": "night2", "e": "gold"}
SLIME_IDLE0 = [
    "", "", "", "", "", "", "", "",
    "......aaaa......",
    "....aaAAAAaa....",
    "...aAAWWAAAAa...",
    "..aAAWAAAAAAAa..",
    "..aAAAAAAeAeAa..",
    "..aaAAAAAAAAaa..",
    "..daaaaaaaaaad..",
    "...dddddddddd...",
]
SLIME_IDLE1 = [
    "", "", "", "", "", "", "", "", "",
    ".....aaaaaa.....",
    "...aaAAAAAAaa...",
    "..aAAWWAAAAAAa..",
    ".aAAWAAAAAAAAAa.",
    ".aAAAAAAAAeAeAa.",
    ".daaAAAAAAAAaad.",
    "..dddddddddddd..",
]
SLIME_JUMP = [
    "", "", "", "",
    ".......aa.......",
    ".....aaAAa......",
    "....aAAWAAa.....",
    "....aAWAAAa.....",
    "....aAAAeAea....",
    "....aAAAAAAa....",
    "....aAAAAAAa....",
    ".....aaAAaa.....",
    "......dddd......",
]

BAT_LEGEND = {"b": "night1", "B": "night2", "w": "night3", "W": "night4", "e": "blood3", "f": "bone2"}
BAT_UP = [
    "", "", "",
    ".w............w.",
    ".ww..........ww.",
    ".wWw...bb...wWw.",
    "..wWw.bBBb.wWw..",
    "..wWWbBBBBbWWw..",
    "...wbBeBBeBbw...",
    "....bBBBBBBb....",
    ".....bBffBb.....",
    "......bbbb......",
]
BAT_DOWN = [
    "", "", "", "", "",
    ".......bb.......",
    "......bBBb......",
    "..wwwbBBBBbwww..",
    ".wWWbBeBBeBbWWw.",
    "wWw.bBBBBBBb.wWw",
    "ww...bBffBb...ww",
    "w.....bbbb.....w",
]

ARCHER_LEGEND = {"v": "violet1", "V": "violet2", "k": "bone3", "K": "bone2", "j": "bone1",
                 "e": "blood3", "x": "ink"}
ARCHER_BODY = [
    "................",
    "......vVVv......",
    ".....vVVVVv.....",
    "....vVkkkkVv....",
    "....vkkkkkkv....",
    "....vkeKKekv....",
    "....vVkkkkkv....",
    ".....vkjxjk.....",
    "....vvjKKjvv....",
    "...vVkKjKjKkv...",
    "...vVjKjKjKjv...",
    "....vkKjKjKk....",
    ".....vjKKjv.....",
    "......jjjj......",
]
ARCHER_LEGS = [
    {14: ".....K....K.....", 15: ".....j....j....."},
    {14: "......K..K......", 15: "......j..j......"},
]


def archer_frame(legs_i, mode):
    c = Canvas(16, 16)
    rows = [""] * 16
    for y, r in ARCHER_LEGS[legs_i].items():
        rows[y] = r
    c.stamp(rows, ARCHER_LEGEND)
    c.stamp(ARCHER_BODY, ARCHER_LEGEND)
    wood, wood_hl, string = col("brown2"), col("brown3"), col("fog")
    arc = [(12, 3), (13, 4), (13, 5), (14, 6), (14, 7), (14, 8), (13, 9), (13, 10), (12, 11)]
    if mode == "aim":
        arc = [(x + 1, y) for x, y in arc]
    for i, (x, y) in enumerate(arc):
        c.put(x, y, wood_hl if i in (3, 4) else wood)
    if mode == "aim":
        c.line(13, 3, 10, 7, string)
        c.line(10, 7, 13, 11, string)
        c.line(9, 7, 15, 7, col("bone3"))
        c.put(15, 7, col("stone4"))
        c.line(11, 9, 12, 8, col("bone2"))
    else:
        c.line(12, 3, 12, 11, string)
        c.line(11, 9, 12, 8, col("bone2"))
    return c.outline()


WISP_LEGEND = {"v": "violet1", "V": "violet2", "P": "violet3", "p": "violet4", "x": "ink", "e": "cream"}
WISP_BASE = [
    ".......p........",
    "......pP........",
    "......PPv.......",
    ".....vVPPv......",
    "....vVxxxVv.....",
    "....vxexexVv....",
    "....vVxxxVVv....",
    "...vVVVPVVVv....",
    "..vVVPPpPPVVv...",
    "..vVPPpppPPVv...",
    "...vVPPpPPVv....",
    "....vVVPVVv.....",
    ".....vVVVv......",
    "......vVv.......",
    ".......v........",
    "................",
]


def wisp_frame(i, cast=False):
    rows = list(WISP_BASE)
    if i == 1:
        rows[0] = "......p........."
        rows[1] = "......Pp........"
        rows[13] = ".....vVv........"
        rows[14] = "......v........."
    elif i == 2:
        rows[0] = "........p......."
        rows[13] = ".......vVv......"
        rows[14] = "........v......."
    if cast:
        rows = [r.replace("P", "p") if 7 <= j <= 10 else r for j, r in enumerate(rows)]
    return ascii_canvas(rows, WISP_LEGEND)


KNIGHT_LEGEND = {"a": "stone1", "A": "stone2", "B": "stone3", "C": "stone4", "e": "blood3", "E": "blood4",
                 "r": "blood2", "R": "blood1", "x": "ink"}
KNIGHT_TOP = [
    "....................",
    ".......rr...........",
    "......rRrr..........",
    ".......aAAAa........",
    "......aABBBAa.......",
    "......aABCCBAa......",
    "......aAxxeEAa......",
    "......aABBBBAa......",
    "......xaAAAAax......",
    "....RraABBBBAar.....",
    "...RraABBCCBBAa.....",
    "...RraABBBBBBAa.....",
    "...RraAABBBBAAa.....",
    "....RaAAAAAAAAa.....",
    ".....aaABBBBAaa.....",
]
KNIGHT_LEGS = [
    {15: ".....aAAa..aAAa.....", 16: ".....aBa....aBa.....", 17: ".....aBa....aBa.....",
     18: "....aABa....aABa...."},
    {15: "......aAAaaAAa......", 16: "......aBa.aBa.......", 17: ".....aBa...aBa......",
     18: "....aABa...aABa....."},
]


def knight_frame(legs_i, mode="walk"):
    c = Canvas(20, 20)
    rows = [""] * 20
    for y, r in KNIGHT_LEGS[legs_i].items():
        rows[y] = r
    c.stamp(rows, KNIGHT_LEGEND)
    top = list(KNIGHT_TOP)
    if mode == "stun":
        top = [r.replace("e", "A").replace("E", "A") for r in top]
    dy = 1 if mode == "windup" else 0
    dx = 1 if mode == "charge" else 0
    c.stamp(top, KNIGHT_LEGEND, dx, dy)
    blade, blade_hl, hilt = col("stone4"), col("white"), col("brown2")
    if mode == "charge":
        c.line(13, 11, 19, 11, blade)
        c.line(14, 10, 18, 10, blade_hl)
        c.rect(12, 10, 1, 3, hilt)
    elif mode == "windup":
        c.line(14, 2, 14, 10, blade)
        c.line(15, 3, 15, 9, blade_hl)
        c.rect(13, 11, 3, 1, hilt)
    else:
        c.line(15, 9, 15, 17, blade)
        c.line(16, 10, 16, 16, blade_hl)
        c.rect(14, 9, 3, 1, hilt)
    return c.outline()


POD_LEGEND = {"m": "moss1", "M": "moss2", "n": "moss3", "N": "moss4", "v": "violet2", "V": "violet3",
              "x": "ink", "y": "gold"}
POD_BASE = [
    "................",
    "................",
    "................",
    "......nnnn......",
    "....nnNNNNnn....",
    "...nNNVNNNNNn...",
    "...nNVVNNVNNn...",
    "..nNNNNNNVVNNn..",
    "..nNNxxxxxxNNn..",
    "..nNxxxxxxxxNn..",
    "..MnNxxxxxxNnM..",
    "...MnNNNNNNnM...",
    "..MM.MnnnnM.MM..",
    ".MmM..MMMM..MmM.",
    "mMm...mMMm...mMm",
    ".mm...mmmm...mm.",
]


def pod_frame(mode):
    rows = list(POD_BASE)
    if mode == "squash":
        rows = rows[:3] + [""] + rows[3:11] + rows[12:]
        rows = rows[:16]
    if mode == "open":
        rows[8] = "..nNxxxxxxxxNn.."
        rows[9] = "..nxxyxxxxyxxn.."
        rows[10] = "..MnxxxyyxxxnM.."
    return ascii_canvas(rows, POD_LEGEND)


SHADE_LEGEND = {"s": "ink", "S": "night1", "w": "fog", "v": "violet2"}
SHADE_A = [
    "............",
    "............",
    ".....ss.....",
    "...ssSSss...",
    "..sSSSSSSs..",
    "..sSwSSwSs..",
    ".sSSSSSSSSs.",
    ".sSSSvvSSSs.",
    ".sSSSSSSSs..",
    "..sSsSSsSs..",
    "..s..s..s...",
    "............",
]
SHADE_B = [
    "............",
    "............",
    "....ss......",
    "...ssSSss...",
    "..sSSSSSSs..",
    "..sSwSSwSs..",
    ".sSSSSSSSSs.",
    ".sSSSvvSSSs.",
    "..sSSSSSSSs.",
    "..sSsSSsSs..",
    "...s..s..s..",
    "............",
]


# --------------------------------------------------------------------------
# Procedural helpers for large sprites
# --------------------------------------------------------------------------
def shaded_blob(c, cx, cy, rx, ry, ramp, seed=0, light=(-0.55, -0.8)):
    """Fill an ellipse with a 4-step colour ramp lit from the top-left."""
    rnd = random.Random(seed)
    lx, ly = light
    for y in range(c.h):
        for x in range(c.w):
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            k = -(nx * lx + ny * ly) * 0.75 + (1 - d) * 0.45 + rnd.uniform(-0.06, 0.06)
            idx = 0 if k < 0.05 else 1 if k < 0.42 else 2 if k < 0.78 else 3
            c.put(x, y, ramp[idx])


def build_matron(out, manifest, previews):
    """Moss Matron: a giant mossy slime with mushrooms (40x32)."""
    ramp = [col("moss1"), col("moss2"), col("moss3"), col("moss4")]

    def frame(rx, ry, cy, eyes_open=True, mouth=False):
        c = Canvas(40, 32)
        shaded_blob(c, 20, cy, rx, ry, ramp, seed=7)
        # darker base band
        for x in range(40):
            for y in range(31, 0, -1):
                if c.opaque(x, y):
                    c.put(x, y, "moss0")
                    if c.opaque(x, y - 1):
                        c.put(x, y - 1, "moss1")
                    break
        top = int(cy - ry)
        # moss tufts + mushrooms on top
        rnd = random.Random(3)
        for i in range(9):
            tx = int(20 - rx * 0.7 + i * rx * 0.175)
            for y in range(32):
                if c.opaque(tx, y):
                    c.put(tx, y - 1, "moss4")
                    if i % 2 == 0:
                        c.put(tx, y - 2, "moss3")
                    break
        for mx, h, cap in ((13, 3, "blood3"), (25, 4, "amber"), (30, 2, "blood3")):
            for y in range(32):
                if c.opaque(mx, y):
                    c.rect(mx, y - h, 1, h, "bone3")
                    c.rect(mx - 2, y - h - 2, 5, 2, cap)
                    c.put(mx - 1, y - h - 2, "cream")
                    break
        ey = int(cy - ry * 0.05)
        for ex in (14, 24):
            if eyes_open:
                c.rect(ex, ey, 3, 3, "ink")
                c.put(ex + 1, ey, "gold")
                c.put(ex, ey, "cream")
            else:
                c.rect(ex, ey + 1, 3, 1, "ink")
        if mouth:
            c.ellipse(20, ey + 6, 4, 2.5, "moss0")
            c.rect(18, ey + 5, 1, 1, "bone3")
            c.rect(21, ey + 5, 1, 1, "bone3")
        else:
            c.rect(17, ey + 5, 6, 1, "moss0")
        # highlight shine
        c.put(int(20 - rx * 0.55), int(cy - ry * 0.55), "cream")
        c.put(int(20 - rx * 0.55) + 1, int(cy - ry * 0.55), "moss4")
        _ = top
        return c.outline()

    s = Sheet("matron", 40, 32)
    idle = [frame(17, 12, 19), frame(18, 11, 20)]
    crouch = [frame(19.5, 9, 22, eyes_open=True, mouth=True)]
    jump = [frame(14, 14.5, 16, eyes_open=True, mouth=True)]
    s.add("idle", idle, fps=3).add("crouch", crouch, fps=1).add("jump", jump, fps=1)
    previews += idle + crouch + jump
    s.build(out, manifest)


def build_snuffer(out, manifest, previews):
    """The Snuffer: a robed giant with a candle-snuffer bell for a head (48x48)."""

    def frame(bob=0, arms="down", eyes="glow", sway=0):
        c = Canvas(48, 48)
        oy = bob
        # robe body (trapezoid) with violet trim
        robe = [(16, 18 + oy), (32, 18 + oy), (38 + sway, 45), (10 + sway, 45)]
        c.poly(robe, "night1")
        c.poly([(18, 19 + oy), (30, 19 + oy), (34 + sway, 44), (14 + sway, 44)], "night2")
        c.poly([(21, 20 + oy), (27, 20 + oy), (29 + sway, 43), (19 + sway, 43)], "night1")
        for x in range(10, 40):
            for y in range(44, 46):
                if c.opaque(x, y):
                    c.put(x, y, "violet2" if (x + y) % 3 else "violet3")
        # tattered hem
        for x in range(11 + sway, 38 + sway, 3):
            c.put(x, 46, "night1")
        # wax drips on shoulders
        for dx, dl in ((17, 4), (20, 2), (29, 3), (31, 5)):
            c.rect(dx, 18 + oy, 1, dl, "bone3")
            c.put(dx, 18 + oy + dl, "cream")
        # arms
        if arms == "up":
            c.line(16, 20 + oy, 8, 9 + oy, "night2")
            c.line(17, 21 + oy, 9, 10 + oy, "night1")
            c.line(32, 20 + oy, 40, 9 + oy, "night2")
            c.line(31, 21 + oy, 39, 10 + oy, "night1")
            hands = [(8, 8 + oy), (40, 8 + oy)]
        elif arms == "forward":
            c.line(32, 22 + oy, 43, 24 + oy, "night2")
            c.line(31, 23 + oy, 42, 25 + oy, "night1")
            c.line(16, 22 + oy, 11, 30 + oy, "night2")
            hands = [(44, 24 + oy), (10, 31 + oy)]
        else:
            c.line(16, 21 + oy, 11, 34 + oy, "night2")
            c.line(17, 21 + oy, 12, 34 + oy, "night1")
            c.line(32, 21 + oy, 37, 34 + oy, "night2")
            c.line(31, 21 + oy, 36, 34 + oy, "night1")
            hands = [(11, 35 + oy), (37, 35 + oy)]
        for hx, hy in hands:
            c.rect(hx - 1, hy - 1, 3, 3, "bone2")
            c.put(hx - 1, hy + 2, "bone3")
            c.put(hx + 1, hy + 2, "bone3")
        # snuffer bell head on a long neck
        c.rect(23, 13 + oy, 2, 6, "stone2")
        bell = [(24, 1 + oy), (31, 13 + oy), (17, 13 + oy)]
        c.poly(bell, "stone2")
        c.poly([(24, 3 + oy), (29, 12 + oy), (24, 12 + oy)], "stone3")
        c.rect(16, 13 + oy, 16, 2, "stone1")
        c.rect(17, 13 + oy, 14, 1, "stone3")
        c.put(24, 0 + oy, "stone4")
        # handle / curl
        c.line(31, 13 + oy, 36, 10 + oy, "stone3")
        c.put(37, 9 + oy, "stone4")
        # hollow face under the bell rim with eyes
        c.rect(19, 15 + oy, 10, 3, "ink")
        if eyes == "glow":
            c.rect(20, 16 + oy, 2, 1, "violet4")
            c.rect(26, 16 + oy, 2, 1, "violet4")
        elif eyes == "bright":
            c.rect(20, 15 + oy, 2, 2, "cream")
            c.rect(26, 15 + oy, 2, 2, "cream")
        return c.outline()

    s = Sheet("snuffer", 48, 48)
    idle = [frame(0, "down", "glow", 0), frame(1, "down", "glow", 1)]
    cast = [frame(0, "up", "bright", 0)]
    charge = [frame(0, "forward", "bright", -1)]
    s.add("idle", idle, fps=2).add("cast", cast, fps=1).add("charge", charge, fps=1)
    previews += idle + cast + charge
    s.build(out, manifest)


# --------------------------------------------------------------------------
# NPCs
# --------------------------------------------------------------------------
GRANNY_LEGEND = {
    "p": "brown1", "P": "brown2", "q": "brown3",       # backpack
    "o": "orange", "y": "amber", "t": "teal3", "v": "violet3",  # trinkets
    "h": "blood1", "H": "blood2",                     # hood / shawl
    "s": "bone2", "S": "bone3", "n": "bone1",         # skin
    "e": "ink", "w": "cream",
    "g": "gold", "G": "amber", "k": "brown2",          # scale
    "r": "night2", "R": "night3",                     # skirt
}
GRANNY_A = [
    "....................",
    "......ty............",
    ".....pqqpo..........",
    "....pPqqPPp.........",
    "....pPPPPPpv........",
    "...pPqPPqPPp........",
    "...pPPPPPPPp.hh.....",
    "...pPPPqPPPphHHh....",
    "...pqPPPPPPhHSSHh...",
    "...pPPPPPPhHSewSs...",
    "...pPPqPPPhHSSSSsn..",
    "...pPPPPPPPhHsSSn...",
    "....pPPPPPhHHHss....",
    "....ppPPPhHHHHHhg...",
    ".....pppHHHHHHHhGg..",
    "........hHHHHHHhkgG.",
    ".........rRRRRrk.g..",
    "........rRRRRRRk....",
    "........rRRRRRRrk...",
    ".......rRRRRRRRrk...",
    ".......rrrrrrrrrk...",
    "........nn..nn..k...",
    "........SS..SS..k...",
    "....................",
]


def granny_frames():
    a = ascii_canvas(GRANNY_A, GRANNY_LEGEND)
    rows = [""] + GRANNY_A[:13] + GRANNY_A[14:]
    rows = rows[:24]
    b = ascii_canvas(rows, GRANNY_LEGEND)
    return [a, b]


def wick_frame(i):
    """The flame spirit Wick (14x16): 4 flicker frames."""
    c = Canvas(14, 16)
    sway = [0, 1, 0, -1][i]
    tip = [(7 + sway, 1), (8 + sway, 2), (6, 3)]
    # outer flame
    c.poly([(7 + sway, 0.5), (11.5, 7), (12, 11), (10, 14.5), (4, 14.5), (2, 11), (2.5, 7)], "orange")
    c.poly([(7 + sway * 0.5, 3), (10.5, 8), (10.5, 11.5), (9, 13.5), (5, 13.5), (3.5, 11.5), (3.5, 8)], "amber")
    c.poly([(7, 6), (9.5, 9.5), (9, 12.5), (5, 12.5), (4.5, 9.5)], "gold")
    for x, y in tip:
        c.put(x, y, "orange")
    # face
    c.put(5, 9, "ink")
    c.put(8, 9, "ink")
    c.put(5, 8, "brown1")
    c.put(8, 8, "brown1")
    c.rect(6, 11, 2, 1, "brown2")
    c.put(4, 10, "blood4")
    c.put(9, 10, "blood4")
    return c.outline(col("blood1"))


def build_npcs(out, manifest, previews):
    g = Sheet("granny", 20, 24)
    gf = granny_frames()
    g.add("idle", gf, fps=2)
    g.build(out, manifest)
    w = Sheet("wick", 14, 16)
    wf = [wick_frame(i) for i in range(4)]
    w.add("idle", wf, fps=8)
    w.build(out, manifest)
    previews += gf + wf


def build_portraits(out, manifest, previews):
    """40x40 dialogue portraits."""
    # Wick portrait: big friendly flame face
    wp = Canvas(40, 40)
    wp.poly([(20, 2), (31, 15), (34, 26), (30, 36), (10, 36), (6, 26), (9, 15)], "orange")
    wp.poly([(20, 8), (29, 18), (31, 27), (27, 34), (13, 34), (9, 27), (11, 18)], "amber")
    wp.poly([(20, 15), (26, 22), (27, 29), (24, 33), (16, 33), (13, 29), (14, 22)], "gold")
    wp.poly([(20, 21), (23, 26), (22, 31), (18, 31), (17, 26)], "cream")
    for ex in (14, 24):
        wp.rect(ex, 22, 3, 4, "ink")
        wp.put(ex + 1, 22, "white")
    wp.rect(17, 29, 6, 1, "brown1")
    wp.put(16, 28, "brown1")
    wp.put(23, 28, "brown1")
    wp.rect(11, 27, 2, 1, "blood4")
    wp.rect(27, 27, 2, 1, "blood4")
    wp.put(26, 5, "amber")
    wp.put(12, 9, "orange")
    wp.outline(col("blood1"))

    # Granny portrait: hooded old face with big nose and a monocle
    gp = Canvas(40, 40)
    gp.ellipse(20, 22, 15, 16, "blood1")
    gp.ellipse(20, 21, 13.5, 14.5, "blood2")
    gp.ellipse(21, 25, 9, 10, "bone2")
    gp.ellipse(20, 23, 7.5, 8, "bone3")
    gp.rect(12, 18, 17, 2, "blood1")      # hood shadow line
    gp.rect(15, 23, 3, 1, "bone0")        # brows
    gp.rect(24, 23, 3, 1, "bone0")
    gp.rect(16, 25, 2, 1, "ink")          # eyes
    gp.rect(24, 25, 2, 1, "ink")
    gp.ring(25, 25.5, 3.2, 2.2, "gold")   # monocle
    gp.put(28, 28, "amber")
    gp.line(28, 28, 30, 34, "amber")
    gp.poly([(20, 24), (23, 31), (19, 32)], "bone1")   # nose
    gp.put(21, 30, "bone3")
    gp.rect(17, 34, 7, 1, "bone0")        # mouth
    gp.put(18, 35, "bone3")               # one tooth
    gp.rect(9, 33, 4, 1, "bone1")
    gp.rect(28, 33, 3, 1, "bone1")
    for x, y, c_ in ((10, 10, "amber"), (29, 9, "teal3"), (31, 12, "violet3")):
        gp.rect(x, y, 2, 2, c_)
    gp.outline()

    s = Sheet("portraits", 40, 40)
    s.add("wick", [wp], fps=1).add("granny", [gp], fps=1)
    previews += [wp, gp]
    s.build(out, manifest)


def build_enemies(out, manifest, previews):
    sl = Sheet("slime", 16, 16)
    i0 = ascii_canvas(SLIME_IDLE0, SLIME_LEGEND, 16, 16)
    i1 = ascii_canvas(SLIME_IDLE1, SLIME_LEGEND, 16, 16)
    jp = ascii_canvas(SLIME_JUMP, SLIME_LEGEND, 16, 16)
    sl.add("idle", [i0, i1], fps=3).add("crouch", [i1], fps=1).add("jump", [jp], fps=1)
    sl.build(out, manifest)
    previews += [i0, i1, jp]

    bt = Sheet("bat", 16, 16)
    bu = ascii_canvas(BAT_UP, BAT_LEGEND, 16, 16)
    bd = ascii_canvas(BAT_DOWN, BAT_LEGEND, 16, 16)
    bt.add("fly", [bu, bd], fps=10)
    bt.build(out, manifest)
    previews += [bu, bd]

    ar = Sheet("archer", 16, 16)
    w0, w1 = archer_frame(0, "idle"), archer_frame(1, "idle")
    aim = archer_frame(0, "aim")
    ar.add("walk", [w0, w1], fps=5).add("aim", [aim], fps=1)
    ar.build(out, manifest)
    previews += [w0, w1, aim]

    ws = Sheet("wisp", 16, 16)
    wf = [wisp_frame(0), wisp_frame(1), wisp_frame(0), wisp_frame(2)]
    ws.add("float", wf, fps=8).add("cast", [wisp_frame(0, True), wisp_frame(1, True)], fps=10)
    ws.build(out, manifest)
    previews += wf[:2] + [wisp_frame(0, True)]

    kn = Sheet("knight", 20, 20)
    k0, k1 = knight_frame(0), knight_frame(1)
    kw, kc, ks = knight_frame(0, "windup"), knight_frame(0, "charge"), knight_frame(0, "stun")
    kn.add("walk", [k0, k1], fps=4).add("windup", [kw], fps=1).add("charge", [kc], fps=1).add("stun", [ks], fps=1)
    kn.build(out, manifest)
    previews += [k0, k1, kw, kc, ks]

    pd = Sheet("pod", 16, 16)
    p0, p1, po = pod_frame("idle"), pod_frame("squash"), pod_frame("open")
    pd.add("idle", [p0, p1], fps=2).add("open", [po], fps=1)
    pd.build(out, manifest)
    previews += [p0, p1, po]

    sh = Sheet("shade", 12, 12)
    sa = ascii_canvas(SHADE_A, SHADE_LEGEND).recolor({})
    sb = ascii_canvas(SHADE_B, SHADE_LEGEND)
    sa = ascii_canvas(SHADE_A, SHADE_LEGEND, outline=False).outline(col("violet1"))
    sb = ascii_canvas(SHADE_B, SHADE_LEGEND, outline=False).outline(col("violet1"))
    sh.add("move", [sa, sb], fps=8)
    sh.build(out, manifest)
    previews += [sa, sb]


def build_all(out, manifest, previews):
    build_player(out, manifest, previews)
    build_enemies(out, manifest, previews)
    build_matron(out, manifest, previews)
    build_snuffer(out, manifest, previews)
    build_npcs(out, manifest, previews)
    build_portraits(out, manifest, previews)
