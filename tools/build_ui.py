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
    "slot": ("slot_0", 6, False, 0),         # inventory slot, thin brass rim
    "slot_selected": ("slot_2", 6, False, 0),
    "button": ("slot_50", 6, False, 2),      # rounded brass button
    "button_pressed": ("slot_45", 6, False, 2),
    "book_left": ("book_3:left", 8, False, 6),   # the journal spread, cut at the fold
    "book_right": ("book_3:right", 8, False, 6),
}
# Frames made from another by brightening (hover states).
BRIGHT = {"button_hover": ("button", 1.25)}


def trim(img):
    return img.crop(img.getbbox())


def build_frames():
    os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
    meta = {}
    for name, (src, corner, tiled, pad) in FRAMES.items():
        file, _, half = src.partition(":")
        path = os.path.join(RAW, file + ".png")
        if not os.path.exists(path):
            continue
        img = trim(Image.open(path).convert("RGBA"))
        if half:
            mid = img.width // 2
            img = img.crop((0, 0, mid, img.height)) if half == "left" else img.crop((mid, 0, img.width, img.height))
        img.save(os.path.join(OUT, "frames", name + ".png"))
        meta[name] = {"margin": corner, "tile": tiled, "pad": pad}
    for name, (base, k) in BRIGHT.items():
        if base in meta:
            img = Image.open(os.path.join(OUT, "frames", base + ".png")).convert("RGBA")
            px = img.load()
            for y in range(img.height):
                for x in range(img.width):
                    r, g, b, a = px[x, y]
                    if a and r > b:  # the brass, not the navy fill
                        px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)
            img.save(os.path.join(OUT, "frames", name + ".png"))
            meta[name] = dict(meta[base])
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
    if os.path.exists(os.path.join(src, "moon_full.png")):
        n += build_moons(Image.open(os.path.join(src, "moon_full.png")).convert("RGBA"))
    return n


def build_moons(full):
    """moon_0..moon_7 from the full moon: 0 new, 4 full; the unlit part is a dark ghost of the disc."""
    import math
    box = full.getbbox()
    cx, cy = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0
    r = (box[2] - box[0]) / 2.0
    for phase in range(8):
        img = full.copy()
        px = img.load()
        f = phase / 8.0                      # 0 new .. 0.5 full .. 1 new
        lit_right = f < 0.5                  # waxing: light grows from the right
        k = math.cos(2 * math.pi * f)        # terminator ellipse: 1 new, -1 full
        for y in range(img.height):
            for x in range(img.width):
                rr, g, b, a = px[x, y]
                if not a:
                    continue
                dy = (y + 0.5 - cy) / r
                half = math.sqrt(max(0.0, 1 - dy * dy))
                dx = (x + 0.5 - cx) / r
                edge = k * half              # x of the terminator
                lit = dx > edge if lit_right else dx < -edge
                if not lit:
                    px[x, y] = (int(rr * 0.22) + 10, int(g * 0.22) + 14, int(b * 0.22) + 24, a)
        img.save(os.path.join(OUT, "icons", "moon_%d.png" % phase))
    return 8


if __name__ == "__main__":
    print("frames", build_frames(), "icons", build_icons())
