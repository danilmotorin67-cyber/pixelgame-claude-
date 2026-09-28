#!/usr/bin/env python3
"""Illustrations drawn in GPT Image (docs/art/ILLUSTRATIONS_GPT_IMAGE.md) -> the game's pixel grid.

Sources lie in assets_src/illustrations_gpt/<id>.(png|webp). Full-screen frames (1536x1024) are cropped to
16:9 around the middle and shrunk to 480x270, the interface grid (shown at 2 screen pixels per pixel);
festival posters (1024x1536) keep their shape at 270 px high; Agatha's sketches (1024x1024) become 160x160.
Averaging each block and cutting the colours down to a small palette without dithering turns the painterly
source into flat pixel art. Output: assets/sprites/illustrations/<id>.png.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets_src" / "illustrations_gpt"
OUT = ROOT / "assets" / "sprites" / "illustrations"
COLORS = 64


def target(stem: str, size: tuple) -> tuple:
    if stem.startswith("poster_"):
        return (round(270 * size[0] / size[1]), 270), None
    if stem.startswith("sketch_"):
        return (160, 160), None
    return (480, 270), 16 / 9


def convert(path: Path) -> Path:
    im = Image.open(path).convert("RGB")
    (w, h), aspect = target(path.stem, im.size)
    if aspect:
        crop_h = min(im.height, round(im.width / aspect))
        top = (im.height - crop_h) // 2
        im = im.crop((0, top, im.width, top + crop_h))
    im = im.resize((w, h), Image.BOX)
    im = im.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = OUT / (path.stem + ".png")
    im.save(out, optimize=True)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path in sorted(SRC.iterdir()):
        if path.suffix.lower() in (".png", ".webp", ".jpg", ".jpeg"):
            print(convert(path).relative_to(ROOT))


if __name__ == "__main__":
    main()
