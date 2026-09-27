"""Crops (4 growth stages + ripe) and crafting stations, all as map-objects (1 generation each).
Output: assets_src/pixellab/crops/<crop>_<1-4|ripe>.png (prompts in crops_raw/<id>/meta.json) and
assets_src/pixellab/stations/<id>/<id>.png; build_art copies them to assets/sprites/props/.
Crop batches of 64 kept failing server-side (the object vanished mid-way), so each stage is its own
32x32 map-object. Output: assets_src/pixellab/crops/<crop>_<1-4|ripe>.png and
assets_src/pixellab/stations/<id>/<id>.png; build_art copies them to assets/sprites/props/."""
import sys, os, json, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl

CROPS_OUT = os.path.join(pl.RAW, "crops")
STATIONS_OUT = os.path.join(pl.RAW, "stations")
CROP_STYLE = ("single crop plant growing in dark tilled soil, farming game crop sprite like Stardew Valley, "
              "seen from above at a 3/4 angle, centred, muted northern palette, transparent background, no text")
MAP_STYLE = ("crafting station for a cozy farming game, pixel art, 3/4 top-down view, northern fishing island, "
             "weathered wood, iron and stone, muted cold palette, transparent background")

# crop: (young plant look, ripe look)
CROP_LOOK = {
 "crop_turnip": ("turnip leaves", "white and purple turnip bulb showing above ground with leaves"),
 "crop_scurvygrass": ("small round glossy leaves of scurvygrass", "bushy scurvygrass with tiny white flowers"),
 "crop_potato": ("potato plant leaves", "flowering potato plant with potatoes peeking from soil"),
 "crop_pea": ("pea shoots climbing a stick", "pea vine on a stick full of green pods"),
 "crop_barley": ("barley shoots", "golden ripe barley ears"),
 "crop_flax": ("thin flax stems", "flax with pale blue flowers and seed heads"),
 "crop_rhubarb": ("rhubarb leaves", "big rhubarb leaves on thick red stalks"),
 "crop_sea_kale": ("blue-grey sea kale leaves", "sea kale with white flower heads"),
 "crop_carrot": ("feathery carrot tops", "orange carrot top showing with feathery leaves"),
 "crop_cabbage": ("young cabbage leaves", "big round green cabbage head"),
 "crop_rutabaga": ("rutabaga leaves", "purple-yellow rutabaga root showing with leaves"),
 "crop_strawberry": ("strawberry plant leaves", "strawberry plant with red berries"),
 "crop_hops": ("hop shoots on a pole", "hop vine on a pole with green hop cones"),
 "crop_samphire": ("succulent samphire shoots", "bushy green samphire"),
 "crop_beans": ("bean shoots on a stick", "bean vine on a stick with long green pods"),
 "crop_onion": ("onion green shoots", "brown onion bulb showing with green tops"),
 "crop_dill": ("feathery dill", "tall dill with yellow umbrella flowers"),
 "crop_pumpkin": ("pumpkin vine leaves", "big orange pumpkin on a vine"),
 "crop_beet": ("beet leaves with red veins", "dark red beetroot showing with leaves"),
 "crop_kale": ("curly kale leaves", "tall curly dark green kale"),
 "crop_leek": ("thin leek shoots", "tall thick leeks with blue-green leaves"),
 "crop_parsnip": ("parsnip leaves", "pale parsnip top showing with leaves"),
 "crop_rye": ("rye shoots", "tall golden rye with ears"),
 "crop_winter_cabbage": ("frosty cabbage leaves", "purple winter cabbage head with frost"),
 "crop_lightflower": ("glowing pale shoots", "magical pale flower glowing soft blue-white light"),
}
STAGES = [("1", "tiny sprout of {young}"), ("2", "small young {young}"), ("3", "half-grown {young}"),
          ("4", "almost mature {young}"), ("ripe", "{ripe}, ripe and ready to harvest")]
CROPS = {}
for crop, (young, ripe) in CROP_LOOK.items():
    for suffix, text in STAGES:
        CROPS[f"{crop}_{suffix}"] = text.format(young=young, ripe=ripe)
CROPS["crop_withered_1"] = "withered brown dead crop plant"
CROPS["crop_withered_2"] = "dried up grey dead seedling"

STATIONS = {
 "workbench": ("sturdy wooden workbench with a vice, saw and hammer", 48, 48),
 "hearth": ("small outdoor stone hearth with a cooking pot and a little fire", 48, 48),
 "compost_pit": ("wooden compost bin full of rotting leaves and scraps", 48, 48),
 "chest": ("small wooden storage chest with iron bands", 32, 32),
 "big_chest": ("large dark wooden sea chest with brass corners", 48, 32),
 "cutting_table": ("fish cutting table with a knife and a bucket", 48, 48),
 "renderer": ("blubber rendering cauldron over a fire", 48, 48),
 "settling_tank": ("wooden settling tank for fish oil with a tap", 48, 48),
 "forge": ("small stone forge with glowing coals, bellows and an anvil", 48, 48),
 "salt_pan": ("shallow iron salt pan over a fire with white salt crust", 48, 48),
 "brine_barrel": ("wooden brine barrel with a lid and a stone weight", 32, 48),
 "smokehouse": ("small wooden smokehouse with a smoking chimney", 48, 64),
 "sawhorse": ("wooden sawhorse with a log and a saw", 48, 32),
 "tar_kiln": ("small earthen tar kiln with a pipe dripping black tar", 48, 48),
 "scutcher": ("wooden flax scutching board and blade", 48, 48),
 "spinning_wheel": ("wooden spinning wheel with wool", 48, 48),
 "loom": ("wooden weaving loom with half-woven cloth", 48, 48),
 "ash_kiln": ("small stone lye ash kiln", 48, 48),
 "drying_rack": ("wooden drying rack with fish and herbs hanging", 48, 48),
 "glass_furnace": ("small brick glass furnace glowing orange with a blowpipe", 48, 48),
 "optical_bench": ("optician's bench with lenses, brass tools and a small lamp", 48, 48),
 "carpentry_table": ("carpentry table with a plane and wood shavings", 48, 48),
 "stonecutter_table": ("stonecutter's table with a chisel and a block of stone", 48, 48),
 "candle_mold": ("tin candle mould rack with candles and a wax pot", 32, 32),
 "butter_churn": ("tall wooden butter churn", 32, 48),
 "cheese_press": ("wooden cheese press with a screw", 32, 48),
 "brewery": ("small copper brewing kettle on a wooden stand", 48, 48),
 "wine_vat": ("wooden berry wine vat with a tap", 48, 48),
 "preserve_jars": ("shelf of glass preserve jars with jam and pickles", 48, 48),
 "still": ("small copper still with a coiled pipe", 48, 48),
 "seed_box": ("wooden seed sorting box with little drawers", 32, 32),
 "herbal_table": ("herbalist's table with drying herbs, mortar and pestle", 48, 48),
 "kitchen_stove": ("cast iron kitchen stove with a pot and a kettle", 48, 48),
 "mill": ("hand millstone quern on a wooden base", 48, 48),
 "receiver_chest": ("copper-bound receiving chest with a slot", 48, 32),
 "cellar_barrel": ("big oak aging barrel on a cradle", 48, 32),
 "beehive": ("traditional straw skep beehive on a stand with bees", 32, 48),
 "eider_nest": ("eider duck nest of grey down on a little stone shelter", 32, 32),
 "stone_wall": ("short straight section of dry stone wall made of stacked grey stones, no roof, no building", 48, 32),
 "gull_scarer": ("gull scarer: pole with fluttering strips and a tin rattle", 32, 64),
 "watering_barrel": ("wooden water barrel with a ladle", 32, 32),
 "cistern": ("stone rainwater cistern with a wooden lid", 48, 48),
 "wind_pump": ("small wooden wind pump with four blades on a frame", 48, 64),
 "keeper_scarecrow": ("scarecrow on a wooden cross pole wearing a navy keeper's coat and a flat cap, straw sticking out, standing in a field", 32, 64),
}


def crop(aid):
    path = os.path.join(CROPS_OUT, aid + ".png")
    if os.path.exists(path):
        return aid
    try:
        pl.create_map_object("crops_raw", aid, f"{CROPS[aid]}, {CROP_STYLE}", 32, 32, "high top-down")
        os.makedirs(CROPS_OUT, exist_ok=True)
        os.replace(os.path.join(pl.RAW, "crops_raw", aid, aid + ".png"), path)
        return aid
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"


def station(aid):
    desc, w, h = STATIONS[aid]
    if os.path.exists(os.path.join(STATIONS_OUT, aid, aid + ".png")):
        return aid
    try:
        pl.create_map_object("stations", aid, f"{desc}, {MAP_STYLE}", w, h, "high top-down")
        return aid
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"


if __name__ == "__main__":
    start = pl.generations_left()
    ids = list(CROPS)
    with cf.ThreadPoolExecutor(4) as ex:
        for r in ex.map(station, STATIONS):
            print(time.strftime("%H:%M:%S"), r, flush=True)
        for r in ex.map(crop, ids):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    if not os.path.exists(os.path.join(pl.RAW, "props", "giant_turnip", "giant_turnip.png")):
        pl.create_map_object("props", "giant_turnip", "giant turnip three times normal size in tilled soil, "
                             "pixel art, 3/4 top-down view, cozy farming game, transparent background", 96, 96, "high top-down")
    print("spent", start - pl.generations_left())
