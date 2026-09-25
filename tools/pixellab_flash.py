"""Pro Flash helpers: instruction edits of finished art and small front-view creations (<= 256 px)."""
import sys, os, io, json, base64, time, urllib.request
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image


def _b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def _result(job, size):
    """The finished job gives an image_url, or raw RGBA bytes in last_response."""
    last = job.get("last_response") or {}
    if last.get("images"):
        return Image.open(io.BytesIO(base64.b64decode(last["images"][0]["base64"]))).convert("RGBA")
    url = job.get("image_url") or last.get("image_url")
    if url:
        with urllib.request.urlopen(url, timeout=120) as r:
            return Image.open(io.BytesIO(r.read())).convert("RGBA")
    img = (job.get("last_response") or {}).get("image")
    if img:
        raw = base64.b64decode(img["base64"])
        try:
            return Image.open(io.BytesIO(raw)).convert("RGBA")
        except Exception:
            return Image.frombytes("RGBA", size, raw)
    raise RuntimeError(json.dumps(job)[:600])


def edit(src_path, instruction, out_path, no_background=True):
    img = Image.open(src_path).convert("RGBA")
    res = pl.request("POST", "/edit-image-pro-flash", {"image": _b64(img), "method": "text", "description": instruction,
                                                        "no_background": no_background})
    job = pl.wait_job(res["background_job_id"])
    if job["status"] != "completed":
        raise RuntimeError(json.dumps(job)[:600])
    out = _result(job, img.size)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path)
    return job
