"""NPCs and animals from PixelLab, with their animations.

Four pipelines:
- human: the approved "variant 3" format (48x48 canvas, custom proportions), then the
  walking and breathing-idle templates in four directions and one signature action (v3, south);
- beast: a quadruped on a skeleton template (dog/horse/cat), then walking and eating templates;
- bird: create-character-v3 (the model draws the bird, then rotates it), then v3 actions from text;
- critter: a single-direction map object animated with animate-with-text-v3 (sea life, flying birds).
Each character keeps its raw PixelLab export in assets_src/pixellab/<group>/<id>/ and a meta.json
with the character id, the prompts and the generations spent."""
import sys, os, io, json, time, base64, glob
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image

R = pl.RAW
STYLE = "cute cozy farming-game style, big head, northern fishing island, muted cold palette with warm accents"
V3_PROPS = {"type": "custom", "head_size": 1.7, "legs_length": 0.6, "arms_length": 0.8, "shoulder_width": 1.2, "hip_width": 1.15}
DIRS = ["south", "east", "north", "west"]


def _meta(folder):
    path = os.path.join(folder, "meta.json")
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}


def _note(folder, key, info):
    meta = _meta(folder)
    meta.setdefault("animations", {})[key] = info
    pl.save_meta(folder, meta)


def _run_anim(folder, character_id, body, key):
    before = pl.generations_left()
    res = pl.request("POST", "/characters/animations", dict(body, character_id=character_id))
    for job_id in res["background_job_ids"]:
        job = pl.wait_job(job_id, timeout=1500)
        if job["status"] != "completed":
            raise RuntimeError(f"{key}: " + json.dumps(job)[:500])
    pl.download_character(character_id, folder)
    _note(folder, key, {"generations": before - pl.generations_left(), "group": res.get("animation_group_id"),
                        **{k: v for k, v in body.items() if k in ("template_animation_id", "action_description", "directions", "frame_count")}})


def has_anim(folder, key):
    return key in _meta(folder).get("animations", {})


def template(group, aid, template_id, directions=DIRS):
    folder = os.path.join(R, group, aid)
    if has_anim(folder, template_id):
        return
    _run_anim(folder, _meta(folder)["character_id"], {"template_animation_id": template_id, "directions": list(directions)}, template_id)


def action(group, aid, key, text, directions=("south",), frames=6):
    folder = os.path.join(R, group, aid)
    if has_anim(folder, key):
        return
    _run_anim(folder, _meta(folder)["character_id"], {"mode": "v3", "action_description": text, "animation_name": key,
                                                      "directions": list(directions), "frame_count": frames}, key)


def human(aid, desc, work=None, idle=True, group="characters"):
    folder = os.path.join(R, group, aid)
    if not _meta(folder).get("character_id"):
        pl.create_character(group, aid, f"{desc}, {STYLE}", 48, 48, {"proportions": V3_PROPS})
    template(group, aid, "walking")
    if idle:
        template(group, aid, "breathing-idle")
    if work:
        action(group, aid, "work", work)
    return aid


def _template_any(group, aid, names):
    """Quadruped skeletons have their own animation names; the first one the skeleton accepts is used."""
    for name in names:
        try:
            template(group, aid, name)
            return name
        except RuntimeError as e:
            if "Invalid template_animation_id" not in str(e):
                raise
    raise RuntimeError(f"{aid}: none of {names} fits the skeleton")


def beast(aid, desc, template_id, size, graze="lowering head and grazing grass", group="animals"):
    folder = os.path.join(R, group, aid)
    if not _meta(folder).get("character_id"):
        pl.create_character(group, aid, f"{desc}, {STYLE}", size, size, {"template_id": template_id})
    _template_any(group, aid, ["walk-6-frames", "walking", "walk"])
    _template_any(group, aid, ["idle", "breathing-idle", "idle-shaking-head"])
    if graze:
        action(group, aid, "graze", graze, ("south", "east"), 6)
    return aid


def bird(aid, desc, size, walk="waddling walk", idle="pecking at the ground", group="animals"):
    folder = os.path.join(R, group, aid)
    if not _meta(folder).get("character_id"):
        before = pl.generations_left()
        body = {"description": f"{desc}, {STYLE}", "image_size": {"width": size, "height": size}, "view": "low top-down",
                "template_id": "mannequin", "no_background": True}
        res = pl.request("POST", "/create-character-v3", body)
        job = pl.wait_job(res["background_job_id"], timeout=1500)
        if job["status"] != "completed":
            raise RuntimeError(json.dumps(job)[:500])
        cid = res.get("character_id") or job.get("last_response", {}).get("character_id")
        pl.download_character(cid, folder)
        pl.save_meta(folder, {"id": aid, "method": "create-character-v3", "prompt": body["description"], "size": [size, size],
                              "character_id": cid, "generations": before - pl.generations_left(), "date": time.strftime("%Y-%m-%d")})
    action(group, aid, "walk", walk, DIRS, 6)
    action(group, aid, "idle", idle, ("south",), 4)
    return aid


def _b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def critter(aid, desc, w, h, anims, view="high top-down", group="animals"):
    """anims: {name: (action text, frames)}; the object image is the first frame of each."""
    folder = os.path.join(R, group, aid)
    png = os.path.join(folder, aid + ".png")
    if not os.path.exists(png):
        pl.create_map_object(group, aid, f"{desc}, pixel art, muted cold palette", w, h, view)
    base = Image.open(png).convert("RGBA")
    for name, (text, frames) in anims.items():
        if has_anim(folder, name):
            continue
        before = pl.generations_left()
        res = pl.request("POST", "/animate-with-text-v3", {"first_frame": _b64(base), "action": text,
                                                          "frame_count": frames, "no_background": True})
        job = pl.wait_job(res["background_job_id"], timeout=1500)
        if job["status"] != "completed":
            raise RuntimeError(json.dumps(job)[:500])
        imgs = (job.get("last_response") or {}).get("images") or []
        out = os.path.join(folder, name)
        os.makedirs(out, exist_ok=True)
        for i, im in enumerate(imgs):
            raw = base64.b64decode(im["base64"])
            try:
                frame = Image.open(io.BytesIO(raw)).convert("RGBA")
            except Exception:
                frame = Image.frombytes("RGBA", (int(im.get("width", w)), int(im.get("height", h))), raw)
            frame.save(os.path.join(out, f"frame_{i:03d}.png"))
        _note(folder, name, {"generations": before - pl.generations_left(), "action": text, "frames": len(imgs)})
    return aid


if __name__ == "__main__":
    print(pl.generations_left())
