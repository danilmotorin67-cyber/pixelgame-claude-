"""The sea: the three boats in 8 directions with their states, the sea's objects, and the spyglass vignettes.
- boats: create-8-direction-object (empty, sail raised), then /objects/{id}/states for the keeper aboard
  under sail and at the oars; sheets saved from the object spritesheet ZIP.
- sea objects: map-objects (1 generation), the whirlpool with an animate-with-text-v3 loop.
- spyglass: create-image-pixen vignettes, ships 64×32 and birds 48×32.
Output: assets_src/pixellab/sea/<id>/ and assets_src/pixellab/spyglass/<id>.png. Resumable.
Usage: python3 tools/pixellab_sea.py [boats|objects|spyglass]..."""
import sys, os, io, json, time, base64, zipfile
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_chars as c
from PIL import Image

SEA = os.path.join(pl.RAW, "sea")
SPY = os.path.join(pl.RAW, "spyglass")
STYLE = "pixel art, northern fishing island, muted cold palette"

BOATS = {
 "yalik": "small wooden sailing dinghy (yalik) with one white canvas sail raised, empty, northern fishing boat",
 "sloop": "small wooden ship's boat (shlyupka) with oars and a short mast with a small raised sail, empty",
 "bot": "sturdy wooden fishing sailboat (bot) with a small cabin at the stern and one big raised gaff sail, empty",
}
STATES = {
 "keeper_sail": "a small lighthouse keeper in a dark coat and knitted cap sits at the stern holding the tiller, sail still raised",
 "keeper_oars": "the sail is lowered and furled on the mast; a small lighthouse keeper in a dark coat and knitted cap sits in the middle rowing with two oars",
}

# id: (description, width, height, animation or None)
OBJECTS = {
 "iceberg_1": ("small white-blue iceberg floating in dark water, jagged top, seen from above", 48, 48, None),
 "iceberg_2": ("large white-blue iceberg with a flat top and cracks, floating, seen from above", 64, 48, None),
 "iceberg_3": ("tiny floating ice floe chunk, white and pale blue", 32, 32, None),
 "eleonora": ("ghost ship Eleonora: an old three-masted sailing ship, translucent pale green, glowing, tattered sails, spectral mist", 96, 96, None),
 "teeth": ("the Teeth: a cluster of sharp black sea rocks jutting out of the water with white foam around them", 96, 64, None),
 "seal_rock": ("flat grey sea rock with wet sides and white foam, seals rest on it", 64, 48, None),
 "eider_isle": ("small grassy islet with rocks, eider duck nests and down, surrounded by foam", 96, 64, None),
 "nameless_isle": ("misty rocky island with a ring of old standing stones and dead grass, foam around it", 128, 80, None),
 "sea_garden": ("sea farm: rows of wooden floats and ropes with kelp and mussels on the water", 64, 48, None),
 "kelp_line": ("rope with small cork floats and brown kelp growing on it, floating on water", 32, 32, None),
 "mussel_rope": ("buoy with a hanging rope of dark mussels, floating on water", 32, 32, None),
 "oyster_cage": ("wire oyster cage hanging under a small buoy, floating on water", 32, 32, None),
 "cargo_crates": ("floating wooden cargo crates tied together, drifting on water", 32, 32, None),
 "cargo_barrels": ("floating wooden barrels drifting on water", 32, 32, None),
 "ship_lights": ("a distant ship at night: dark silhouette with lit yellow portholes and a red and a green lantern", 64, 32, None),
 "steamer": ("small black passenger steamer Gull with a red funnel and smoke, seen from above, heading right", 96, 48, None),
 "whirlpool": ("dark swirling whirlpool in the sea, spiral of foam", 64, 64, ("spinning slowly, foam spiralling inward", 8)),
}

BIRDS = {
 "puffin": "Atlantic puffin with a colourful beak", "guillemot": "common guillemot, black and white seabird",
 "loon": "black-throated loon on the water", "eider": "common eider duck", "cormorant": "black cormorant drying its wings",
 "fulmar": "northern fulmar gliding", "gannet": "northern gannet diving", "skua": "dark arctic skua chasing",
 "kittiwake": "black-legged kittiwake gull", "herring_gull": "herring gull on a post", "arctic_tern": "arctic tern hovering",
 "oystercatcher": "oystercatcher with a red beak on the shore", "sea_eagle": "white-tailed sea eagle soaring",
 "snow_bunting": "snow bunting on snow", "snowy_owl": "snowy owl on a rock",
}
SHIPS = {
 "gull": "small black passenger steamer with a red funnel", "queen": "grand white passenger liner Queen of Kronwald with two funnels",
 "pyostraya": "colourful patched xebec with lateen sails", "treska": "small fishing boat Treska", "berta": "old brig Saint Berta",
 "harald": "whaler Harald with a harpoon gun at the bow", "hope": "brig Hope under full sail",
 "silver_herring": "schooner Silver Herring with grey sails", "count_elmstorp": "steamer Count Elmstorp with a tall funnel",
 "north_star": "barque North Star with three masts", "icebreaker": "stubby red icebreaker pushing through ice",
 "kapriz": "elegant white yacht Caprice", "vigilant": "grey naval sloop with a small cannon",
 "black_olaf": "dirty black collier with coal smoke", "diligent": "pilot boat with a pilot flag",
 "cabin_boy": "training sailing ship with many small sails", "st_elmo": "floating chapel: a barge with a small church and bell",
 "eleonora": "ghost ship, translucent pale green, tattered sails", "neptune_1": "modern grey factory trawler Neptune-1",
 "mercy_2": "white hospital ship with a red cross",
}


def b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def wait_object(oid, timeout=1800):
    t0 = time.time()
    while time.time() - t0 < timeout:
        info = pl.request("GET", f"/objects/{oid}")
        if str(info.get("status")) in ("completed", "failed", "review"):
            return info
        time.sleep(10)
    raise TimeoutError(oid)


def save_sheet(oid, folder):
    z = zipfile.ZipFile(io.BytesIO(pl.request("GET", f"/objects/{oid}/spritesheet", raw=True)))
    os.makedirs(folder, exist_ok=True)
    for n in z.namelist():
        if n.endswith(".png"):
            with open(os.path.join(folder, "sheet.png"), "wb") as f:
                f.write(z.read(n))
        elif n.endswith(".json"):
            with open(os.path.join(folder, "sheet.json"), "wb") as f:
                f.write(z.read(n))


def boat(bid):
    folder = os.path.join(SEA, bid)
    meta_path = os.path.join(folder, "meta.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {"id": bid, "states": {}}
    os.makedirs(folder, exist_ok=True)
    if not os.path.exists(os.path.join(folder, "base", "sheet.png")):
        legacy = os.path.join(SEA, "yalik_raw", "obj.json")
        if bid == "yalik" and os.path.exists(legacy):
            meta["object_id"] = json.load(open(legacy))["object_id"]
        else:
            r = pl.request("POST", "/create-8-direction-object", {"description": f"{BOATS[bid]}, {STYLE}", "size": 64,
                                                                  "view": "high top-down"})
            meta["object_id"] = r["object_id"]
            wait_object(r["object_id"])
        save_sheet(meta["object_id"], os.path.join(folder, "base"))
        json.dump(meta, open(meta_path, "w"), indent=1)
    for sid, text in STATES.items():
        if os.path.exists(os.path.join(folder, sid, "sheet.png")):
            continue
        r = pl.request("POST", f"/objects/{meta['object_id']}/states", {"edit_description": text, "state_name": sid})
        new_id = r.get("object_id") or r.get("id")
        wait_object(new_id)
        save_sheet(new_id, os.path.join(folder, sid))
        meta["states"][sid] = new_id
        json.dump(meta, open(meta_path, "w"), indent=1)
    return bid


def sea_object(oid):
    desc, w, h, anim = OBJECTS[oid]
    return c.critter(oid, f"{desc}, {STYLE}", w, h, {"loop": anim} if anim else {}, "high top-down", "sea")


def vignette(kind, vid, desc):
    path = os.path.join(SPY, f"{kind}_{vid}.png")
    if os.path.exists(path):
        return vid
    w, h = (64, 32) if kind == "ship" else (48, 32)
    what = (f"{desc} sailing on the open sea, side view, horizon and cloudy sky behind" if kind == "ship"
            else f"{desc}, close view, sea and sky behind")
    res = pl.request("POST", "/create-image-pixen", {
        "description": f"small landscape vignette: {what}, no frame, no border, no lens, {STYLE}",
        "image_size": {"width": w, "height": h},
        "no_background": False})
    img = None
    if res.get("background_job_id"):
        job = pl.wait_job(res["background_job_id"])
        lr = job.get("last_response") or {}
        imgs = lr.get("images") or ([lr["image"]] if lr.get("image") else [])
        raw = imgs[0]
    else:
        raw = (res.get("images") or [res.get("image")])[0]
    data = base64.b64decode(raw["base64"])
    try:
        img = Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception:
        img = Image.frombytes("RGBA", (w, h), data)
    os.makedirs(SPY, exist_ok=True)
    img.save(path)
    return vid


def safe(fn, *args):
    try:
        return fn(*args)
    except Exception as e:
        return f"FAIL {args} {str(e)[:300]}"


if __name__ == "__main__":
    parts = sys.argv[1:] or ["boats", "objects", "spyglass"]
    jobs = []
    if "boats" in parts:
        jobs += [(boat, b) for b in BOATS]
    if "objects" in parts:
        jobs += [(sea_object, o) for o in OBJECTS]
    if "spyglass" in parts:
        jobs += [(vignette, "ship", k, v) for k, v in SHIPS.items()] + [(vignette, "bird", k, v) for k, v in BIRDS.items()]
    start = pl.generations_left()
    with cf.ThreadPoolExecutor(6) as ex:
        for r in ex.map(lambda j: safe(j[0], *j[1:]), jobs):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
