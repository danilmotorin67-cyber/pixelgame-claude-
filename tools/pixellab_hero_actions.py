"""The keeper's actions for both heroes (hero_male, hero_female): v3 text animations on the existing
PixelLab characters in south, east and north (build_art mirrors east into west), a lying sleep and the
diving suit as a state of the character (the helmet hides the face, so one suit serves both).
Each action is one /characters/animations call; the calls of one hero run in parallel and the
character ZIP is downloaded once at the end. Output: assets_src/pixellab/characters/<hero>/ (+ hero_suit).
Usage: python3 tools/pixellab_hero_actions.py [hero ...] [action ...|redo]   (resumable)"""
import sys, os, json, time, threading
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl

HEROES = ["hero_male", "hero_female"]
SIDE = ["south", "east", "north"]
# key: (action text, directions, frames)
ACTIONS = {
 "hoe": ("raising a garden hoe over the head with both hands and striking the ground in front", SIDE, 6),
 "water": ("tilting a metal watering can forward, water pouring onto the ground in front", SIDE, 6),
 "axe": ("swinging a wood axe over the shoulder and chopping forward", SIDE, 6),
 "pick": ("swinging a pickaxe high over the head and striking down at a rock in front", SIDE, 6),
 "scythe": ("sweeping a long scythe low from side to side, mowing", SIDE, 6),
 "shovel": ("digging with a spade: pushing it into the ground and lifting a clump of earth", SIDE, 6),
 "cast": ("casting a fishing rod: swinging the rod back over the shoulder and flicking it forward", SIDE, 6),
 "reel": ("holding a bent fishing rod with both hands, pulling back and reeling in a fighting fish", SIDE, 6),
 "net": ("sweeping a small hand net on a pole down and forward, scooping", SIDE, 6),
 "attack": ("slashing forward with a short cutlass in one hand, quick strike", SIDE, 6),
 "carry": ("walking slowly while carrying a long canvas-wrapped body over one shoulder", SIDE, 6),
 "swim": ("swimming breaststroke underwater, body horizontal, arms and legs kicking", SIDE, 6),
 "sit": ("sitting on the ground with knees up, resting and breathing slowly", SIDE, 4),
 "sleep": ("lying on the ground on the back, asleep, chest rising and falling slowly", ["south"], 4),
 # The keeper's own business, the rest of the manifest.
 "harpoon": ("aiming a harpoon gun at the shoulder and firing it, the gun kicking back", SIDE, 6),
 "dodge": ("quick dodge roll forward along the ground and back up", SIDE, 6),
 "rite": ("kneeling before a low stone, laying both hands on it, head bowed", SIDE, 6),
 "light_lamp": ("reaching up with a long burning match and lighting a lamp, the flame catching", SIDE, 6),
 "clean_glass": ("wiping a pane of glass in circles with a rag, arm raised", SIDE, 6),
 "wind": ("turning a big crank handle round and round with both hands", SIDE, 6),
 "ring_bell": ("pulling a bell rope down hard, then letting it go up", SIDE, 6),
 "pet": ("crouching down and stroking a small animal on the ground", SIDE, 6),
 "eat": ("eating: lifting food to the mouth and chewing happily", ["south"], 6),
 "faint": ("swaying on the spot, eyes closing, then collapsing to the ground", ["south"], 6),
 "lift_cat": ("picking up a black cat and holding it in the arms, smiling", ["south"], 6),
 "surprised": ("startled: a small jump back with both hands raised, eyes wide", ["south"], 4),
 "happy": ("happy little jump, cheering with both arms raised", ["south"], 4),
}
# Second takes ("<action>:2"): directions PixelLab left out and the weakest ones. They are stored
# under the same animation name; build_art.py lets the later take win direction by direction.
PICK = ("swinging a pickaxe: lifting it over the shoulder and bringing it down hard onto a rock on the "
        "ground in front, no magic, no glow, no effects")
REDO = {
 "hero_male": {
  "pick:2": (PICK, SIDE, 6),
  "water:2": ACTIONS["water"][:1] + (["north"], 6),
  "cast:2": ACTIONS["cast"][:1] + (["north"], 6),
  "sit:2": ("sitting down cross-legged on the ground and resting", ["south"], 6),
  "sleep:2": ("slowly lying down on the ground on the side and falling asleep", ["south"], 6),
 },
 "hero_female": {
  "pick:2": (PICK, ["south"], 6),
  "reel:2": ACTIONS["reel"][:1] + (["east", "north"], 6),
  "net:2": ACTIONS["net"][:1] + (["north"], 6),
  "shovel:2": ("digging with a spade, the spade clearly visible: pushing it into the ground and lifting a clump "
               "of earth", ["north"], 6),
 },
}
SUIT = ("wearing an old brass diving helmet with a round glass window and a thick canvas diving suit "
        "with heavy lead boots, the face hidden behind the helmet glass")

lock = threading.Lock()


def folder(hero):
    return os.path.join(pl.RAW, "characters", hero)


def meta(hero):
    return json.load(open(os.path.join(folder(hero), "meta.json"), encoding="utf-8"))


def note(hero, key, info):
    with lock:
        m = meta(hero)
        m.setdefault("animations", {})[key] = info
        pl.save_meta(folder(hero), m)


def animate(hero, key, text, directions, frames):
    cid = meta(hero)["character_id"]
    res = pl.request("POST", "/characters/animations", {
        "character_id": cid, "mode": "v3", "action_description": text, "animation_name": key.split(":")[0],
        "directions": list(directions), "frame_count": frames})
    for job_id in res["background_job_ids"]:
        job = pl.wait_job(job_id, timeout=2400)
        if job["status"] != "completed":
            raise RuntimeError(f"{hero} {key}: " + json.dumps(job)[:400])
    note(hero, key, {"group": res.get("animation_group_id"), "action_description": text,
                     "directions": list(directions), "frame_count": frames})
    return f"{hero} {key}"


def suit():
    """hero_suit: the diving suit as a state of the keeper, walking in four directions."""
    dest = os.path.join(pl.RAW, "characters", "hero_suit")
    if os.path.exists(os.path.join(dest, "meta.json")) and "walking" in json.load(open(os.path.join(dest, "meta.json"))).get("animations", {}):
        return "hero_suit (kept)"
    m = json.load(open(os.path.join(dest, "meta.json"))) if os.path.exists(os.path.join(dest, "meta.json")) else {}
    if not m.get("character_id"):
        res = pl.request("POST", "/create-character-state", {
            "character_id": meta("hero_male")["character_id"], "edit_description": SUIT, "state_name": "diving suit",
            "use_color_palette_from_reference": False, "no_background": True})
        job = pl.wait_job(res["background_job_id"], timeout=2400)
        if job["status"] != "completed":
            raise RuntimeError("suit: " + json.dumps(job)[:400])
        m = {"id": "hero_suit", "method": "create-character-state", "prompt": SUIT, "source": "hero_male", "state": 1,
             "character_id": res["character_id"], "date": time.strftime("%Y-%m-%d")}
        pl.download_character(res["character_id"], dest)
        pl.save_meta(dest, m)
    pl.animate_character("characters", "hero_suit", m["character_id"], "walking")
    return "hero_suit"


def safe(fn, *args):
    try:
        return fn(*args)
    except Exception as e:
        return f"FAIL {args[:2]} {str(e)[:300]}"


if __name__ == "__main__":
    heroes = [a for a in sys.argv[1:] if a in HEROES] or HEROES
    keys = [a for a in sys.argv[1:] if a in ACTIONS or a == "suit"] or list(ACTIONS) + ["suit"]
    start = pl.generations_left()
    print("left", start, flush=True)
    jobs = [(animate, h, k, *ACTIONS[k]) for h in heroes for k in keys
            if k in ACTIONS and k not in meta(h).get("animations", {})]
    if "redo" in sys.argv[1:]:
        keys = []
        jobs = [(animate, h, k, *v) for h in heroes for k, v in REDO.get(h, {}).items()
                if k not in meta(h).get("animations", {})]
    with cf.ThreadPoolExecutor(8) as ex:
        futs = [ex.submit(safe, *j) for j in jobs]
        if "suit" in keys:
            futs.append(ex.submit(safe, suit))
        for f in cf.as_completed(futs):
            print(time.strftime("%H:%M:%S"), f.result(), flush=True)
    for h in heroes:
        pl.download_character(meta(h)["character_id"], folder(h))
    print("spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
