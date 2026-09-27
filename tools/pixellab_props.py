"""Map props: small pieces in one 32 px batch, everything larger as map-objects (1 generation each).
Output: assets_src/pixellab/props/<id>.png (+ meta.json per map-object), copied by build_art."""
import sys, os, json, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_icons as ic

OUT = os.path.join(pl.RAW, "props")
MAP_STYLE = "pixel art, 3/4 top-down view, cozy farming game, northern fishing island, muted cold palette, transparent background"
BATCH_STYLE = ("single map prop for a top-down farming game, seen from above at a 3/4 angle, cozy northern island, "
               "muted cold palette, dark outline, transparent background, no text")

SMALL = {
 "rock_1": "small grey stone", "rock_2": "two small grey stones", "rock_3": "flat grey pebble with lichen", "rock_4": "mossy small rock",
 "snag_1": "twisted driftwood snag", "snag_2": "grey dead root snag", "snag_3": "broken branch on the ground",
 "weeds_1": "clump of tall weeds", "weeds_2": "thistle weed", "weeds_3": "dry grass tuft",
 "stump_1": "old tree stump", "stump_2": "mossy tree stump",
 "heather_1": "purple heather bush", "heather_2": "small heather tuft", "heather_3": "faded brown heather",
 "flowers_1": "pink sea thrift flowers", "flowers_2": "white cottongrass tufts", "flowers_3": "yellow buttercups", "flowers_4": "blue harebells",
 "clam_bubbles": "bubbles and small holes in wet sand", "seaweed_1": "washed-up brown seaweed", "seaweed_2": "washed-up green kelp",
 "bird_nest_1": "sea bird nest with eggs", "bird_nest_2": "empty twig nest", "bird_nest_3": "nest with a sitting gull chick",
 "bonfire_unlit": "unlit bonfire of stacked driftwood in a stone ring", "bonfire_lit": "burning bonfire with bright flames in a stone ring",
 "mailbox": "wooden mailbox on a post, painted blue", "shipping_box_1": "wooden shipping crate with lid", "shipping_box_2": "wooden shipping crate with lid open",
 "rain_butt": "wooden rain water barrel", "tower_bell": "small brass hand bell on a hook",
 "barrel": "wooden barrel", "crate": "wooden crate", "barrels_stack": "two barrels together", "crates_stack": "stack of crates",
 "fence_wood_post": "wooden fence post", "fence_wood_h": "horizontal wooden fence section", "fence_wood_v": "wooden fence section seen end-on",
 "fence_stone_post": "dry stone wall pillar", "fence_stone_h": "horizontal dry stone wall section", "fence_stone_v": "dry stone wall seen end-on",
 "fence_iron_post": "wrought iron fence post", "fence_iron_h": "horizontal wrought iron fence section", "fence_iron_v": "wrought iron fence seen end-on",
 "gate_wood": "wooden farm gate", "gate_stone": "gap in a stone wall with a wooden gate", "gate_iron": "wrought iron cemetery gate",
 "raven_mark": "patch of freshly disturbed dark earth", "rest_buoy": "small red and white buoy", "stone_cairn": "small stone cairn",
}

STAGES = {"sapling": "tiny sapling", "young": "young small tree", "grown": "fully grown tree", "fruiting": "grown tree full of ripe fruit",
          "autumn": "grown tree with autumn leaves", "winter": "bare grown tree in winter with a little snow", "spring": "grown tree in spring blossom"}
BUSH_STAGES = {"sapling": "tiny sprout", "young": "young small bush", "grown": "full grown bush", "fruiting": "bush covered with ripe berries",
               "winter": "bare bush in winter with a little snow"}
BIG = {}  # id: (description, w, h)
for tree, look in (("buckthorn", "sea buckthorn with silver-green leaves and orange berries"), ("rowan", "rowan tree with red berry clusters"),
                   ("apple", "small northern apple tree with red apples")):
    for stage, text in STAGES.items():
        BIG[f"tree_{tree}_{stage}"] = (f"{look}, {text}", 64, 96 if stage not in ("sapling", "young") else 64)
for bush, look in (("cloudberry", "cloudberry plant with amber berries"), ("blueberry", "blueberry bush with blue berries"),
                   ("lingonberry", "lingonberry shrub with red berries"), ("cranberry", "bog cranberry with red berries on moss")):
    for stage, text in BUSH_STAGES.items():
        BIG[f"bush_{bush}_{stage}"] = (f"{look}, {text}", 32, 32)
for season, text in (("spring", "light green spring leaves"), ("summer", "full green leaves"), ("autumn", "yellow autumn leaves"),
                     ("winter", "bare white branches with a little snow")):
    BIG[f"birch_{season}"] = (f"slender white birch tree, {text}", 64, 96)
BIG["pine_1"] = ("wind-bent scots pine", 64, 96)
BIG["pine_2"] = ("small wind-bent pine on a rock", 64, 96)
for i, look in enumerate(["tall reed clump", "reeds with cattails"], 1):
    BIG[f"reeds_{i}"] = (look, 32, 64)
for i, look in enumerate(["rock pool with seaweed", "rock pool with a starfish", "shallow rock pool with pebbles"], 1):
    BIG[f"tide_pool_{i}"] = (look, 64, 32)
BIG.update({
 "street_lamp_off": ("iron village lantern post, lamp dark", 32, 64), "street_lamp_on": ("iron village lantern post, lamp glowing warm", 32, 64),
 "signpost_1": ("wooden signpost with two arrows", 32, 64), "signpost_2": ("weathered wooden signpost with one board", 32, 64),
 "notice_board_1": ("wooden notice board with pinned papers under a little roof", 32, 64),
 "notice_board_2": ("empty wooden notice board under a little roof", 32, 64),
 "graveyard_bell": ("small bell hanging in a wooden frame", 32, 64),
 "bench_1": ("wooden bench", 64, 32), "bench_2": ("stone bench", 64, 32),
 "net_rack_1": ("fishing nets drying on a wooden rack", 64, 64), "net_rack_2": ("net rack with floats", 64, 64),
 "beached_boat_1": ("small wooden rowing boat pulled up on sand", 64, 32), "beached_boat_2": ("upturned wooden boat", 64, 32),
 "beached_boat_3": ("old rotten rowing boat", 64, 32),
 "boulder_1": ("large dark basalt boulder", 64, 64), "boulder_2": ("mossy boulder", 64, 64), "boulder_3": ("split grey boulder", 64, 64),
 "driftwood_1": ("big bleached driftwood log", 64, 32), "driftwood_2": ("driftwood log with roots", 64, 32), "driftwood_3": ("two driftwood logs", 64, 32),
 "big_hull_1": ("large broken wooden shipwreck hull half buried in sand", 96, 48), "big_hull_2": ("shipwreck ribs sticking out of sand", 96, 48),
 "big_hull_3": ("wrecked hull with a broken mast", 96, 48),
 "small_wreck_1": ("small wrecked boat on its side", 64, 32), "small_wreck_2": ("broken boat planks and a rudder", 64, 32),
 "small_wreck_3": ("small wreck with torn sail", 64, 32),
 "cave_entrance_1": ("dark cave mouth in a basalt cliff", 64, 64), "cave_entrance_2": ("sea cave entrance with wet rocks", 64, 64),
 "drowned_well": ("old stone well half flooded with dark water", 64, 64),
})
GRAVES = {
 "grave_mound_new": "fresh grave with a small pile of stones", "grave_mound_old": "old grave with a mossy pile of stones",
 "grave_wooden_cross_new": "fresh grave with a plain wooden cross", "grave_wooden_cross_old": "old grave with a weathered leaning wooden cross",
 "grave_carved_cross_new": "grave with a carved wooden cross", "grave_carved_cross_old": "grave with an old grey carved wooden cross",
 "grave_stone_slab_new": "grave with a flat stone slab", "grave_stone_slab_old": "grave with a mossy stone slab",
 "grave_headstone_new": "grave with an upright headstone", "grave_headstone_old": "grave with an old lichen-covered headstone",
 "grave_beacon_stone_new": "grave with a stone carved like a small lighthouse", "grave_beacon_stone_old": "grave with an old lighthouse-shaped stone",
 "old_grave": "old broken neglected grave with a cracked stone", "old_grave_fixed": "old grave repaired and tidied with flowers",
 "open_pit": "freshly dug empty grave pit with a spade", "filled_grave": "freshly filled grave, bare earth mound",
 "weeds_overlay": "weeds and nettles growing over a grave", "sunk_overlay": "sunken grave with a hollow of earth",
 "cat_grave": "tiny cat grave with a small stone and a fish bone",
 "body_shore_1": "drowned sailor lying face down on the sand, respectful, not gory", "body_shore_2": "drowned body lying on its back on the sand wrapped in seaweed, respectful, not gory",
 "body_shore_3": "drowned body curled on its side on the sand, respectful, not gory",
 "body_wrapped": "body wrapped in grey sailcloth tied with rope", "body_table": "body under a white sheet on a wooden table",
 "coffin_open_1": "open plain pine coffin with a body inside, respectful", "coffin_open_2": "open dark oak coffin with a body inside, respectful",
 "coffin_open_3": "open coffin lined with white cloth and flowers", "remains": "bones of a drowned man in rags on the sand, not gory",
}


def one(aid, desc, w, h, view="high top-down"):
    folder = os.path.join(OUT, aid)
    if os.path.exists(os.path.join(folder, aid + ".png")):
        return aid
    try:
        pl.create_map_object("props", aid, f"{desc}, {MAP_STYLE}", w, h, view)
        return aid
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"


def small_batch():
    if all(os.path.exists(os.path.join(OUT, "small", a + ".png")) for a in SMALL):
        return "small done"
    oid = ic.batch(SMALL, 32, "props_small", BATCH_STYLE)[0]
    t0 = time.time()
    # "review" at 95% shows up while frames are still being drawn: wait until every frame exists.
    while len(pl.request("GET", f"/objects/{oid}").get("frame_urls") or []) < len(SMALL) and time.time() - t0 < 2400:
        time.sleep(15)
    made = ic.fetch(oid, list(SMALL), os.path.join(OUT, "small"))
    json.dump({"batch": oid, "items": {a: {"object_id": o, "prompt": SMALL[a]} for a, o in made.items()}},
              open(os.path.join(OUT, "small", "meta.json"), "w"), ensure_ascii=False, indent=1)
    return f"small {len(made)}"


if __name__ == "__main__":
    start = pl.generations_left()
    jobs = [(a, d, w, h) for a, (d, w, h) in BIG.items()] + [(a, d, 32, 64) for a, d in GRAVES.items()]
    with cf.ThreadPoolExecutor(4) as ex:
        fut = ex.submit(small_batch)
        for r in ex.map(lambda j: one(*j), jobs):
            print(time.strftime("%H:%M:%S"), r, flush=True)
        print(fut.result(), flush=True)
    print("spent", start - pl.generations_left())
