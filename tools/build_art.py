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
from PIL import Image, ImageChops

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
    """(names the export folder may carry, group id, animation name in the sheet) of each recorded animation,
    in creation order. PixelLab exports skeleton templates under "animating" (or their own name), custom
    ones under their animation name; "<name>:2" keys are second takes of <name>."""
    path = os.path.join(folder, "meta.json")
    if not os.path.exists(path):
        return []
    out = []
    for key, info in json.load(open(path)).get("animations", {}).items():
        template = info.get("template_animation_id")
        base = template or key.split(":")[0]
        names = {base, "animating"} if template else {base}
        out.append((names, str(info.get("group") or ""), NAMES.get(base, base)))
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
                # A character made as a state of another (hero_suit) exports the whole group; meta.json
                # names which state is its own.
                own = json.load(open(os.path.join(folder, "meta.json"))).get("state", 0) \
                    if os.path.exists(os.path.join(folder, "meta.json")) else 0
                frames = json.load(open(meta_path))["states"][own]["frames"]
                load = lambda rel: Image.open(os.path.join(folder, rel)).convert("RGBA")
                for d in ("south", "east", "north", "west"):
                    if d in frames["rotations"]:
                        strips.append(("rot", d, [load(frames["rotations"][d])]))
                # A re-run animation gets a folder "<name>-<first 8 of its group id>" or takes the plain
                # name; meta.json records the groups in creation order. Directions merge oldest first,
                # so a direction redone later (a fixed south idle) replaces the old one.
                anims = frames.get("animations", {})
                # Each export folder is matched to its recorded animation: by the group id in its suffix, else by
                # its name among the animations not yet matched; the sheet name comes from the recorded one.
                # Folders merge in creation order, so a later take replaces a direction drawn before.
                recorded = list(_meta_groups(folder))
                order = {}
                for name in anims:
                    m = re.fullmatch(r"(.*)-([0-9a-f]{8})", name)
                    if m:
                        order[name] = next((i for i, (n, g, _) in enumerate(recorded) if g.startswith(m.group(2))), -1)
                # Plain folders named after their animation are matched before the generic "animating" ones.
                plain = sorted((n for n in anims if n not in order), key=lambda n: n == "animating")
                for name in plain:
                    claimed = set(order.values())
                    free = [i for i, (n, g, _) in enumerate(recorded) if name in n and i not in claimed]
                    order[name] = free[0] if free else -1
                merged = {}
                for name in sorted(anims, key=lambda n: order[n]):
                    base = re.sub(r"-[0-9a-f]{8}$", "", name)
                    sheet_name = recorded[order[name]][2] if order[name] >= 0 else NAMES.get(base, base)
                    merged.setdefault(sheet_name, {}).update(anims[name])
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
# Blocks of four rows (HERO_ORDER) in this order; the first two keep the old walk/idle layout.
HERO_ANIMS = ("walk", "idle", "hoe", "water", "axe", "pick", "scythe", "shovel", "cast", "reel", "net", "attack",
              "carry", "swim", "sit", "sleep", "harpoon", "dodge", "rite", "light_lamp", "clean_glass", "wind",
              "ring_bell", "pet", "eat", "faint", "lift_cat", "surprised", "happy")


def build_hero():
    """The player's sheets assets/sprites/characters/<hero_male|hero_female|hero_suit>.png: one block of four
    rows (down, left, right, up) per animation of HERO_ANIMS the hero has, columns = the longest cycle.
    West is east mirrored where PixelLab drew no west; a direction it lacks takes the south one.
    <id>.json: frame size, foot, columns and {anim: [first row, frames]}."""
    out = "assets/sprites/characters"
    made = 0
    for aid in ("hero_male", "hero_female", "hero_suit"):
        path = os.path.join(CAST_OUT, aid + ".json")
        if not os.path.exists(path):
            continue
        info = json.load(open(path))
        fw, fh = info["frame"]
        src = Image.open(os.path.join(CAST_OUT, aid + ".png")).convert("RGBA")
        cast = dict(info["anims"])
        if "idle" not in cast:
            cast["idle"] = {d: v for d, v in cast["rot"].items()}
        names = [a for a in HERO_ANIMS if a in cast]
        cols = max(max(n for _, n in cast[a].values()) for a in names)
        sheet = Image.new("RGBA", (fw * cols, fh * 4 * len(names)))
        layout = {}
        for block, anim in enumerate(names):
            dirs = cast[anim]
            count = max(n for _, n in dirs.values())
            for r, d in enumerate(HERO_ORDER):
                flip = d == "west" and "west" not in dirs and "east" in dirs
                row, n = dirs["east"] if flip else dirs.get(d, dirs.get("south", next(iter(dirs.values()))))
                for k in range(count):
                    # Cycles wrap; a one-off action shorter in this direction holds its last pose.
                    j = k % n if anim in ("walk", "idle") else min(k, n - 1)
                    frame = src.crop((j * fw, row * fh, (j + 1) * fw, (row + 1) * fh))
                    if flip:
                        frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
                    sheet.paste(frame, (k * fw, (block * 4 + r) * fh))
            layout[anim] = [block * 4, count]
        sheet.save(os.path.join(out, aid + ".png"))
        with open(os.path.join(out, aid + ".json"), "w") as f:
            json.dump({"frame": [fw, fh], "foot": info["foot"], "cols": cols, "anims": layout,
                       "idle_frames": layout["idle"][1]}, f)
        made += 1
    return made


def _station_work(base, folder, dest):
    """A station's work loop (stations/<id>/work/frame_*.png) as one strip cropped to what any frame
    covers; <dest>.json keeps the frame size, the count and the anchor — where the still sprite's
    bottom centre falls in the frame, so smoke and sparks may leave the sprite's box."""
    paths = sorted(glob.glob(os.path.join(folder, "work", "frame_*.png")))
    if not paths:
        return 0
    frames = [Image.open(p).convert("RGBA") for p in paths]
    frames = [f if f.size == base.size else f.resize(base.size, Image.NEAREST) for f in frames]
    sb = base.getbbox() or (0, 0, base.width, base.height)
    ub = list(sb)
    for f in frames:
        b = f.getbbox()
        if b:
            ub = [min(ub[0], b[0]), min(ub[1], b[1]), max(ub[2], b[2]), max(ub[3], b[3])]
    w, h = ub[2] - ub[0], ub[3] - ub[1]
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.paste(f.crop(tuple(ub)), (i * w, 0))
    strip.save(dest + ".png")
    with open(dest + ".json", "w") as fh:
        json.dump({"frame": [w, h], "frames": len(frames),
                   "anchor": [(sb[0] + sb[2]) / 2.0 - ub[0], sb[3] - ub[1]]}, fh)
    return 1


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
            count += _station_work(img, folder, os.path.join(out, "station_" + aid + "_work"))
    # Interior furniture (furn_*), lighthouse fittings (lh_*) and placeable decor (decor_*).
    for folder in sorted(glob.glob(os.path.join(SRC, "interiors", "*"))):
        aid = os.path.basename(folder)
        path = os.path.join(folder, aid + ".png")
        if os.path.exists(path):
            img = Image.open(path).convert("RGBA")
            img.crop(img.getbbox() or (0, 0, img.width, img.height)).save(os.path.join(out, aid + ".png"))
            count += 1
    # Map props, the Deep's and the grottoes' objects (deep_*, grotto_*) and the story's places (story_*).
    for folder in sorted(glob.glob(os.path.join(SRC, "props", "*")) + glob.glob(os.path.join(SRC, "deep", "*"))
                         + glob.glob(os.path.join(SRC, "story", "*"))):
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
    legend = {f["id"] for f in json.load(open("data/fish.json")) if f.get("legendary")}
    count = 0
    for path in sorted(glob.glob(os.path.join(SRC, "icons", "*.png"))):
        img = Image.open(path).convert("RGBA")
        if os.path.basename(path)[:-4] in legend:
            img = gold_ring(img)
        img.save(os.path.join(out, os.path.basename(path)))
        count += 1
    return count + build_derived_icons(out)


def gold_ring(img, color=(242, 210, 122, 255)):
    """Legendary fish: a crisp one-pixel pale gold ring around the silhouette."""
    a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    ring = Image.new("L", img.size)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ring = ImageChops.lighter(ring, ImageChops.offset(a, dx, dy))
    ring = ImageChops.subtract(ring, a)
    out = Image.new("RGBA", img.size, color)
    out.putalpha(ring)
    out.alpha_composite(img)
    return out


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
