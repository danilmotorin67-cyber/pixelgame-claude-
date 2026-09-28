#!/usr/bin/env python3
"""The island chart (M, tab «Остров»).

1. `sketch` draws a flat colour layout of the whole island from data/island_map.json and the land maps
   themselves (data/regions.json and the cape): each map at its place, its coast, roads, houses, lakes,
   cliffs, bog, the wrecks; the gaps between maps are filled with moor and grass so it is one island.
2. `generate` sends the sketch to PixelLab (create-image-pixflux with the sketch as the init image) to be
   redrawn as a pixel-art chart; results go to assets_src/pixellab/island_map/variant_<n>.png.
   `pro [seed]` asks the Pro model (generate-image-v2) with the sketch as a layout reference instead;
   `inpaint <n> x0,y0,x1,y1 "<text>"` redraws one box of a variant (how the lighthouse was moved to the cape).
3. `pick <n>` copies a variant to assets/sprites/ui/island_map.png.

The Pro picture follows the sketch only roughly, so data/island_map.json keeps a second set of rectangles,
`chart`, fitted by eye to the finished picture; the game uses those.
"""
import base64
import io
import json
import math
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab as pl  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = json.load(open(os.path.join(ROOT, "data", "island_map.json")))["layout"]
REGIONS = json.load(open(os.path.join(ROOT, "data", "regions.json")))
RAW = os.path.join(pl.RAW, "island_map")
SKETCH = os.path.join(RAW, "sketch.png")
OUT = os.path.join(ROOT, "assets", "sprites", "ui")

C = {"deep": (27, 43, 60), "sea": (36, 64, 90), "shallow": (63, 127, 143), "foam": (207, 230, 226),
     "sand": (216, 196, 154), "wet": (140, 106, 78), "grass": (78, 110, 58), "meadow": (122, 150, 76),
     "heather": (113, 100, 123), "rock": (108, 110, 118), "basalt": (69, 70, 78), "road": (176, 143, 108),
     "roof": (107, 74, 51), "roof2": (155, 47, 42), "wall": (216, 196, 154), "water": (47, 90, 118),
     "bog": (74, 52, 40), "birch": (47, 74, 48), "birch2": (201, 200, 194), "stones": (201, 200, 194),
     "wreck": (43, 31, 26), "white": (244, 247, 246), "lamp": (255, 200, 90), "field": (107, 74, 51),
     "grave": (201, 200, 194)}

CAPE = {"size": [90, 70], "biome": "cape", "coast_row": 54}


def region(rid):
    return CAPE if rid == "cape" else REGIONS[rid]


def ground(rid, reg, tx, ty):
    """The colour of one tile of a land map, much as the game draws it."""
    w, h = reg["size"]
    coast = int(reg.get("coast_row", -1))
    biome = reg["biome"]
    if coast >= 0 and ty >= coast:
        if ty >= coast + 6:
            return C["sea"] if ty < coast + 9 else C["deep"]
        return C["sand"] if ty < coast + 3 else C["wet"]
    if biome == "birch" and 12 <= tx < 17 and (ty < 18 or ty > 22):
        return C["water"]
    if biome in ("village", "moor") and (abs(tx - w // 2) <= 1 or abs(ty - h // 2) <= 1):
        return C["road"]
    return {"moor": C["heather"], "cliffs": C["rock"], "village": C["meadow"], "beach": C["sand"],
            "birch": C["grass"], "lagoon": C["grass"], "cape": C["grass"]}.get(biome, C["grass"])


LANDMARK = {"house": "roof", "hall": "roof2", "smith": "roof", "tavern": "roof2", "chapel": "wall", "ruin": "rock",
            "lake": "water", "stream": "water", "bog": "bog", "reeds": "bog", "cliff": "basalt", "stones": "stones",
            "wreck": "wreck", "cave": "basalt", "nests": "stones", "pier": "road", "clearing": "meadow"}


def _noise(size, seed, scale):
    """Smooth value noise in [-1, 1]: a coarse random grid blown up with bicubic smoothing."""
    import random
    rnd = random.Random(seed)
    gw, gh = size[0] // scale + 2, size[1] // scale + 2
    grid = Image.new("L", (gw, gh))
    grid.putdata([rnd.randint(0, 255) for _ in range(gw * gh)])
    big = grid.resize((gw * scale, gh * scale), Image.BICUBIC).crop((0, 0, size[0], size[1]))
    return [(v - 128) / 128.0 for v in big.get_flattened_data()]


def _dry_rect(rid):
    x, y, w, h = LAYOUT["regions"][rid]
    reg = region(rid)
    coast = int(reg.get("coast_row", -1))
    dry = h if coast < 0 else round(h * (coast + 2) / reg["size"][1])
    return x, y, w, dry


def island_mask(size):
    """One island: the dry part of every land map, blurred together and cut by noise into a coastline."""
    base = Image.new("L", size, 0)
    d = ImageDraw.Draw(base)
    for rid in LAYOUT["regions"]:
        x, y, w, h = _dry_rect(rid)
        d.rectangle([x + 2, y + 2, x + w - 3, y + h - 3], fill=255)
    soft = base.filter(ImageFilter.GaussianBlur(8))
    noise = _noise(size, 3, 9)
    fine = _noise(size, 5, 3)
    out = Image.new("L", size, 0)
    out.putdata([255 if v / 255.0 + 0.2 * n + 0.08 * f > 0.42 else 0 for v, n, f in zip(soft.get_flattened_data(), noise, fine)])
    return out.filter(ImageFilter.ModeFilter(3))


BIOME = {"moor": "heather", "cliffs": "rock", "village": "meadow", "beach": "grass", "birch": "grass",
         "lagoon": "grass", "cape": "grass"}


def _nearest(xx, yy):
    best, rid_best = 1e9, None
    for rid in LAYOUT["regions"]:
        x, y, w, h = _dry_rect(rid)
        dx = max(x - xx, 0, xx - (x + w))
        dy = max(y - yy, 0, yy - (y + h))
        dist = dx * dx + dy * dy
        if dist < best:
            best, rid_best = dist, rid
    return rid_best


def sketch():
    size = tuple(LAYOUT["size"])
    img = Image.new("RGB", size, C["deep"])
    d = ImageDraw.Draw(img)
    mask = island_mask(size)
    img.paste(C["sea"], mask=mask.filter(ImageFilter.MaxFilter(11)))
    img.paste(C["shallow"], mask=mask.filter(ImageFilter.MaxFilter(5)))
    img.paste(C["foam"], mask=mask.filter(ImageFilter.MaxFilter(3)))
    beach = mask.filter(ImageFilter.MinFilter(3))
    img.paste(C["sand"], mask=mask)
    # The ground by the nearest land map, dithered where two meet.
    jitter = _noise(size, 11, 4)
    px = img.load()
    bp = beach.load()
    for yy in range(size[1]):
        for xx in range(size[0]):
            if not bp[xx, yy]:
                continue
            j = jitter[yy * size[0] + xx]
            rid = _nearest(xx + round(j * 5), yy + round(j * 4))
            colour = C[BIOME.get(region(rid)["biome"], "grass")]
            if (xx + yy) % 2 and j > 0.45:
                colour = C["meadow"] if colour != C["meadow"] else C["grass"]
            px[xx, yy] = colour
    # Rock along the north, the cliffs' own ground.
    x, y, w, h = LAYOUT["regions"]["bird_cliffs"]
    for yy in range(y, y + h):
        for xx in range(x - 6, x + w + 6):
            if bp[xx, yy] and (xx * 7 + yy * 3) % 5 and yy < y + h - 6:
                px[xx, yy] = C["rock"] if (xx + yy) % 3 else C["basalt"]
    # Each map's own features.
    for rid, (x, y, w, h) in LAYOUT["regions"].items():
        reg = region(rid)
        rw, rh = reg["size"]
        k = (w / rw, h / rh)
        if reg["biome"] in ("village", "moor"):
            coast = int(reg.get("coast_row", rh))
            cx, cy = x + w // 2, y + h // 2
            d.line([cx, y, cx, y + (coast if coast > 0 else rh) * k[1]], fill=C["road"])
            d.line([x, cy, x + w - 1, cy], fill=C["road"])
        if rid == "birch":
            sx = x + 14 * k[0]
            d.line([sx, y, sx, y + h], fill=C["water"], width=2)
            for i in range(34):
                bx, by = x + (i * 37) % w, y + (i * 23) % h
                if abs(bx - sx) > 3:
                    d.ellipse([bx - 2, by - 2, bx + 2, by + 2], fill=C["birch"])
                    d.point((bx, by + 2), fill=C["birch2"])
        for item in reg.get("landmarks", []):
            colour = LANDMARK.get(item["kind"])
            if not colour:
                continue
            ax, ay = item["at"]
            sw, sh = item["size"]
            box = [x + ax * k[0], y + ay * k[1], x + (ax + sw) * k[0] - 1, y + (ay + sh) * k[1] - 1]
            kind = item["kind"]
            if kind in ("house", "hall", "smith", "tavern", "chapel", "ruin"):
                d.rectangle(box, fill=C[colour], outline=C["wreck"])
            elif kind in ("stones", "nests"):
                cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
                for a in range(8):
                    d.point((cx + 3 * math.cos(a * math.pi / 4), cy + 3 * math.sin(a * math.pi / 4)), fill=C[colour])
            elif kind == "wreck":
                d.line([box[0], box[3], box[2], box[1] + 2], fill=C[colour], width=2)
                d.line([box[0] + 4, box[1], box[0] + 6, box[3]], fill=C[colour])
            elif kind in ("lake", "bog", "reeds"):
                d.ellipse(box, fill=C[colour])
            elif kind == "pier":
                d.rectangle([box[0], box[1], box[0] + 2, box[3] + 6], fill=C[colour])
            elif kind in ("cliff", "cave"):
                d.rectangle(box, fill=C[colour])
    # The cape: fields, the graveyard, the keeper's cottage and the lighthouse with its light.
    x, y, w, h = LAYOUT["regions"]["cape"]
    d.rectangle([x + 8, y + 26, x + 20, y + 33], fill=C["field"])
    d.rectangle([x + 44, y + 25, x + 56, y + 32], fill=C["field"])
    for gx in range(4):
        for gy in range(2):
            d.point((x + 17 + gx * 2, y + 22 + gy * 3), fill=C["grave"])
    d.rectangle([x + 23, y + 12, x + 30, y + 17], fill=C["roof"], outline=C["wreck"])
    d.rectangle([x + 33, y + 5, x + 35, y + 15], fill=C["white"], outline=C["basalt"])
    d.rectangle([x + 33, y + 3, x + 35, y + 5], fill=C["lamp"])
    # The Teeth off the cape.
    for tx, ty in [(236, 160), (242, 164), (230, 166), (246, 156), (224, 171)]:
        d.polygon([(tx, ty - 3), (tx + 2, ty + 1), (tx - 2, ty + 1)], fill=C["basalt"])
    os.makedirs(RAW, exist_ok=True)
    img.save(SKETCH)
    print(SKETCH)


PROMPT = ("top-down pixel art game world map of a small cold northern island in a slate-grey sea, old explorer's "
          "chart look: basalt cliffs in the north, lilac heather moorland with a lake and a stone circle, a birch "
          "wood with a stream, sandy beaches with seals in the south-west, a bay with ship wrecks, a fishing "
          "village of tarred wooden houses with turf roofs and a pier, a quiet reedy lagoon, a basalt cape in the "
          "east with a white stone lighthouse, a cottage, fields and a small graveyard; jagged black rocks in the "
          "sea; muted colours, crisp pixels, no text, no letters, no labels, no border")


def b64(path):
    with open(path, "rb") as f:
        return {"type": "base64", "base64": base64.b64encode(f.read()).decode(), "format": "png"}


# The chart is drawn larger than the layout, to be shown at about one texel per screen pixel.
SCALE = 400 / 260  # pixflux takes at most 400 px a side


def generate(strengths):
    size = [round(LAYOUT["size"][0] * SCALE) // 4 * 4, round(LAYOUT["size"][1] * SCALE) // 4 * 4]
    big = os.path.join(RAW, "sketch_big.png")
    Image.open(SKETCH).resize(size, Image.NEAREST).save(big)  # the init image; not kept
    spent = 0.0
    first = 1 + len([f for f in os.listdir(RAW) if f.startswith("variant_") and f.endswith(".png")])
    for n, strength in enumerate(strengths, first):
        before = pl.generations_left()
        res = pl.request("POST", "/create-image-pixflux", {
            "description": PROMPT, "image_size": {"width": size[0], "height": size[1]},
            "init_image": b64(big), "init_image_strength": strength, "view": "high top-down",
            "outline": "single color black outline", "detail": "highly detailed", "text_guidance_scale": 8,
            "seed": 7 + n})
        img = Image.open(io.BytesIO(base64.b64decode(res["image"]["base64"]))).convert("RGB")
        path = os.path.join(RAW, f"variant_{n}.png")
        img.save(path)
        used = before - pl.generations_left()
        spent += used
        print(path, "strength", strength, "generations", used)
    os.remove(big)
    meta_path = os.path.join(RAW, "meta.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {"runs": []}
    meta["runs"].append({"method": "create-image-pixflux, init image sketch_big.png", "prompt": PROMPT,
                         "size": size, "strengths": strengths, "first_variant": first, "generations": spent})
    with open(meta_path, "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


def generate_pro(seed=1):
    """The Pro model with the sketch as a layout reference (one picture above 170 px)."""
    size = [416, 288]
    before = pl.generations_left()
    res = pl.request("POST", "/generate-image-v2", {
        "description": PROMPT, "image_size": {"width": size[0], "height": size[1]}, "no_background": False,
        "seed": seed,
        "reference_images": [{"image": b64(SKETCH), "size": {"width": LAYOUT["size"][0], "height": LAYOUT["size"][1]},
                              "usage_description": "exact layout of the island map: keep the coastline, where each "
                                                   "area, road, house, lake, stream, field and the lighthouse lie"}]})
    job = pl.wait_job(res["background_job_id"], timeout=1800)
    if job["status"] != "completed":
        raise RuntimeError(json.dumps(job)[:400])
    data = (job.get("last_response") or {}).get("images", [{}])[0]
    img = Image.open(io.BytesIO(base64.b64decode(data["base64"]))).convert("RGB")
    first = 1 + len([f for f in os.listdir(RAW) if f.startswith("variant_") and f.endswith(".png")])
    path = os.path.join(RAW, f"variant_{first}.png")
    img.save(path)
    used = before - pl.generations_left()
    meta_path = os.path.join(RAW, "meta.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {"runs": []}
    meta["runs"].append({"method": "generate-image-v2, reference sketch.png", "prompt": PROMPT, "size": size,
                         "seed": seed, "first_variant": first, "generations": used})
    with open(meta_path, "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print(path, "generations", used)


def inpaint(n, box, text, seed=1):
    """Redraw one box [x0, y0, x1, y1] of variant n (Pro inpaint); the result is saved as the next variant."""
    src = os.path.join(RAW, f"variant_{n}.png")
    img = Image.open(src).convert("RGB")
    mask = Image.new("RGB", img.size, (0, 0, 0))
    ImageDraw.Draw(mask).rectangle(box, fill=(255, 255, 255))
    buf = io.BytesIO()
    mask.save(buf, "PNG")
    before = pl.generations_left()
    res = pl.request("POST", "/inpaint-v3", {
        "description": text, "inpainting_image": {"image": b64(src), "size": {"width": img.width, "height": img.height}},
        "mask_image": {"image": {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"},
                       "size": {"width": img.width, "height": img.height}},
        "seed": seed, "no_background": False})
    job = pl.wait_job(res["background_job_id"], timeout=1800)
    if job["status"] != "completed":
        raise RuntimeError(json.dumps(job)[:400])
    lr = job.get("last_response") or {}
    data = (lr.get("images") or [lr.get("image")])[0]
    out = Image.open(io.BytesIO(base64.b64decode(data["base64"]))).convert("RGB")
    if out.size != img.size:
        out = out.resize(img.size, Image.NEAREST)
    first = 1 + len([f for f in os.listdir(RAW) if f.startswith("variant_") and f.endswith(".png")])
    path = os.path.join(RAW, f"variant_{first}.png")
    out.save(path)
    used = before - pl.generations_left()
    meta_path = os.path.join(RAW, "meta.json")
    meta = json.load(open(meta_path))
    meta["runs"].append({"method": "inpaint-v3", "from": n, "box": box, "prompt": text, "first_variant": first,
                         "generations": used})
    with open(meta_path, "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print(path, "generations", used)


def pick(n):
    os.makedirs(OUT, exist_ok=True)
    shutil.copy(os.path.join(RAW, f"variant_{n}.png"), os.path.join(OUT, "island_map.png"))
    print(os.path.join(OUT, "island_map.png"))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sketch"
    if cmd == "sketch":
        sketch()
    elif cmd == "generate":
        generate([int(s) for s in sys.argv[2:]] or [250, 400, 550])
    elif cmd == "pro":
        generate_pro(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    elif cmd == "inpaint":
        inpaint(int(sys.argv[2]), [int(v) for v in sys.argv[3].split(",")], sys.argv[4])
    elif cmd == "pick":
        pick(int(sys.argv[2]))
