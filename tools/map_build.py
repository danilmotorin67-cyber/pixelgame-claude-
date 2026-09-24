#!/usr/bin/env python3
"""Parse ASCII maps into JSON tile dumps consumed by MapLoader."""
from __future__ import annotations
import json, sys
from pathlib import Path


def parse_map(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    meta: dict = {}
    layers: dict[str, list[str]] = {}
    current = None
    objects: list[dict] = []
    for ln in lines:
        if ln.startswith("#"):
            continue
        if ln.startswith("size:"):
            a, b = ln.split(":", 1)[1].strip().lower().split("x")
            meta["w"], meta["h"] = int(a), int(b)
        elif ln.startswith("tileset:"):
            meta["tileset"] = ln.split(":", 1)[1].strip()
        elif ln.startswith("[") and ln.endswith("]"):
            current = ln.strip("[]")
            if current != "objects":
                layers[current] = []
        elif current == "objects" and ln.strip():
            objects.append({"raw": ln.strip()})
        elif current and ln:
            layers[current].append(ln)
    return {"meta": meta, "layers": layers, "objects": objects}


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "assets_src/maps")
    dst = Path(sys.argv[2] if len(sys.argv) > 2 else "assets/maps")
    dst.mkdir(parents=True, exist_ok=True)
    for p in sorted(src.glob("*.map.txt")):
        data = parse_map(p)
        out = dst / (p.name.replace(".map.txt", ".json"))
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2))
        print("map", p.name, "->", out)


if __name__ == "__main__":
    main()
