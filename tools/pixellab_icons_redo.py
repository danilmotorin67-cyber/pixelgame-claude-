"""Second pass over the weakest inventory icons, one 32 px batch of up to 64 (tools/pixellab_ui_icons.py):
seed packets with the crop printed large instead of the shared blank packet, legendary fish without the
noisy glow (build_art.py rings them in gold), charms on a thin cord instead of white wedges, potions and
lenses told apart, and a few pale or captioned ones.
Output: assets_src/pixellab/icons_redo/<id>.png for review; `apply <ids...>` moves the chosen ones
into assets_src/pixellab/icons/.
Usage: python3 tools/pixellab_icons_redo.py [run|apply ids...]"""
import sys, os, json, time, shutil
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_icons as ic
import pixellab_ui_icons as ui

OUT = os.path.join(pl.RAW, "icons_redo")

SEEDS = {
 "turnip": "white and purple turnip", "scurvygrass": "green scurvy-grass sprigs with white flowers",
 "potato": "brown potatoes", "pea": "green pea pod", "barley": "golden barley ears", "flax": "blue flax flowers",
 "rhubarb": "red rhubarb stalks", "sea_kale": "blue-green sea kale leaves", "carrot": "orange carrot",
 "cabbage": "green cabbage head", "rutabaga": "purple-topped rutabaga", "strawberry": "red strawberries",
 "hops": "green hop cones", "samphire": "green samphire shoots", "beans": "brown beans", "onion": "golden onion",
 "dill": "feathery green dill", "pumpkin": "orange pumpkin", "beet": "dark red beetroot",
 "kale": "curly dark green kale", "leek": "white and green leek", "parsnip": "cream parsnip",
 "rye": "rye ears", "winter_cabbage": "frosty blue-green winter cabbage", "lightflower": "glowing pale golden flower",
}
ITEMS = {"seed_" + k: f"small paper seed packet with a big colourful picture of {v} printed on its front, folded top"
         for k, v in SEEDS.items()}
LEGEND = {k: ic.FISH[k].replace(", golden glow outline", "") + ", shiny rare trophy fish" for k in (
    "fish_old_codger", "fish_herring_king", "fish_golden_halibut", "fish_grandmother", "fish_lantern_fish",
    "fish_codger_son", "fish_herring_princess", "fish_golden_calf", "fish_granddaughter", "fish_lantern_fry")}
ITEMS.update(LEGEND)
ITEMS.update({
 "rowan_amulet": "charm of red rowan berries and leaves tied on a thin brown cord",
 "amber_pendant": "polished orange amber pendant on a thin leather cord",
 "wolffish_fang": "curved white fish fang pendant on a thin leather cord",
 "pearl_earring": "single silver earring with a white pearl drop",
 "whalebone_charm": "carved whalebone charm shaped like a small whale on a cord",
 "moray_fang": "long yellowed moray eel fang pendant on a dark cord",
 "rann_gills": "pendant of pale green fish gills in a silver setting on a cord",
 "martin_ember": "glowing orange ember in a small iron cage on a chain",
 "crow_eye": "round black pebble with a white fleck on a cord",
 "raven_totem": "small carved wooden totem with black raven feathers tied on",
 "ebb_totem": "small driftwood totem carved with wave lines and a shell",
 "scurvy_brew": "clay jug of green herbal brew",
 "warm_balm": "small round tin of warming red balm, lid open",
 "rowan_tincture": "tall thin bottle of red rowan tincture with a rowan sprig tied to it",
 "depth_elixir": "round flask of deep blue elixir with bubbles",
 "depth_elixir_plus": "round flask of glowing deep blue elixir with bubbles and a silver cap",
 "fisher_luck_potion": "green bottle with a tiny fish shape floating inside, cork",
 "vigor_brew": "stout brown bottle of amber brew with a lightning mark",
 "light_water": "flask of glowing golden water, bright",
 "calm_potion": "pale lilac potion in a teardrop bottle with a ribbon",
 "lens_fresnel_4": "small lighthouse Fresnel lens, glass rings in a brass frame, small",
 "lens_fresnel_3": "medium lighthouse Fresnel lens with glass prism rings in a brass frame",
 "lens_fresnel_2": "large tall lighthouse Fresnel lens, many glass prism rings, brass frame, gleaming",
 "brass_fittings": "handful of brass pipe fittings, elbows and nuts",
 "sea_glass": "three smooth frosted pieces of sea glass, green, blue and white",
 "glow_plankton": "glass jar of glowing blue-green plankton",
 "dill": "bunch of feathery green dill with yellow flower umbels",
 "fish_sandeel": "sand eel, slender long silver fish, whole fish clearly visible",
})


def run():
    jobs = {k: v for k, v in ITEMS.items() if not os.path.exists(os.path.join(OUT, k + ".png"))}
    ids = list(jobs)[:64]
    if not ids:
        return 0
    icons = {i: jobs[i] for i in ids}
    oid, info, ids, before = ic.batch(icons, 32, "redo", ui.STYLE)
    created = info.get("created_at")
    t0, gone = time.time(), False
    while time.time() - t0 < 2400:
        try:
            info = pl.request("GET", f"/objects/{oid}")
        except RuntimeError as e:
            gone = "404" in str(e)
            break
        if str(info.get("status")) in ("review", "completed") and len(info.get("frame_urls") or []) >= len(ids):
            break
        time.sleep(15)
    made = 0
    if not gone:
        try:
            made = len(ic.fetch(oid, ids, OUT))
        except RuntimeError as e:
            gone = "404" in str(e)
    if gone:
        made = ui.recover([(i, icons[i], OUT) for i in ids], created)
    print("spent", before - pl.generations_left(), flush=True)
    return made


def apply(ids):
    for i in ids:
        shutil.copy(os.path.join(OUT, i + ".png"), os.path.join(ic.OUT, i + ".png"))


if __name__ == "__main__":
    if sys.argv[1:2] == ["apply"]:
        apply(sys.argv[2:])
    else:
        print("left", pl.generations_left(), "queued", len(ITEMS), flush=True)
        print("made", run(), "left", pl.generations_left(), flush=True)
