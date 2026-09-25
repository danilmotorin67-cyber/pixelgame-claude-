"""Pass 3c: buildings that kept coming out at an angle are redrawn from a front-on sibling used as the init image
(coop_3 from coop_2, the small greenhouse from the big one, the burnt cannery from the cannery)."""
import sys, os, io, base64, shutil
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
from pixellab_pass2 import FRONT
from PIL import Image

R = pl.RAW
JOBS = {
 "coop_3": ("coop_2", "large wooden hen house with small fenced run", 128, 96),
 "greenhouse_small": ("greenhouse", "small glass greenhouse, glass panes in a timber frame, plants inside, one door", 192, 192),
 "cannery_ruin": ("cannery", "RUINED burnt-out brick factory after a fire, roof collapsed and missing, walls broken and jagged, windows empty black holes, soot and rubble, no smoke", 256, 192),
}


def init_from(ref, w, h):
    src = Image.open(os.path.join(R, "buildings", ref, ref + ".png")).convert("RGBA")
    src = src.crop(src.getbbox())
    k = min(w / src.width, h / src.height)
    src = src.resize((max(1, int(src.width * k)), max(1, int(src.height * k))), Image.NEAREST)
    img = Image.new("RGBA", (w, h))
    img.paste(src, ((w - src.width) // 2, h - src.height))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}


def job(aid, strength=500):
    ref, desc, w, h = JOBS[aid]
    folder = os.path.join(R, "buildings", aid)
    if os.path.exists(folder):
        shutil.rmtree(folder)
    try:
        meta = pl.create_map_object("buildings", aid, f"{desc}, {FRONT}", w, h, "side",
                                    {"init_image": init_from(ref, w, h), "init_image_strength": strength})
    except Exception as e:
        return f"FAIL {aid} {str(e)[:300]}"
    meta["init_from"] = ref
    pl.save_meta(folder, meta)
    return aid


if __name__ == "__main__":
    with cf.ThreadPoolExecutor(3) as ex:
        for r in ex.map(job, JOBS):
            print(r, flush=True)
