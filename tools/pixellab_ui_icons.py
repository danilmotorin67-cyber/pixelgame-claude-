"""HUD icons and inventory icons in 32 px batches of 64 (create-1-direction-object, tools/pixellab_icons.py).
Item prompts come from the English item names (localization/strings.csv) with a hint per category and
hand-written overrides for names that say little about the look. Items whose map sprite already reads
as an icon (decor, stations, saplings, grave markers) and seed packets are made locally by build_art.py.
HUD icons land in assets_src/pixellab/ui/icons/, item icons in assets_src/pixellab/icons/.
Usage: python3 tools/pixellab_ui_icons.py [batches]  (resumable: finished icons are skipped)."""
import sys, os, csv, json, time
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_icons as ic

ROOT = pl.ROOT
HUD_OUT = os.path.join(pl.RAW, "ui", "icons")
ITEM_OUT = ic.OUT
STYLE = ("game UI icon, single object centred, cozy farming game like Stardew Valley, clean dark outline, "
         "muted cold northern palette, transparent background, no text")

HUD = {
 "hud_light": "small brass oil lamp with a warm amber flame",
 "hud_peace": "lit white wax candle with a soft lilac glow",
 "hud_sea": "curling teal sea wave with white foam",
 "hud_coin": "silver coin stamped with a tiny lighthouse",
 "hud_energy": "warm amber flame",
 "hud_health": "red heart",
 "hud_cold": "pale blue snowflake",
 "hud_air": "three round air bubbles",
 "hud_clock": "brass pocket watch",
 "weather_clear": "bright yellow sun",
 "weather_cloud": "grey cloud",
 "weather_rain": "grey cloud with blue rain drops",
 "weather_storm": "dark storm cloud with a yellow lightning bolt",
 "weather_fog": "pale grey fog bands",
 "weather_snow": "grey cloud with white snowflakes",
 "weather_hmar": "lilac fog cloud with a faint pale face in it",
 "weather_aurora": "green and violet northern lights ribbon",
 "moon_full": "pale full moon with soft grey craters",
 "tide_up": "blue arrow pointing up over a small wave",
 "tide_down": "blue arrow pointing down over a small wave",
 "heart_full": "small red heart, filled",
 "heart_empty": "small empty heart outline, grey",
 "star_silver": "small silver star",
 "star_gold": "small gold star",
 "star_violet": "small violet star with sparkle",
 "tab_inventory": "brown leather satchel",
 "tab_skills": "crossed hoe and fishing rod",
 "tab_knowledge": "open book with a small tree drawn on the page",
 "tab_relations": "two hands holding a heart",
 "tab_quests": "rolled paper scroll with a red wax seal",
 "tab_collections": "small wooden box with a seashell inside",
 "tab_map": "folded sea chart",
 "tab_calendar": "paper wall calendar",
 "tab_compass": "brass compass",
 "tab_letters": "envelope with a red wax seal",
 "tab_settings": "brass gear",
 "tab_save": "quill pen in an inkwell",
 "seed_packet": "small blank paper seed packet with a folded top",
}

HINT = {
 "tool": "tool", "weapon": "weapon", "crop": "harvested vegetable or crop", "food": "cooked dish of northern cooking",
 "forage": "foraged item", "shellfish": "shellfish", "material": "crafting material", "artisan": "artisan goods",
 "ingredient": "cooking ingredient", "potion": "potion in a small glass bottle", "amulet": "charm or amulet jewellery",
 "clothes": "piece of clothing", "tackle": "fishing tackle", "bait": "fishing bait", "egg": "egg",
 "fertilizer": "garden fertilizer in a sack", "fuel": "lamp fuel in a can or jar", "fuel_misc": "fuel",
 "candle": "candle", "fish_product": "fish product", "gift": "gift", "trash": "rubbish",
 "part": "lighthouse machine part", "cargo": "wooden cargo crate", "keepsake": "keepsake",
 "keepsake_box": "keepsake box", "artifact": "old artifact", "quest": "story item", "coffin": "wooden coffin",
 "remains": "bones wrapped in old canvas", "decor": "decoration", "furniture": "furniture",
}
ORDER = ["tool", "weapon", "crop", "food", "forage", "shellfish", "ingredient", "artisan", "egg", "material",
         "potion", "amulet", "clothes", "tackle", "bait", "fertilizer", "fuel", "fuel_misc", "candle", "fish_product",
         "trash", "gift", "coffin", "remains", "decor", "furniture", "cargo", "part", "keepsake", "keepsake_box",
         "quest", "artifact"]
OVERRIDE = {
 "lightflower": "glowing pale golden flower",
 "hmar_cap": "pale lilac glowing mushroom",
 "glowing_plankton": "jar of glowing blue-green plankton",
 "ice_crystal": "clear blue ice crystal",
 "wisp_of_hmar": "lilac mist wisp in a small glass jar",
 "light_water": "flask of glowing golden water",
 "svetla_spark": "tiny glowing golden spark in cupped glass",
 "neptune_can": "tin can of fish with a sea god on the label",
 "rann_torch": "sea-green torch with a pale blue flame",
 "red_sector": "red glass lamp screen",
 "salt_shroud": "white canvas cover crusted with salt",
 "pyostraya_stamp": "rare colourful postage stamp",
 "stroganina": "curled shavings of frozen raw fish on a plate",
 "lutefisk": "white gelatinous fish on a plate",
 "frozen_swordfish": "frozen swordfish used as a sword, icy blue",
 "anchor_agatha": "heavy iron anchor used as a weapon",
 "belt_keg": "small keg on a leather belt",
 "air_bag": "leather air bag for diving",
 "storm_sails": "folded storm sail",
 "icebreaker_bow": "iron icebreaker bow plate for a boat",
}


def english():
    loc = {r["keys"]: r for r in csv.DictReader(open(os.path.join(ROOT, "localization", "strings.csv"), encoding="utf-8"))}
    return lambda key, fallback: loc.get(key, {}).get("en") or fallback


def derived(item_id, props):
    """Items build_art.py makes from an existing sprite (or a seed packet)."""
    if item_id.startswith("seed_"):
        return True
    for c in (item_id, "decor_" + item_id, "station_" + item_id, item_id + "_post", "grave_%s_new" % item_id):
        if c in props:
            return True
    return item_id in ("sapling_buckthorn", "sapling_rowan", "sapling_apple", "bush_blueberry", "bush_lingonberry",
                       "cloudberry_bush")


def queue():
    en = english()
    props = {f[:-4] for f in os.listdir(os.path.join(ROOT, "assets", "sprites", "props")) if f.endswith(".png")}
    items = json.load(open(os.path.join(ROOT, "data", "items.json")))
    jobs = [(k, v, HUD_OUT) for k, v in HUD.items() if not os.path.exists(os.path.join(HUD_OUT, k + ".png"))]
    rank = {c: i for i, c in enumerate(ORDER)}
    for it in sorted(items, key=lambda i: rank.get(i["category"], 99)):
        iid, cat = it["id"], it["category"]
        if cat == "fish" or derived(iid, props) or os.path.exists(os.path.join(ITEM_OUT, iid + ".png")):
            continue
        desc = OVERRIDE.get(iid) or "%s, %s" % (en(it["name"], iid.replace("_", " ")), HINT.get(cat, "item"))
        jobs.append((iid, desc, ITEM_OUT))
    return jobs


def recover(jobs, created_at):
    """PixelLab sometimes promotes a finished batch to single objects on its own (the batch then
    answers 404): find them among the newest objects by their prompt prefix (the promoted objects
    carry the time of promotion, not the batch's)."""
    import zipfile, io
    from PIL import Image
    objs, off = [], 0
    while off <= 1000:
        page = pl.request("GET", f"/objects?limit=100&offset={off}").get("objects") or []
        objs += [o for o in page if created_at is None or str(o.get("created_at", "")) >= str(created_at)]
        if len(page) < 100 or off >= 200:
            break
        off += 100
    got = 0
    for iid, desc, dest in jobs:
        full = f"{desc}, {STYLE}"
        # Names are cut to 30 characters; the prompt (cut later) tells apart items that start alike.
        match = [o for o in objs if o.get("prompt") and full.startswith(str(o["prompt"]))] or \
                [o for o in objs if not o.get("prompt") and full.startswith(str(o.get("name")))]
        if not match:
            continue
        objs.remove(match[0])
        z = zipfile.ZipFile(io.BytesIO(pl.request("GET", f"/objects/{match[0]['id']}/spritesheet", raw=True)))
        img = Image.open(io.BytesIO(z.read(next(n for n in z.namelist() if n.endswith(".png"))))).convert("RGBA")
        img = ic.strip_captions(img.crop((0, 0, min(img.size), min(img.size))))
        os.makedirs(dest, exist_ok=True)
        img.save(os.path.join(dest, iid + ".png"))
        got += 1
    return got


def run_batch(n):
    jobs = queue()[:64]
    if not jobs:
        return 0
    icons = {j[0]: j[1] for j in jobs}
    oid, info, ids, before = ic.batch(icons, 32, "ui_%d" % n, STYLE)
    created = info.get("created_at")
    # Frame links exist from the start: wait for 95% ("review") and every frame.
    t0 = time.time()
    gone = False
    while time.time() - t0 < 2400:
        try:
            info = pl.request("GET", f"/objects/{oid}")
        except RuntimeError as e:
            gone = "404" in str(e)
            break
        created = info.get("created_at", created)
        if str(info.get("status")) in ("review", "completed") and len(info.get("frame_urls") or []) >= len(ids):
            break
        time.sleep(15)
    made = 0
    if not gone:
        tmp = os.path.join(pl.RAW, "icons", "_batch_%d" % n)
        try:
            done = ic.fetch(oid, ids, tmp)
            for iid in done:
                dest = next(j[2] for j in jobs if j[0] == iid)
                os.makedirs(dest, exist_ok=True)
                os.replace(os.path.join(tmp, iid + ".png"), os.path.join(dest, iid + ".png"))
            made = len(done)
        except RuntimeError as e:
            gone = "404" in str(e)
        if os.path.isdir(tmp) and not os.listdir(tmp):
            os.rmdir(tmp)
    if gone:
        made = recover(jobs, created)
    with open(os.path.join(pl.RAW, "icons", "_ui_batches.json"), "a") as f:
        f.write(json.dumps({"batch": n, "object": oid, "items": {i: icons[i] for i in ids},
                            "spent": before - pl.generations_left()}) + "\n")
    return made


if __name__ == "__main__":
    batches = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    print("queued", len(queue()), "left", pl.generations_left(), flush=True)
    for n in range(batches):
        start = pl.generations_left()
        got = run_batch(int(time.time()))
        print(time.strftime("%H:%M:%S"), "batch", n, "icons", got, "spent", start - pl.generations_left(), flush=True)
        if not got:
            break
