#!/usr/bin/env python3
"""Generates a group of docs/art/assets.csv with PixelLab (tools/pixellab.py), skipping what is done.
Sizes in the CSV are world units; art is drawn at 2x (960×540 rendering, docs/ART_DIRECTION.md).

Run: python3 tools/gen_batch.py tiles buildings [--workers 4] [--only id1,id2]
"""
import argparse
import base64
import concurrent.futures as cf
import csv
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab as pl  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 2
FRONT = ("straight front view facade facing the camera, orthographic, roof seen from slightly above, cozy farming game "
         "building like Stardew Valley, northern island, weathered stone and timber, muted cold palette with warm lamp light")
VILLAGE_SIZE = (160, 128)


def rows(groups, only):
    with open(os.path.join(ROOT, "docs", "art", "assets.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r["group"] in groups and (not only or r["id"] in only):
                yield r


def done(r):
    return os.path.exists(os.path.join(pl.RAW, r["group"], r["id"], "meta.json"))


def size_of(r):
    nums = [int(n) for n in re.findall(r"\d+", r["size"].split("(")[0].split("×")[0].replace("–", " "))]
    if len(nums) >= 2 and "x" in r["size"]:
        return min(nums[0] * SCALE, 400), min(nums[1] * SCALE, 400)
    return VILLAGE_SIZE


def run(r):
    if r["method"] == "create-tileset":
        m = re.match(r"top-down tileset: lower '(.+?)', upper '(.+?)',", r["prompt_en"])
        return pl.create_tileset(r["group"], r["id"], m.group(1), m.group(2), 32)
    if r["group"] == "tiles":
        folder = os.path.join(pl.RAW, r["group"], r["id"])
        before = pl.generations_left()
        desc = "seamless top-down ground texture tile, " + r["prompt_en"].split("—")[0].replace("seamless 16x16 ground tile:", "").strip() \
            + ", pixel art, farming game, muted cold palette"
        res = pl.request("POST", "/create-image-pixflux", {"description": desc, "image_size": {"width": 32, "height": 32},
                                                            "view": "high top-down", "outline": "lineless",
                                                            "color_image": pl.palette_image()})
        pl._save_b64(os.path.join(folder, r["id"] + ".png"), res["image"])
        meta = {"id": r["id"], "method": "create-image-pixflux", "prompt": desc, "size": [32, 32],
                "generations": before - pl.generations_left(), "date": time.strftime("%Y-%m-%d")}
        pl.save_meta(folder, meta)
        return meta
    w, h = size_of(r)
    desc = r["prompt_en"].split(", pixel art")[0]
    return pl.create_map_object(r["group"], r["id"], f"{desc}, {FRONT}", w, h, "high top-down")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("groups", nargs="+")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    todo = [r for r in rows(set(a.groups), only) if not done(r)]
    start = pl.generations_left()
    print(f"{len(todo)} to generate, {start} generations left", flush=True)
    failed = []
    with cf.ThreadPoolExecutor(a.workers) as ex:
        futures = {ex.submit(run, r): r for r in todo}
        for fut in cf.as_completed(futures):
            r = futures[fut]
            try:
                fut.result()
                print("ok", r["group"], r["id"], flush=True)
            except Exception as e:  # keep going; failures are listed at the end
                failed.append(r["id"])
                print("FAIL", r["id"], str(e)[:300], flush=True)
    print(f"spent {start - pl.generations_left()}, failed: {failed}", flush=True)


if __name__ == "__main__":
    main()
