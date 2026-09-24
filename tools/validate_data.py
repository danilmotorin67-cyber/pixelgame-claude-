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
    "bottles", "pages", "tales", "shops", "buildings", "balance", "forage",
    "interiors", "places",
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
    for crop in rows(tables.get("crops", [])):
        for key in ("seed", "produce"):
            if crop.get(key) not in item_ids:
                errs.append(f"crop {crop.get('id')} unknown {key} {crop.get(key)}")
        if sum(crop.get("stage_days", [])) <= 0:
            errs.append(f"crop {crop.get('id')} has no growth days")
    for shop in rows(tables.get("shops", [])):
        for entry in shop.get("stock", []):
            if "service" in entry and entry["service"] not in ("open_chest", "rumor", "boat_blessing"):
                errs.append(f"shop {shop.get('id')} offers unknown service {entry['service']}")
            if "upgrade" not in entry and "service" not in entry and entry.get("item") not in item_ids:
                errs.append(f"shop {shop.get('id')} sells unknown item {entry.get('item')}")
    tag_ids = set()
    for r in rows(tables.get("items", [])):
        tag_ids.update(r.get("tags", []))
    station_ids = {r["id"] for r in rows(tables.get("stations", []))}
    for table in ("recipes_craft", "recipes_cook"):
        for recipe in rows(tables.get(table, [])):
            if recipe.get("station") not in station_ids:
                errs.append(f"{recipe.get('id')} unknown station {recipe.get('station')}")
            for need, _count in recipe.get("in", []):
                known = need[4:] in tag_ids if need.startswith("tag:") else need in item_ids
                if not known:
                    errs.append(f"{recipe.get('id')} unknown ingredient {need}")
            if recipe.get("out", [None])[0] not in item_ids:
                errs.append(f"{recipe.get('id')} unknown product")
    loot = tables.get("loot_tables", {})
    for name, table in (loot.items() if isinstance(loot, dict) else []):
        for item, _lo, _hi, _weight in table.get("table", []):
            if item not in item_ids:
                errs.append(f"loot {name} unknown item {item}")
    for ship in rows(tables.get("ships", [])):
        if "crate" in ship and ship["crate"] not in item_ids:
            errs.append(f"ship {ship['id']} unknown crate {ship['crate']}")
    for row in rows(tables.get("items", [])):
        if "open" in row and row["open"] not in loot:
            errs.append(f"item {row['id']} opens unknown loot {row['open']}")
    forage = tables.get("forage", {})
    for band in ("near", "far", "storm"):
        for item, _weight in forage.get(band, []):
            if item not in item_ids:
                errs.append(f"forage {band} unknown item {item}")
    for season, spots in forage.get("seasonal", {}).items():
        for item, where, _weight in spots:
            if item not in item_ids or where not in forage.get("zones", {}):
                errs.append(f"forage {season} bad spot {item}@{where}")
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
    errs.extend(check_people(tables, npc_ids))
    if errs:
        print("FAIL")
        for e in errs:
            print(" -", e)
        return 1
    print("OK tables", len(tables), "npcs", len(npc_ids), "items", len(item_ids))
    return 0


def check_people(tables, npc_ids) -> list:
    """Interiors, named places and schedules (33.3, 33.7) refer only to things that exist."""
    errs = []
    interiors = tables.get("interiors", {})
    places = tables.get("places", {})
    regions = tables.get("regions", {})
    maps = set(regions) | set(interiors) | {"cape", "sea"}
    for name, room in interiors.items():
        w, h = room.get("size", [0, 0])
        for spot, at in room.get("spots", {}).items():
            if not (0 < at[0] < w - 1 and 0 < at[1] < h - 1):
                errs.append(f"interior {name} spot {spot} outside")
        for exit_ in room.get("exits", []):
            if exit_.get("to") not in maps:
                errs.append(f"interior {name} leads nowhere")
    for region in regions.values():
        for lm in region.get("landmarks", []):
            if "interior" in lm and lm["interior"] not in interiors:
                errs.append(f"landmark {lm.get('title')} has unknown interior")
    for name in places:
        if name not in maps:
            errs.append(f"places for unknown map {name}")
    def spot_ok(map_id, spot):
        if isinstance(spot, list):
            return True
        if isinstance(spot, str) and (spot.startswith("door:") or spot.startswith("home:")):
            return True
        return spot in places.get(map_id, {}) or spot in interiors.get(map_id, {}).get("spots", {})
    for npc in rows(tables.get("npcs", [])):
        home = npc.get("home", {})
        if home.get("map") not in maps | {"away", "lh_1"}:
            errs.append(f"{npc['id']} home on unknown map")
    sched_dir = DATA / "schedules"
    for path in sorted(sched_dir.glob("*.json")) if sched_dir.exists() else []:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("npc") not in npc_ids:
            errs.append(f"schedule {path.name} for unknown npc")
        for entry in data.get("entries", []):
            for step in entry.get("path", []):
                t, map_id, spot = step[0], step[1], step[2]
                if len(t) != 5 or t[2] != ":":
                    errs.append(f"schedule {path.name} bad time {t}")
                if map_id in ("home", "away"):
                    continue
                if map_id not in maps or not spot_ok(map_id, spot):
                    errs.append(f"schedule {path.name} unknown place {map_id}:{spot}")
    errs.extend(check_scenes(tables, npc_ids, maps))
    return errs


SCENE_COMMANDS = {"fade_out", "fade_in", "place", "move", "face", "wait", "emote", "say", "choice", "label", "goto",
                  "camera_pan", "camera_follow", "shake", "sound", "music", "spawn", "despawn", "anim", "set_time",
                  "set_weather", "effects", "end", "branch"}
EFFECTS = {"friendship", "flag", "give", "item", "take", "money", "honor", "points", "xp", "start_quest", "step_quest",
           "mail", "unlock_recipe", "recipe", "set_weather_tomorrow", "play_music", "achievement", "stat", "mercy"}


def loc_keys():
    import csv
    with open(ROOT / "localization" / "strings.csv", encoding="utf-8") as f:
        return {row[0] for row in csv.reader(f) if row}


def check_scenes(tables, npc_ids, maps) -> list:
    """Scene scripts of 33.6: known commands, labels, speakers, text keys and effects."""
    errs = []
    keys = loc_keys()
    events_dir = DATA / "events"
    seen_ids = set()
    for path in sorted(events_dir.glob("*.json")) if events_dir.exists() else []:
        data = json.loads(path.read_text(encoding="utf-8"))
        scenes = data if isinstance(data, list) else data.get("events", [data])
        for scene in scenes:
            sid = scene.get("id", "?")
            if sid in seen_ids:
                errs.append(f"scene {sid} defined twice")
            seen_ids.add(sid)
            trig = scene.get("trigger", {})
            if trig.get("map") and trig["map"] not in maps:
                errs.append(f"scene {sid} on unknown map {trig['map']}")
            script = scene.get("script", [])
            labels = {c[1] for c in script if c and c[0] == "label"}
            if not script or script[-1][0] != "end":
                errs.append(f"scene {sid} must finish with end")
            for c in script:
                op = c[0]
                if op not in SCENE_COMMANDS:
                    errs.append(f"scene {sid} unknown command {op}")
                if op == "say":
                    if c[1] not in npc_ids and c[1] not in ("hero", "narrator"):
                        errs.append(f"scene {sid} unknown speaker {c[1]}")
                    if c[3] not in keys:
                        errs.append(f"scene {sid} missing text {c[3]}")
                if op == "branch" and c[2] not in labels:
                    errs.append(f"scene {sid} branch to missing label {c[2]}")
                if op == "goto" and c[1] not in labels:
                    errs.append(f"scene {sid} goto missing label {c[1]}")
                if op == "choice":
                    for option in c[1]:
                        if option[0] not in keys:
                            errs.append(f"scene {sid} missing choice text {option[0]}")
                        if len(option) > 2 and option[2] and option[2] not in labels:
                            errs.append(f"scene {sid} choice to missing label {option[2]}")
                        for eff in option[1]:
                            if eff[0] not in EFFECTS:
                                errs.append(f"scene {sid} unknown effect {eff[0]}")
                if op == "effects":
                    for eff in c[1]:
                        if eff[0] not in EFFECTS:
                            errs.append(f"scene {sid} unknown effect {eff[0]}")
                if op in ("place", "move", "face", "emote", "anim", "spawn", "despawn") and c[1] not in npc_ids and c[1] != "hero":
                    errs.append(f"scene {sid} unknown actor {c[1]}")
    return errs


if __name__ == "__main__":
    sys.exit(main())
