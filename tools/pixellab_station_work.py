"""Stations at work: a short loop of each processing station's own sprite (animate-with-text-v3 on
assets_src/pixellab/stations/<id>/<id>.png, about one generation each), played while the station has a
job in its queue; a few outdoor ones (AMBIENT in scripts/objects/station_object.gd) loop all the time.
Output: assets_src/pixellab/stations/<id>/work/frame_*.png; build_art.py packs station_<id>_work strips.
Usage: python3 tools/pixellab_station_work.py [ids...]   (resumable)"""
import sys, os, json, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_chars as c

FRAMES = 6
WORK = {
 "workbench": "a saw moving back and forth on a plank, sawdust falling",
 "hearth": "fire flickering, flames dancing, embers glowing",
 "compost_pit": "warm steam rising gently from the compost",
 "cutting_table": "a knife chopping up and down, fish scales flying",
 "renderer": "fat bubbling in the pot, fire flickering underneath, steam rising",
 "settling_tank": "oil slowly swirling, bubbles rising to the surface",
 "salt_pan": "brine simmering, steam rising, fire flickering beneath",
 "forge": "coals glowing brighter and dimmer, sparks flying, bellows pumping",
 "brine_barrel": "brine surface rippling with small bubbles",
 "sawhorse": "a saw cutting through a log back and forth, sawdust falling",
 "smokehouse": "smoke puffing from the roof, hanging fish swaying inside",
 "scutcher": "wooden blade beating flax up and down, fibres flying",
 "tar_kiln": "thick dark smoke rising, fire glowing at the base",
 "spinning_wheel": "the wheel spinning, yarn twisting onto the spindle",
 "loom": "the shuttle sliding back and forth, threads moving",
 "ash_kiln": "fire glowing inside, smoke rising from the top",
 "drying_rack": "fish and herbs swaying gently in the wind",
 "glass_furnace": "furnace glow pulsing orange, sparks rising",
 "optical_bench": "lens glinting, a light beam flickering through the glass",
 "carpentry_table": "a plane gliding along the board, shavings curling up",
 "stonecutter_table": "a chisel tapping the stone, chips and dust flying",
 "candle_mold": "melted wax dripping into the molds, small flames flickering",
 "butter_churn": "the churn plunger moving up and down",
 "cheese_press": "the press screw turning down slowly, whey dripping",
 "brewery": "wort bubbling in the kettle, steam rising, fire underneath",
 "wine_vat": "juice bubbling, fermenting foam rising",
 "preserve_jars": "jars bubbling in a hot water bath, steam rising",
 "still": "the copper still bubbling, steam puffing, drops dripping from the coil",
 "seed_box": "tiny seedlings swaying and growing a little",
 "herbal_table": "a pestle grinding in the mortar, herb dust puffing",
 "mill": "the millstone turning, flour dust puffing",
 "kitchen_stove": "fire flickering in the stove, the pot on top steaming",
 # Ambient: always moving.
 "beehive": "bees buzzing around the hive",
 "gull_scarer": "pinwheel spinning in the wind, ribbons fluttering",
 "wind_pump": "windmill blades turning, water trickling",
 "keeper_scarecrow": "old coat and scarf flapping in the wind",
}


def work(sid):
    meta = json.load(open(os.path.join(pl.RAW, "stations", sid, "meta.json")))
    w, h = meta.get("size", [48, 48])
    c.critter(sid, meta.get("prompt", sid), w, h, {"work": (WORK[sid] + ", seamless loop, same object", FRAMES)},
              meta.get("view", "high top-down"), "stations")
    return sid


def safe(sid):
    try:
        return work(sid)
    except Exception as e:
        return f"FAIL {sid} {str(e)[:300]}"


if __name__ == "__main__":
    ids = sys.argv[1:] or list(WORK)
    start = pl.generations_left()
    print("left", start, flush=True)
    with cf.ThreadPoolExecutor(6) as ex:
        for r in ex.map(safe, ids):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
