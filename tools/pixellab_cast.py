"""The whole cast: every NPC and every animal from docs/art/assets.csv, with animations.
Resumable: finished characters and animations are skipped (see tools/pixellab_chars.py)."""
import sys, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
import pixellab_chars as c

# id: (appearance, signature action shown when the resident is at work)
NPCS = {
 "npc_sigrid": ("young woman 25, shop assistant, dark bob hair, black knitted shawl over a grey dress, pale, quiet poet", "writing a poem in a small notebook"),
 "npc_liv": ("young woman 26, naturalist, long ginger braid, green field coat, binoculars on a strap", "looking through binoculars"),
 "npc_hedda": ("woman 31, fishing boat captain, weathered face, yellow oilskin coat, blue knit cap", "hauling a rope hand over hand"),
 "npc_ingrid": ("woman 27, village teacher, neat blonde hair bun, grey wool dress, holding books", "reading an open book"),
 "npc_einar": ("broad man 29, blacksmith, leather apron, rolled sleeves, soot on face, short dark hair", "hammering on an anvil"),
 "npc_knud": ("man 28, carpenter, curly brown hair, apron with sawdust, pencil behind ear", "sawing a plank"),
 "npc_magnus": ("man 38, village doctor, ex-navy surgeon, trim dark beard, long dark coat, black medical bag", "checking a pocket watch"),
 "npc_olaf": ("young man 24, postman and telegraphist, round glasses, blue postal cap, leather satchel", "sorting letters"),
 "npc_tuve": ("young selkie person, grey sealskin cloak, long dark wet hair, grey eyes, barefoot", "wringing water from long hair"),
 "npc_halvdan": ("man 58, village elder and merchant, grey beard, fine brown wool coat, holding a lantern", "counting coins"),
 "npc_stern": ("man 49, city insurance director, black suit, black top hat, walking cane, stern face", "tapping cane impatiently"),
 "npc_tora": ("strong woman 54, blacksmith, grey hair tied back, bandaged hand, leather apron", "quenching hot iron in a bucket"),
 "npc_ilm": ("old man 60, taciturn builder, white beard, flat cap, work jacket, carpenter's pencil", "measuring with a folding ruler"),
 "npc_karl": ("man 55, gloomy shopkeeper, balding, long apron, ledger under arm", "writing in a ledger"),
 "npc_solveig": ("cheerful plump woman 52, baker, red headscarf, flour on apron", "kneading dough"),
 "npc_bjorn": ("barrel-bellied man 47, tavern keeper, big red beard, white apron", "wiping a beer mug with a cloth"),
 "npc_margit": ("old woman 63, animal and wool shop owner, knitted shawl, walking stick", "knitting with needles"),
 "npc_benedict": ("man 45, chapel priest, black cassock, white collar, nervous look", "praying with folded hands"),
 "npc_helga": ("tiny old woman 97, herbalist storyteller, many layered scarves, bundle of herbs", "stirring a small pot"),
 "npc_erland": ("old man 70, retired sea captain, captain's cap, white beard, pipe, wooden leg", "smoking a pipe"),
 "npc_kai": ("man 51, half-mad hermit, ragged patched coat, wild grey hair, lantern", "swinging a lantern"),
 "npc_nils": ("boy 10, ghost-hunter club, flat cap, short trousers, butterfly net", "swinging a butterfly net"),
 "npc_freya": ("girl 10, ghost-hunter club, two blonde braids, raincoat, small lantern", "raising a lantern high"),
 "npc_palm": ("man 50, pedantic lighthouse inspector, navy uniform with brass buttons, clipboard", "writing on a clipboard"),
 "npc_nut": ("man 30, rough fisherman, stubble, blue knit cap, wool sweater", "mending a fishing net"),
 "npc_rud": ("man 33, rough fisherman, black beard, yellow oilskins", "gutting a fish"),
 "npc_sandro": ("southern merchant, colourful striped clothes, gold earring, wide grin, dark curly hair", "showing off wares with open arms"),
 "npc_grump": ("grumpy old steamer skipper, captain's cap, huge grey moustache, navy coat", "blowing a whistle"),
}
EXTRAS = {
 "agatha": "old woman lighthouse keeper, long grey braid, yellow oilskin coat, holding a lantern",
 "kid_toddler_boy": "toddler boy 3, knitted sweater, tiny boots, very small",
 "kid_toddler_girl": "toddler girl 3, knitted dress, tiny boots, very small",
 "kid_child_boy": "boy 7, wool sweater, short trousers, tousled hair",
 "kid_child_girl": "girl 7, pinafore dress, pigtails",
 "villager_1": "fisherman villager, wool sweater, knit cap",
 "villager_2": "fishwife villager, headscarf, apron, basket",
 "sailor_rescued": "shivering rescued sailor wrapped in a grey blanket, wet hair",
}
BEASTS = {
 "sheep": ("fluffy cream island sheep with dark face", "dog", 48),
 "goat": ("white and brown goat with small horns and a beard", "dog", 48),
 "cow": ("small shaggy northern cow, red-brown with white patches", "horse", 64),
 "pony": ("small sturdy dun island pony with dark mane", "horse", 64),
 "cat_wick": ("sleek old black cat with yellow eyes", "cat", 32),
}
BIRDS = {
 "chicken": ("small brown speckled hen", 32),
 "duck": ("white farm duck with orange beak", 32),
 "eider": ("eider duck, black and white drake", 32),
}
# id: (description, w, h, view, {animation: (action, frames)})
CRITTERS = {
 "seal": ("grey harbour seal lying on a rock, seen from above at an angle", 64, 32, "high top-down", {"flop": ("seal flopping and lifting its head", 6)}),
 "seal_swim": ("grey seal head and back swimming in water, top-down", 48, 32, "high top-down", {"swim": ("swimming forward, bobbing in waves", 6)}),
 "gull": ("white and grey herring gull standing, seen from above at an angle", 32, 32, "high top-down", {"idle": ("turning head, looking around", 4)}),
 "gull_fly": ("white and grey herring gull flying with spread wings, seen from above", 48, 32, "high top-down", {"fly": ("flapping wings in flight", 6)}),
 "puffin": ("atlantic puffin standing, black and white with orange beak", 32, 32, "high top-down", {"idle": ("bobbing head, shuffling", 4)}),
 "puffin_fly": ("atlantic puffin flying with fast beating wings, seen from above", 32, 32, "high top-down", {"fly": ("fast flapping wings in flight", 6)}),
 "raven": ("black raven sitting, seen from above at an angle", 32, 32, "high top-down", {"idle": ("tilting head and cawing", 4)}),
 "raven_fly": ("black raven flying with spread wings, seen from above", 48, 32, "high top-down", {"fly": ("gliding and flapping wings in flight", 6)}),
 "whale": ("humpback whale back and dorsal fin breaking the grey sea surface, side view", 192, 96, "side", {"surface": ("whale surfaces, blows spray, dives and raises tail fluke", 8)}),
 "orca": ("black and white orca fin and back breaking the sea surface, side view", 128, 64, "side", {"surface": ("orca rises and dives back into the water", 6)}),
 "herring_school": ("school of silver herring seen from above in dark water", 96, 64, "high top-down", {"shimmer": ("school of fish swirling and shimmering", 6)}),
 "fish_shadow": ("dark fish shadow under water seen from above", 32, 32, "high top-down", {"swim": ("fish shadow swimming, tail swaying", 6)}),
 "eider_wild": ("wild eider duck swimming on the sea, seen from above at an angle", 32, 32, "high top-down", {"swim": ("duck bobbing on waves", 4)}),
 "npc_fortuna": ("wooden ship figurehead of a maiden with chipped nose and flaking gilt, hanging on a wall", 48, 64, "side", {"speak": ("eyes glowing softly and lips moving while speaking", 6)}),
 "baby_cradle": ("baby sleeping in a wooden cradle with a knitted blanket", 32, 32, "high top-down", {"rock": ("cradle gently rocking", 4)}),
}


def run(kind, aid):
    try:
        if kind == "npc":
            desc, work = NPCS[aid]
            return c.human(aid, desc, work)
        if kind == "extra":
            return c.human(aid, EXTRAS[aid])
        if kind == "beast":
            desc, tpl, size = BEASTS[aid]
            if aid == "cat_wick":
                c.beast(aid, desc, tpl, size, None)
                c.action("animals", aid, "sleep", "curling up into a ball and sleeping", ("south",), 4)
                return aid
            return c.beast(aid, desc, tpl, size)
        if kind == "bird":
            desc, size = BIRDS[aid]
            return c.bird(aid, desc, size)
        desc, w, h, view, anims = CRITTERS[aid]
        return c.critter(aid, desc, w, h, anims, view, "characters" if aid in ("npc_fortuna", "baby_cradle") else "animals")
    except Exception as e:
        return f"FAIL {aid} {str(e)[:300]}"


if __name__ == "__main__":
    start = pl.generations_left()
    jobs = ([("npc", k) for k in NPCS] + [("extra", k) for k in EXTRAS] + [("beast", k) for k in BEASTS]
            + [("bird", k) for k in BIRDS] + [("critter", k) for k in CRITTERS])
    with cf.ThreadPoolExecutor(3) as ex:
        for r in ex.map(lambda j: run(*j), jobs):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left())
