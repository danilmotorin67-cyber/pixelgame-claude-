"""Death animations for the enemies and bosses (tools/pixellab_spirits_enemies.py): one
animate-with-text-v3 call on each creature's existing sprite, one at a time so the spend is exact;
stops when the balance runs low. Output: assets_src/pixellab/enemies/<id>/die/."""
import sys, time
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_chars as c
from pixellab_spirits_enemies import ENEMIES, BOSSES

DEATHS = {
 "crab": "flipping onto its back, legs curling, fading",
 "jellyfish": "deflating and dissolving into the water",
 "urchin": "spines drooping and crumbling apart",
 "moray": "going limp and sinking",
 "bullhead": "turning belly-up and fading",
 "seal_bully": "flopping over and fading away",
 "drowned": "collapsing into seaweed and water",
 "drowned_citizen": "collapsing into seaweed and water",
 "hmarnik": "dissolving into lilac mist",
 "helmet_crayfish": "helmet cracking, crayfish collapsing",
 "octopus": "going limp in a cloud of ink",
 "electric_ray": "sparks fizzling out, sinking",
 "net_trap": "net tearing apart and falling",
 "anglerfish": "lure going dark, sinking",
 "deep_crab": "shell cracking, collapsing",
 "bonefish": "bones scattering apart",
 "hmar_spirit": "core flickering out, dissolving into mist",
 "hot_vent": "eruption dying down to still rock",
 "gull_marauder": "tumbling down in a burst of feathers",
 "wet_dog": "whimpering and dissolving into shadow",
 "saboteur": "falling down and dropping the crowbar",
 "mother_moray": "thrashing then sinking lifeless into the kelp",
 "bell_ringer": "bell cracking, giant crumbling into seaweed",
 "bone_whale": "bones falling apart, eye glow fading",
}

if __name__ == "__main__":
    start = pl.generations_left()
    print("left", start, flush=True)
    for aid, text in DEATHS.items():
        left = pl.generations_left()
        if left < 2:
            print("stop: balance", left, flush=True)
            break
        spec = ENEMIES.get(aid) or BOSSES.get(aid)
        desc, w, h = spec[0], spec[1], spec[2]
        frames = 8 if aid in BOSSES else 6
        try:
            c.critter(aid, desc, w, h, {"die": (text, frames)}, "high top-down", "enemies")
            print(time.strftime("%H:%M:%S"), aid, "spent", left - pl.generations_left(), flush=True)
        except Exception as e:
            print("FAIL", aid, str(e)[:200], flush=True)
    print("total spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
