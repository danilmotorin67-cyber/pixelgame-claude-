#!/usr/bin/env python3
"""Cuts the interface kit out of the PixelLab variant sheets (tools/pixellab_ui.py) into
assets/ui/frames/<name>.png plus assets/ui/frames.json: the nine-patch corner in texels, whether
the edges tile, and the extra padding (units) inside the frame. HUD icons come from the icon
batches (tools/pixellab_ui_icons.py) and are copied to assets/ui/icons/."""
import json
import os
import shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_src", "pixellab", "ui")
OUT = os.path.join(ROOT, "assets", "ui")

# name: (variant file, corner texels, tiled edges, padding in units)
FRAMES = {
    "panel": ("panel_0", 9, False, 2),       # slate with brass rivets: HUD panels, generic panels
    "window": ("panel_2", 11, False, 3),     # rounded brass: windows and dialogues
    "inset": ("panel_7", 6, False, 1),       # bevelled well: lists, portraits, fields
    "compass": ("panel_8", 14, True, 1),     # compass-rose corners: the keeper's Compass
    "tooltip": ("panel_15", 8, True, 2),     # studded: hints and item cards
}


def trim(img):
    return img.crop(img.getbbox())


def build_frames():
    os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
    meta = {}
    for name, (src, corner, tiled, pad) in FRAMES.items():
        path = os.path.join(RAW, src + ".png")
        if not os.path.exists(path):
            continue
        trim(Image.open(path).convert("RGBA")).save(os.path.join(OUT, "frames", name + ".png"))
        meta[name] = {"margin": corner, "tile": tiled, "pad": pad}
    with open(os.path.join(OUT, "frames.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    return len(meta)


def build_icons():
    src = os.path.join(RAW, "icons")
    if not os.path.isdir(src):
        return 0
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    n = 0
    for f in sorted(os.listdir(src)):
        if f.endswith(".png"):
            shutil.copy(os.path.join(src, f), os.path.join(OUT, "icons", f))
            n += 1
    return n


if __name__ == "__main__":
    print("frames", build_frames(), "icons", build_icons())
