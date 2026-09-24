#!/usr/bin/env python3
"""Build .pxl pixel maps into PNG sheets and a frames JSON."""
from __future__ import annotations
import json, sys
from pathlib import Path

PALETTE = {
    ".": None,
    "1": (11, 14, 20), "2": (18, 26, 38), "3": (27, 43, 60), "4": (36, 64, 90),
    "5": (47, 90, 118), "6": (63, 127, 143), "7": (111, 176, 179), "8": (207, 230, 226),
    "9": (159, 177, 184), "A": (185, 169, 201), "B": (223, 231, 234), "C": (244, 247, 246),
    "D": (42, 42, 48), "E": (69, 70, 78), "F": (108, 110, 118), "G": (154, 156, 163),
    "H": (201, 200, 194), "I": (43, 31, 26), "J": (74, 52, 40), "K": (107, 74, 51),
    "L": (140, 106, 78), "M": (176, 143, 108), "N": (216, 196, 154), "O": (234, 220, 184),
    "P": (31, 46, 34), "Q": (47, 74, 48), "R": (78, 110, 58), "S": (122, 150, 76),
    "T": (169, 179, 106), "U": (61, 39, 66), "V": (107, 63, 110), "W": (160, 106, 158),
    "X": (155, 47, 42), "Y": (224, 123, 42), "Z": (233, 166, 74),
    "a": (90, 30, 30), "b": (194, 65, 45), "c": (240, 138, 43), "d": (255, 200, 90),
    "e": (255, 233, 168), "f": (255, 248, 225), "g": (107, 69, 49), "h": (176, 122, 85),
    "i": (231, 185, 149), "j": (138, 143, 150), "k": (221, 211, 191), "l": (201, 162, 74),
    "m": (181, 101, 58),
}

try:
    from PIL import Image
except ImportError:
    Image = None


def parse_pxl(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    header, _, rest = text.partition("---")
    meta = {}
    for line in header.splitlines():
        if ":" in line and not line.startswith("#"):
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    size = meta.get("size", "16x16")
    w, h = [int(x) for x in size.lower().split("x")]
    frames = []
    chunks = rest.split("---")
    for ch in chunks:
        lines = [ln.rstrip("\n") for ln in ch.splitlines() if ln.strip() and not ln.strip().startswith("frame")]
        lines = [ln for ln in lines if set(ln) <= set(PALETTE)]
        if len(lines) < h:
            continue
        rows = [ln[:w].ljust(w, ".") for ln in lines[:h]]
        frames.append(rows)
    return {"meta": meta, "w": w, "h": h, "frames": frames}


def render(parsed: dict, out_png: Path) -> None:
    if Image is None:
        raise SystemExit("Pillow required")
    w, h, frames = parsed["w"], parsed["h"], parsed["frames"]
    if not frames:
        raise SystemExit("no frames")
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    px = img.load()
    for fi, rows in enumerate(frames):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                col = PALETTE.get(ch)
                if col:
                    px[fi * w + x, y] = (*col, 255)
    out_png.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_png)


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "assets_src")
    dst = Path(sys.argv[2] if len(sys.argv) > 2 else "assets")
    catalog = []
    for p in sorted((src / "sprites").glob("*.pxl")) if (src / "sprites").exists() else []:
        parsed = parse_pxl(p)
        out = dst / "sprites" / (p.stem + ".png")
        render(parsed, out)
        catalog.append({"name": parsed["meta"].get("name", p.stem), "file": str(out), "meta": parsed["meta"]})
        print("built", p.name, "->", out)
    (dst / "sprites" / "pxl_catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
