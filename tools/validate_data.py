#!/usr/bin/env python3
from __future__ import annotations
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
REQUIRED = [
    "items", "crops", "trees", "fish", "shellfish", "animals",
    "recipes_craft", "recipes_cook", "stations", "tools", "weapons", "amulets", "clothes",
    "enemies", "bosses", "loot_tables", "deep_biomes", "grotto", "sea_map", "ships",
    "npcs", "gifts", "quests", "bodies", "registry", "ghosts", "the_twenty", "evidence",
    "weather", "tides", "festivals", "bundles", "neptune", "regions",
    "skills", "knowledge_tree", "achievements", "collections",
    "bottles", "pages", "tales", "shops", "buildings", "balance",
]


def load(name: str):
    p = DATA / f"{name}.json"
    if not p.exists():
        return None, f"missing {p}"
    try:
        return json.loads(p.read_text(encoding="utf-8")), None
    except json.JSONDecodeError as e:
        return None, f"json {p}: {e}"


def rows(obj):
    if isinstance(obj, list):
        return obj
    if isinstance(obj, dict):
        for k in ("items", "nodes", "list"):
            if k in obj and isinstance(obj[k], list):
                return obj[k]
    return []


def main() -> int:
    errs = []
    tables = {}
    for name in REQUIRED:
        obj, err = load(name)
        if err:
            errs.append(err)
            continue
        tables[name] = obj
        ids = []
        for row in rows(obj):
            if isinstance(row, dict) and "id" in row:
                ids.append(row["id"])
        if ids and len(ids) != len(set(ids)):
            errs.append(f"dup id in {name}")
    npc_ids = {r["id"] for r in rows(tables.get("npcs", [])) if isinstance(r, dict) and "id" in r}
    if "npc_fortuna" not in npc_ids:
        errs.append("npc_fortuna missing")
    if "npc_hedda" not in npc_ids:
        errs.append("npc_hedda missing")
    item_ids = {r["id"] for r in rows(tables.get("items", [])) if isinstance(r, dict) and "id" in r}
    for need in ("seed_turnip", "tool_hoe", "fish_cod"):
        if need not in item_ids:
            errs.append(f"item {need} missing")
    regions = tables.get("regions", {})
    if isinstance(regions, dict):
        sizes = {name: entry.get("size", []) for name, entry in regions.items()}
        sizes["cape"] = [90, 70]
        required_regions = {"village", "moor", "birch", "seal_shore",
                            "wreck_bay", "bird_cliffs", "lagoon"}
        if set(regions) != required_regions:
            errs.append("island regions missing or unexpected")
        for name, entry in regions.items():
            dims = sizes[name]
            if len(dims) != 2 or min(dims) < 20:
                errs.append(f"region {name} invalid size")
                continue
            for edge in entry.get("exits", []):
                target = edge.get("to", "")
                if target not in sizes:
                    errs.append(f"region {name} unknown exit {target}")
                    continue
                at, spawn = edge.get("at", []), edge.get("spawn", [])
                target_size = sizes[target]
                if (len(at) != 2 or not all(2 <= v < size - 2
                                             for v, size in zip(at, dims))):
                    errs.append(f"region {name} invalid exit position")
                if (len(spawn) != 2 or not all(2 <= v < size - 2
                                                for v, size in zip(spawn, target_size))):
                    errs.append(f"region {name} invalid spawn in {target}")
                if target != "cape" and not any(
                    other.get("to") == name for other in regions[target].get("exits", [])
                ):
                    errs.append(f"region {name} -> {target} has no return")
        reachable = {"cape"}
        pending = ["village"]  # The cape's signed west road.
        while pending:
            node = pending.pop()
            if node in reachable or node not in regions:
                continue
            reachable.add(node)
            pending.extend(edge.get("to", "") for edge in regions[node].get("exits", []))
        if reachable != set(sizes):
            errs.append(f"disconnected island regions: {sorted(set(sizes) - reachable)}")
    else:
        errs.append("regions data must be an object")
    if errs:
        print("FAIL")
        for e in errs:
            print(" -", e)
        return 1
    print("OK tables", len(tables), "npcs", len(npc_ids), "items", len(item_ids))
    return 0


if __name__ == "__main__":
    sys.exit(main())
