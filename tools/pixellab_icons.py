"""Inventory icons from PixelLab in batches: one create-1-direction-object call at 32 px
returns up to 64 objects, each drawn from its own entry of item_descriptions.
Icons land in assets_src/pixellab/icons/<id>.png; tools/build_art.py copies them to
assets/sprites/icons/."""
import sys, os, io, json, time, base64, urllib.request
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image

OUT = os.path.join(pl.RAW, "icons")
STYLE = ("inventory item icon, single object centred, seen from the side at a slight angle, "
         "cozy farming game like Stardew Valley, clean dark outline, muted cold northern palette, transparent background")

FISH = {
 "fish_cod": "atlantic cod, olive-brown speckled back, pale belly, chin barbel",
 "fish_saithe": "saithe (coalfish), dark green-grey back, silver belly, slim",
 "fish_haddock": "haddock, grey with a black lateral line and a dark thumbprint spot",
 "fish_herring": "atlantic herring, small silver fish with blue-green back",
 "fish_mackerel": "atlantic mackerel, blue-green back with black wavy stripes, silver belly",
 "fish_capelin": "capelin, tiny slender silver-olive fish",
 "fish_flounder": "flounder, flat brown fish with orange spots, both eyes on one side",
 "fish_bullhead": "sea bullhead, grumpy brown fish with big head and spiny fins",
 "fish_lumpfish": "lumpfish, round lumpy green-grey fish with bumps",
 "fish_redfish": "redfish (ocean perch), bright red fish with huge eyes",
 "fish_wolffish": "atlantic wolffish, long grey-blue fish with big fang teeth and dark stripes",
 "fish_navaga": "navaga (saffron cod), small grey-yellow cod-like fish",
 "fish_smelt": "european smelt, slim translucent silver fish",
 "fish_halibut": "atlantic halibut, big flat dark olive-brown fish",
 "fish_skate": "thornback skate, flat diamond-shaped ray with long tail, brown with spots",
 "fish_monkfish": "monkfish, ugly wide-mouthed brown fish with lure on its head",
 "fish_squid": "squid, pale pink-white with tentacles",
 "fish_porbeagle": "porbeagle shark, small grey-blue shark",
 "fish_whiting": "whiting, pale silvery fish with a small dark spot at the pectoral fin",
 "fish_sandeel": "sand eel, very thin long silver fish",
 "fish_sea_scorpion": "sea scorpion, spiky mottled red-brown rock-pool fish",
 "fish_garfish": "garfish, needle-thin green-blue fish with long beak jaw",
 "fish_sea_trout": "sea trout, silver trout with dark spots",
 "fish_char": "arctic char, olive back, red-orange belly, pale spots",
 "fish_grayling": "grayling, grey fish with a big colourful sail-like dorsal fin",
 "fish_salmon": "atlantic salmon, silver with small black spots, pink tint",
 "fish_burbot": "burbot, long mottled brown freshwater cod with chin barbel",
 "fish_pike": "northern pike, long green fish with pale spots and duck-bill jaw",
 "fish_perch": "european perch, green-yellow with dark vertical stripes and red fins",
 "fish_eel": "european eel, long snake-like dark olive fish",
 "fish_stickleback": "three-spined stickleback, tiny fish with spines",
 "fish_eelpout": "eelpout, long brown-yellow fish with tapered tail",
 "fish_whitefish": "whitefish, sleek silvery lake fish",
 "fish_old_codger": "legendary giant old cod, scarred, grey-green, with an old fishing hook in its lip, golden glow outline",
 "fish_herring_king": "legendary oarfish, long silver ribbon body with a crimson crown-like fin, golden glow outline",
 "fish_golden_halibut": "legendary golden halibut, flat fish shining gold, golden glow outline",
 "fish_grandmother": "legendary ancient huge pike, grey-green, frost on its scales, wise old eyes, golden glow outline",
 "fish_lantern_fish": "legendary deep-sea lanternfish, black with glowing blue-green lights along its body, golden glow outline",
 "fish_codger_son": "young giant cod with a tiny hook scar, grey-green, golden glow outline",
 "fish_herring_princess": "slender silver oarfish with a small crimson crown fin, golden glow outline",
 "fish_golden_calf": "small golden halibut shining gold, golden glow outline",
 "fish_granddaughter": "young pike with frost on its scales, golden glow outline",
 "fish_lantern_fry": "small black lanternfish with glowing blue-green dots, golden glow outline",
}


def _png(item):
    """An object frame: base64 image, raw RGBA, or a URL on the API host."""
    if isinstance(item, dict) and item.get("base64"):
        raw = base64.b64decode(item["base64"])
        try:
            return Image.open(io.BytesIO(raw)).convert("RGBA")
        except Exception:
            return Image.frombytes("RGBA", (int(item["width"]), int(item["height"])), raw)
    raise RuntimeError("no image in " + json.dumps(item)[:200])


def batch(icons, size=32, name="batch"):
    """icons: {id: description}. Up to 64 per call at size <= 42."""
    ids = list(icons)
    before = pl.generations_left()
    res = pl.request("POST", "/create-1-direction-object", {
        "description": STYLE, "size": size, "view": "top-down",
        "item_descriptions": [f"{icons[i]}, {STYLE}" for i in ids]})
    oid = res["object_id"]
    t0 = time.time()
    while True:
        info = pl.request("GET", f"/objects/{oid}")
        status = str(info.get("status", ""))
        if status in ("review", "completed", "failed") or time.time() - t0 > 1800:
            break
        time.sleep(10)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"_{name}_object.json"), "w") as f:
        json.dump({k: v for k, v in info.items() if k not in ("frames", "images", "candidates")}, f, indent=1, default=str)
    return oid, info, ids, before


if __name__ == "__main__":
    print(pl.generations_left())
