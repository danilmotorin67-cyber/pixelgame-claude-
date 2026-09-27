"""Talk portraits, 64×64, six emotions each. The neutral bust comes from the character's own sprite
(portrait-character-pro, character_to_portrait: same face and clothes); the other five are text edits
of that bust on the Pixen model (edit-image-pixen, 1 generation each), so the face stays the same.
Output: assets_src/pixellab/portraits/<id>/<emotion>.png; build_art.py packs them.
Usage: python3 tools/pixellab_portraits.py [ids...]   (resumable: finished files are kept)"""
import sys, os, io, json, base64, zipfile, time
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image

OUT = os.path.join(pl.RAW, "portraits")
EMOTIONS = {
    "happy": "make the face happy: a warm open smile, bright eyes",
    "sad": "make the face sad: downturned mouth, sorrowful eyes, brows raised in the middle",
    "angry": "make the face angry: frowning brows, narrowed eyes, tight mouth",
    "surprised": "make the face surprised: wide eyes, raised brows, small open mouth",
}
# The sixth, "special" expression: each one's own (default: shy and blushing).
SPECIAL = {
    "npc_fortuna": "a sly knowing smirk, one eyebrow raised",
    "npc_sigrid": "dreamy, lost in thought, looking slightly away",
    "npc_liv": "laughing out loud with eyes closed",
    "npc_hedda": "stern and suspicious, squinting",
    "npc_ingrid": "cold polite smile, eyes not smiling",
    "npc_einar": "proud grin, confident",
    "npc_knud": "embarrassed, scratching his head, sheepish grin",
    "npc_magnus": "tired and weary, heavy eyelids",
    "npc_olaf": "pompous and self-important, chin raised",
    "npc_tuve": "mischievous grin",
    "npc_halvdan": "wistful, distant sad smile",
    "npc_stern": "cold predatory smile",
    "npc_tora": "determined, jaw set",
    "npc_ilm": "thoughtful, calculating, one eye narrowed",
    "npc_karl": "nervous, sweating",
    "npc_solveig": "gentle motherly smile",
    "npc_bjorn": "booming laugh",
    "npc_margit": "gossiping whisper, hand near the mouth",
    "npc_benedict": "serene, eyes closed in prayer",
    "npc_helga": "knowing old smile, eyes twinkling",
    "npc_erland": "drunk and merry, rosy cheeks",
    "npc_kai": "haunted, staring into the distance",
    "npc_nils": "excited, sparkling eyes",
    "npc_freya": "adventurous wink",
    "npc_palm": "scheming smile",
    "npc_nut": "shy, hiding a smile",
    "npc_rud": "grumpy, arms crossed feel",
    "npc_sandro": "charming smile, raised eyebrow",
    "npc_grump": "scowling grumpily",
    "agatha": "determined, steely gaze",
    "hero_male": "determined, steady gaze",
    "hero_female": "determined, steady gaze",
}
DAUGHTERS = ["zyb", "pena", "burun", "stuzha", "tish", "svetla", "priliva", "hmar"]


def b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def decode(im, w=64, h=64):
    raw = base64.b64decode(im["base64"])
    try:
        return Image.open(io.BytesIO(raw)).convert("RGBA")
    except Exception:
        return Image.frombytes("RGBA", (int(im.get("width", w)), int(im.get("height", h))), raw)


def source(pid):
    """The front view the bust is drawn from."""
    if pid.startswith("daughter_"):
        return Image.open(os.path.join(pl.RAW, "spirits", pid, pid + ".png")).convert("RGBA")
    zpath = os.path.join(pl.RAW, "characters", pid, "character.zip")
    if os.path.exists(zpath):
        z = zipfile.ZipFile(zpath)
        name = next(n for n in z.namelist() if n.endswith("rotations/south.png"))
        return Image.open(io.BytesIO(z.read(name))).convert("RGBA")
    # Otherwise the first front-facing frame of the packed cast sheet (e.g. Fortuna, a figurehead).
    meta = json.load(open(os.path.join(pl.ROOT, "assets", "sprites", "cast", pid + ".json")))
    fw, fh = meta["frame"]
    rows = meta["anims"].get("rot") or next(iter(meta["anims"].values()))
    row = rows.get("south") or next(iter(rows.values()))
    sheet = Image.open(os.path.join(pl.ROOT, "assets", "sprites", "cast", pid + ".png")).convert("RGBA")
    frame = sheet.crop((0, row[0] * fh, fw, (row[0] + 1) * fh))
    return frame.crop(frame.getbbox())


def job_image(res):
    job = pl.wait_job(res["background_job_id"], timeout=1500)
    if job["status"] != "completed":
        raise RuntimeError(json.dumps(job)[:400])
    lr = job.get("last_response") or {}
    imgs = lr.get("images") or ([lr["image"]] if lr.get("image") else [])
    return decode(imgs[0])


def portrait(pid):
    folder = os.path.join(OUT, pid)
    os.makedirs(folder, exist_ok=True)
    spent = {}
    neutral_path = os.path.join(folder, "neutral.png")
    if not os.path.exists(neutral_path):
        before = pl.generations_left()
        img = job_image(pl.request("POST", "/portrait-character-pro", {
            "direction": "character_to_portrait", "image": b64(source(pid)), "result_size": 64}))
        img.save(neutral_path)
        spent["neutral"] = before - pl.generations_left()
    neutral = Image.open(neutral_path).convert("RGBA")
    edits = dict(EMOTIONS)
    edits["special"] = "change the facial expression to: " + SPECIAL.get(pid, "shy, blushing, looking away")
    for emo, text in edits.items():
        path = os.path.join(folder, emo + ".png")
        if os.path.exists(path):
            continue
        before = pl.generations_left()
        img = job_image(pl.request("POST", "/edit-image-pixen", {
            "image": b64(neutral), "description": text + "; keep the same person, hair, clothes, framing and pixel style",
            "width": 64, "height": 64, "no_background": True}))
        img.save(path)
        spent[emo] = before - pl.generations_left()
    meta_path = os.path.join(folder, "meta.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {"id": pid, "size": 64, "spent": {}}
    meta["spent"].update(spent)
    json.dump(meta, open(meta_path, "w"), indent=1)
    return f"{pid} {spent}"


def safe(pid):
    try:
        return portrait(pid)
    except Exception as e:
        return f"FAIL {pid} {str(e)[:300]}"


def all_ids():
    npcs = json.load(open(os.path.join(pl.ROOT, "data", "npcs.json")))
    npcs = npcs if isinstance(npcs, list) else npcs["npcs"]
    return [n["id"] for n in npcs] + ["agatha", "hero_male", "hero_female"] + ["daughter_" + d for d in DAUGHTERS]


if __name__ == "__main__":
    ids = sys.argv[1:] or all_ids()
    start = pl.generations_left()
    with cf.ThreadPoolExecutor(6) as ex:
        for r in ex.map(safe, ids):
            print(time.strftime("%H:%M:%S"), r, flush=True)
    print("spent", start - pl.generations_left(), "left", pl.generations_left(), flush=True)
