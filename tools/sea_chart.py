#!/usr/bin/env python3
"""The sea chart (M, tab «Море»), drawn in PixelLab the way the island chart is (tools/island_map.py).

1. `sketch` draws the sea from its real data (data/balance.json → sea): the island's coast along the top with
   the cape pier and the lighthouse, the three zones deepening southwards, the reefs, the Teeth, Seal Rock,
   Eider Isle, the Dead Fire, the Nameless Isle, the whirlpool of the Drowned Well, the sea garden, the
   Resting Place buoys, the ice field and the Kronvald fairway. Three pixels a sea tile (120x140 -> 360x420).
2. `pro [seed]` has the Pro model redraw it with the sketch as the layout reference;
   `inpaint <n> x0,y0,x1,y1 "<text>"` redraws one box of a variant.
   `move <n> x0,y0,x1,y1 cx,cy fx,fy` shifts one thing of a variant to its true place by hand (no generation).
3. `pick <n>` copies a variant to assets/sprites/ui/sea_chart.png.

The chart is laid over the sea by tile, so whatever drifts from the sketch is fixed by inpainting.
"""
import base64
import io
import json
import math
import os
import random
import shutil
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab as pl  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEA = json.load(open(os.path.join(ROOT, "data", "balance.json")))["sea"]
RAW = os.path.join(pl.RAW, "sea_chart")
SKETCH = os.path.join(RAW, "sketch.png")
OUT = os.path.join(ROOT, "assets", "sprites", "ui")
K = 3

C = {"z1": (63, 127, 143), "z2": (47, 90, 118), "z3": (36, 64, 90), "z3b": (27, 43, 60), "wave": (111, 176, 179),
     "foam": (207, 230, 226), "sand": (216, 196, 154), "grass": (78, 110, 58), "grass2": (122, 150, 76),
     "rock": (69, 70, 78), "rock2": (108, 110, 118), "black": (18, 26, 38), "white": (244, 247, 246),
     "wood": (107, 74, 51), "kelp": (74, 110, 58), "kelp2": (139, 106, 78), "ice": (223, 233, 234),
     "lamp": (255, 200, 90), "red": (155, 47, 42), "bird": (201, 200, 194)}


def at(place):
    x, y = SEA["places"][place]["at"]
    return x * K + K // 2, y * K + K // 2


def rock(d, x, y, r=4, colour="rock"):
    d.polygon([(x - r, y + r // 2), (x - r // 2, y - r), (x + r // 3, y - r // 2), (x + r, y + r // 2)], fill=C[colour])
    d.line([x - r - 1, y + r // 2 + 1, x + r + 1, y + r // 2 + 1], fill=C["foam"])


def islet(d, x, y, w, h, top):
    d.ellipse([x - w - 2, y - h - 2, x + w + 2, y + h + 2], fill=C["foam"])
    d.ellipse([x - w, y - h, x + w, y + h], fill=C["rock2"])
    d.ellipse([x - w + 3, y - h + 2, x + w - 3, y + h - 3], fill=C[top])


def sketch():
    w, h = SEA["size"]
    size = (w * K, h * K)
    img = Image.new("RGB", size, C["z1"])
    d = ImageDraw.Draw(img)
    # The zones deepen southwards, with a dithered seam between them.
    z2, z3 = SEA["zone2_row"] * K, SEA["zone3_row"] * K
    d.rectangle([0, z2, size[0], size[1]], fill=C["z2"])
    d.rectangle([0, z3, size[0], size[1]], fill=C["z3"])
    d.rectangle([0, z3 + 90, size[0], size[1]], fill=C["z3b"])
    for seam, colour in [(z2, "z1"), (z3, "z2"), (z3 + 90, "z3")]:
        for x in range(0, size[0], 2):
            for dy in range(0, 8, 2):
                if (x // 2 + dy // 2) % 2 == 0:
                    d.point((x + (dy // 2) % 2, seam + dy), fill=C[colour])
    rnd = random.Random(5)
    for _ in range(260):
        x, y = rnd.randrange(size[0]), rnd.randrange(SEA["coast_rows"] * K + 6, size[1])
        d.line([x, y, x + rnd.randint(3, 6), y], fill=C["wave"] if y < z2 else C["z1"])
    # The island's south coast along the top: grass, a sandy edge with foam, the cape pier and the lighthouse.
    coast = SEA["coast_rows"] * K
    for x in range(size[0]):
        edge = coast - 4 + round(2 * math.sin(x * 0.07) + math.sin(x * 0.23))
        d.line([x, 0, x, edge], fill=C["grass"] if (x // 3) % 4 else C["grass2"])
        d.line([x, edge + 1, x, edge + 4], fill=C["sand"])
        d.point((x, edge + 5), fill=C["foam"])
    dx, dy = SEA["dock"]
    d.rectangle([dx * K - 2, coast - 4, dx * K + 3, dy * K + 6], fill=C["wood"])
    lx = dx * K + 16
    d.rectangle([lx - 2, 2, lx + 2, 13], fill=C["white"], outline=C["rock"])
    d.rectangle([lx - 2, 0, lx + 2, 2], fill=C["lamp"])
    # The sea garden: rows of kelp on floats off the pier.
    gx, gy = at("sea_garden")
    for row in range(4):
        d.line([gx - 22, gy - 9 + row * 6, gx + 22, gy - 9 + row * 6], fill=C["kelp"], width=2)
        for x in range(gx - 22, gx + 23, 6):
            d.point((x, gy - 10 + row * 6), fill=C["kelp2"])
    # The Resting Place: a ring of white buoys.
    rx, ry = at("rest_place")
    for a in range(8):
        d.rectangle([rx + 9 * math.cos(a * math.pi / 4) - 1, ry + 9 * math.sin(a * math.pi / 4) - 1,
                     rx + 9 * math.cos(a * math.pi / 4) + 1, ry + 9 * math.sin(a * math.pi / 4) + 1], fill=C["white"])
    # The Drowned Well: a dark whirlpool.
    wx, wy = at("drowned_well")
    for n in range(60):
        t = n / 60 * 3 * math.tau
        r = 2 + n / 60 * 12
        d.point((wx + r * math.cos(t), wy + r * math.sin(t) * 0.8), fill=C["black"] if n % 3 else C["foam"])
    # Reefs, then the Teeth as a jagged black cluster.
    for x, y in SEA["reefs"]:
        rock(d, x * K + 1, y * K + 1, 3)
    tx, ty = at("teeth")
    for ox, oy, r in [(-8, -4, 5), (0, -7, 6), (8, -2, 5), (-3, 5, 4), (6, 7, 4), (-10, 6, 3)]:
        rock(d, tx + ox, ty + oy, r, "black")
    # Seal Rock with seals, Eider Isle with birds, the Dead Fire with its dead tower, the Nameless Isle.
    sx, sy = at("seal_rock")
    d.ellipse([sx - 14, sy - 6, sx + 14, sy + 7], fill=C["foam"])
    d.ellipse([sx - 12, sy - 5, sx + 12, sy + 5], fill=C["rock2"])
    for ox in (-6, 0, 6):
        d.ellipse([sx + ox - 2, sy - 2, sx + ox + 2, sy + 1], fill=C["rock"])
    ex, ey = at("eider_isle")
    islet(d, ex, ey, 14, 9, "grass")
    for ox, oy in [(-5, -2), (0, 1), (5, -1), (2, -4)]:
        d.point((ex + ox, ey + oy), fill=C["bird"])
    fx, fy = at("dead_fire")
    islet(d, fx, fy, 13, 9, "rock")
    d.rectangle([fx - 2, fy - 12, fx + 2, fy + 2], fill=C["rock2"], outline=C["black"])
    d.rectangle([fx - 3, fy - 14, fx + 3, fy - 12], fill=C["black"])
    d.rectangle([fx + 5, fy - 1, fx + 10, fy + 4], fill=C["rock2"], outline=C["black"])
    nx, ny = at("nameless_isle")
    islet(d, nx, ny, 20, 13, "grass")
    for ox, oy in [(-8, -3), (-2, -6), (5, -2), (9, 3), (-5, 4)]:
        d.ellipse([nx + ox - 3, ny + oy - 3, nx + ox + 3, ny + oy + 3], fill=C["kelp"])
    # The ice field: floes around a pale patch.
    ix, iy = at("ice_field")
    for n in range(14):
        a, r = n * 2.4, 6 + (n * 7) % 26
        x, y = ix + r * math.cos(a), iy + r * math.sin(a) * 0.7
        d.polygon([(x - 4, y), (x - 1, y - 3), (x + 4, y - 1), (x + 2, y + 3)], fill=C["ice"])
    # The Kronvald fairway: a dashed lane across the far south with a steamer on it.
    fy2 = at("fairway")[1]
    for x in range(0, size[0], 12):
        d.line([x, fy2, x + 6, fy2], fill=C["sand"])
    d.rectangle([150, fy2 - 8, 170, fy2 - 3], fill=C["black"])
    d.rectangle([158, fy2 - 12, 161, fy2 - 8], fill=C["red"])
    os.makedirs(RAW, exist_ok=True)
    img.save(SKETCH)
    print(SKETCH)


PROMPT = ("top-down pixel art game sea chart of a cold northern sea south of a small island, seen straight from "
          "above: the island's green coast with a sandy shore, a wooden pier and a white lighthouse along the top "
          "edge; the water turning from teal shallows to deep dark blue towards the bottom; scattered black rocks "
          "with foam; a cluster of jagged black sea stacks; a flat grey rock with seals; a small grassy islet with "
          "white birds; a rocky islet with an old dead stone signal tower; a larger wooded island in the far south; "
          "a dark whirlpool; rows of kelp on floats; a ring of white buoys; ice floes; a dashed shipping lane with a "
          "small black steamer with a red funnel; muted colours, crisp pixels, no text, no letters, no border")


def b64(path):
    with open(path, "rb") as f:
        return {"type": "base64", "base64": base64.b64encode(f.read()).decode(), "format": "png"}


def _next_variant():
    return 1 + len([f for f in os.listdir(RAW) if f.startswith("variant_") and f.endswith(".png")])


def _log(entry):
    path = os.path.join(RAW, "meta.json")
    meta = json.load(open(path)) if os.path.exists(path) else {"runs": []}
    meta["runs"].append(entry)
    with open(path, "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


def _result(job):
    if job["status"] != "completed":
        raise RuntimeError(json.dumps(job)[:400])
    lr = job.get("last_response") or {}
    data = (lr.get("images") or [lr.get("image")])[0]
    return Image.open(io.BytesIO(base64.b64decode(data["base64"]))).convert("RGB")


def pro(seed=1):
    size = Image.open(SKETCH).size
    before = pl.generations_left()
    res = pl.request("POST", "/generate-image-v2", {
        "description": PROMPT, "image_size": {"width": size[0], "height": size[1]}, "no_background": False,
        "seed": seed,
        "reference_images": [{"image": b64(SKETCH), "size": {"width": size[0], "height": size[1]},
                              "usage_description": "exact layout of the sea chart: keep the coast at the top, where "
                                                   "every rock, islet, the whirlpool, the kelp rows, the buoys, the "
                                                   "ice and the shipping lane lie, and the depth bands"}]})
    img = _result(pl.wait_job(res["background_job_id"], timeout=1800))
    n = _next_variant()
    path = os.path.join(RAW, f"variant_{n}.png")
    img.save(path)
    used = before - pl.generations_left()
    _log({"method": "generate-image-v2, reference sketch.png", "prompt": PROMPT, "size": list(size), "seed": seed,
          "variant": n, "generations": used})
    print(path, "generations", used)


def inpaint(n, box, text, seed=1):
    src = os.path.join(RAW, f"variant_{n}.png")
    img = Image.open(src).convert("RGB")
    mask = Image.new("RGB", img.size, (0, 0, 0))
    ImageDraw.Draw(mask).rectangle(box, fill=(255, 255, 255))
    buf = io.BytesIO()
    mask.save(buf, "PNG")
    size = {"width": img.width, "height": img.height}
    before = pl.generations_left()
    res = pl.request("POST", "/inpaint-v3", {
        "description": text, "inpainting_image": {"image": b64(src), "size": size},
        "mask_image": {"image": {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"},
                       "size": size},
        "seed": seed, "no_background": False})
    out = _result(pl.wait_job(res["background_job_id"], timeout=1800))
    if out.size != img.size:
        out = out.resize(img.size, Image.NEAREST)
    m = _next_variant()
    path = os.path.join(RAW, f"variant_{m}.png")
    out.save(path)
    used = before - pl.generations_left()
    _log({"method": "inpaint-v3", "from": n, "box": box, "prompt": text, "variant": m, "generations": used})
    print(path, "generations", used)


def _water_mask(img, box, tolerance=16):
    """What in `box` is not open water: pixels unlike every colour on the box's border (foam kept)."""
    x0, y0, x1, y1 = box
    px = img.load()
    border = {px[x, y] for x in range(x0, x1) for y in (y0, y1 - 1)} | {px[x, y] for y in range(y0, y1) for x in (x0, x1 - 1)}
    border = list(border)
    mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    mp = mask.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = px[x, y]
            if min(sum(abs(a - b) for a, b in zip(c, w)) for w in border) > tolerance:
                mp[x - x0, y - y0] = 255
    from PIL import ImageFilter
    return mask.filter(ImageFilter.MaxFilter(3))


def move(n, box, centre, fill_from):
    """Moves the thing in `box` of variant n so its middle lands on `centre`; the hole it leaves is filled
    with the open water of the same size at `fill_from` (a corner). Saved as the next variant."""
    src = Image.open(os.path.join(RAW, f"variant_{n}.png")).convert("RGB")
    out = src.copy()
    x0, y0, x1, y1 = box
    thing = src.crop(box)
    mask = _water_mask(src, box)
    fx, fy = fill_from
    out.paste(src.crop((fx, fy, fx + x1 - x0, fy + y1 - y0)), (x0, y0))
    cx, cy = centre
    out.paste(thing, (cx - (x1 - x0) // 2, cy - (y1 - y0) // 2), mask)
    m = _next_variant()
    path = os.path.join(RAW, f"variant_{m}.png")
    out.save(path)
    _log({"method": "move (by hand, no generation)", "from": n, "box": box, "centre": centre, "fill_from": fill_from,
          "variant": m, "generations": 0})
    print(path)


def pick(n):
    os.makedirs(OUT, exist_ok=True)
    shutil.copy(os.path.join(RAW, f"variant_{n}.png"), os.path.join(OUT, "sea_chart.png"))
    print(os.path.join(OUT, "sea_chart.png"))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sketch"
    if cmd == "sketch":
        sketch()
    elif cmd == "pro":
        pro(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    elif cmd == "inpaint":
        inpaint(int(sys.argv[2]), [int(v) for v in sys.argv[3].split(",")], sys.argv[4])
    elif cmd == "move":
        move(int(sys.argv[2]), [int(v) for v in sys.argv[3].split(",")], [int(v) for v in sys.argv[4].split(",")],
             [int(v) for v in sys.argv[5].split(",")])
    elif cmd == "pick":
        pick(int(sys.argv[2]))
