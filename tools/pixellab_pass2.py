import sys, os, json, shutil, base64, io
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image
FRONT = ("front elevation, flat straight-on view of the front facade, symmetrical, camera directly in front and slightly above, "
         "NOT isometric, no side walls visible, cozy farming game like Stardew Valley, northern island, weathered stone and timber, "
         "muted cold palette with warm lamp light")
B = {
 "boathouse_1": ("wooden boathouse with wide boat doors", 128, 96), "boathouse_2": ("larger wooden boathouse with slipway doors", 160, 112),
 "boathouse_3": ("big boathouse for a sailing boat, tall doors", 192, 128), "coop_1": ("small wooden hen house with little ramp", 96, 80),
 "coop_2": ("bigger wooden hen house", 112, 88), "coop_3": ("large hen house with fenced run", 128, 96),
 "cannery": ("grim brick cannery factory with chimney and company sign", 256, 192), "cannery_ruin": ("burnt-out ruined cannery, broken walls, soot", 256, 192),
 "erland_boat_house": ("old upturned wooden boat turned into a small house with door and stovepipe", 112, 80),
 "greenhouse": ("large glass greenhouse with timber frame", 320, 384), "greenhouse_small": ("small glass greenhouse with timber frame", 192, 192),
 "guild_ruin": ("ruined old guild hall, broken roof, boarded windows, fog", 256, 192), "guild_room_x6": ("old guild hall with one restored wing, scaffolding", 256, 192),
 "guild_restored": ("restored old guild hall with lanterns and banners", 256, 192), "hayloft_1": ("hay barn with open loft door", 96, 88),
 "hayloft_2": ("bigger hay barn", 112, 96), "helga_hut": ("old herbalist's turf-roof hut with herbs drying", 112, 96),
 "house_3": ("keeper's stone house with porch and cellar door", 224, 192), "ice_house": ("half-buried ice house with turf roof and heavy door", 96, 80),
 "kai_hut": ("hermit hut built of driftwood", 96, 80), "mill": ("stone windmill with four sails", 96, 160), "mill_ruin": ("broken stone windmill, torn sails", 96, 160),
 "stable": ("small pony stable", 96, 80), "workshop": ("stone workshop with wide double doors", 128, 96), "village_10": ("fishing village house with turf roof", 160, 128),
}
OTHER = {
 "nine_maidens": ("ring of nine ancient standing stones on heather moorland, seen from above at an angle, no buildings", 288, 288, "high top-down"),
 "rann_stone": ("tall split standing stone in the sea surf, cracked in two, seaweed at the base, no buildings", 64, 64, "high top-down"),
 "rann_stone_whole": ("tall whole standing stone glowing with faint blue light, seaweed at the base, no buildings", 64, 64, "high top-down"),
 "steamer_gull": ("small old coastal mail steamer ship with one funnel, side view, moored", 192, 96, "side"),
 "pier_cape": ("small wooden landing jetty going into water, top-down", 64, 96, "high top-down"),
 "pier_village": ("wooden harbour pier with posts and bollards, top-down", 192, 96, "high top-down"),
 "hearse": ("black horse-drawn funeral cart, side view", 64, 32, "side"),
}
TS = {  # autumn and broken tilesets
 "tiles_grass_path_autumn": ("dull olive-yellow autumn grass with fallen brown leaves", "packed brown dirt footpath"),
 "tiles_grass_sand_autumn": ("dull olive-yellow autumn grass", "pale beach sand with shells"),
 "tiles_grass_cliff_autumn": ("dull olive-yellow autumn grass", "dark grey basalt cliff rock"),
 "tiles_grass_heather_autumn": ("dull olive-yellow autumn grass", "faded brown-purple autumn heather"),
 "tiles_grass_bog_autumn": ("dull olive-yellow autumn grass", "dark brown wet peat bog with small pools"),
 "tiles_grass_cobble_autumn": ("dull olive-yellow autumn grass", "grey cobblestone street"),
 "tiles_grass_forest_autumn": ("dull olive-yellow autumn grass", "forest floor covered with yellow birch leaves"),
 "tiles_grass_soil_autumn": ("dull olive-yellow autumn grass", "dark brown tilled farm soil"),
 "tiles_grass_graveyard_autumn": ("dull olive-yellow autumn grass", "grey gravel graveyard earth"),
 "tiles_grass_graveyard_spring": ("short green grass", "grey gravel graveyard earth"),
 "tiles_grass_soil_spring": ("short green grass", "dark brown tilled farm soil"),
 "tiles_grass_bog_spring": ("short green grass", "dark brown wet peat bog with small pools"),
 "tiles_grass_bog_winter": ("snow-covered grass", "frozen dark peat bog with ice"),
 "tiles_grass_cliff_summer": ("short green grass", "dark grey basalt cliff rock"),
}
SINGLE = {
 "tile_soil_tilled": "dark brown tilled farm soil with furrows", "tile_soil_watered": "dark wet tilled farm soil, darker and glistening",
 "tile_soil_salt1": "tilled farm soil with a few white salt crystals", "tile_soil_salt2": "tilled farm soil covered with a white salt crust",
 "tile_soil_watered_salt": "wet tilled soil with white salt crust", "tile_greenhouse_floor": "wooden plank greenhouse floor",
 "tile_peat_cut": "dark cut peat ground with spade marks", "tile_sand_dug": "dug-up pale beach sand",
 "tile_stone_path": "flat grey stone paving slabs", "tile_snow_trampled": "trampled snow with footprints",
}
R = pl.RAW
def redo(group, aid):
    d = os.path.join(R, group, aid)
    if os.path.exists(d): shutil.rmtree(d)
def job(kind, aid):
    try:
        if kind == "b":
            desc, w, h = B[aid]; redo("buildings", aid)
            return pl.create_map_object("buildings", aid, f"{desc}, {FRONT}", w, h, "side")
        if kind == "o":
            desc, w, h, v = OTHER[aid]; redo("buildings", aid)
            return pl.create_map_object("buildings", aid, f"{desc}, pixel art, muted cold palette", w, h, v)
        if kind == "t":
            lo, up = TS[aid]; redo("tiles", aid)
            return pl.create_tileset("tiles", aid, lo, up, 32)
        if kind == "s":
            redo("tiles", aid); folder = os.path.join(R, "tiles", aid)
            desc = f"seamless tileable ground texture filling the whole square edge to edge, no border, no grass edge: {SINGLE[aid]}, top-down pixel art"
            res = pl.request("POST", "/create-image-pixflux", {"description": desc, "image_size": {"width": 32, "height": 32}, "view": "high top-down", "outline": "lineless"})
            pl._save_b64(os.path.join(folder, aid + ".png"), res["image"]); pl.save_meta(folder, {"id": aid, "method": "create-image-pixflux", "prompt": desc})
            return aid
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"
if __name__ == "__main__":
    start = pl.generations_left()
    jobs = [("b", k) for k in B] + [("o", k) for k in OTHER] + [("t", k) for k in TS] + [("s", k) for k in SINGLE]
    with cf.ThreadPoolExecutor(4) as ex:
        for r in ex.map(lambda j: job(*j), jobs):
            print(str(r)[:160], flush=True)
    print("spent", start - pl.generations_left())
