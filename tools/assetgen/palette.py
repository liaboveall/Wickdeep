"""Shared palette for every generated sprite, tile and UI element.

Warm candlelight colours against cool violet shadows. Keeping all art on one
palette is what makes code-generated pixel art look like a single style.
"""

PALETTE = {
    # cool neutrals (shadows, night)
    "outline": "#120e18",
    "ink": "#1c1626",
    "night1": "#262036",
    "night2": "#383050",
    "night3": "#524a6c",
    "night4": "#766d8e",
    "mist": "#a49bb6",
    "fog": "#d8d0e2",
    "white": "#f4f0ea",
    # warm light
    "brown0": "#2a1712",
    "brown1": "#4a2a1c",
    "brown2": "#7a4528",
    "brown3": "#a8663a",
    "orange": "#e08a3c",
    "amber": "#f5b84c",
    "gold": "#ffd978",
    "cream": "#fff3cf",
    # moss
    "moss0": "#18241c",
    "moss1": "#2b3d28",
    "moss2": "#46613a",
    "moss3": "#6f8f45",
    "moss4": "#a9c46a",
    # teal / ghost light
    "teal0": "#14202e",
    "teal1": "#213a4f",
    "teal2": "#33607a",
    "teal3": "#5797ad",
    "teal4": "#9cd3dc",
    # blood / ember red
    "blood0": "#2e0f1a",
    "blood1": "#5e1a28",
    "blood2": "#9c2c34",
    "blood3": "#d8503f",
    "blood4": "#f08a6a",
    # violet magic
    "violet0": "#24142f",
    "violet1": "#432657",
    "violet2": "#6e3f8a",
    "violet3": "#a466c4",
    "violet4": "#dba8ec",
    # bone
    "bone0": "#5c5246",
    "bone1": "#8c7f6a",
    "bone2": "#b9aa8c",
    "bone3": "#e2d6b8",
    # stone
    "stone0": "#2c2a30",
    "stone1": "#45424a",
    "stone2": "#625e66",
    "stone3": "#858089",
    "stone4": "#aaa5ac",
}


def rgba(name_or_hex, alpha=255):
    """Return an (r, g, b, a) tuple for a palette name or a #rrggbb string."""
    h = PALETTE.get(name_or_hex, name_or_hex).lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


OUTLINE = rgba("outline")
