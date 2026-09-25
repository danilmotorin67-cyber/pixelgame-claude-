"""Copies PixelLab output from assets_src/pixellab into the game's asset folders.

- Wang tilesets become a 4x4 atlas assets/tilesets/<id>.png (32 px cells) and <id>.json,
  which maps the corner key "NW NE SW SE" (1 = upper terrain, 0 = lower) to the atlas cell.
- Single ground tiles are copied to assets/tilesets/single/<id>.png.
- Buildings are cropped to their visible pixels and saved to assets/sprites/buildings/<id>.png;
  assets/sprites/buildings/index.json keeps each sprite's size and the offset of the crop.

- Characters and animals become a sprite sheet assets/sprites/cast/<id>.png (one row per
  animation and direction, frames centred) and <id>.json: {"frame": [w, h], "foot": y of the lowest opaque
  pixel, "anims": {name: {direction: [row, frames]}}}. Animation names are normalised to
  walk, idle, work, graze, sleep; "rot" holds the still rotations. Single-direction critters
  (sea life, flying birds) get the direction "south".

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


CAST_OUT = "assets/sprites/cast"
NAMES = {"walking": "walk", "walk-6-frames": "walk", "walk-8-frames": "walk", "walk-4-frames": "walk",
         "animating": "idle", "breathing-idle": "idle"}


def _pack(aid, strips):
    """strips: [(anim, direction, [Image])] -> sheet + json."""
    fw = max(im.width for _, _, ims in strips for im in ims)
    fh = max(im.height for _, _, ims in strips for im in ims)
    cols = max(len(ims) for _, _, ims in strips)
    sheet = Image.new("RGBA", (fw * cols, fh * len(strips)))
    anims, foot = {}, 0
    for row, (anim, direction, ims) in enumerate(strips):
        for col, im in enumerate(ims):
            x, y = col * fw + (fw - im.width) // 2, row * fh + (fh - im.height) // 2
            sheet.paste(im, (x, y))
            box = im.getbbox()
            if box and anim == "rot":
                foot = max(foot, box[3] + (fh - im.height) // 2)
        anims.setdefault(anim, {})[direction] = [row, len(ims)]
    sheet.save(os.path.join(CAST_OUT, aid + ".png"))
    with open(os.path.join(CAST_OUT, aid + ".json"), "w") as f:
        json.dump({"frame": [fw, fh], "foot": foot or fh, "anims": anims}, f, indent=1, sort_keys=True)


def build_cast():
    os.makedirs(CAST_OUT, exist_ok=True)
    count = 0
    for group in ("characters", "animals"):
        for folder in sorted(glob.glob(os.path.join(SRC, group, "*"))):
            aid = os.path.basename(folder)
            strips = []
            meta_path = os.path.join(folder, "metadata.json")
            if os.path.exists(meta_path):
                frames = json.load(open(meta_path))["states"][0]["frames"]
                load = lambda rel: Image.open(os.path.join(folder, rel)).convert("RGBA")
                for d in ("south", "east", "north", "west"):
                    if d in frames["rotations"]:
                        strips.append(("rot", d, [load(frames["rotations"][d])]))
                for name, dirs in sorted(frames.get("animations", {}).items()):
                    for d in ("south", "east", "north", "west"):
                        if d in dirs:
                            strips.append((NAMES.get(name, name), d, [load(rel) for rel in dirs[d]]))
            else:
                still = os.path.join(folder, aid + ".png")
                if not os.path.exists(still):
                    continue
                strips.append(("rot", "south", [Image.open(still).convert("RGBA")]))
                for anim in sorted(glob.glob(os.path.join(folder, "*", "frame_000.png"))):
                    d = os.path.dirname(anim)
                    strips.append((os.path.basename(d), "south",
                                   [Image.open(f).convert("RGBA") for f in sorted(glob.glob(os.path.join(d, "frame_*.png")))]))
            if strips:
                _pack(aid, strips)
                count += 1
    return count


if __name__ == "__main__":
    print("tilesets", build_tilesets(), "buildings", build_buildings(), "cast", build_cast())
