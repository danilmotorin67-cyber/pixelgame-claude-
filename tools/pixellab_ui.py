"""Interface kit from PixelLab generate-ui-v2: one call returns a sheet of variants (16 at 64 px,
64 at <=42 px, about 20 generations); the variants we use are cut and named by tools/build_ui.py.
Raw results: assets_src/pixellab/ui/<name>_<n>.png."""
import sys, os, io, base64
import concurrent.futures as cf
sys.path.insert(0, "tools")
import pixellab as pl
from PIL import Image

OUT = os.path.join(pl.RAW, "ui")
KIT = {
 "panel": ("empty rectangular game UI panel frame, dark navy blue slate background, thin warm brass border, "
           "small brass rivets in the four corners, flat, no text", 64, "dark navy blue, brass gold, warm tan"),
 "book": ("open leather-bound journal book spread seen from above, two blank cream parchment pages, dark brown leather "
          "cover edge, brass corner caps, flat, no text", 64, "dark brown leather, cream paper, brass gold"),
 "slot": ("small square inventory slot button, dark navy blue inside, brass gold rim, empty, flat, no icon, no text",
          32, "dark navy blue, brass gold"),
}


def gen(name):
    desc, size, palette = KIT[name]
    if os.path.exists(os.path.join(OUT, f"{name}_0.png")):
        return f"{name} kept"
    r = pl.request("POST", "/generate-ui-v2", {"description": desc, "image_size": {"width": size, "height": size},
                                               "color_palette": palette, "no_background": True})
    job = pl.wait_job(r["background_job_id"])
    os.makedirs(OUT, exist_ok=True)
    for i, im in enumerate(job["last_response"]["images"]):
        raw = base64.b64decode(im["base64"])
        try:
            img = Image.open(io.BytesIO(raw))
        except Exception:
            img = Image.frombytes("RGBA", (im["width"], im["height"]), raw)
        img.save(os.path.join(OUT, f"{name}_{i}.png"))
    return f"{name} {len(job['last_response']['images'])}"


if __name__ == "__main__":
    start = pl.generations_left()
    names = sys.argv[1:] or list(KIT)
    with cf.ThreadPoolExecutor(3) as ex:
        for r in ex.map(gen, names):
            print(r, flush=True)
    print("spent", start - pl.generations_left())
