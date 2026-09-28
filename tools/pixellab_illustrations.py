"""Illustrations: the title screen, the prologue, the Great Tide, Helga's tales (engravings), festival
posters and minigame backdrops, the epilogue slides and the sketches on Agatha's pages.
Full-screen pictures are 480x272 (the 480x270 base screen, one texel a unit) from generate-image-v2;
posters 160x224, sketches 64x64 on the Pixen model. Output: assets_src/pixellab/illustrations/<id>.png;
build_art.py copies them to assets/sprites/illustrations/. Resumable.
Usage: python3 tools/pixellab_illustrations.py [group|id ...]   groups: title prologue finale tales posters
minigames epilogue pages"""
import sys, os, io, json, time, base64
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image

OUT = os.path.join(pl.RAW, "illustrations")
WORLD = ("a small northern fishing island with a basalt cape, a stone lighthouse, a village of tarred wooden houses, "
         "moorland of heather, cold grey-green sea")
SCENE = ("cinematic pixel art illustration, wide establishing shot, muted cold palette (slate sea, basalt, moss, "
         "lilac heather) with warm amber lamplight, atmospheric, detailed, no text, no letters, no frame")
ENGRAVING = ("old woodcut engraving printed in sepia ink on yellowed paper, fine hatching, folk tale illustration, "
             "pixel art, no text, no letters, no frame")
POSTER = ("vintage village festival poster, bold simple shapes, warm paper colours, pixel art, "
          "a blank band at the bottom for a title, no text, no letters")
SKETCH = ("quick ink sketch on yellowed journal paper, brown ink lines, a few watercolour washes, pixel art, "
          "no text, no letters")

FULL = (480, 272)
TITLE = {"title": f"night view of the lighthouse on the basalt cape, its beam sweeping through fog over a dark "
                  f"sea, a lit keeper's cottage below, stars, {WORLD}"}
PROLOGUE = {
 "prologue_office": "a gloomy insurance office in a rainy harbour city, rows of desks, clerks stamping papers, "
                    "tall windows streaming with rain, a sign with a trident on the wall",
 "prologue_letters": "two letters lying on a clerk's desk under a green lamp: an official one with a trident seal and "
                     "a small handwritten one with a lighthouse drawing, a rubber stamp and an ink pad",
 "prologue_stern": "a tall thin man in a black frock coat with a cold smile standing behind a desk in a dim office, "
                   "rain on the window behind him, a model ship on a shelf",
 "prologue_form": "a keeper's application form and a fountain pen on a desk, a brass key and a faded photograph "
                  "of an old woman keeper beside it, warm lamplight",
 "prologue_steamer": "a small black passenger steamer with a red funnel sailing through thick fog on a grey sea, "
                     "a lone passenger at the rail with a suitcase",
 "prologue_pier": f"a wooden pier on a misty island at dusk, the steamer leaving, a figure with a suitcase looking "
                  f"up at a dark lighthouse on the cape, {WORLD}",
}
FINALE = {
 "finale_fire": "a stone lighthouse in a raging storm at night, its lamp blazing, dark figures climbing the "
                "spiral stair, huge waves breaking on the rocks",
 "finale_tide": "the sea drawn far out at night under a full moon, the wet seabed shining all the way to jagged "
                "black rocks on the horizon, stranded boats, a lighthouse beam across the sand",
 "finale_path": "a keeper with a lantern walking along a path on the exposed seabed between kelp and old ruins "
                "of a drowned village, walls of water glowing faintly on both sides",
 "finale_gates": "enormous ancient stone gates on the sea floor, carved with waves and nine women, cold blue light "
                 "pouring through, a tiny figure with a lantern before them",
 "finale_halls": "vast underwater halls of pale coral and pearl, drowned lanterns floating, a giant woman made of "
                 "waves seated on a throne of foam, nine smaller figures around her",
 "finale_stone": "a round stone broken into three pieces glowing on an altar, a keeper's hand and a wave-hand "
                 "reaching toward it, lamplight and sea-light meeting",
 "finale_dawn": f"dawn after a great storm, the sea calm and silver, the lighthouse lamp just going out, "
                f"villagers on the shore looking at the sunrise, {WORLD}",
}
TALES = {
 "tale_1": "a huge sorrowful sea woman weeping into the ocean, her tears turning the sea to salt, tiny boats below",
 "tale_2": "nine standing stones on a moor with nine ghostly maidens made of swell, foam, frost and fog sitting on them",
 "tale_3": "the first keeper with a single lantern facing a wall of fog on a cape, a sea woman rising from the waves",
 "tale_4": "a wrecker with a crooked lantern luring a ship onto the rocks at night",
 "tale_5": "a village flooded in one night, the sea rising over roofs, a bell tower half under water",
 "tale_6": "a keeper and a woman of waves clasping hands over a stone, words of an oath like a ribbon of light",
 "tale_7": "a cat sailing on a floating door through a stormy sea toward a lighthouse",
 "tale_8": "seals on a rock under a full moon, some of them girls in grey sealskins, a man hiding a skin",
 "tale_9": "a bell ringer ringing in a belfry as the water rises around the tower, people fleeing in boats",
 "tale_10": "a weeping young woman made of fog wandering over the sea at night, searching",
 "tale_11": "the sea drawn back to the horizon, the gates of the deep opening on the sea floor, a walker with a lantern",
 "tale_12": "a young woman keeper singing at the lamp of a lighthouse through a stormy night, alone",
}
FESTIVALS = {
 "boat_blessing": "boats decorated with ribbons launched from a slipway in spring, a priest blessing them",
 "bird_day": "puffins and gulls over sea cliffs, villagers with binoculars and birdhouses, spring flowers",
 "white_sun": "a midsummer bonfire on a hill under the midnight sun, people dancing around it",
 "regatta": "small sailboats racing between buoys on a bright summer sea, flags and a cheering pier",
 "herring_fair": "an autumn harbour fair with barrels of herring, stalls, lanterns and bunting",
 "drowned_night": "floating candle lanterns on dark water at night, villagers on the shore remembering the drowned",
 "ice_festival": "a frozen lagoon with skaters, ice sculptures and a swordfish frozen in a block of ice",
 "long_night": "the longest winter night, a tavern glowing with warm light in the snow, the aurora above",
}
POSTERS = {f"poster_{k}": v for k, v in FESTIVALS.items()}
MINIGAMES = {f"minigame_{k}": v + ", wide background scene, empty foreground" for k, v in FESTIVALS.items()}
EPILOGUE = {
 "epilogue_ending_a": "a soft morning mist over the cape, fishermen smiling, the lighthouse and the sea at peace",
 "epilogue_ending_b": "an old woman keeper sitting in the watch room criticising a vegetable garden through the window",
 "epilogue_ending_c": "a clear cold sea with no fog and no ghosts, an empty silent shore, the lighthouse dark",
 "epilogue_ending_d": "a keeper holding the lamp alight while a faint figure holds a door under the sea",
 "epilogue_court_trial": "a courtroom in a harbour town, a clerk reading a verdict, fishermen cheering",
 "epilogue_court_arrest": "a man in a hat behind prison bars, a rainy city office with a new sign far away",
 "epilogue_court_fled": "a hat lying on a shelf in an empty tavern, nobody touching it",
 "epilogue_court_pardon": "an old lighthouse on a rock lit again at night, a man polishing its glass",
 "epilogue_court_taken": "a young woman placing a stone on a grave on a windswept hill",
 "epilogue_court_none": "a quiet island village going about its day, smoke from chimneys",
 "epilogue_fortuna_stays": "a carved wooden ship figurehead of a woman on a lighthouse wall, smiling and talking",
 "epilogue_fortuna_released": "a carved wooden ship figurehead of a woman, silent and smiling, sunlight on her face",
 "epilogue_fortuna_rests": "a carved wooden ship figurehead of a woman asleep, dust and moonlight",
 "epilogue_fortuna_silent": "a carved wooden ship figurehead of a woman frowning at the sea",
 "epilogue_twenty_done": "a graveyard on a cape with twenty new wooden grave markers, a ship's roll framed on a wall",
 "epilogue_twenty_waiting": "an empty quiet hall with twenty empty places, dust in a beam of light",
 "epilogue_tuve_stays": "a girl in grey walking into the sea under a full moon, a warm house behind her",
 "epilogue_tuve_left": "a grey seal on a rock looking toward a village",
 "epilogue_tuve_sea": "seals on a rock waiting, one empty place among them",
 "epilogue_community_all": "summer night over the cape with fireflies glowing above the grass",
 "epilogue_community_some": "misty ghostly figures repairing a boat and a fence at dusk",
 "epilogue_community_none": "an empty guild house with fog in its windows",
 "epilogue_neptune_signed": "a smoking cannery in a bay, a frowning grey sea",
 "epilogue_neptune_annulled": "a closed cannery with boarded windows, villagers laughing",
 "epilogue_neptune_torn": "a torn contract hanging in a frame on a tavern wall",
 "epilogue_neptune_never": "an unspoiled bay with fishing boats and no factory",
 "epilogue_spouse": "two keepers together at the lighthouse lamp at night",
 "epilogue_children": "two children in a seaside graveyard asking questions, wooden grave markers",
}
PAGES = {
 "page_1": "a lighthouse lamp just lit and a cat sitting beside it", "page_2": "a big letter F circled twice",
 "page_3": "nine standing stones on a moor, three of them glowing", "page_4": "a list of ships and a clear starry night",
 "page_5": "rows of kelp growing like streets of houses under water", "page_6": "an empty rowing boat at dawn",
 "page_7": "a frightened boy looking at a fire", "page_8": "a round stone broken in three",
 "page_9": "two fires burning on dark rocks at night", "page_10": "a lighthouse lens with a red sector",
 "page_11": "a fresco of a keeper, a woman of waves and a broken stone", "page_12": "men in bowler hats with briefcases on a pier",
 "page_13": "a schooner wrecked on jagged rocks", "page_14": "a brig sinking by the rocks",
 "page_15": "a ship named Hope breaking on the rocks", "page_16": "sums and arrows scribbled around a lighthouse",
 "page_17": "dots and dashes of Morse code and a telegraph key", "page_18": "a knitted sweater pattern and a frying pan",
 "page_19": "a bell tower under water with a bell ringer", "page_20": "a third piece of a broken stone",
 "page_21": "a figure descending into dark water with a lantern", "page_22": "a carved ship figurehead of a woman",
 "page_23": "a figure holding a heavy door shut under the sea", "page_24": "a candle almost burnt down beside a letter",
}

GROUPS = {"title": TITLE, "prologue": PROLOGUE, "finale": FINALE, "tales": TALES, "posters": POSTERS,
          "minigames": MINIGAMES, "epilogue": EPILOGUE, "pages": PAGES}


def spec(iid):
    """(prompt, size, endpoint) of an illustration."""
    if iid in TALES:
        return f"{TALES[iid]}, {ENGRAVING}", FULL, "v2"
    if iid in POSTERS:
        return f"{POSTERS[iid]}, {POSTER}", (160, 224), "pixen"
    if iid in PAGES:
        return f"{PAGES[iid]}, {SKETCH}", (64, 64), "pixen"
    for group in (TITLE, PROLOGUE, FINALE, MINIGAMES, EPILOGUE):
        if iid in group:
            return f"{group[iid]}, {SCENE}", FULL, "v2"
    raise KeyError(iid)


def _decode(im, w, h):
    raw = base64.b64decode(im["base64"])
    try:
        return Image.open(io.BytesIO(raw)).convert("RGBA")
    except Exception:
        return Image.frombytes("RGBA", (int(im.get("width", w)), int(im.get("height", h))), raw)


def make(iid, endpoint=None):
    path = os.path.join(OUT, iid + ".png")
    if os.path.exists(path):
        return f"{iid} (kept)"
    prompt, (w, h), ep = spec(iid)
    ep = endpoint or ep
    before = pl.generations_left()
    if ep == "v2":
        res = pl.request("POST", "/generate-image-v2", {"description": prompt, "image_size": {"width": w, "height": h},
                                                         "no_background": False})
    else:
        res = pl.request("POST", "/create-image-pixen", {"description": prompt, "image_size": {"width": w, "height": h},
                                                          "no_background": False, "detail": "highly detailed"})
    if res.get("background_job_id"):
        job = pl.wait_job(res["background_job_id"], timeout=1800)
        if job["status"] != "completed":
            raise RuntimeError(json.dumps(job)[:400])
        lr = job.get("last_response") or {}
    else:
        lr = res
    imgs = lr.get("images") or ([lr["image"]] if lr.get("image") else [])
    img = _decode(imgs[0], w, h)
    os.makedirs(OUT, exist_ok=True)
    img.save(path)
    meta_path = os.path.join(OUT, "meta.json")
    with open(meta_path, "a") as f:
        f.write(json.dumps({"id": iid, "endpoint": ep, "size": [w, h], "prompt": prompt,
                            "spent": before - pl.generations_left()}) + "\n")
    return f"{iid} {ep}"


def safe(iid):
    try:
        return make(iid)
    except Exception as e:
        return f"FAIL {iid} {str(e)[:300]}"


if __name__ == "__main__":
    ids = []
    for a in sys.argv[1:] or list(GROUPS):
        ids += list(GROUPS[a]) if a in GROUPS else [a]
    start = pl.generations_left()
    print("left", start, "queued", len(ids), flush=True)
    with cf.ThreadPoolExecutor(6) as ex:
        for r in ex.map(safe, ids):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
