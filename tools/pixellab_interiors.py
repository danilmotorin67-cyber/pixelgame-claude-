"""Interior furniture, lighthouse fittings and placeable decor, all as map-objects (1 generation each).
Output: assets_src/pixellab/interiors/<id>/<id>.png; build_art copies them to assets/sprites/props/
(furniture as furn_<kind>, lighthouse fittings as lh_<kind>, decor as decor_<item id>)."""
import sys, os, time, json
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl

STYLE = "pixel art, 3/4 top-down view, cozy farming game interior furniture, northern fishing village, warm wood, muted palette, transparent background"
OUT = os.path.join(pl.RAW, "interiors")

# kind: (description, tiles wide, tiles deep) — the most common footprint in data/interiors.json
FURNITURE = {
 "altar": ("small chapel altar with white cloth, candles and a brass cross", 3, 1),
 "anvil": ("iron anvil on a tree stump", 1, 1), "bar": ("long wooden tavern bar counter with taps and mugs", 8, 1),
 "barrel": ("two wooden barrels side by side", 2, 1), "bed": ("wooden bed with a patchwork quilt", 2, 2),
 "board": ("wooden notice board with pinned papers", 1, 1), "boat": ("small wooden rowing boat on trestles being built", 2, 3),
 "candles": ("iron candle stand with many lit candles", 1, 1), "coffin": ("plain pine coffin on trestles, lid closed", 2, 1),
 "counter": ("wooden shop counter with a till and scales", 4, 1), "crates": ("stack of wooden crates", 2, 2),
 "desk": ("wooden writing desk with papers and an inkwell", 2, 1), "fireplace": ("stone fireplace with a burning fire", 1, 2),
 "forge": ("blacksmith's brick forge with glowing coals and bellows", 3, 2), "hay": ("pile of hay bales", 2, 2),
 "herbs": ("bundles of drying herbs on a small rack", 1, 1), "loom": ("wooden floor weaving loom frame with warp threads and half-woven wool cloth, no chair", 2, 2),
 "nets": ("fishing nets and floats hanging on a wooden frame", 1, 1), "pew": ("wooden chapel pew bench", 3, 1),
 "safe": ("heavy black iron strongbox safe with a brass dial and handle", 1, 1), "shelf": ("tall wooden shelf full of jars, boxes and bottles", 1, 3),
 "stairs": ("wooden stairs going up", 1, 1), "table": ("wooden table with two stools", 2, 1),
 "telegraph": ("brass telegraph key and sounder with wires and a paper tape on a small wooden table", 1, 1), "workbench": ("carpenter's workbench with planks and tools", 3, 1),
}
LIGHTHOUSE = {
 "stairs_up": ("worn stone spiral stairs going up", 32, 32), "stairs_down": ("worn stone stairs going down into darkness", 32, 32),
 "door": ("heavy arched wooden door in a stone wall", 32, 48), "barrel": ("wooden fuel oil barrel with a brass tap", 32, 32),
 "repair": ("repair table with tools, lamp parts and a vice", 48, 32), "desk": ("keeper's desk with logbook and oil lamp", 48, 32),
 "bunk": ("narrow wooden bunk with a grey blanket", 48, 32), "barometer": ("brass wall barometer", 32, 32),
 "calendar": ("paper tide calendar pinned to a board", 32, 32), "lamp_off": ("big unlit lighthouse lamp with brass burner", 32, 48),
 "lamp_on": ("large brass oil lamp burner with a bright amber flame inside a glass chimney, no building", 32, 48), "mechanism": ("clockwork rotation mechanism with brass gears", 32, 32),
 "glass": ("large faceted glass fresnel lens panel in a brass frame, no plant", 32, 32),
}
DECOR = {
 "stained_glass": ("small stained glass panel on a stand", 32, 32), "memory_lantern": ("graveyard memory lantern on a post", 32, 48),
 "statue_mourning": ("stone statue of a mourning woman on a plinth", 32, 64), "decor_stool": ("wooden stool", 32, 32),
 "decor_driftwood_table": ("table made of driftwood", 64, 32), "decor_wall_shelf": ("wall shelf with jars", 32, 32),
 "decor_rag_rug": ("round colourful rag rug", 64, 32), "decor_net_curtain": ("fishing net curtain with shells", 32, 48),
 "decor_rope_coil": ("coil of thick rope", 32, 32), "decor_lantern_hook": ("iron hook with a hanging lantern", 32, 48),
 "decor_coat_rack": ("wooden coat rack with a coat and cap", 32, 64), "decor_crate_table": ("table made of crates", 32, 32),
 "decor_plank_bench": ("plank bench", 64, 32), "decor_wash_tub": ("wooden wash tub with washboard", 32, 32),
 "decor_water_butt": ("wooden water butt barrel with iron hoops and a tap, no house", 32, 32), "decor_oar_rack": ("rack of wooden oars", 32, 48),
 "decor_flower_box": ("window flower box with red flowers", 32, 32), "decor_cork_garland": ("string of round cork fishing floats hanging between two small posts", 64, 32),
 "decor_shell_mobile": ("hanging shell mobile", 32, 48), "decor_driftwood_frame": ("mirror in a driftwood frame", 32, 48),
 "decor_hearth_rug": ("sheepskin hearth rug", 64, 32), "decor_log_seat": ("log seat", 32, 32),
 "decor_tide_board": ("wooden board painted with a tide table chart on a small easel", 32, 48), "decor_oak_table": ("solid oak table", 64, 32),
 "decor_oak_chair": ("oak chair", 32, 32), "decor_bookshelf": ("tall bookshelf full of books", 32, 64),
 "decor_wardrobe": ("tall wooden wardrobe", 32, 64), "decor_bed_single": ("narrow single wooden bed with a grey wool blanket and a white pillow", 32, 64),
 "decor_sea_chest_decor": ("sailor's sea chest with rope handles", 32, 32), "decor_brass_lamp": ("brass oil lamp on a stand", 32, 48),
 "decor_glass_lamp": ("tall glass oil lamp with a warm flame on a small wooden side table", 32, 48), "decor_painting_cape": ("framed painting of a lighthouse on a cape on an easel", 32, 48),
 "decor_painting_village": ("framed painting of a fishing village on an easel", 32, 48),
 "decor_painting_teeth": ("framed painting of jagged sea rocks on an easel", 32, 48), "decor_model_chayka": ("model of a small steamer ship on a stand", 32, 32),
 "decor_model_queen": ("model of a sailing ship on a stand", 32, 32), "decor_aquarium": ("glass aquarium with small fish on a stand", 32, 48),
 "decor_globe": ("antique globe on a wooden stand", 32, 48), "decor_barometer_decor": ("round brass barometer on a wooden stand", 32, 48),
 "decor_chart_table": ("chart table with a sea map and compass", 64, 32), "decor_wool_rug": ("woven wool rug with a pattern", 64, 32),
 "decor_linen_curtain": ("linen curtain on a rod", 32, 48), "decor_wreath": ("wreath of heather and ribbons", 32, 32),
 "decor_carved_armchair": ("carved wooden armchair with a cushion", 32, 48), "decor_carved_bed": ("big carved wooden double bed", 64, 64),
 "decor_grand_clock": ("tall grandfather clock", 32, 64), "decor_lens_lamp": ("lamp with a prism lens casting rainbow light", 32, 48),
 "decor_painting_aurora": ("framed painting of the northern lights on an easel", 32, 48),
 "decor_painting_rann": ("framed painting of a standing stone in the sea on an easel", 32, 48),
 "decor_painting_agatha": ("framed portrait of an old woman lighthouse keeper on an easel", 32, 48),
 "decor_model_berta": ("model of a sailing boat on a stand", 32, 32), "decor_ship_in_bottle": ("ship in a bottle on a stand", 32, 32),
 "decor_stuffed_old_codger": ("mounted huge old grey-green cod fish with a hook in its lip, trophy on a wooden plaque stand", 48, 32),
 "decor_stuffed_herring_king": ("mounted long silver ribbon oarfish with a red crest fin, trophy on a long wooden plaque stand", 64, 32),
 "decor_stuffed_golden_halibut": ("mounted shining gold flat halibut fish trophy on a wooden plaque stand", 48, 32),
 "decor_stuffed_grandmother": ("mounted huge old pike trophy on a stand", 64, 32),
 "decor_stuffed_lantern_fish": ("mounted black deep sea lanternfish with glowing blue dots, trophy on a wooden plaque stand", 48, 32),
 "decor_brass_telescope": ("brass telescope on a tripod", 32, 48), "decor_trophy_cup": ("silver trophy cup on a pedestal", 32, 32),
 "decor_seasonal_garland": ("garland of leaves and berries on a stand", 64, 32), "decor_aurora_rug": ("rug woven with green aurora pattern", 64, 32),
 "decor_amber_lamp": ("amber glass lamp glowing warm", 32, 48), "decor_memorial_plaque": ("bronze memorial plaque on a stone", 32, 32),
 "decor_stained_window": ("stained glass window in a wooden frame on a stand", 32, 48), "copper_helmet": ("old copper diving helmet", 32, 32),
 "bartholomew_ladle": ("dented copper ladle on a hook", 32, 32), "violin_decor": ("violin on a wall hook", 32, 48),
 "twin_medallion": ("two-half silver medallion on a velvet stand", 32, 32), "gudmund_hammer": ("old blacksmith\'s hammer with a worn wooden handle lying on a small wooden stand", 32, 32),
 "vera_pointer": ("long thin wooden school pointer stick resting on a small blackboard", 32, 48), "solvik_pennant": ("blue and white pennant flag on a pole", 32, 48),
 "regatta_cup": ("dented silver regatta cup", 32, 32), "nest_box": ("wooden eider nest box", 32, 32),
}
JOBS = ([("furn_" + k, d, w * 32, h * 32 + 16) for k, (d, w, h) in FURNITURE.items()]
        + [("lh_" + k, d, w, h) for k, (d, w, h) in LIGHTHOUSE.items()]
        + [(k if k.startswith("decor_") else "decor_" + k, d, w, h) for k, (d, w, h) in DECOR.items()])


def one(aid, desc, w, h):
    if os.path.exists(os.path.join(OUT, aid, aid + ".png")):
        return aid
    try:
        pl.create_map_object("interiors", aid, f"{desc}, {STYLE}", min(w, 400), min(h, 400), "high top-down")
        return aid
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"


if __name__ == "__main__":
    start = pl.generations_left()
    with cf.ThreadPoolExecutor(4) as ex:
        for r in ex.map(lambda j: one(*j), JOBS):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left())
