"""A tiny pixel canvas: exact, aliased drawing on an RGBA numpy array."""

import json
import math
import os

import numpy as np
from PIL import Image

from palette import OUTLINE, rgba


def col(c):
    """Accept a palette name, hex string or rgba tuple."""
    if c is None:
        return None
    if isinstance(c, tuple):
        return c if len(c) == 4 else (*c, 255)
    return rgba(c)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)

    # ---- basic access -------------------------------------------------
    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = col(c)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return tuple(int(v) for v in self.a[y, x])
        return (0, 0, 0, 0)

    def opaque(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.a[y, x, 3] > 0

    def copy(self):
        c = Canvas(self.w, self.h)
        c.a = self.a.copy()
        return c

    # ---- shapes ----------------------------------------------------------
    def rect(self, x, y, w, h, c):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = col(c)

    def frame(self, x, y, w, h, c):
        self.rect(x, y, w, 1, c)
        self.rect(x, y + h - 1, w, 1, c)
        self.rect(x, y, 1, h, c)
        self.rect(x + w - 1, y, 1, h, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx, cy, rx, ry, c, filled=True):
        """Ellipse centred on (cx, cy); half-integer centres give even sizes."""
        for y in range(self.h):
            for x in range(self.w):
                dx = (x + 0.5 - cx) / max(rx, 0.01)
                dy = (y + 0.5 - cy) / max(ry, 0.01)
                d = dx * dx + dy * dy
                if filled and d <= 1.0:
                    self.put(x, y, c)
                elif not filled and 0.62 <= d <= 1.0:
                    self.put(x, y, c)

    def circle(self, cx, cy, r, c, filled=True):
        self.ellipse(cx, cy, r, r, c, filled)

    def ring(self, cx, cy, r_out, r_in, c):
        for y in range(self.h):
            for x in range(self.w):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if r_in <= d <= r_out:
                    self.put(x, y, c)

    def poly(self, pts, c):
        """Even-odd scanline fill of a polygon given in pixel-centre coordinates."""
        n = len(pts)
        for y in range(self.h):
            yc = y + 0.5
            xs = []
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                    self.put(x, y, c)

    # ---- ascii art -------------------------------------------------------
    def stamp(self, rows, legend, ox=0, oy=0):
        """Draw ascii rows. '.' and ' ' are transparent; other chars map via legend."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in ". ":
                    continue
                if ch not in legend:
                    raise KeyError(f"char {ch!r} missing from legend (row {j}: {row!r})")
                self.put(ox + i, oy + j, legend[ch])

    # ---- compositing -----------------------------------------------------
    def blit(self, other, x, y, flip_x=False):
        src = other.a[:, ::-1] if flip_x else other.a
        for j in range(other.h):
            ty = y + j
            if not 0 <= ty < self.h:
                continue
            for i in range(other.w):
                tx = x + i
                if 0 <= tx < self.w and src[j, i, 3] > 0:
                    self.a[ty, tx] = src[j, i]

    def outline(self, c=OUTLINE, diagonal=False):
        """Add a 1px outline around every opaque shape (outside only)."""
        m = self.a[:, :, 3] > 0
        n = np.zeros_like(m)
        n[1:, :] |= m[:-1, :]
        n[:-1, :] |= m[1:, :]
        n[:, 1:] |= m[:, :-1]
        n[:, :-1] |= m[:, 1:]
        if diagonal:
            n[1:, 1:] |= m[:-1, :-1]
            n[1:, :-1] |= m[:-1, 1:]
            n[:-1, 1:] |= m[1:, :-1]
            n[:-1, :-1] |= m[1:, 1:]
        edge = n & ~m
        self.a[edge] = col(c)
        return self

    def recolor(self, mapping):
        """Swap colours: mapping of source colour -> target colour."""
        out = self.copy()
        for src, dst in mapping.items():
            s = np.array(col(src), dtype=np.uint8)
            mask = np.all(self.a == s, axis=2)
            out.a[mask] = col(dst)
        return out

    def tint_all(self, c):
        """Every opaque pixel becomes colour c (used for flash / silhouettes)."""
        out = self.copy()
        out.a[self.a[:, :, 3] > 0] = col(c)
        return out

    def shifted(self, dx, dy):
        out = Canvas(self.w, self.h)
        out.blit(self, dx, dy)
        return out

    def flipped(self):
        out = Canvas(self.w, self.h)
        out.a = self.a[:, ::-1].copy()
        return out

    def image(self):
        return Image.fromarray(self.a, "RGBA")

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.image().save(path)


def ascii_canvas(rows, legend, w=None, h=None, outline=True, diagonal=False):
    h = h or len(rows)
    w = w or max(len(r) for r in rows)
    for r in rows:
        if len(r) > w:
            raise ValueError(f"row longer than {w}: {r!r}")
    c = Canvas(w, h)
    c.stamp(rows, legend)
    if outline:
        c.outline(diagonal=diagonal)
    return c


class Sheet:
    """Collects animation rows of equal-sized frames into one PNG + manifest entry."""

    def __init__(self, name, fw, fh):
        self.name, self.fw, self.fh = name, fw, fh
        self.anims = []  # (anim_name, [Canvas], fps, loop)

    def add(self, anim, frames, fps=8, loop=True):
        for f in frames:
            assert (f.w, f.h) == (self.fw, self.fh), f"{self.name}/{anim}: frame {f.w}x{f.h} != {self.fw}x{self.fh}"
        self.anims.append((anim, frames, fps, loop))
        return self

    def build(self, out_dir, manifest):
        cols = max(len(fr) for _, fr, _, _ in self.anims)
        img = Canvas(cols * self.fw, len(self.anims) * self.fh)
        entry = {"file": f"{self.name}.png", "w": self.fw, "h": self.fh, "anims": {}}
        for row, (anim, frames, fps, loop) in enumerate(self.anims):
            for i, f in enumerate(frames):
                img.blit(f, i * self.fw, row * self.fh)
            entry["anims"][anim] = {"row": row, "frames": len(frames), "fps": fps, "loop": loop}
        img.save(os.path.join(out_dir, f"{self.name}.png"))
        manifest[self.name] = entry
        return img


def save_manifest(manifest, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)


def preview(canvases, path, scale=4, bg=(40, 34, 52, 255), pad=4):
    """Lay out canvases on one big preview image (for eyeballing the art)."""
    cols = 8
    cw = max(c.w for c in canvases) + pad
    ch = max(c.h for c in canvases) + pad
    rows = (len(canvases) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cw * scale, rows * ch * scale), bg)
    for i, c in enumerate(canvases):
        x, y = (i % cols) * cw, (i // cols) * ch
        im = c.image().resize((c.w * scale, c.h * scale), Image.NEAREST)
        img.alpha_composite(im, (x * scale + pad * scale // 2, y * scale + pad * scale // 2))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
