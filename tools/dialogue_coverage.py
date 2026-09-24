#!/usr/bin/env python3
"""Dialogue coverage report (spec 2.4, M6): counts every islander's lines by category against the minimum
volume and lists heart scenes by character. Writes docs/dialogue_coverage.md; exit code 1 on shortfalls
when run with --strict."""
from __future__ import annotations
import csv, json, re, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVENTS = ["wreck", "funeral", "hmar", "inspection", "wedding", "villains"]
MINIMUM = {
    "spring": 10, "summer": 10, "autumn": 10, "winter": 10,
    "weather": 8, "festival": 6, "gift": 10, "birthday": 4,
    "act1": 6, "act2": 6, "act3": 6, "act4": 6,
    "married_other": 5,
    **{f"event.{e}": 5 for e in EVENTS},
}
# Heart scenes of section 4 (hearts per character) plus the best-friend evening at 10 hearts (22.4).
HEART_SCENES = {
    "sigrid": [2, 4, 6, 8, 10, 14], "liv": [2, 4, 6, 8, 10, 14], "hedda": [2, 4, 6, 8, 10, 14],
    "ingrid": [2, 4, 6, 8, 10, 14], "einar": [2, 4, 6, 8, 10, 14], "knud": [2, 4, 6, 8, 10, 14],
    "magnus": [2, 4, 6, 8, 10, 14], "olaf": [2, 4, 6, 8, 10, 14], "tuve": [2, 4, 6, 8, 10, 14],
    "halvdan": [2, 4, 6], "tora": [2, 4, 6, 8, 10], "ilm": [2, 4, 6, 8, 10], "karl": [2, 4, 6, 8, 10],
    "solveig": [2, 4, 6, 8, 10], "bjorn": [2, 4, 6, 8, 10], "margit": [2, 4, 6, 8, 10],
    "benedict": [2, 4, 6, 8, 10], "helga": [2, 4, 6, 8, 10], "erland": [2, 4, 6, 8, 10],
    "rud": [2, 4], "kai": [2, 4, 6, 8, 10], "nils": [10], "freya": [10],
}


def category(key: str, short: str) -> str:
    rest = key[len(f"npc.{short}."):]
    head = rest.split(".")[0]
    if head in ("weather", "festival", "gift", "event"):
        return head if head != "event" else "event." + rest.split(".")[1]
    if head == "birthday_gift":
        return "birthday"
    return head


def main() -> int:
    strict = "--strict" in sys.argv
    npcs = json.loads((ROOT / "data/npcs.json").read_text(encoding="utf-8"))
    rows = list(csv.reader((ROOT / "localization/strings.csv").read_text(encoding="utf-8").splitlines()))
    keys = {r[0]: r for r in rows[1:] if r}
    scenes = defaultdict(list)
    scene_lines = 0
    for path in sorted((ROOT / "data/events").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for e in (data if isinstance(data, list) else data.get("events", [data])):
            short = str(e.get("npc", "")).replace("npc_", "")
            scenes[short].append(int(e.get("hearts", 0)))
            scene_lines += sum(1 for c in e.get("script", []) if c[0] == "say")
    residents = [n for n in npcs if n["id"] != "npc_fortuna"]
    out = ["# Покрытие реплик (раздел 2.4)", "",
           "Отчёт создаётся `python3 tools/dialogue_coverage.py`. Минимум на жителя: 40 обычных (по 10 на сезон), "
           "8 погодных, 6 праздничных, 10 реакций на подарки, 4 на день рождения, 6 сюжетных на акт, "
           "5 после чужой свадьбы героя, по 5 на крупные события острова (крушение, похороны, Ночь Хмари, "
           "инспекция, свадьба героя, развязка злодеев), все сцены сердечек.", "",
           "| Житель | " + " | ".join(MINIMUM) + " | Сцены | Итого | Недостача |",
           "|---" * (len(MINIMUM) + 4) + "|"]
    total_lines = 0
    short_total = 0
    long_lines = 0
    for npc in residents:
        short = npc["id"].replace("npc_", "")
        counts = defaultdict(int)
        for key, row in keys.items():
            if key.startswith(f"npc.{short}.") and key != f"npc.{short}.name":
                counts[category(key, short)] += 1
                if len(row[1]) > 120:
                    long_lines += 1
        have = sum(counts.values())
        total_lines += have
        missing = sum(max(0, need - counts[cat]) for cat, need in MINIMUM.items())
        wanted = HEART_SCENES.get(short, [])
        missing_scenes = [h for h in wanted if h not in scenes.get(short, [])]
        missing += len(missing_scenes)
        short_total += missing
        cells = [f"{counts[c]}" if counts[c] >= need else f"**{counts[c]}**" for c, need in MINIMUM.items()]
        scene_cell = f"{len(scenes.get(short, []))}/{len(wanted)}" if wanted else str(len(scenes.get(short, [])))
        name = keys.get(npc["name"], [npc["name"], npc["name"]])[1]
        out.append(f"| {name} | " + " | ".join(cells) + f" | {scene_cell} | {have} | {missing or '—'} |")
    out += ["", f"Всего реплик жителей: **{total_lines}**; строк в сценах: **{scene_lines}**; "
            f"сцен: **{sum(len(v) for v in scenes.values())}**; реплик длиннее 120 знаков (листаются окнами): {long_lines}.",
            "", f"Недостача по минимуму 2.4: **{short_total}**." if short_total else "Минимум 2.4 выполнен для всех жителей."]
    (ROOT / "docs/dialogue_coverage.md").write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"lines {total_lines}, scene lines {scene_lines}, shortfall {short_total}")
    return 1 if strict and short_total else 0


if __name__ == "__main__":
    sys.exit(main())
