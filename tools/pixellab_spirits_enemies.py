"""Ghosts, spirits, enemies and bosses: a map-object each, animated with animate-with-text-v3
(pixellab_chars.critter). Ghosts and spirits float; enemies move and attack; bosses idle and attack.
Output: assets_src/pixellab/<spirits|enemies>/<id>/; build_art packs them into assets/sprites/cast/."""
import sys, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_chars as c

GHOST = "translucent pale-blue glowing ghost, see-through, floating, faint glow"
GHOSTS = {
 "ghost_bartholomew": "ghost of a stout ship's cook with an apron and a ladle",
 "ghost_pim": "ghost of a young cabin boy in a sailor's shirt",
 "ghost_odile": "ghost of an elegant lady in a long dress and feathered hat",
 "ghost_grunwald": "ghost of a navigator with a sextant and a long coat",
 "ghost_martin": "ghost of a burly ship's stoker with a coal shovel",
 "ghost_ion": "ghost of a thin fiddler playing a violin",
 "ghost_jacques": "ghost of a sturdy sailor carrying two small barrels",
 "ghost_twins": "ghosts of two small twin children holding hands",
 "ghost_lotta": "ghost of a young bride in a wedding veil",
 "ghost_horn": "ghost of a sea captain with a captain's cap and a beard",
 "ghost_pennington": "ghost of a thin gentleman in a top hat holding a pen",
 "ghost_gudmund": "ghost of an old fisherman in oilskins with a net",
 "ghost_ulrika": "ghost of an old woman lighthouse keeper with a lantern",
 "ghost_dog": "ghost dog: a shaggy dog with floppy ears, four legs and a tail, standing side view, whole body pale blue see-through, not a sheet ghost",
 "ghost_tobias": "ghost of a deep sea diver in a heavy helmet suit",
 "ghost_emmerich": "ghost of a cartographer holding a rolled map",
 "ghost_nilsen": "ghost of a pastor in a cassock with a small book",
 "ghost_brigi": "ghost of a bent old woman with a shawl and a cane",
 "ghost_vera": "ghost of a schoolteacher with a pointer and a bun",
 "ghost_grim": "ghost of a hunched crooked old man with a long beard, a walking stick and a crooked lantern",
}
# id: (description, w, h, {animation: (action, frames)})
SPIRITS = {
 "rann": ("vast sea goddess of water and kelp rising from the waves, long flowing hair of seaweed, calm glowing eyes",
          128, 128, {"rise": ("rising slowly out of the water", 8), "speak": ("speaking, hair and water flowing, eyes glowing", 8)}),
 "hmar_faces": ("lilac mist wisp with one pale sad human face with closed eyes in it, soft and eerie, not a skull", 64, 64, {"drift": ("fog drifting, faces fading in and out", 8)}),
 "fogfolk": ("hooded grey fog folk spirit, faceless, made of mist", 32, 48, {"float": ("floating and swaying like mist", 6)}),
}
for daughter, look in (("zyb", "a daughter of the sea of ripples, rippling water body"), ("pena", "a daughter of the sea made of white foam"),
                       ("burun", "a daughter of the sea of breaking surf, wild wave hair"), ("stuzha", "a daughter of the sea of frost, icy blue"),
                       ("tish", "a daughter of the sea of calm, still glassy water"), ("svetla", "a daughter of the sea of light, glowing golden"),
                       ("priliva", "a daughter of the sea of the tide, green and silver"), ("hmar", "a daughter of the sea of fog, lilac mist")):
    SPIRITS["daughter_" + daughter] = (f"ethereal sea spirit maiden, {look}", 64, 64, {"idle": ("floating gently, hair flowing", 6)})

MOVE_ATTACK = lambda move, attack: {"move": (move, 6), "attack": (attack, 6)}
ENEMIES = {
 "crab": ("big red cutter crab with sharp claws", 32, 32, MOVE_ATTACK("scuttling sideways", "snapping its claws")),
 "jellyfish": ("stinging pale pink jellyfish with long tentacles", 32, 32, MOVE_ATTACK("pulsing and drifting", "lashing its tentacles")),
 "urchin": ("black spiny sea urchin", 32, 32, MOVE_ATTACK("spines slowly waving", "spines bristling outwards")),
 "moray": ("green kelp moray eel with an open mouth", 64, 32, MOVE_ATTACK("slithering forward", "lunging and biting")),
 "bullhead": ("small spiny brown bullhead fish", 32, 32, MOVE_ATTACK("swimming", "darting forward")),
 "seal_bully": ("fat grey bully seal with a smug face", 48, 32, MOVE_ATTACK("flopping forward", "slapping with its flipper")),
 "drowned": ("drowned sailor with seaweed hair and pale skin, rags, not gory", 32, 48, MOVE_ATTACK("shambling forward", "reaching out to grab")),
 "drowned_citizen": ("drowned townsman in an old waistcoat, seaweed, pale, not gory", 32, 48, MOVE_ATTACK("shambling forward", "reaching out to grab")),
 "hmarnik": ("pale lilac fog creature with long thin arms and hollow eyes", 32, 48, MOVE_ATTACK("flickering and gliding", "phasing forward to strike")),
 "helmet_crayfish": ("crayfish wearing an old copper diving helmet as a shell", 48, 32, MOVE_ATTACK("crawling", "pinching with claws")),
 "octopus": ("dark red octopus", 48, 48, MOVE_ATTACK("crawling with tentacles", "squirting black ink")),
 "electric_ray": ("flat grey electric ray fish seen from above, wide wing fins and long thin tail, small blue sparks", 48, 48, MOVE_ATTACK("gliding", "crackling with electric sparks")),
 "net_trap": ("tangled old fishing net snare with floats", 32, 32, MOVE_ATTACK("swaying in the current", "snapping shut")),
 "anglerfish": ("black deep sea anglerfish with a glowing lure", 48, 32, MOVE_ATTACK("swimming, lure glowing", "opening its huge jaws")),
 "deep_crab": ("huge armoured deep sea crab with barnacles", 48, 48, MOVE_ATTACK("walking slowly", "slamming its big claw")),
 "bonefish": ("skeletal fish made of bones", 32, 32, MOVE_ATTACK("swimming", "biting")),
 "hmar_spirit": ("hovering lilac fog spirit with a glowing core", 32, 48, MOVE_ATTACK("hovering", "shooting a fog bolt")),
 "hot_vent": ("hot volcanic vent on the sea floor", 32, 32, MOVE_ATTACK("bubbling gently", "erupting with hot bubbles")),
 "gull_marauder": ("big angry herring gull with a stolen fish", 48, 32, MOVE_ATTACK("flying", "diving and pecking")),
 "wet_dog": ("gaunt wet black stray dog with glowing eyes", 48, 32, MOVE_ATTACK("running", "lunging and biting")),
 "saboteur": ("hooded saboteur in a dark coat with a crowbar", 32, 48, MOVE_ATTACK("sneaking", "swinging a crowbar")),
}
BOSSES = {
 "mother_moray": ("giant ancient moray eel mother coiled in kelp, huge jaws, scarred", 128, 96,
                  {"idle": ("coiling and breathing", 8), "attack": ("lunging with open jaws", 8)}),
 "bell_ringer": ("drowned bell-ringer giant holding a huge green bronze bell, seaweed robes", 96, 128,
                 {"idle": ("swaying, bell swinging slowly", 8), "attack": ("swinging and ringing the bell hard", 8)}),
 "bone_whale": ("colossal whale skeleton swimming in dark water, glowing blue eye sockets", 128, 96,
                {"idle": ("swimming slowly, bones creaking", 8), "attack": ("charging with open jaws", 8)}),
}


def run(group, aid, desc, w, h, anims):
    try:
        return c.critter(aid, desc, w, h, anims, "high top-down", group)
    except Exception as e:
        return f"FAIL {aid} {str(e)[:200]}"


if __name__ == "__main__":
    start = pl.generations_left()
    jobs = ([("spirits", a, f"{d}, {GHOST}", 32, 48, {"float": ("floating gently up and down, glowing softly", 6)}) for a, d in GHOSTS.items()]
            + [("spirits", a, d, w, h, an) for a, (d, w, h, an) in SPIRITS.items()]
            + [("enemies", a, f"{d}, enemy", w, h, an) for a, (d, w, h, an) in ENEMIES.items()]
            + [("enemies", a, f"{d}, boss monster", w, h, an) for a, (d, w, h, an) in BOSSES.items()])
    if len(sys.argv) > 1:
        jobs = [j for j in jobs if j[1] in sys.argv[1:]]
    with cf.ThreadPoolExecutor(4) as ex:
        for r in ex.map(lambda j: run(*j), jobs):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left())
