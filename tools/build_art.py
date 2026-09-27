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
import os, re, json, glob
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
         "animating": "idle", "breathing-idle": "idle", "idle-shaking-head": "idle"}


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


def _meta_groups(folder):
    """(export folder name, group id) of each recorded animation, in creation order."""
    path = os.path.join(folder, "meta.json")
    if not os.path.exists(path):
        return []
    out = []
    for key, info in json.load(open(path)).get("animations", {}).items():
        template = info.get("template_animation_id")
        base = {"breathing-idle": "animating"}.get(template, template) if template else key.split(":")[0]
        out.append((base, str(info.get("group") or "")))
    return out


def build_cast():
    os.makedirs(CAST_OUT, exist_ok=True)
    count = 0
    for group in ("characters", "animals", "spirits", "enemies"):
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
                # A re-run animation gets a folder "<name>-<first 8 of its group id>" or takes the plain
                # name; meta.json records the groups in creation order. Directions merge oldest first,
                # so a direction redone later (a fixed south idle) replaces the old one.
                anims = frames.get("animations", {})
                order = {}
                recorded = list(_meta_groups(folder))
                for name in anims:
                    m = re.fullmatch(r"(.*)-([0-9a-f]{8})", name)
                    if m:
                        order[name] = next((i for i, (b, g) in enumerate(recorded) if g.startswith(m.group(2))), -1)
                for name in anims:
                    if name in order:
                        continue
                    claimed = {order[n] for n in order if n.startswith(name + "-")}
                    free = [i for i, (b, g) in enumerate(recorded) if b == name and i not in claimed]
                    order[name] = free[0] if free else -1
                merged = {}
                for name in sorted(anims, key=lambda n: order[n]):
                    base = re.sub(r"-[0-9a-f]{8}$", "", name)
                    merged.setdefault(NAMES.get(base, base), {}).update(anims[name])
                for name, dirs in sorted(merged.items()):
                    for d in ("south", "east", "north", "west"):
                        if d in dirs:
                            strips.append((name, d, [load(rel) for rel in dirs[d]]))
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


HERO_ORDER = ("south", "west", "east", "north")  # the player's rows: down, left, right, up


def build_hero():
    """The player's sheets assets/sprites/characters/hero_<male|female>.png: rows 0-3 walk (6 frames),
    rows 4-7 breathing idle (padded to 6), in Player._direction_index order; <id>.json keeps the foot."""
    out = "assets/sprites/characters"
    made = 0
    for aid in ("hero_male", "hero_female"):
        path = os.path.join(CAST_OUT, aid + ".json")
        if not os.path.exists(path):
            continue
        info = json.load(open(path))
        fw, fh = info["frame"]
        src = Image.open(os.path.join(CAST_OUT, aid + ".png")).convert("RGBA")
        sheet = Image.new("RGBA", (fw * 6, fh * 8))
        for block, anim in enumerate(("walk", "idle")):
            for r, d in enumerate(HERO_ORDER):
                row, count = info["anims"][anim][d]
                for k in range(6):
                    frame = src.crop((k % count * fw, row * fh, (k % count + 1) * fw, (row + 1) * fh))
                    sheet.paste(frame, (k * fw, (block * 4 + r) * fh))
        sheet.save(os.path.join(out, aid + ".png"))
        with open(os.path.join(out, aid + ".json"), "w") as f:
            json.dump({"frame": [fw, fh], "foot": info["foot"], "idle_frames": info["anims"]["idle"]["south"][1]}, f)
        made += 1
    return made


def build_props():
    """Map props: batch pieces from props/small/ and map-objects, all cropped to their pixels
    (PropArt stands them on their bottom edge)."""
    out = "assets/sprites/props"
    os.makedirs(out, exist_ok=True)
    count = 0
    for path in sorted(glob.glob(os.path.join(SRC, "props", "small", "*.png"))):
        img = Image.open(path).convert("RGBA")
        img.crop(img.getbbox() or (0, 0, img.width, img.height)).save(os.path.join(out, os.path.basename(path)))
        count += 1
    # Crop stages (<crop>_<1-4|ripe>) and stations (station_<id>) share the props folder.
    for path in sorted(glob.glob(os.path.join(SRC, "crops", "*.png"))):
        img = Image.open(path).convert("RGBA")
        img.crop(img.getbbox() or (0, 0, img.width, img.height)).save(os.path.join(out, os.path.basename(path)))
        count += 1
    for folder in sorted(glob.glob(os.path.join(SRC, "stations", "*"))):
        aid = os.path.basename(folder)
        path = os.path.join(folder, aid + ".png")
        if os.path.exists(path):
            img = Image.open(path).convert("RGBA")
            img.crop(img.getbbox() or (0, 0, img.width, img.height)).save(os.path.join(out, "station_" + aid + ".png"))
            count += 1
    # Interior furniture (furn_*), lighthouse fittings (lh_*) and placeable decor (decor_*).
    for folder in sorted(glob.glob(os.path.join(SRC, "interiors", "*"))):
        aid = os.path.basename(folder)
        path = os.path.join(folder, aid + ".png")
        if os.path.exists(path):
            img = Image.open(path).convert("RGBA")
            img.crop(img.getbbox() or (0, 0, img.width, img.height)).save(os.path.join(out, aid + ".png"))
            count += 1
    for folder in sorted(glob.glob(os.path.join(SRC, "props", "*"))):
        aid = os.path.basename(folder)
        path = os.path.join(folder, aid + ".png")
        if aid == "small" or not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGBA")
        img.crop(img.getbbox() or (0, 0, img.width, img.height)).save(os.path.join(out, aid + ".png"))
        count += 1
    return count


def build_icons():
    """Inventory icons: assets_src/pixellab/icons/<item id>.png -> assets/sprites/icons/."""
    out = "assets/sprites/icons"
    os.makedirs(out, exist_ok=True)
    count = 0
    for path in sorted(glob.glob(os.path.join(SRC, "icons", "*.png"))):
        Image.open(path).convert("RGBA").save(os.path.join(out, os.path.basename(path)))
        count += 1
    return count + build_derived_icons(out)


SAPLINGS = {"sapling_buckthorn": "tree_buckthorn_young", "sapling_rowan": "tree_rowan_young",
            "sapling_apple": "tree_apple_young", "bush_blueberry": "bush_blueberry_fruiting",
            "bush_lingonberry": "bush_lingonberry_fruiting", "cloudberry_bush": "bush_cloudberry_fruiting"}


def icon_fit(img, size=32):
    """A map sprite as a 32 px icon: trimmed, shrunk by whole steps (box filter, hard alpha), centred."""
    img = img.crop(img.getbbox())
    k = 1
    while img.width / k > size or img.height / k > size:
        k += 1
    if k > 1:
        img = img.reduce(k)
        a = img.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
        img.putalpha(a)
    out = Image.new("RGBA", (size, size))
    out.paste(img, ((size - img.width) // 2, (size - img.height) // 2))
    return out


def build_derived_icons(out):
    """Items whose map sprite already reads as an icon (decor, stations, saplings, grave markers),
    and seed packets: the paper packet with the crop drawn small in its corner."""
    items = json.load(open("data/items.json"))
    props = "assets/sprites/props"
    count = 0
    for it in items:
        iid = it["id"]
        dest = os.path.join(out, iid + ".png")
        if os.path.exists(os.path.join(SRC, "icons", iid + ".png")):
            continue
        if iid.startswith("seed_"):
            packet = os.path.join(SRC, "ui", "icons", "seed_packet.png")
            crop = os.path.join(SRC, "icons", iid[5:] + ".png")
            if not os.path.exists(packet):
                continue
            img = Image.open(packet).convert("RGBA")
            if os.path.exists(crop):
                small = Image.open(crop).convert("RGBA")
                small = small.crop(small.getbbox())
                small = small.resize((max(1, small.width * 14 // 32), max(1, small.height * 14 // 32)), Image.NEAREST)
                img.alpha_composite(small, (img.width - small.width - 6, img.height - small.height - 6))
            img.save(dest)
            count += 1
            continue
        names = [SAPLINGS.get(iid, ""), iid, "decor_" + iid, "station_" + iid, iid + "_h", "grave_%s_new" % iid]
        src = next((os.path.join(props, n + ".png") for n in names if n and os.path.exists(os.path.join(props, n + ".png"))), "")
        if src:
            icon_fit(Image.open(src).convert("RGBA")).save(dest)
            count += 1
    return count


def build_portraits():
    """Talk portraits: assets_src/pixellab/portraits/<id>/<emotion>.png -> assets/sprites/portraits/<id>_<emotion>.png."""
    out = "assets/sprites/portraits"
    os.makedirs(out, exist_ok=True)
    count = 0
    for path in sorted(glob.glob(os.path.join(SRC, "portraits", "*", "*.png"))):
        pid = os.path.basename(os.path.dirname(path))
        emo = os.path.splitext(os.path.basename(path))[0]
        Image.open(path).convert("RGBA").save(os.path.join(out, "%s_%s.png" % (pid, emo)))
        count += 1
    return count


def drop_specks(img, share=0.35):
    """Removes stray blobs (foam, grass flecks) smaller than `share` of the largest one and more than 4 px
    away from it (a sail drawn apart from the hull stays), in place."""
    from collections import deque
    w, h = img.size
    px = img.load()
    seen, comps = set(), []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 20 and (x, y) not in seen:
                q, comp = deque([(x, y)]), []
                seen.add((x, y))
                while q:
                    a, b = q.popleft()
                    comp.append((a, b))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            n = (a + dx, b + dy)
                            if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n][3] > 20:
                                seen.add(n)
                                q.append(n)
                comps.append(comp)
    if len(comps) > 1:
        main = max(comps, key=len)
        near = set()
        for (a, b) in main:
            for dx in range(-4, 5):
                for dy in range(-4, 5):
                    near.add((a + dx, b + dy))
        for comp in comps:
            if comp is main or len(comp) >= len(main) * share:
                continue
            if not any(p in near for p in comp):
                for p in comp:
                    px[p] = (0, 0, 0, 0)
    return img


def build_sea():
    """Boats (sea/<boat>/<state>/sheet.png, 8 rotations in a row) -> assets/sprites/sea/boat_<boat>_<state>.png +
    .json {frame, dirs}; sea objects (sea/<id>/<id>.png, loops in sea/<id>/loop/) -> assets/sprites/sea/<id>.png
    and <id>_loop.png strips; spyglass vignettes -> assets/sprites/spyglass/."""
    out = "assets/sprites/sea"
    os.makedirs(out, exist_ok=True)
    count = 0
    for sheet in sorted(glob.glob(os.path.join(SRC, "sea", "*", "*", "sheet.png"))):
        state = os.path.basename(os.path.dirname(sheet))
        boat = os.path.basename(os.path.dirname(os.path.dirname(sheet)))
        meta = json.load(open(sheet[:-4] + ".json"))["spritesheet"]
        img = Image.open(sheet).convert("RGBA")
        cw = meta["cell_size"]["width"]
        for i in range(img.width // cw):
            cell = drop_specks(img.crop((i * cw, 0, (i + 1) * cw, img.height)))
            img.paste(cell, (i * cw, 0))
        img.save(os.path.join(out, "boat_%s_%s.png" % (boat, state)))
        json.dump({"frame": [meta["cell_size"]["width"], meta["cell_size"]["height"]], "dirs": meta["rows"][0]["directions"]},
                  open(os.path.join(out, "boat_%s_%s.json" % (boat, state)), "w"))
        count += 1
    for folder in sorted(glob.glob(os.path.join(SRC, "sea", "*"))):
        oid = os.path.basename(folder)
        png = os.path.join(folder, oid + ".png")
        if not os.path.exists(png):
            continue
        img = Image.open(png).convert("RGBA")
        img.crop(img.getbbox()).save(os.path.join(out, oid + ".png"))
        count += 1
        frames = sorted(glob.glob(os.path.join(folder, "loop", "frame_*.png")))
        if frames:
            imgs = [Image.open(f).convert("RGBA") for f in frames]
            w, h = imgs[0].size
            strip = Image.new("RGBA", (w * len(imgs), h))
            for i, im in enumerate(imgs):
                strip.paste(im, (i * w, 0))
            strip.save(os.path.join(out, oid + "_loop.png"))
            json.dump({"frame": [w, h], "frames": len(imgs)}, open(os.path.join(out, oid + "_loop.json"), "w"))
    spy = "assets/sprites/spyglass"
    os.makedirs(spy, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SRC, "spyglass", "*.png"))):
        Image.open(path).convert("RGBA").save(os.path.join(spy, os.path.basename(path)))
        count += 1
    return count


if __name__ == "__main__":
    print("icons", build_icons(), "props", build_props(), "portraits", build_portraits(), "sea", build_sea())
    print("tilesets", build_tilesets(), "buildings", build_buildings(), "cast", build_cast(), "hero", build_hero())
