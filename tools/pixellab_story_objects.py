"""The places of the story (data/story_spots.json) as map-objects, about one generation each: Agatha's desk with
the code lock, her journal, the evidence board, the office archive, the cabinet of curiosities, Neptune's
counter, the cannery, the crypts, the stone circle and the cairn, the wreck of the Saint Berta, the Treska,
the Teeth, the raven mark, dig spots, sketching easels, the Guild House stand, the Kronvald steamer post,
the mill owl, the glowing water. Kinds that already have art (bonfires, cats, ghosts, daughters, Agatha,
the telegraph and safe as furniture) are not here.
Output: assets_src/pixellab/story/<id>/<id>.png; build_art.py crops them into assets/sprites/props/.
Usage: python3 tools/pixellab_story_objects.py [ids...]   (resumable)"""
import sys, os, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl

LAND = "single object, pixel art, 3/4 top-down view, northern fishing island, muted cold palette, transparent background, no text"
ROOM = "single piece of furniture indoors, pixel art, 3/4 top-down view, muted cold palette, transparent background, no text"
SEA = "single object standing in the sea, pixel art, 3/4 top-down view, muted cold palette, transparent background, no text"

# story_<kind>: (description, width, height, setting)
OBJECTS = {
 "story_code_lock": ("old writing desk with a small iron strongbox on it closed with a brass combination dial lock", 32, 32, ROOM),
 "story_journal": ("keeper's logbook lying open on a small desk beside an inkwell and a candle", 32, 32, ROOM),
 "story_board": ("cork evidence board on an easel with pinned papers, photographs and red string between them", 32, 40, ROOM),
 "story_archive": ("tall wooden archive shelves full of ledgers, folders and document boxes", 32, 40, ROOM),
 "story_cabinet": ("cabinet of curiosities: glass-fronted wooden cabinet with shells, a small skull, bottles and oddities", 32, 48, ROOM),
 "story_neptune_counter": ("insurance office counter with a trident emblem, a ledger, a brass bell and tins of fish", 48, 32, ROOM),
 "story_chapel_crypt": ("square stone floor hatch with an iron ring handle leading down to a crypt", 32, 32, ROOM),
 "story_glow_water": ("patch of sea water glowing soft blue with tiny sparkles", 32, 32, SEA),
 "story_berta_wreck": ("broken hull of a wrecked old brig lying on its side on black rocks, snapped masts, torn rags of sail, holes in the planks, no sails up", 64, 48, SEA),
 "story_crypt": ("small stone crypt with an iron door on a rocky islet, a dead signal fire basket beside it", 48, 48, SEA),
 "story_ambush": ("cluster of black rocks with ropes, a hidden dark lantern and a smugglers' rowboat tied behind them", 48, 32, SEA),
 "story_lantern_dive": ("old brass lantern lying under clear shallow water among rocks, glowing faintly", 32, 32, SEA),
 "story_treska": ("old wooden fishing boat beached on its side on sand, peeling blue paint, torn brown sail", 48, 32, LAND),
 "story_cairn": ("cairn of piled grey stones with a small wreath of heather at its foot", 32, 40, LAND),
 "story_raven_mark": ("three black ravens standing around a patch of freshly disturbed earth", 32, 32, LAND),
 "story_ritual": ("flat ancient stone slab carved with a spiral, a shallow bowl of sea water and two candles on it", 32, 32, LAND),
 "story_circle": ("nine small rough standing stones arranged in a ring on moorland grass and heather, open grass in the middle, no platform", 64, 48, LAND),
 "story_owl": ("old barn owl sitting on a broken wooden mill beam", 32, 32, LAND),
 "story_dig": ("patch of disturbed earth marked with an X of small stones", 32, 32, LAND),
 "story_sketch": ("small wooden sketching easel with a half-finished pencil drawing of the sea", 32, 40, LAND),
 "story_guild": ("wooden notice stand with a carved guild emblem of a lantern and an anchor, a hanging lamp", 32, 40, LAND),
 "story_cannery": ("small grim fish cannery shed of corrugated iron with a smoking chimney and a trident emblem", 64, 48, LAND),
 "story_kronvald": ("wooden pier post with a steamer timetable board and a small brass bell", 32, 40, LAND),
 "story_ghost_mark": ("faint cold mist swirling above the ground, pale blue", 32, 32, LAND),
}


def make(oid):
    if os.path.exists(os.path.join(pl.RAW, "story", oid, oid + ".png")):
        return f"{oid} (kept)"
    desc, w, h, where = OBJECTS[oid]
    pl.create_map_object("story", oid, f"{desc}, {where}", w, h, "high top-down")
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
