"""Generate every sprite, tile, icon, sound and music track for the game.

Usage (from the repository root):
    python tools/assetgen/build_all.py            # everything
    python tools/assetgen/build_all.py sprites    # only some groups: sprites tiles ui sfx music
Outputs go to assets/; eyeball previews go to tools/assetgen/previews/ (not used by the game).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from canvas import preview, save_manifest  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")
AUDIO = os.path.join(ROOT, "assets", "audio")
PREVIEWS = os.path.join(HERE, "previews")


def main(groups):
    manifest_path = os.path.join(SPRITES, "manifest.json")
    manifest = {}
    if os.path.exists(manifest_path):
        import json
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)

    if "sprites" in groups:
        import sprites
        prev = []
        sprites.build_all(SPRITES, manifest, prev)
        preview(prev, os.path.join(PREVIEWS, "actors.png"), scale=5)
        print(f"sprites: {len(prev)} preview frames")
    if "tiles" in groups:
        import tiles
        prev = []
        tiles.build_all(SPRITES, manifest, prev, PREVIEWS)
        print("tiles: done")
    if "ui" in groups:
        import ui
        prev = []
        ui.build_all(SPRITES, manifest, prev)
        preview(prev, os.path.join(PREVIEWS, "ui.png"), scale=5)
        print(f"ui: {len(prev)} preview items")
    save_manifest(manifest, manifest_path)
    if "sfx" in groups:
        import sfx
        n = sfx.build_all(os.path.join(AUDIO, "sfx"))
        print(f"sfx: {n} sounds")
    if "music" in groups:
        import music
        n = music.build_all(os.path.join(AUDIO, "music"))
        print(f"music: {n} tracks")


if __name__ == "__main__":
    args = sys.argv[1:] or ["sprites", "tiles", "ui", "sfx", "music"]
    main(set(args))
