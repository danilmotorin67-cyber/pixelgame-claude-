"""Objects of the Deep and the Ebb Grottoes as map-objects (about one generation each): Deep chests for
each biome, the ropes, the debris on the way down, the diving bell and the bell station, sea-floor decor
for the three biomes; the grottoes' puzzle pieces and finds by the letters of data/grotto.json.
Output: assets_src/pixellab/deep/<id>/<id>.png; build_art.py crops them into assets/sprites/props/.
Usage: python3 tools/pixellab_deep_objects.py [ids...]   (resumable)"""
import sys, os, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl

UNDER = "underwater on the sea floor, pixel art, 3/4 top-down view, muted cold palette, transparent background"
CAVE = "single object found in a tidal sea cave, isolated, pixel art, 3/4 top-down view, muted cold palette, transparent background"

# id: (description, width, height, setting)
OBJECTS = {
 # Deep: finds and the way down
 "deep_chest_kelp": ("old wooden sea chest overgrown with kelp and barnacles, closed", 32, 32, UNDER),
 "deep_chest_solvik": ("iron-bound wooden chest half buried among old cobblestones, closed", 32, 32, UNDER),
 "deep_chest_bone": ("chest made of whale bone and rusty iron bands, closed, faint pale glow", 32, 32, UNDER),
 "deep_chest_open": ("old sea chest with the lid thrown open, empty inside", 32, 32, UNDER),
 "deep_rope_up": ("thick knotted hemp rope hanging down from the surface, a lead weight at its end, bubbles", 32, 48, UNDER),
 "deep_rope_down": ("iron ring bolted into a flat rock on the seabed with a thick hemp rope coiled around it and leading down, dark crack beside it", 32, 32, UNDER),
 "deep_debris": ("big heap of shipwreck debris: broken planks, a ship wheel, rusty chains and a crushed barrel piled up", 32, 32, UNDER),
 "deep_bell": ("old brass diving bell with a small round glass window hanging on a chain, air bubbles", 32, 40, UNDER),
 "deep_station": ("diving bell station: a brass diving bell anchored to the seabed with chains, an air hose going "
                  "up, a small lamp glowing", 48, 48, UNDER),
 # Deep: floor decor, kelp forest
 "deep_kelp_clump": ("tall clump of brown kelp swaying", 32, 40, UNDER),
 "deep_kelp_rock": ("rock covered with barnacles and small anemones", 32, 32, UNDER),
 "deep_kelp_starfish": ("orange starfish and sea urchins on sand", 32, 32, UNDER),
 "deep_kelp_shells": ("pile of scallop and mussel shells on sand", 32, 32, UNDER),
 # Deep: drowned Old Solvik
 "deep_solvik_lamp": ("fallen iron street lamp overgrown with weed", 32, 32, UNDER),
 "deep_solvik_wheel": ("broken wooden cart wheel lying in silt", 32, 32, UNDER),
 "deep_solvik_door": ("fallen wooden house door with an iron knocker, covered in silt", 32, 32, UNDER),
 "deep_solvik_chimney": ("stump of a brick chimney sticking out of the seabed", 32, 40, UNDER),
 "deep_solvik_sign": ("tilted wooden shop sign with a painted fish picture on a post, overgrown with weed, blank board", 32, 40, UNDER),
 # Deep: bone abyss
 "deep_bone_rib": ("giant curved whale rib bone sticking out of dark silt", 32, 40, UNDER),
 "deep_bone_skull": ("single enormous whale skull bone with empty eye sockets, bleached white, half buried in silt", 48, 32, UNDER),
 "deep_bone_coral": ("branching pale deep-sea coral bush glowing faint blue", 32, 32, UNDER),
 "deep_bone_pile": ("pile of small fish bones and vertebrae", 32, 32, UNDER),
 "deep_bone_vent": ("black rock chimney of a hydrothermal vent with orange glow", 32, 40, UNDER),
 # Grottoes, by the letters of the hall maps
 "grotto_tidepool": ("small rocky basin of clear sea water with a red starfish and green anemones, grey rock rim", 32, 32, CAVE),
 "grotto_mussels": ("cluster of dark blue mussels on a wet rock", 32, 32, CAVE),
 "grotto_boulder": ("round grey boulder, heavy", 32, 32, CAVE),
 "grotto_plate": ("square stone pressure plate set into the cave floor, carved rim", 32, 32, CAVE),
 "grotto_plate_down": ("square stone pressure plate pressed down into the floor, glowing rim", 32, 32, CAVE),
 "grotto_grate": ("rusty iron grate gate set in rock, closed", 32, 32, CAVE),
 "grotto_page_niche": ("grey stone block with a small arched niche carved into it, a rolled yellow paper page inside", 32, 32, CAVE),
 "grotto_pedestal": ("carved stone pedestal with an empty round hollow on top", 32, 32, CAVE),
 "grotto_salt": ("cluster of white salt crystals growing on rock", 32, 32, CAVE),
 "grotto_cat_grave": ("tiny grave: a small stone with a carved cat and a shell on it", 32, 32, CAVE),
 "grotto_crate": ("old wet wooden crate washed into a cave", 32, 32, CAVE),
 "grotto_skeleton": ("old sailor's skeleton sitting against a rock with a rusty lantern", 32, 32, CAVE),
 "grotto_stalactite": ("stalactite column dripping water, wet rock", 32, 40, CAVE),
 "grotto_echo_pool": ("dark round pool that glows faintly blue", 32, 32, CAVE),
 "grotto_rubble": ("pile of fallen cave rocks blocking a passage", 32, 32, CAVE),
 "grotto_eleonora_niche": ("carved niche with an old ship's nameboard and burnt-down candles, no text", 32, 40, CAVE),
 "grotto_treasure": ("small open treasure chest spilling old gold coins", 32, 32, CAVE),
 "grotto_false_lantern": ("crooked old wrecker's lantern on a pole, glowing orange", 32, 40, CAVE),
 "grotto_ebb_pool": ("shallow round puddle of blue-green sea water with a grey stone rim and small shells", 32, 32, CAVE),
 "grotto_heart_chest": ("ornate chest decorated with a heart of red coral, closed", 32, 32, CAVE),
 "grotto_altar": ("ancient grey stone altar block carved with waves and nine small figures, a shell on top", 48, 40, CAVE),
 "grotto_entry": ("short flight of worn stone steps going up, wet grey stone", 32, 32, CAVE),
 "grotto_passage": ("round dark hole in the rock floor with worn stone steps leading down into it", 32, 32, CAVE),
 "grotto_slippery": ("patch of wet slippery green seaweed on the cave floor", 32, 32, CAVE),
}


def make(oid):
    if os.path.exists(os.path.join(pl.RAW, "deep", oid, oid + ".png")):
        return f"{oid} (kept)"
    desc, w, h, where = OBJECTS[oid]
    pl.create_map_object("deep", oid, f"{desc}, {where}", w, h, "high top-down")
    return oid


def safe(oid):
    try:
        return make(oid)
    except Exception as e:
        return f"FAIL {oid} {str(e)[:300]}"


if __name__ == "__main__":
    ids = sys.argv[1:] or list(OBJECTS)
    start = pl.generations_left()
    print("left", start, flush=True)
    with cf.ThreadPoolExecutor(6) as ex:
        for r in ex.map(safe, ids):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
