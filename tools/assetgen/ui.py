"""UI art: health flames, panels, buttons, crosshair, relic icons, logo and a 5x7 pixel font."""

import math
import os

from canvas import Canvas, Sheet, col

# ---------------------------------------------------------------------------
# 5x7 pixel font (uppercase, digits, a few symbols) -> BMFont (.fnt) for Godot
# ---------------------------------------------------------------------------
GLYPHS = {
    "0": [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
    "1": ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "2": [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
    "3": ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "],
    "4": ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "],
    "5": ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "],
    "6": ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "],
    "7": ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
    "8": [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "],
    "9": [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "],
    "A": [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "B": ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
    "C": [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "],
    "D": ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
    "E": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
    "F": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
    "G": [" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ####"],
    "H": ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "I": ["###", " # ", " # ", " # ", " # ", " # ", "###"],
    "J": ["  ###", "   # ", "   # ", "   # ", "   # ", "#  # ", " ##  "],
    "K": ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
    "L": ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
    "M": ["#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #"],
    "N": ["#   #", "#   #", "##  #", "# # #", "#  ##", "#   #", "#   #"],
    "O": [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "P": ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
    "Q": [" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"],
    "R": ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
    "S": [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
    "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    "U": ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "V": ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "],
    "W": ["#   #", "#   #", "#   #", "# # #", "# # #", "# # #", " # # "],
    "X": ["#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #"],
    "Y": ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
    "Z": ["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"],
    "+": ["     ", "  #  ", "  #  ", "#####", "  #  ", "  #  ", "     "],
    "-": ["   ", "   ", "   ", "###", "   ", "   ", "   "],
    "x": ["     ", "     ", "#   #", " # # ", "  #  ", " # # ", "#   #"],
    "/": ["    #", "    #", "   # ", "  #  ", " #   ", "#    ", "#    "],
    "%": ["##  #", "##  #", "   # ", "  #  ", " #   ", "#  ##", "#  ##"],
    ".": [" ", " ", " ", " ", " ", " ", "#"],
    ",": ["  ", "  ", "  ", "  ", "  ", " #", "# "],
    ":": [" ", "#", " ", " ", " ", "#", " "],
    "!": ["#", "#", "#", "#", "#", " ", "#"],
    "?": [" ### ", "#   #", "    #", "   # ", "  #  ", "     ", "  #  "],
    "'": ["#", "#", " ", " ", " ", " ", " "],
    "(": [" #", "# ", "# ", "# ", "# ", "# ", " #"],
    ")": ["# ", " #", " #", " #", " #", " #", "# "],
    "*": ["     ", "# # #", " ### ", "#####", " ### ", "# # #", "     "],
    "_": ["     ", "     ", "     ", "     ", "     ", "#   #", "#####"],
}


def build_font(out, outlined):
    """Write pixel5x7[_o].png + .fnt. Outlined glyphs are 2px larger with a dark border."""
    pad = 1 if outlined else 0
    gh = 7 + pad * 2
    chars = sorted(GLYPHS.keys())
    cell_w = 5 + pad * 2 + 1
    cols = 16
    rows = (len(chars) + cols - 1) // cols
    W, H = 128, 64
    img = Canvas(W, H)
    lines = []
    name = "pixel5x7_o" if outlined else "pixel5x7"
    for i, ch in enumerate(chars):
        rows_ = GLYPHS[ch]
        w = max(len(r) for r in rows_)
        gx, gy = (i % cols) * cell_w, (i // cols) * (gh + 1)
        g = Canvas(w + pad * 2, gh)
        for y, r in enumerate(rows_):
            for x, c_ in enumerate(r):
                if c_ == "#":
                    g.put(x + pad, y + pad, "white")
        if outlined:
            g.outline(col("outline"), diagonal=True)
        img.blit(g, gx, gy)
        adv = w + 1
        lines.append(f"char id={ord(ch)} x={gx} y={gy} width={g.w} height={gh} xoffset={-pad} "
                     f"yoffset={-pad} xadvance={adv} page=0 chnl=15")
        if ch.isalpha():   # lowercase maps onto the same glyph
            lines.append(f"char id={ord(ch.lower())} x={gx} y={gy} width={g.w} height={gh} xoffset={-pad} "
                         f"yoffset={-pad} xadvance={adv} page=0 chnl=15")
    lines.append(f"char id=32 x=0 y={H - 1} width=0 height=0 xoffset=0 yoffset=0 xadvance=3 page=0 chnl=15")
    assert rows * (gh + 1) <= H
    img.save(os.path.join(out, f"{name}.png"))
    header = [
        f'info face="{name}" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
        f'padding=0,0,0,0 spacing=1,1 outline={pad}',
        f"common lineHeight=9 base=7 scaleW={W} scaleH={H} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(lines)}",
    ]
    with open(os.path.join(out, f"{name}.fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(header + lines) + "\n")
    return img


def text_canvas(text, scale=1, color="white"):
    """Render text with the 5x7 glyphs (used for the logo)."""
    w = sum(max(len(r) for r in GLYPHS[ch]) + 1 for ch in text if ch != " ") + text.count(" ") * 3
    c = Canvas(w * scale, 7 * scale)
    x = 0
    for ch in text:
        if ch == " ":
            x += 3
            continue
        rows = GLYPHS[ch]
        for y, r in enumerate(rows):
            for i, p in enumerate(r):
                if p == "#":
                    c.rect((x + i) * scale, y * scale, scale, scale, color)
        x += max(len(r) for r in rows) + 1
    return c


# ---------------------------------------------------------------------------
# HUD pieces
# ---------------------------------------------------------------------------
def flame_icon(state):
    """10x11 life flame: 'full', 'half' or 'empty'."""
    c = Canvas(11, 12)
    shape = [(5.5, 0.5), (9.5, 6), (9, 9.5), (7, 11.5), (4, 11.5), (2, 9.5), (1.5, 6)]
    inner = [(5.5, 4), (8, 7.5), (7.5, 10), (3.5, 10), (3, 7.5)]
    if state == "empty":
        c.poly(shape, "night2")
        c.poly(inner, "night1")
    else:
        c.poly(shape, "orange")
        c.poly(inner, "amber")
        c.rect(5, 8, 2, 2, "cream")
        if state == "half":
            for y in range(12):
                for x in range(6, 11):
                    if c.opaque(x, y):
                        c.put(x, y, "night2" if c.get(x, y)[:3] == col("orange")[:3] else "night1")
    return c.outline()


def panel(kind):
    """24x24 nine-slice frames (margin 6)."""
    c = Canvas(24, 24)
    if kind == "panel":
        c.rect(0, 0, 24, 24, "outline")
        c.rect(1, 1, 22, 22, "bone0")
        c.rect(2, 2, 20, 20, "night1")
        c.rect(3, 3, 18, 18, (30, 24, 42, 240))
        for x, y in ((1, 1), (21, 1), (1, 21), (21, 21)):
            c.rect(x, y, 2, 2, "amber")
        c.rect(2, 2, 20, 1, "night3")
    elif kind == "panel_dark":
        c.rect(0, 0, 24, 24, (12, 9, 18, 235))
        c.frame(0, 0, 24, 24, "night2")
    elif kind == "bubble":
        c.rect(1, 0, 22, 24, "outline")
        c.rect(0, 1, 24, 22, "outline")
        c.rect(1, 1, 22, 22, "cream")
        c.rect(2, 2, 20, 20, "white")
    else:  # buttons
        fill, top, border = {
            "btn": ("night2", "night3", "bone0"),
            "btn_hover": ("brown2", "brown3", "amber"),
            "btn_press": ("brown1", "brown2", "amber"),
            "btn_disabled": ("night1", "night1", "night2"),
        }[kind]
        c.rect(0, 0, 24, 24, "outline")
        c.rect(1, 1, 22, 22, border)
        c.rect(2, 2, 20, 20, fill)
        c.rect(2, 2, 20, 2, top)
        c.rect(2, 20, 20, 2, col("outline")[:3] + (90,))
    return c


def crosshair():
    c = Canvas(11, 11)
    for x, y in ((5, 0), (5, 1), (5, 9), (5, 10), (0, 5), (1, 5), (9, 5), (10, 5)):
        c.put(x, y, "cream")
    c.ring(5.5, 5.5, 3.4, 2.4, "amber")
    c.put(5, 5, "cream")
    return c.outline()


def cursor_arrow():
    rows = ["#.......", "##......", "#c#.....", "#cc#....", "#ccc#...", "#cccc#..", "#ccccc#.",
            "#ccc###.", "#c#c#...", "##..#c#.", "#...#c#.", ".....#.."]
    c = Canvas(8, 12)
    for y, r in enumerate(rows):
        for x, p in enumerate(r):
            if p == "#":
                c.put(x, y, "outline")
            elif p == "c":
                c.put(x, y, "cream")
    return c


def key_icon(letter):
    c = Canvas(11, 11)
    c.rect(0, 0, 11, 11, "outline")
    c.rect(1, 1, 9, 9, "bone2")
    c.rect(1, 8, 9, 2, "bone1")
    c.rect(1, 1, 9, 1, "bone3")
    t = text_canvas(letter, 1, "ink")
    c.blit(t, (11 - t.w) // 2, 2)
    return c


def ember_icon():
    c = Canvas(9, 9)
    c.poly([(4.5, 0.5), (8, 4.5), (4.5, 8.5), (1, 4.5)], "orange")
    c.poly([(4.5, 2), (6.5, 4.5), (4.5, 7), (2.5, 4.5)], "amber")
    c.put(4, 3, "cream")
    return c.outline(col("brown0"))


def rarity_frame(r):
    c = Canvas(20, 20)
    border = {"common": "bone1", "rare": "teal3", "legendary": "amber", "cursed": "blood3"}[r]
    c.rect(0, 0, 20, 20, "outline")
    c.rect(1, 1, 18, 18, border)
    c.rect(2, 2, 16, 16, "night1")
    return c


# ---------------------------------------------------------------------------
# relic icons (16x16)
# ---------------------------------------------------------------------------
def flame(c, x, y, s=1.0, cols=("orange", "amber", "cream")):
    c.poly([(x, y - 6 * s), (x + 3.5 * s, y), (x + 2.5 * s, y + 3 * s), (x - 2.5 * s, y + 3 * s), (x - 3.5 * s, y)],
           cols[0])
    c.poly([(x, y - 2.5 * s), (x + 2 * s, y + 0.5 * s), (x + 1.2 * s, y + 2.2 * s), (x - 1.2 * s, y + 2.2 * s),
            (x - 2 * s, y + 0.5 * s)], cols[1])
    c.put(x - 0.5, y + 1 * s, cols[2])


def icon(name):
    c = Canvas(16, 16)
    if name == "twin_wick":
        flame(c, 5, 8, 0.85)
        flame(c, 11, 8, 0.85)
        c.rect(3, 12, 10, 2, "bone2")
    elif name == "keen_spark":
        c.poly([(8, 1), (9.5, 6.5), (15, 8), (9.5, 9.5), (8, 15), (6.5, 9.5), (1, 8), (6.5, 6.5)], "gold")
        c.poly([(8, 4), (9, 7), (12, 8), (9, 9), (8, 12), (7, 9), (4, 8), (7, 7)], "cream")
    elif name == "quickburn":
        flame(c, 10, 9, 1.0)
        for y, l in ((5, 5), (8, 6), (11, 4)):
            c.rect(1, y, l, 1, "amber")
    elif name == "pierce":
        c.ring(9, 8, 5, 3.6, "teal3")
        c.line(1, 8, 14, 8, "cream")
        c.poly([(15, 8), (12, 5), (12, 11)], "cream")
    elif name == "ricochet":
        pts = [(1, 13), (5, 3), (9, 13), (13, 3)]
        for a, b in zip(pts, pts[1:]):
            c.line(*a, *b, "amber")
        c.circle(13.5, 3.5, 2, "orange")
        c.rect(0, 14, 16, 2, "stone3")
    elif name == "searing":
        c.poly([(8, 2), (12, 9), (11, 13), (5, 13), (4, 9)], "blood3")
        flame(c, 8, 10, 0.7)
    elif name == "seeker":
        c.ellipse(8, 8, 7, 4.5, "bone3")
        c.circle(8, 8, 3.2, "orange")
        c.circle(8, 8, 1.5, "ink")
        c.put(7, 7, "cream")
    elif name == "long_flame":
        c.line(2, 13, 11, 4, "orange")
        c.line(1, 12, 10, 3, "amber")
        c.line(3, 14, 11, 6, "brown3")
        c.circle(12, 4, 2.6, "gold")
        c.put(12, 3, "cream")
    elif name == "glass_shade":
        c.ellipse(8, 9, 6, 6, "teal3")
        c.ellipse(8, 9, 4.5, 4.5, "teal1")
        c.rect(2, 12, 12, 3, "teal2")
        c.put(6, 6, "teal4")
        c.put(5, 7, "teal4")
        flame(c, 8, 10, 0.5)
    elif name == "moth_heart":
        c.ellipse(5, 6, 4, 4, "bone2")
        c.ellipse(11, 6, 4, 4, "bone2")
        c.ellipse(5, 11, 3, 2.5, "bone1")
        c.ellipse(11, 11, 3, 2.5, "bone1")
        c.rect(7, 4, 2, 10, "brown1")
        c.circle(5, 6, 1.4, "blood3")
        c.circle(11, 6, 1.4, "blood3")
    elif name == "light_feet":
        c.poly([(4, 4), (9, 4), (9, 10), (14, 11), (14, 14), (4, 14)], "brown2")
        c.rect(4, 12, 10, 2, "brown1")
        c.poly([(3, 6), (0, 3), (0, 9)], "fog")
        c.poly([(3, 9), (0, 8), (1, 12)], "mist")
    elif name == "shadow_step":
        for i, a in enumerate((60, 120, 255)):
            x = 2 + i * 4
            c.ellipse(x + 2, 6, 2, 2, (*col("violet2")[:3], a))
            c.rect(x + 1, 8, 3, 6, (*col("violet2")[:3], a))
        c.put(12, 6, "cream")
    elif name == "ember_magnet":
        c.ring(8, 9, 6, 3, "blood3")
        c.rect(2, 2, 12, 7, (0, 0, 0, 0))
        c.rect(2, 7, 3, 3, "stone4")
        c.rect(11, 7, 3, 3, "stone4")
        c.ring(8, 9, 6, 3, "blood3")
        c.rect(1, 2, 14, 6, (0, 0, 0, 0))
        c.rect(2, 6, 3, 2, "stone4")
        c.rect(11, 6, 3, 2, "stone4")
        c.poly([(8, 1), (10, 3.5), (8, 6), (6, 3.5)], "amber")
    elif name == "combustion":
        c.circle(8, 10, 5, "night3")
        c.circle(7, 9, 2, "night4")
        c.rect(7, 2, 2, 4, "brown2")
        flame(c, 9, 3, 0.45)
    elif name == "motes":
        c.ring(8, 8, 6.5, 5.5, "night3")
        for ang in (0.3, 2.4, 4.4):
            x, y = 8 + math.cos(ang) * 6, 8 + math.sin(ang) * 6
            c.circle(x, y, 2, "amber")
            c.put(int(x), int(y), "cream")
        c.circle(8, 8, 2, "orange")
    elif name == "lucky_spark":
        for ang in (0, 1.57, 3.14, 4.71):
            c.circle(8 + math.cos(ang) * 3.5, 8 + math.sin(ang) * 3.5, 3, "moss3")
        c.circle(8, 8, 2, "moss4")
        c.line(8, 10, 11, 15, "moss2")
        c.put(8, 8, "gold")
    elif name == "thick_wax":
        c.rect(5, 6, 6, 9, "bone3")
        c.rect(5, 6, 2, 9, "cream")
        c.rect(4, 14, 8, 2, "bone1")
        c.rect(10, 7, 1, 3, "bone2")
        c.rect(7, 4, 1, 2, "ink")
        flame(c, 7.5, 3, 0.4)
    elif name == "calm_flame":
        for r, cc in ((6.5, "teal2"), (4.5, "teal3"), (2.5, "teal4")):
            c.ring(8, 8, r, r - 1.1, cc)
        c.circle(8, 8, 1.2, "cream")
    elif name == "shatter":
        c.poly([(8, 1), (13, 6), (11, 15), (5, 15), (3, 6)], "teal3")
        c.poly([(8, 1), (10, 6), (8, 15), (5, 15), (3, 6)], "teal4")
        c.line(8, 1, 8, 15, "teal2")
        c.line(3, 6, 13, 6, "teal2")
    elif name == "slow_burn":
        c.rect(3, 1, 10, 2, "brown2")
        c.rect(3, 13, 10, 2, "brown2")
        c.poly([(4, 3), (12, 3), (8.5, 8), (12, 13), (4, 13), (7.5, 8)], "teal4")
        c.poly([(5.5, 4), (10.5, 4), (8, 7)], "amber")
        c.poly([(8, 9.5), (11, 12.5), (5, 12.5)], "amber")
    elif name == "greedy_lamp":
        c.ellipse(8, 10, 6, 4.5, "gold")
        c.ellipse(8, 9, 4, 2.5, "amber")
        c.rect(12, 7, 3, 2, "gold")
        flame(c, 8, 5, 0.55, ("blood3", "blood4", "cream"))
    elif name == "wildfire":
        flame(c, 5, 9, 0.8, ("blood3", "orange", "cream"))
        flame(c, 11, 10, 0.75)
        flame(c, 8, 7, 0.9, ("orange", "gold", "cream"))
    elif name == "warden_bell":
        c.poly([(8, 2), (12, 6), (13, 12), (3, 12), (4, 6)], "amber")
        c.poly([(8, 3), (10, 6), (10, 11), (6, 11), (6, 6)], "gold")
        c.rect(2, 12, 12, 2, "brown2")
        c.circle(8, 14.5, 1.5, "bone2")
        c.rect(7, 0, 2, 2, "brown2")
    elif name == "second_wick":
        c.rect(5, 7, 6, 8, "bone3")
        c.rect(5, 7, 2, 8, "cream")
        flame(c, 6, 5, 0.5)
        flame(c, 10, 5, 0.5, ("teal3", "teal4", "white"))
    elif name == "molten_core":
        c.circle(8, 8, 6.5, "blood2")
        c.circle(8, 8, 5, "orange")
        c.circle(7, 7, 3, "amber")
        c.circle(6.5, 6.5, 1.3, "cream")
    elif name == "oil":
        c.poly([(8, 1), (13, 9), (12, 14), (4, 14), (3, 9)], "amber")
        c.ellipse(8, 10.5, 3.5, 3, "gold")
        c.put(6, 8, "cream")
    elif name == "big_oil":
        c.rect(4, 4, 8, 11, "teal2")
        c.rect(5, 6, 6, 8, "amber")
        c.rect(5, 6, 6, 2, "gold")
        c.rect(6, 1, 4, 3, "brown2")
        c.put(6, 9, "cream")
    else:
        raise KeyError(name)
    return c.outline()


RELIC_ICONS = ["twin_wick", "keen_spark", "quickburn", "pierce", "ricochet", "searing", "seeker",
               "long_flame", "glass_shade", "moth_heart", "light_feet", "shadow_step", "ember_magnet",
               "combustion", "motes", "lucky_spark", "thick_wax", "calm_flame", "shatter", "slow_burn",
               "greedy_lamp", "wildfire", "warden_bell", "second_wick", "molten_core", "oil", "big_oil"]


def logo():
    """WICKDEEP title: chunky gradient letters with outline and drop shadow."""
    scale = 4
    t = text_canvas("WICKDEEP", scale, "white")
    W, H = t.w + 8, t.h + 10
    c = Canvas(W, H)
    grad = ["cream", "gold", "gold", "amber", "amber", "orange", "orange", "blood3"]
    body = Canvas(W, H)
    for y in range(t.h):
        band = grad[min(len(grad) - 1, y * len(grad) // t.h)]
        for x in range(t.w):
            if t.a[y, x, 3]:
                body.put(x + 4, y + 3, band)
    shadow = body.tint_all("blood1").shifted(0, 3)
    c.blit(shadow, 0, 0)
    c.blit(body, 0, 0)
    c.outline(col("outline"))
    # a flame dancing on the 'I'
    ix = 4 + (6 * scale) + scale
    f = Canvas(W, H)
    flame(f, ix + 1, 6, 0.7)
    for y in range(H):
        for x in range(W):
            if f.a[y, x, 3] and not c.a[y, x, 3]:
                c.put(x, y, f.get(x, y))
    return c


def build_all(out, manifest, previews):
    build_font(out, False)
    build_font(out, True)

    s = Sheet("hud_flame", 11, 12)
    fl = [flame_icon("full"), flame_icon("half"), flame_icon("empty")]
    s.add("full", [fl[0]], fps=1).add("half", [fl[1]], fps=1).add("empty", [fl[2]], fps=1)
    s.build(out, manifest)
    previews += fl

    for kind in ("panel", "panel_dark", "bubble", "btn", "btn_hover", "btn_press", "btn_disabled"):
        p = panel(kind)
        p.save(os.path.join(out, "ui", f"{kind}.png"))
        previews.append(p)

    misc = {"crosshair": crosshair(), "cursor": cursor_arrow(), "ember_icon": ember_icon(),
            "key_e": key_icon("E"), "key_q": key_icon("Q"), "key_space": key_icon("_"),
            "logo": logo()}
    for kind in ("common", "rare", "legendary", "cursed"):
        misc[f"frame_{kind}"] = rarity_frame(kind)
    for name, cnv in misc.items():
        cnv.save(os.path.join(out, "ui", f"{name}.png"))
        previews.append(cnv)

    icons = Sheet("icons", 16, 16)
    frames = [icon(n) for n in RELIC_ICONS]
    for n, f in zip(RELIC_ICONS, frames):
        icons.add(n, [f], fps=1)
    icons.build(out, manifest)
    previews += frames
