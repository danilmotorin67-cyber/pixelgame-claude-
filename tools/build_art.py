"""Copies PixelLab output from assets_src/pixellab into the game's asset folders.

- Wang tilesets become a 4x4 atlas assets/tilesets/<id>.png (32 px cells) and <id>.json,
  which maps the corner key "NW NE SW SE" (1 = upper terrain, 0 = lower) to the atlas cell.
- Single ground tiles are copied to assets/tilesets/single/<id>.png.
- Buildings are cropped to their visible pixels and saved to assets/sprites/buildings/<id>.png;
  assets/sprites/buildings/index.json keeps each sprite's size and the offset of the crop.

Run: python3 tools/build_art.py"""
import os, json, glob
from PIL import Image

SRC = "assets_src/pixellab"
TILES_OUT = "assets/tilesets"
BUILD_OUT = "assets/sprites/buildings"


def build_tilesets():
    os.makedirs(os.path.join(TILES_OUT, "single"), exist_ok=True)
    count = 0
    for folder in sorted(glob.glob(os.path.join(SRC, "tiles", "tiles_*"))):
        aid = os.path.basename(folder)
        path = os.path.join(folder, "tileset.json")
        if not os.path.exists(path):
            continue
        ts = json.load(open(path))
        size = ts["tile_size"]
        atlas = Image.new("RGBA", (size * 4, size * 4))
        cells = {}
        for i, t in enumerate(ts["tiles"]):
            c = t["corners"]
            key = "".join("1" if c[k] == "upper" else "0" for k in ("NW", "NE", "SW", "SE"))
            atlas.paste(Image.open(os.path.join(folder, t["file"])).convert("RGBA"), ((i % 4) * size, (i // 4) * size))
            cells[key] = i
        atlas.save(os.path.join(TILES_OUT, aid + ".png"))
        with open(os.path.join(TILES_OUT, aid + ".json"), "w") as f:
            json.dump({"tile": size, "cells": cells}, f, indent=1, sort_keys=True)
        count += 1
    for folder in sorted(glob.glob(os.path.join(SRC, "tiles", "tile_*"))):
        aid = os.path.basename(folder)
        Image.open(os.path.join(folder, aid + ".png")).convert("RGBA").save(os.path.join(TILES_OUT, "single", aid + ".png"))
    return count


def build_buildings():
    os.makedirs(BUILD_OUT, exist_ok=True)
    index = {}
    for folder in sorted(glob.glob(os.path.join(SRC, "buildings", "*"))):
        aid = os.path.basename(folder)
        path = os.path.join(folder, aid + ".png")
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGBA")
        box = img.getbbox() or (0, 0, img.width, img.height)
        img.crop(box).save(os.path.join(BUILD_OUT, aid + ".png"))
        index[aid] = {"size": [box[2] - box[0], box[3] - box[1]], "crop": list(box[:2])}
    with open(os.path.join(BUILD_OUT, "index.json"), "w") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    return len(index)


if __name__ == "__main__":
    print("tilesets", build_tilesets(), "buildings", build_buildings())
