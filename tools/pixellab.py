#!/usr/bin/env python3
"""A small PixelLab API v2 client for the game's art (docs/art/ART_ASSETS.md). The proxy adds the credentials.
Raw results go to assets_src/pixellab/<group>/<id>/ with meta.json (prompt, method, ids, generations spent)."""
import base64
import io
import json
import os
import sys
import time
import urllib.request

API = "https://api.pixellab.ai/v2"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_src", "pixellab")
# Palette «Солёный свет», spec 31.2.
PALETTE = ["0b0e14", "121a26", "1b2b3c", "24405a", "2f5a76", "3f7f8f", "6fb0b3", "cfe6e2", "9fb1b8", "b9a9c9", "dfe7ea",
           "f4f7f6", "2a2a30", "45464e", "6c6e76", "9a9ca3", "c9c8c2", "2b1f1a", "4a3428", "6b4a33", "8c6a4e", "b08f6c",
           "d8c49a", "eadcb8", "1f2e22", "2f4a30", "4e6e3a", "7a964c", "a9b36a", "3d2742", "6b3f6e", "a06a9e", "9b2f2a",
           "e07b2a", "e9a64a", "5a1e1e", "c2412d", "f08a2b", "ffc85a", "ffe9a8", "fff8e1", "6b4531", "b07a55", "e7b995",
           "8a8f96", "ddd3bf", "c9a24a", "b5653a"]


def request(method, path, body=None, raw=False):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method, headers={"Content-Type": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                content = r.read()
                return content if raw else json.loads(content)
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code >= 500 and attempt < 3:
                time.sleep(2 ** attempt * 2)
                continue
            raise RuntimeError(f"{method} {path}: {e.code} {msg[:500]}")
        except urllib.error.URLError:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt * 2)


def generations_left():
    return float(request("GET", "/balance")["subscription"]["generations"])


def palette_image():
    """The 48 colours as an 8×6 PNG, for color_image/force_colors."""
    from PIL import Image
    img = Image.new("RGB", (8, 6))
    for i, h in enumerate(PALETTE):
        img.putpixel((i % 8, i // 8), tuple(int(h[k:k + 2], 16) for k in (0, 2, 4)))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def wait_job(job_id, timeout=900):
    t0 = time.time()
    while time.time() - t0 < timeout:
        job = request("GET", f"/background-jobs/{job_id}")
        if job["status"] in ("completed", "failed"):
            return job
        time.sleep(8)
    raise TimeoutError(job_id)


def save_meta(folder, meta):
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


def download_character(character_id, folder):
    os.makedirs(folder, exist_ok=True)
    data = request("GET", f"/characters/{character_id}/zip", raw=True)
    with open(os.path.join(folder, "character.zip"), "wb") as f:
        f.write(data)
    import zipfile
    zipfile.ZipFile(io.BytesIO(data)).extractall(folder)
    return request("GET", f"/characters/{character_id}")


def create_character(group, aid, description, width, height, extra=None):
    folder = os.path.join(RAW, group, aid)
    before = generations_left()
    body = {"description": description, "image_size": {"width": width, "height": height}, "view": "low top-down",
            "outline": "single color black outline", "shading": "basic shading", "detail": "medium detail",
            "color_image": palette_image()}
    body.update(extra or {})
    res = request("POST", "/create-character-with-4-directions", body)
    job = wait_job(res["background_job_id"])
    if job["status"] != "completed":
        raise RuntimeError(json.dumps(job)[:800])
    detail = download_character(res["character_id"], folder)
    meta = {"id": aid, "method": "create-character-with-4-directions", "prompt": description, "size": [width, height],
            "character_id": res["character_id"], "generations": before - generations_left(), "date": time.strftime("%Y-%m-%d")}
    save_meta(folder, meta)
    return meta, detail


def animate_character(group, aid, character_id, template, directions=("south", "east", "north", "west")):
    folder = os.path.join(RAW, group, aid)
    before = generations_left()
    res = request("POST", "/characters/animations", {"character_id": character_id, "template_animation_id": template,
                                                    "directions": list(directions)})
    for job_id in res["background_job_ids"]:
        job = wait_job(job_id)
        if job["status"] != "completed":
            raise RuntimeError(json.dumps(job)[:800])
    detail = download_character(character_id, folder)
    meta_path = os.path.join(folder, "meta.json")
    meta = json.load(open(meta_path, encoding="utf-8")) if os.path.exists(meta_path) else {"id": aid}
    meta.setdefault("animations", {})[template] = {"generations": before - generations_left(), "group": res.get("animation_group_id")}
    save_meta(folder, meta)
    return meta, detail


if __name__ == "__main__":
    print(generations_left())
