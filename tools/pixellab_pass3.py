"""Pass 3: fixes for angled buildings, broken tilesets, and single ground tiles.

Single tiles are no longer drawn as separate pictures (the model always framed them with grass).
Instead they are taken from the full tiles of Wang tilesets, which tile seamlessly by construction:
- tilled soil = the all-soil tile of tiles_grass_soil_summer, toned from orange to dark garden brown;
- watered soil and the salt variants are derived from it locally;
- the stone path is the full cobble tile (the slab half of tiles_snow_pair came out blue);
- floors, peat and snow come from two-terrain tilesets made only for their full tiles."""
import sys, os, io, json, base64, shutil, random
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
from pixellab_pass2 import FRONT, B, TS
from PIL import Image

R = pl.RAW
BUILD = {k: B[k] for k in ("coop_3", "greenhouse_small", "house_3", "kai_hut", "stable", "cannery_ruin")}
TILES = {k: TS[k] for k in ("tiles_grass_cliff_autumn", "tiles_grass_cliff_summer", "tiles_grass_graveyard_autumn")}
TILES["tiles_grass_forest_summer"] = ("short green grass", "shady forest floor with brown pine needles and moss")
TILES["tiles_grass_forest_autumn"] = ("dull olive-yellow autumn grass", "forest floor with brown fallen leaves and pine needles")
# Terrain references taken from the full tiles of tilesets that came out well,
# so the grass and the rock match the neighbouring sets (dropping the palette made them garish).
REF = {
 "tiles_grass_cliff_autumn": (("tiles_grass_path_autumn", "lower"), ("tiles_grass_cliff_spring", "upper")),
 "tiles_grass_cliff_summer": (("tiles_grass_path_summer", "lower"), ("tiles_grass_cliff_spring", "upper")),
 "tiles_grass_forest_autumn": (("tiles_grass_path_autumn", "lower"), ("tiles_grass_forest_summer", "upper")),
}
FREE = {  # descriptions for the reference-guided retry
 "tiles_grass_cliff_autumn": ("muted olive-green and ochre autumn grass with small tufts", "dark slate-grey basalt cliff rock with cracks"),
 "tiles_grass_cliff_summer": ("short green grass with small tufts", "dark slate-grey basalt cliff rock with cracks, cold grey, not purple"),
 "tiles_grass_forest_autumn": ("muted olive-green and ochre autumn grass", "brown forest floor with fallen ochre and brown leaves and pine needles, not red"),
}
PAIRS = {  # two-terrain tilesets used only for their full tiles
 "tiles_floor_pair": ("weathered wooden plank floor, planks running horizontally", "dark cut peat ground with straight spade cuts"),
 "tiles_snow_pair": ("trampled snow with footprints and blue shadows", "flat grey stone paving slabs"),
}
FROM_PAIRS = {"tile_greenhouse_floor": ("tiles_floor_pair", "lower"), "tile_peat_cut": ("tiles_floor_pair", "upper"),
              "tile_snow_trampled": ("tiles_snow_pair", "lower"), "tile_stone_path": ("tiles_grass_cobble_summer", "upper")}


def redo(group, aid):
    d = os.path.join(R, group, aid)
    if os.path.exists(d):
        shutil.rmtree(d)


def job(kind, aid):
    try:
        if kind == "b":
            desc, w, h = BUILD[aid]
            redo("buildings", aid)
            return pl.create_map_object("buildings", aid, f"{desc}, {FRONT}, plain transparent background", w, h, "side")
        if kind == "f":
            lo, up = FREE[aid]
            redo("tiles", aid)
            (lts, lside), (uts, uside) = REF[aid]
            refs = {"lower_reference_image": ref_b64(full_tile(lts, lside)), "upper_reference_image": ref_b64(full_tile(uts, uside))}
            return pl.create_tileset("tiles", aid, lo, up, 32, refs)
        lo, up = (TILES if kind == "t" else PAIRS)[aid]
        redo("tiles", aid)
        return pl.create_tileset("tiles", aid, lo, up, 32)
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"


def ref_b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def full_tile(tileset, side):
    d = os.path.join(R, "tiles", tileset)
    ts = json.load(open(os.path.join(d, "tileset.json")))
    name = next(t["file"] for t in ts["tiles"] if set(t["corners"].values()) == {side})
    return Image.open(os.path.join(d, name)).convert("RGBA")


def shade(img, k, blue=0):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), min(255, int(b * k) + blue), a)
    return img


def salt(img, count, seed):
    """White salt crystals scattered with wrap-around so the tile stays seamless."""
    rnd = random.Random(seed)
    px = img.load()
    n = img.width
    for _ in range(count):
        x, y = rnd.randrange(n), rnd.randrange(n)
        for dx, dy, c in ((0, 0, (236, 240, 242)), (1, 0, (206, 214, 220)), (0, 1, (206, 214, 220)), (1, 1, (170, 178, 186))):
            if dx + dy == 2 and rnd.random() < 0.5:
                continue
            px[(x + dx) % n, (y + dy) % n] = c + (255,)
    return img


def save_single(aid, img, source):
    d = os.path.join(R, "tiles", aid)
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    img.save(os.path.join(d, aid + ".png"))
    pl.save_meta(d, {"id": aid, "method": "derived", "source": source, "generations": 0})


def earthen(img):
    """Pulls the orange tileset soil towards a dark garden brown, keeping its pattern."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            lum = 0.3 * r + 0.59 * g + 0.11 * b
            px[x, y] = (int(lum * 0.62 + 20), int(lum * 0.46 + 12), int(lum * 0.34 + 8), a)
    return img


def singles():
    base = earthen(full_tile("tiles_grass_soil_summer", "upper"))
    src = "tiles_grass_soil_summer full soil tile, toned to dark brown"
    save_single("tile_soil_tilled", base.copy(), src)
    save_single("tile_soil_watered", shade(base.copy(), 0.62, 6), src + ", darkened")
    save_single("tile_soil_salt1", salt(base.copy(), 7, 1), src + ", salt crystals")
    save_single("tile_soil_salt2", salt(base.copy(), 26, 2), src + ", salt crust")
    save_single("tile_soil_watered_salt", salt(shade(base.copy(), 0.62, 6), 16, 3), src + ", darkened, salt")
    for aid, (ts, side) in FROM_PAIRS.items():
        save_single(aid, full_tile(ts, side), f"{ts} full {side} tile")


if __name__ == "__main__":
    start = pl.generations_left()
    jobs = [("b", k) for k in BUILD] + [("t", k) for k in TILES] + [("p", k) for k in PAIRS]
    with cf.ThreadPoolExecutor(4) as ex:
        for r in ex.map(lambda j: job(*j), jobs):
            print(r if isinstance(r, str) else r["id"], flush=True)
    singles()
    with cf.ThreadPoolExecutor(3) as ex:
        for r in ex.map(lambda k: job("f", k), FREE):
            print(r if isinstance(r, str) else r["id"], flush=True)
    print("spent", start - pl.generations_left())
