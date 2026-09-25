#!/usr/bin/env python3
"""The art to generate with PixelLab: every sprite, tile, icon, portrait and illustration of the game, and every
animation, built from the game's data so nothing is forgotten. Writes docs/art/assets.csv, docs/art/animations.csv
and the summary with the cost estimate in docs/art/ART_ASSETS.md.

Run: python3 tools/art_manifest.py
"""
import csv
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "art")

# The user's rates for PixelLab: about 5 tokens an image, 20 an animation (one direction of it).
RATE_ART = 5
RATE_ANIM = 20
# From the PixelLab API docs: a 1-direction object call costs 20-40 generations and returns up to 64 candidates
# at <=42 px, 16 at <=85 px, 4 at <=170 px; a template (skeleton) animation costs 1 generation per direction.
BATCH_COST = 30

STYLE = ("pixel art, 3/4 top-down view, cozy northern island, muted cold palette (slate sea, basalt, moss, "
         "lilac heather) with warm amber lamp light, light from top-left, 1px dark selective outline")


def load(name):
    with open(os.path.join(ROOT, "data", name + ".json"), encoding="utf-8") as f:
        return json.load(f)


STRINGS = {}
with open(os.path.join(ROOT, "localization", "strings.csv"), encoding="utf-8") as f:
    for row in csv.reader(f):
        if len(row) >= 3:
            STRINGS[row[0]] = (row[1], row[2])


def ru(key):
    return STRINGS.get(key, (key, key))[0]


def en(key):
    return STRINGS.get(key, (key, key))[1]


assets = []
anims = []


def add(group, aid, title, size, images, method, prompt, priority, note="", dirs=1):
    assets.append({"group": group, "id": aid, "title_ru": title, "size": size, "directions": dirs, "images": images,
                   "method": method, "priority": priority, "prompt_en": prompt, "note": note})


def anim(group, target, action, dirs, frames, method, prompt, priority, note=""):
    anims.append({"group": group, "target": target, "animation": action, "directions": dirs, "frames": frames,
                  "method": method, "priority": priority, "prompt_en": prompt, "note": note})


# ---------------------------------------------------------------- 1. tilesets (Wang, 16x16)
SEASONS = ["spring", "summer", "autumn", "winter"]
SEASONAL_PAIRS = [
    ("grass_path", "Трава ↔ тропа", "short northern grass with moss", "packed dirt footpath"),
    ("grass_sand", "Трава ↔ сухой песок", "short northern grass", "pale dry beach sand with shells"),
    ("grass_cliff", "Трава ↔ базальтовый обрыв", "short northern grass", "dark basalt cliff rock"),
    ("grass_heather", "Трава ↔ вереск", "short grass", "lilac heather moorland"),
    ("grass_bog", "Трава ↔ торфяное болото", "short grass", "dark wet peat bog with pools"),
    ("grass_cobble", "Трава ↔ булыжник деревни", "short grass", "grey cobblestone street"),
    ("grass_forest", "Трава ↔ лесная подстилка", "short grass", "birch forest floor with leaves"),
    ("grass_soil", "Трава ↔ поле (земля)", "short grass", "bare farm soil"),
    ("grass_graveyard", "Трава ↔ земля погоста", "short grass", "trodden graveyard earth with gravel"),
]
for key, title, low, up in SEASONAL_PAIRS:
    for season in SEASONS:
        cover = " covered with snow" if season == "winter" else (" in autumn colours" if season == "autumn" else "")
        add("tiles", f"tiles_{key}_{season}", f"{title} ({season})", "16x16 ×16 (Wang)", 1, "create-tileset",
            f"top-down tileset: lower '{low}{cover}', upper '{up}{cover}', {STYLE}",
            "P1" if key in ("grass_path", "grass_sand", "grass_soil") and season == "spring" else "P2",
            "1 вызов = 16 тайлов перехода")
STATIC_PAIRS = [
    ("sand_wet", "Сухой ↔ мокрый песок (приливная полоса)", "dry pale sand", "dark wet sand with foam lines", "P1"),
    ("wet_shallow", "Мокрый песок ↔ мелкая вода", "wet sand", "shallow turquoise sea water", "P1"),
    ("shallow_deep", "Мелкая ↔ глубокая вода", "shallow turquoise water", "deep slate-blue sea", "P1"),
    ("rock_water", "Скалы ↔ вода", "dark basalt shore rocks", "sea water with foam", "P2"),
    ("lagoon_ice", "Лагуна ↔ лёд", "calm lagoon water", "frozen lagoon ice with snow", "P3"),
    ("reeds_water", "Тростник ↔ вода", "reed bed", "still pond water", "P3"),
    ("sea_chart_reef", "Открытое море ↔ рифы", "open sea", "reef rocks and breakers", "P3"),
    ("sea_ice_field", "Море ↔ ледяное поле", "cold open sea", "broken ice field", "P3"),
    ("floor_wood", "Интерьер: дощатый пол ↔ стена", "wooden plank floor", "timber wall with beams", "P2"),
    ("floor_stone", "Интерьер: каменный пол ↔ стена", "stone flag floor", "whitewashed stone wall", "P2"),
    ("floor_plaster", "Интерьер: пол ↔ оштукатуренная стена", "painted floorboards", "plaster wall", "P3"),
    ("floor_hut", "Интерьер хижины: земляной пол ↔ стена", "earthen floor with rugs", "turf and log wall", "P3"),
    ("lighthouse_round", "Этажи маяка: пол ↔ круглая стена", "worn stone floor", "curved lighthouse wall", "P1"),
    ("deep_kelp", "Глубь 1–20: дно ↔ стена (кельповый лес)", "sandy seabed with kelp roots", "rock wall overgrown with kelp", "P3"),
    ("deep_solvik", "Глубь 21–40: дно ↔ стена (Старый Сольвик)", "sunken cobble street", "drowned stone house walls", "P3"),
    ("deep_bone", "Глубь 41–60: дно ↔ стена (Костяная Бездна)", "dark abyss silt", "walls of giant whale bones", "P3"),
    ("grotto_floor", "Гроты: пол ↔ стена", "wet cave floor", "tidal cave rock wall", "P3"),
    ("grotto_water", "Гроты: пол ↔ приливная вода", "wet cave floor", "rising tidal water", "P3"),
    ("rann_halls", "Чертоги Ранн", "mother-of-pearl floor", "coral and pearl walls", "P3"),
    ("pier_planks", "Причал: доски ↔ вода", "wooden pier planks", "sea water between piles", "P2"),
]
for key, title, low, up, prio in STATIC_PAIRS:
    add("tiles", f"tiles_{key}", title, "16x16 ×16 (Wang)", 1, "create-tileset",
        f"top-down tileset: lower '{low}', upper '{up}', {STYLE}", prio, "1 вызов = 16 тайлов перехода")
SINGLE_TILES = [
    ("soil_tilled", "Вскопанная земля"), ("soil_watered", "Политая земля"), ("soil_salt1", "Земля, Соль 1 (корка)"),
    ("soil_salt2", "Земля, Соль 2 (белая корка)"), ("soil_watered_salt", "Политая солёная земля"),
    ("greenhouse_floor", "Пол теплицы"), ("peat_cut", "Срезанный торф"), ("sand_dug", "Вскопанный песок"),
    ("stone_path", "Каменная дорожка"), ("snow_trampled", "Утоптанный снег"),
]
for key, title in SINGLE_TILES:
    add("tiles", f"tile_{key}", title, "16x16", 1, "create-1-direction-object (пакет)",
        f"seamless 16x16 ground tile: {title} — {STYLE}", "P1" if key.startswith("soil") else "P2", "пакетом ≤64 за вызов")

# ---------------------------------------------------------------- 2. buildings (map objects)
BUILDINGS = [
    ("lighthouse", "Маяк «Вороний Глаз» — запущенный", "48x144", "tall white-and-red stone lighthouse, peeling paint, cracked lantern glass", "P1"),
    ("lighthouse_repaired", "Маяк — отремонтированный", "48x144", "restored white-and-red lighthouse with brass lantern room", "P1"),
    ("lighthouse_lit", "Маяк — фонарная горит (ночь)", "48x144", "lighthouse at night, lantern room glowing amber", "P1"),
    ("house_1", "Дом смотрителя, ур. 0–1", "96x80", "small stone keeper's cottage with turf roof and chimney", "P1"),
    ("house_2", "Дом смотрителя, ур. 2 (спальня, детская)", "112x88", "enlarged keeper's cottage with a new wing", "P2"),
    ("house_3", "Дом смотрителя, ур. 3 (погреб)", "112x96", "keeper's house with cellar door and porch", "P3"),
    ("morgue", "Покойницкая", "64x56", "small grim stone mortuary shed with heavy door", "P2"),
    ("ice_house", "Ледник", "48x40", "half-buried ice house with turf roof", "P3"),
    ("boathouse_1", "Лодочный сарай ур. 1", "64x48", "wooden boathouse on the shore", "P2"),
    ("boathouse_2", "Лодочный сарай ур. 2", "80x56", "larger boathouse with slipway", "P3"),
    ("boathouse_3", "Лодочный сарай ур. 3", "96x64", "big boathouse for a sailing bot", "P3"),
    ("coop_1", "Курятник ур. 1", "48x40", "small wooden hen house", "P2"), ("coop_2", "Курятник ур. 2", "56x44", "bigger hen house", "P3"),
    ("coop_3", "Курятник ур. 3", "64x48", "large hen house with run", "P3"),
    ("barn_1", "Хлев ур. 1", "64x48", "red wooden barn", "P2"), ("barn_2", "Хлев ур. 2", "72x52", "bigger barn", "P3"),
    ("barn_3", "Хлев ур. 3", "80x56", "large barn with hayloft door", "P3"),
    ("stable", "Конюшня", "48x40", "small pony stable", "P3"), ("hayloft_1", "Сенник", "48x44", "hay barn", "P3"),
    ("hayloft_2", "Сенник ур. 2", "56x48", "bigger hay barn", "P3"),
    ("workshop", "Мастерская", "64x48", "stone workshop with wide doors", "P2"), ("well", "Колодец", "24x24", "stone well with bucket", "P2"),
    ("chapel_small", "Малая часовня на погосте", "48x56", "tiny white chapel with bell", "P3"),
    ("hearse", "Дроги", "32x16", "black funeral cart", "P3"),
    ("greenhouse_small", "Малая теплица", "96x96", "small glass greenhouse, top-down", "P3"),
    ("greenhouse", "Теплица", "160x192", "large glass greenhouse, top-down", "P3"),
    ("guild_ruin", "Гильдейский дом — руина", "128x96", "ruined guild hall of fog folk, broken roof", "P3"),
    ("guild_room_x6", "Гильдейский дом — 6 восстановленных комнат (слои)", "128x96", "guild hall with one restored wing", "P3"),
    ("guild_restored", "Гильдейский дом — восстановлен", "128x96", "restored guild hall with lanterns", "P3"),
    ("mill_ruin", "Мельница — руина", "48x80", "broken windmill", "P3"), ("mill", "Мельница", "48x80", "working windmill", "P3"),
    ("dead_fire", "Мёртвый Огонь (руина маяка в море)", "48x112", "ruined dark lighthouse on a sea rock", "P3"),
    ("kai_hut", "Хижина Кая", "48x40", "hermit hut of driftwood", "P3"),
    ("cannery", "Консервный завод «Нептуна»", "128x96", "grim modern cannery with chimney", "P3"),
    ("cannery_ruin", "Консервный завод — разрушен", "128x96", "burnt-out cannery", "P3"),
    ("helga_hut", "Хижина Хельги", "56x48", "old herbalist's turf hut", "P2"),
    ("erland_boat_house", "Перевёрнутая лодка Эрланда", "56x40", "upturned boat used as a house", "P2"),
    ("steamer_gull", "Пароход «Чайка» у причала", "96x48", "small mail steamer at the pier", "P2"),
    ("pier_village", "Пирс гавани", "96x48", "wooden harbour pier", "P2"),
    ("pier_cape", "Причал мыса", "32x48", "small wooden landing", "P1"),
    ("rann_stone", "Камень Ранн (расколотый)", "32x32", "split standing stone in the surf", "P2"),
    ("rann_stone_whole", "Камень Ранн (целый)", "32x32", "whole glowing standing stone", "P3"),
    ("nine_maidens", "Девять Дев (круг камней)", "144x144", "circle of nine standing stones on moor", "P3"),
]
VILLAGE = ["Лавка Бергов", "Кузня Торы", "Лоцманская управа", "Таверна «Сухой Утопленник»", "Часовня Святого Эльма",
           "Торговый дом Грима", "Дом доктора Фалька", "«Гробы и колыбели» Ильма", "Лодочная лавка Эрланда",
           "«Шерсть и кости» Маргит", "Дом Хедды", "Дом Гримов", "Дом Олафа", "Хижина Скау", "Дом Лив",
           "Дом Ингрид (школа)", "Дом Бенедикта", "Рыбацкий дом 1", "Рыбацкий дом 2", "Амбар гавани"]
for aid, title, size, desc, prio in BUILDINGS:
    add("buildings", aid, title, size, 1, "map-objects", f"{desc}, {STYLE}", prio)
for i, title in enumerate(VILLAGE):
    add("buildings", f"village_{i + 1:02d}", title, "64–96 px", 1, "map-objects",
        f"northern fishing village building: {title}, timber and stone, turf or slate roof, {STYLE}", "P2")

# ---------------------------------------------------------------- 3. nature and map props
PROPS = [
    ("rock", 4, "16x16", "loose stones"), ("boulder", 3, "32x32", "basalt boulders"), ("snag", 3, "16x16", "driftwood snags"),
    ("weeds", 3, "16x16", "tall weeds"), ("driftwood_log", 3, "32x16", "beached driftwood logs"),
    ("stump", 2, "16x16", "tree stumps"), ("reeds", 2, "16x32", "reed clumps"), ("heather_clump", 3, "16x16", "heather bushes"),
    ("wildflowers", 4, "16x16", "wild flowers (armeria, cottongrass)"), ("birch_tree", 4, "32x48", "birch tree in each season"),
    ("pine_tree", 2, "32x48", "wind-bent pine"), ("tide_pool", 3, "32x16", "rock tide pools"), ("clam_bubbles", 1, "16x16", "bubbles in wet sand"),
    ("seaweed_wrack", 2, "16x16", "washed-up seaweed"), ("bird_nest", 3, "16x16", "sea-bird nests on ledges"),
    ("bonfire", 2, "16x16", "bonfire unlit and lit"), ("street_lamp", 2, "16x32", "village lantern post"),
    ("signpost", 2, "16x32", "wooden signposts"), ("mailbox", 1, "16x16", "keeper's mailbox"),
    ("shipping_box", 2, "16x16", "shipping crate on the pier"), ("notice_board", 2, "16x32", "notice board with papers"),
    ("rain_butt", 1, "16x16", "rain water barrel"), ("tower_bell", 1, "16x16", "small bell on a post"),
    ("graveyard_bell", 1, "16x32", "graveyard bell frame"), ("bench", 2, "32x16", "wooden benches"),
    ("net_rack", 2, "32x32", "fishing nets drying"), ("beached_boat", 3, "32x16", "small beached boats"),
    ("barrels_crates", 4, "16x16", "barrels and crates"), ("fence_wood", 6, "16x16", "wooden fence pieces"),
    ("fence_stone", 6, "16x16", "dry stone wall pieces"), ("fence_iron", 6, "16x16", "wrought iron fence pieces"),
    ("gate", 3, "16x16", "fence gates"), ("raven_mark", 1, "16x16", "disturbed ground where ravens circle"),
    ("big_hull", 3, "48x24", "big wooden shipwreck hulls in the sand"), ("small_wreck", 3, "32x16", "small wreck pieces"),
    ("cave_entrance", 2, "32x32", "grotto entrance under a rock / cave mouth"), ("drowned_well", 1, "32x32", "whirlpool well in the sea"),
    ("rest_buoy", 1, "16x16", "marker buoy"), ("stone_cairn", 1, "16x16", "stone cairn"),
]
for aid, n, size, desc in PROPS:
    add("props", aid, desc, size, n, "create-1-direction-object (пакет)", f"{desc}, {STYLE}",
        "P1" if aid in ("rock", "snag", "weeds", "mailbox", "rain_butt", "tower_bell", "fence_wood", "shipping_box") else "P2",
        f"{n} вариантов пакетом")
GRAVES = [("mound", "Каменная насыпь"), ("wooden_cross", "Деревянный крест"), ("carved_cross", "Резной крест"),
          ("stone_slab", "Каменная плита"), ("headstone", "Надгробие с эпитафией"), ("beacon_stone", "Маячный камень")]
for aid, title in GRAVES:
    add("graveyard", f"grave_{aid}", title + " (новый и обветренный)", "16x32", 2, "create-1-direction-object (пакет)",
        f"grave marker: {title} — new and weathered, {STYLE}", "P2")
for aid, title in [("old_grave", "Старая разбитая могила"), ("old_grave_fixed", "Отремонтированная старая могила"),
                   ("open_pit", "Выкопанная яма"), ("filled_grave", "Засыпанная могила"), ("weeds_overlay", "Сорняки на могиле"),
                   ("sunk_overlay", "Просевшая могила"), ("cat_grave", "Кошачья могилка")]:
    add("graveyard", aid, title, "16x32", 1, "create-1-direction-object (пакет)", f"{title}, {STYLE}", "P2")
for aid, n, title in [("body_shore", 3, "Тело на берегу (3 позы)"), ("body_wrapped", 1, "Тело в парусине"),
                      ("body_table", 1, "Тело на секционном столе"), ("coffin_open", 3, "Гроб с телом (3 вида)"),
                      ("remains", 1, "Останки утопца")]:
    add("graveyard", aid, title, "16x32", n, "create-1-direction-object (пакет)", f"{title}, respectful, not gory, {STYLE}", "P2")

# ---------------------------------------------------------------- 4. crops and trees
for crop in load("crops"):
    name = en("item.%s.name" % crop["produce"]) if ("item.%s.name" % crop["produce"]) in STRINGS else crop["id"]
    stages = len(crop.get("stage_days", [])) + 1
    add("crops", crop["id"], f"{ru('item.%s.name' % crop['produce'])}: {stages} стадий (ростки → зрелая)", "16x16/16x32",
        stages, "create-1-direction-object (пакет)", f"{name} crop growth stages from sprout to ripe, one plant per frame, {STYLE}",
        "P1" if crop["id"] == "crop_turnip" else "P2")
add("crops", "giant_turnip", "Гигантская репа («Репка»)", "48x48", 1, "create-1-direction-object", f"giant turnip, {STYLE}", "P3")
add("crops", "crop_withered", "Погибший росток / съеденное чайками", "16x16", 2, "create-1-direction-object (пакет)", f"withered sprout, pecked crop, {STYLE}", "P2")
for tree in load("trees"):
    name = tree["id"].replace("tree_", "").replace("bush_", "").replace("bog_", "")
    is_tree = tree["id"].startswith("tree")
    n = 3 + (4 if is_tree else 2)
    add("trees", tree["id"], f"{name}: саженец, молодое, взрослое + сезоны/плоды", "32x48" if is_tree else "16x16",
        n, "create-1-direction-object (пакет)", f"{name} {'tree' if is_tree else 'bush'}: sapling, young, grown, fruiting, winter bare, {STYLE}", "P2")

# ---------------------------------------------------------------- 5. stations, decor and furniture
for st in load("stations"):
    if st["id"] in ("decor", "tree"):
        continue
    add("stations", st["id"], ru(st.get("name", st["id"])), "16–48 px", 1, "create-1-direction-object",
        f"{en(st.get('name', st['id']))} crafting station, idle state, {STYLE}", "P2" if st["id"] in ("workbench", "hearth", "compost_pit", "chest") else "P3")
items = load("items")
decor = [i for i in items if i.get("category") in ("decor", "furniture")]
for i in decor:
    add("decor", i["id"], ru(i["name"]), "16–48 px", 1, "create-1-direction-object (пакет)",
        f"{en(i['name'])} ({i['category']}), {STYLE}", "P3", "иконка инвентаря = уменьшенный спрайт (resize, без генерации)")
FURNITURE_KINDS = sorted({f["kind"] for v in load("interiors").values() for f in v.get("furniture", [])})
for kind in FURNITURE_KINDS:
    add("interiors", f"furn_{kind}", f"Мебель интерьеров: {kind}", "16–64 px", 1, "create-1-direction-object (пакет)",
        f"interior furniture: {kind}, {STYLE}", "P2")
for aid, title in [("lh_1", "Маяк 1: прихожая и кладовая"), ("lh_2", "Маяк 2: лестница и механизм"), ("lh_3", "Маяк 3: вахтенная"),
                   ("lh_4", "Маяк 4: фонарная и галерея"), ("house_inside", "Дом смотрителя изнутри"), ("cape_workshop", "Мастерская изнутри")]:
    add("interiors", aid, title + " (декор комнаты)", "480x270 слой", 1, "create-image-pixflux",
        f"{title}, cosy interior, top-down 3/4, {STYLE}", "P1" if aid.startswith("lh") else "P2", "фон-подложка; стены/пол — из тайлсетов")
for aid, n, title in [("lens", 5, "Линзы: старое зеркало → Френель 4 → Большое око"), ("lamp", 4, "Лампы: фитиль → Арганд → керосин → Светоч"),
                      ("mechanism", 3, "Механизм вращения: гири → пружина → автозавод"), ("signal", 3, "Сигнал: колокол → ревун → паровой ревун"),
                      ("fuel_barrel", 1, "Резервуар топлива")]:
    add("interiors", f"lh_{aid}", title, "32x32", n, "create-1-direction-object (пакет)", f"lighthouse equipment: {title}, {STYLE}", "P1")

# ---------------------------------------------------------------- 6. characters
NPC_LOOK = {
    "npc_fortuna": "wooden ship figurehead maiden with chipped nose and flaking gilt, hanging on a wall",
    "npc_sigrid": "woman 25, shop assistant, dark bob hair, black shawl, secretly writes gloomy poems",
    "npc_liv": "woman 26, naturalist, ginger braid, green field coat, binoculars, notebook",
    "npc_hedda": "woman 31, fishing boat captain, weathered, oilskin coat, knit cap",
    "npc_ingrid": "woman 27, teacher, neat blonde hair bun, grey dress, books",
    "npc_einar": "man 29, blacksmith, broad, leather apron, soot on face",
    "npc_knud": "man 28, carpenter, curly hair, sawdust apron",
    "npc_magnus": "man 38, doctor and coroner, ex-navy surgeon, trim beard, dark coat, medical bag",
    "npc_olaf": "man 24, postman and telegraphist, round glasses, postal cap, satchel",
    "npc_tuve": "young selkie person with sealskin cloak, dark wet hair, grey eyes",
    "npc_halvdan": "man 58, village elder and merchant, grey beard, fine wool coat, lantern",
    "npc_stern": "man 49, city insurance director, black suit, top hat, cane",
    "npc_tora": "woman 54, blacksmith, strong, bandaged hand, leather apron",
    "npc_ilm": "man 60, taciturn carpenter-builder, white beard, carpenter's pencil",
    "npc_karl": "man 55, gloomy shopkeeper, apron, ledger",
    "npc_solveig": "woman 52, cheerful baker and gossip, headscarf, pie",
    "npc_bjorn": "man 47, barrel-bellied tavern keeper, red beard, apron",
    "npc_margit": "woman 63, animal and wool shop owner, knitted shawl, walking stick",
    "npc_benedict": "man 45, priest of the chapel, black cassock, afraid of water",
    "npc_helga": "woman 97, tiny herbalist storyteller, many scarves, bundle of herbs",
    "npc_erland": "man 70, retired sea captain, captain's cap, pipe, peg-leg feel",
    "npc_kai": "man 51, half-mad hermit keeper, ragged coat, wild hair, lantern",
    "npc_nils": "boy 10, ghost-hunter club, cap, butterfly net",
    "npc_freya": "girl 10, ghost-hunter club, twin braids, lantern",
    "npc_palm": "man 50, pedantic inspector, uniform, clipboard",
    "npc_nut": "man 30, rough fisherman, stubble, knit cap",
    "npc_rud": "man 33, rough fisherman, beard, oilskins",
    "npc_sandro": "southern merchant, colourful clothes, earring, grin",
    "npc_grump": "grumpy steamer skipper, captain's cap, big moustache",
}
for aid, desc in [("hero_m", "young man, city clerk turned lighthouse keeper, navy jacket, scarf"),
                  ("hero_f", "young woman, city clerk turned lighthouse keeper, navy jacket, scarf")]:
    add("characters", aid, "Герой (" + ("м" if aid.endswith("m") else "ж") + "), 4 направления", "16x32", 4,
        "create-character-with-4-directions", f"{desc}, 16x32 character, {STYLE}", "P1", "база для всех анимаций героя", dirs=4)
add("characters", "hero_hats", "Шапки/головные уборы героя (20 × 4 направления)", "16x16", 80, "create-1-direction-object (пакет)",
    f"pixel hat overlays for a 16x32 character, 4 views, {STYLE}", "P4", "кастомизация, можно отложить")
add("characters", "hero_hair", "Причёски героя (10 × 4 направления)", "16x16", 40, "create-1-direction-object (пакет)",
    f"hair overlays for a 16x32 character, 4 views, {STYLE}", "P4", "кожа/одежда — палитровой подменой, без генерации")
for npc in load("npcs"):
    static = npc["id"] == "npc_fortuna"
    add("characters", npc["id"], ru(npc["name"]) + (" (носовая фигура, 1 вид)" if static else ", 4 направления"),
        "32x48" if static else "16x32", 1 if static else 4, "create-object" if static else "create-character-with-4-directions",
        f"{NPC_LOOK.get(npc['id'], ru(npc['name']))}, {STYLE}", "P2", dirs=1 if static else 4)
for aid, title, desc, dirs in [("agatha", "Агата (живая, один день; призрак)", "old woman lighthouse keeper, grey braid, oilskin, lantern", 4),
                               ("kid_toddler_boy", "Малыш (м)", "toddler boy", 4), ("kid_toddler_girl", "Малыш (ж)", "toddler girl", 4),
                               ("kid_child_boy", "Ребёнок (м)", "child boy 7", 4), ("kid_child_girl", "Ребёнок (ж)", "child girl 7", 4),
                               ("baby_cradle", "Младенец в колыбели", "baby in a wooden cradle", 1),
                               ("villager_1", "Житель-статист 1", "fisherman villager", 4), ("villager_2", "Жительница-статист 2", "fishwife villager", 4),
                               ("sailor_rescued", "Спасённый моряк", "shivering rescued sailor in blanket", 4)]:
    add("characters", aid, title, "16x32", dirs, "create-character-with-4-directions" if dirs == 4 else "create-object",
        f"{desc}, {STYLE}", "P2" if aid == "agatha" else "P3", dirs=dirs)
for g in load("ghosts"):
    add("spirits", g["id"], ru(g["name"]) + " (призрак)", "16x32", 1, "create-object",
        f"translucent pale-blue glowing ghost of {en(g['name'])}, {STYLE}", "P3")
for aid, title, size, desc in [("rann", "Ранн, Хозяйка Глуби", "128x128", "vast sea goddess silhouette of water and kelp"),
                               ("hmar_faces", "Хмарь: лица и огоньки в тумане (3)", "32x32", "faint faces and wisps in lilac fog"),
                               ("fogfolk", "Туманники (6)", "16x32", "hooded fog folk spirits")]:
    add("spirits", aid, title, size, 3 if aid == "hmar_faces" else (6 if aid == "fogfolk" else 1), "create-object", f"{desc}, {STYLE}", "P3")
for d in ["zyb", "pena", "burun", "stuzha", "tish", "svetla", "priliva", "hmar"]:
    add("spirits", f"daughter_{d}", f"Дочь Ранн: {d}", "64x64", 1, "create-object", f"sea daughter spirit '{d}', ethereal, {STYLE}", "P3")

# Portraits for the dialogue window: 30 × 6 emotions.
EMOTIONS = ["neutral", "happy", "sad", "angry", "surprised", "special"]
for npc in load("npcs"):
    add("portraits", "portrait_" + npc["id"], "Портрет: " + ru(npc["name"]) + " × 6 эмоций", "64x64", 6,
        "create-image-pixflux + edit-image (эмоции)", f"64x64 bust portrait, {NPC_LOOK.get(npc['id'], '')}, emotions: {', '.join(EMOTIONS)}",
        "P2", "эмоции — правкой одной базы (edit-image), чтобы лицо не «уплывало»")
add("portraits", "portrait_agatha", "Портрет: Агата × 6 эмоций", "64x64", 6, "create-image-pixflux + edit-image", "64x64 portrait of old keeper Agatha", "P2")
add("portraits", "portrait_hero", "Портрет героя (м/ж) × 3", "64x64", 6, "create-image-pixflux", "64x64 portrait of the keeper", "P3")
add("portraits", "portrait_daughters", "Портреты дочерей Ранн (8)", "64x64", 8, "create-image-pixflux", "sea daughter portraits", "P3")

# ---------------------------------------------------------------- 7. animals and creatures
for a in load("animals"):
    extra = 4 if a["id"] == "sheep" else 0
    add("animals", a["id"], ru(a["name"]) + (" (+стриженая)" if extra else "") + ", 4 направления", "16x16–32x32", 4 + extra,
        "create-character-with-4-directions", f"{en(a['name'])} farm animal, {STYLE}", "P2", dirs=4)
for aid, title, size, n in [("cat_wick", "Кот Фитиль, 4 направления", "16x16", 4), ("seal", "Тюлени (лежит, плывёт)", "32x16", 2),
                            ("gull", "Чайка (стоит, летит)", "16x16", 2), ("puffin", "Тупики", "16x16", 2), ("raven", "Вороны (сидит, летит)", "16x16", 2),
                            ("whale", "Кит (спина, хвост)", "96x48", 2), ("orca", "Косатки", "64x32", 1), ("herring_school", "Косяк сельди", "48x32", 1),
                            ("fish_shadow", "Тени рыб в воде (3 размера)", "16x16", 3), ("eider_wild", "Гаги в море", "16x16", 1)]:
    add("animals", aid, title, size, n, "create-1-direction-object (пакет)" if n <= 3 else "create-character-with-4-directions",
        f"{title}, {STYLE}", "P2" if aid in ("cat_wick", "gull") else "P3", dirs=4 if n == 4 else 1)
FOUR_DIR_ENEMIES = {"crab", "deep_crab", "helmet_crayfish", "seal_bully", "drowned", "drowned_citizen", "wet_dog", "saboteur",
                    "moray", "octopus", "bonefish", "gull_marauder"}
for e in load("enemies"):
    four = e["id"] in FOUR_DIR_ENEMIES
    add("enemies", e["id"], ru(e["name"]) + (", 4 направления" if four else ""), "16x16–32x32", 4 if four else 1,
        "create-character-with-4-directions" if four else "create-object", f"{en(e['name'])} enemy, {STYLE}", "P3", dirs=4 if four else 1)
for b in load("bosses"):
    add("enemies", b["id"], ru(b.get("name", b["id"])) + " (босс, 2 фазы)", "64x64–128x96", 2, "create-object",
        f"boss: {en(b.get('name', b['id']))}, {STYLE}", "P3")

# ---------------------------------------------------------------- 8. sea
for boat, title, states in [("yalik", "Ялик", 1), ("sloop", "Парусная шлюпка (парус поднят/спущен)", 2), ("bot", "Бот «Вороний Глаз» (парус поднят/спущен)", 2)]:
    add("sea", "boat_" + boat, title + ", 8 направлений", "32x32–48x48", 8 * states, "create-8-direction-object",
        f"small {boat} boat seen from above, {STYLE}", "P2", dirs=8)
add("sea", "hero_in_boat", "Герой, сидящий в лодке (гребёт), 4 направления", "16x24", 4, "create-character-with-4-directions",
    f"keeper sitting and rowing, {STYLE}", "P2", dirs=4)
SEA = [("iceberg", 3, "айсберги"), ("eleonora_ship", 1, "корабль-призрак «Элеонора»"), ("teeth_reef", 3, "скалы Зубы"),
       ("nameless_island", 1, "Остров Без Имени"), ("bird_colony_rock", 1, "птичий базар на скале"), ("seal_rock", 1, "Тюлений камень"),
       ("sea_garden", 6, "морской огород: ламинария, мидиевые верёвки, устричные садки (пусто/урожай)"), ("cargo_flotsam", 2, "плавучий груз"),
       ("ship_lights_night", 3, "огни проходящих кораблей ночью"), ("steamer_at_sea", 1, "пароход «Чайка» в море"), ("whirlpool", 1, "Колодец Утопленников")]
for aid, n, title in SEA:
    add("sea", aid, title, "16–96 px", n, "create-1-direction-object (пакет)", f"{title}, top-down sea object, {STYLE}", "P3")
SIGHTINGS = json.load(open(os.path.join(ROOT, "data", "balance.json"), encoding="utf-8"))["spyglass"]
for row in SIGHTINGS["birds"]:
    add("spyglass", "bird_" + row[0], "Птица в трубу: " + row[1], "48x32", 1, "create-image-pixflux (пакет)",
        f"side view of a {row[0].replace('_', ' ')} in flight or perched, spyglass vignette, {STYLE}", "P3")
for row in SIGHTINGS["ships"]:
    add("spyglass", "ship_" + row[0], "Корабль в трубу: " + ru(row[1]), "64x32", 1, "create-image-pixflux (пакет)",
        f"distant side view of {en(row[1])}, spyglass vignette, {STYLE}", "P3")

# ---------------------------------------------------------------- 9. Deep and grottoes
DEEP = [("deep_resource", 10, "узлы ресурсов Глуби (руды, кварц, кельп, жемчужницы)"), ("deep_chest", 3, "сундуки Глуби (обычный, обросший, сокровищница)"),
        ("deep_rope", 2, "трос вверх/вниз"), ("deep_debris", 2, "обломки на тросе"), ("bell_station", 1, "колокольная станция"),
        ("diving_bell", 1, "водолазный колокол"), ("grotto_puzzle", 6, "гроты: плиты, решётка, капель, завал, ложный фонарь, Сердце грота"),
        ("deep_decor", 8, "декор Глуби: кельп, кораллы, кости, затонувшие вывески")]
for aid, n, title in DEEP:
    add("deep", aid, title, "16–32 px", n, "create-1-direction-object (пакет)", f"underwater: {title}, {STYLE}", "P3")

# ---------------------------------------------------------------- 10. story spots
SPOT_KINDS = sorted({s["kind"] for s in load("story_spots")} - {"ghost", "cat", "raven_mark"})
for kind in SPOT_KINDS:
    add("story", "spot_" + kind, "Сюжетная точка: " + kind, "16–48 px", 1, "create-1-direction-object (пакет)",
        f"story object '{kind}', {STYLE}", "P3")

# ---------------------------------------------------------------- 11. inventory icons
PLACEABLE = {i["id"] for i in items if i.get("category") in ("decor", "furniture")}
for i in items:
    if i["id"] in PLACEABLE:
        continue
    add("icons", "icon_" + i["id"], ru(i["name"]), "16x16", 1, "create-1-direction-object (пакет ≤64)",
        f"16x16 inventory icon: {en(i['name'])} ({i.get('category', '')}), {STYLE}",
        "P1" if i["id"] in ("seed_turnip", "turnip", "tool_hoe", "tool_can", "tool_pick", "tool_axe", "tool_shovel", "tool_scythe",
                            "fish_oil", "bread_rye", "tea", "lantern_tin") else "P2", "пакетом до 64 иконок за вызов")

# ---------------------------------------------------------------- 12. UI
UI_PANELS = ["9-slice панель «кожа и латунь»", "разворот «Журнала смотрителя» (книга)", "окно диалога + рамка портрета", "подсказка (tooltip)",
             "кнопка (4 состояния)", "вкладки журнала", "слот хотбара/инвентаря (+выделенный)", "панель лавки", "бумага «Ночного отчёта»",
             "письмо/почта", "доска улик (пробка, карточки, булавки, нитки)", "сетка календаря", "рамка карты моря", "мини-игра рыбалки (шкала натяжения)",
             "рамка мини-игр праздников", "шкалы: энергия/здоровье/холод/воздух", "шкалы компаса (Свет/Покой/Море)", "всплывающее уведомление",
             "панель станка с очередью", "секционный стол (UI)", "доска опознания", "экран выбора профессии", "экран финального выбора", "титульное меню",
             "панель подзорной трубы"]
for n, title in enumerate(UI_PANELS):
    add("ui", f"ui_panel_{n + 1:02d}", title, "192–688 px", 1, "create-ui-asset", f"{title}, leather and brass, parchment, {STYLE}",
        "P1" if n in (0, 4, 6, 15, 16) else "P2")
UI_ICONS = [("compass", 3), ("weather", 8), ("tide", 2), ("moon", 8), ("season", 4), ("hearts", 4), ("quality_stars", 4), ("status_bars", 4),
            ("money", 1), ("points_anchor_leaf_candle", 3), ("honour", 1), ("mail", 1), ("quest_marks", 3), ("skills", 7), ("knowledge_branches", 6),
            ("professions", 42), ("cursors", 3), ("buffs", 12), ("evidence", 8), ("festivals", 8), ("community_rooms", 6), ("blessings", 8),
            ("neptune_logo", 1), ("key_prompts", 12)]
for aid, n in UI_ICONS:
    add("ui", "ui_icons_" + aid, f"Значки UI: {aid} ({n})", "16x16", n, "create-1-direction-object (пакет ≤64)",
        f"16x16 UI icons: {aid.replace('_', ' ')}, {STYLE}", "P1" if aid in ("compass", "weather", "tide", "moon", "status_bars", "money") else "P2")
add("ui", "fonts", "Пиксельные шрифты 5×7 и 8×8 (кириллица)", "font", 2, "generate-font-pro", "pixel font with Cyrillic", "P2",
    "проверить поддержку кириллицы; иначе рисовать вручную")

# ---------------------------------------------------------------- 13. illustrations
ILLU = [("title", 2, "титульный экран: маяк ночью, логотип"), ("prologue", 6, "пролог: контора «Нептуна», письма, Штерн, анкета, пароход в тумане, причал"),
        ("finale", 7, "Великий Прилив: удержание огня, тропа на дне, Врата, Чертоги Ранн, выбор A–D"),
        ("tales", 12, "гравюры 12 сказов Хельги"), ("festival_banners", 8, "афиши 8 праздников"), ("minigame_bg", 6, "фоны мини-игр"),
        ("kronvald", 1, "поездка в Кронвальд"), ("faint", 1, "обморок/спасение"), ("night_report", 1, "шапка ночного отчёта")]
for aid, n, title in ILLU:
    add("illustrations", "illu_" + aid, title, "128–400 px", n, "create-image-pixflux", f"{title}, cinematic pixel art illustration, {STYLE}", "P3")
EPILOGUE = [k for k in STRINGS if k.startswith("epilogue.") and k not in ("epilogue.title", "epilogue.next", "epilogue.free")]
add("illustrations", "illu_epilogue", f"слайды эпилога ({len(EPILOGUE)})", "240x135", len(EPILOGUE), "create-image-pixflux",
    f"epilogue slides of the island's fate, {STYLE}", "P3")
add("illustrations", "illu_pages", "наброски на страницах Агаты (24)", "64x64", 24, "create-image-pixflux (пакет)",
    f"ink sketches in a keeper's journal, {STYLE}", "P4", "можно отложить")

# ================================================================ animations
HERO_4DIR = [("walk", "template"), ("idle", "template"), ("hoe", "v3"), ("watering can", "v3"), ("pickaxe", "v3"), ("axe chop", "v3"),
             ("scythe swing", "v3"), ("shovel dig", "v3"), ("fishing cast", "v3"), ("melee attack", "template"), ("harpoon shot", "v3"),
             ("carry body on shoulder walk", "v3"), ("dodge roll", "template"), ("swim", "v3"), ("diving suit walk on seabed", "v3"), ("fishing reel fight", "v3")]
HERO_1DIR = ["eat/drink", "sleep", "faint", "sit", "rite at stone", "light the lamp", "clean glass", "wind mechanism", "ring bell",
             "pet animal", "lift cat", "surprised emote", "happy emote"]
for body in ("hero_m", "hero_f"):
    for action, mode in HERO_4DIR:
        anim("hero", body, action, 4, 6, "characters/animations (" + mode + ")", f"keeper {action}", "P1" if action in ("walk", "idle", "hoe", "watering can") else "P2")
    for action in HERO_1DIR:
        anim("hero", body, action, 1, 6, "characters/animations (v3)", f"keeper {action}", "P2")
    anim("hero", body, "rowing in boat", 4, 6, "characters/animations (v3)", "keeper rowing", "P2")
for npc in load("npcs"):
    if npc["id"] == "npc_fortuna":
        anim("npcs", npc["id"], "speaking glow", 1, 6, "animate-with-text-v3", "figurehead eyes glow while speaking", "P2")
        continue
    anim("npcs", npc["id"], "walk", 4, 6, "characters/animations (template)", "walk", "P2")
    anim("npcs", npc["id"], "idle", 1, 4, "characters/animations (template)", "breathing idle", "P2")
    anim("npcs", npc["id"], "work pose", 1, 6, "characters/animations (v3)", "signature work action", "P3")
for aid in ("agatha", "kid_toddler_boy", "kid_toddler_girl", "kid_child_boy", "kid_child_girl", "villager_1", "villager_2", "sailor_rescued"):
    anim("npcs", aid, "walk", 4, 6, "characters/animations (template)", "walk", "P3")
for g in load("ghosts"):
    anim("spirits", g["id"], "float idle", 1, 6, "animate-with-text-v3", "ghost floating and flickering", "P3")
for aid in ("ghost_appear", "ghost_dissipate", "rann_rise", "rann_speak", "hmar_drift", "hmar_faces"):
    anim("spirits", aid, aid.replace("_", " "), 1, 8, "animate-with-text-v3", aid.replace("_", " "), "P3")
for d in ["zyb", "pena", "burun", "stuzha", "tish", "svetla", "priliva", "hmar"]:
    anim("spirits", "daughter_" + d, "idle", 1, 6, "animate-with-text-v3", "sea spirit idle", "P3")
for a in load("animals"):
    anim("animals", a["id"], "walk", 4, 6, "characters/animations (template)", "walk", "P2")
    anim("animals", a["id"], "eat/idle", 1, 4, "characters/animations (v3)", "eat grass / peck", "P2")
anim("animals", "cat_wick", "walk", 4, 6, "characters/animations (template)", "cat walk", "P2")
anim("animals", "cat_wick", "sleep", 1, 4, "characters/animations (v3)", "cat sleeping", "P2")
for aid, action in [("seal", "flop"), ("gull", "fly"), ("puffin", "fly"), ("raven", "circle"), ("whale", "surface and dive"),
                    ("orca", "surface"), ("herring_school", "shimmer"), ("fish_shadow", "swim")]:
    anim("animals", aid, action, 1, 6, "animate-with-text-v3", action, "P3")
for e in load("enemies"):
    dirs = 4 if e["id"] in FOUR_DIR_ENEMIES else 1
    anim("enemies", e["id"], "move", dirs, 6, "characters/animations (template)" if dirs == 4 else "animate-with-text-v3", "move", "P3")
    anim("enemies", e["id"], "attack", 1, 6, "animate-with-text-v3", "attack", "P3")
    anim("enemies", e["id"], "death", 1, 6, "animate-with-text-v3", "death / dissolve", "P3")
for b in load("bosses"):
    for action in ("idle", "attack 1", "attack 2", "phase change", "death"):
        anim("enemies", b["id"], action, 1, 8, "animate-with-text-v3", action, "P3")
for st in load("stations"):
    if st.get("kind") in ("process", "cook", "hive") or st["id"] == "wind_pump":
        anim("stations", st["id"], "working", 1, 4, "objects/{id}/animations (v3)", "working: smoke, fire, moving parts", "P3")
ENV = [("lighthouse", "lamp flame"), ("lighthouse", "lens rotation"), ("lighthouse", "beam glow"), ("lighthouse", "mechanism weights"),
       ("tower_bell", "bell swing"), ("fog_horn", "horn blast"),
       ("water", "deep water"), ("water", "shallow water"), ("water", "shore foam"), ("water", "tide pool"), ("water", "lagoon"),
       ("water", "sea chart water"), ("water", "stream"), ("water", "whirlpool"),
       ("fire", "hearth"), ("fire", "bonfire"), ("fire", "candle"), ("fire", "lantern"), ("fire", "street lamp"), ("fire", "window glow"), ("fire", "forge"),
       ("nature", "trees sway"), ("nature", "reeds sway"), ("nature", "flag"), ("nature", "chimney smoke"), ("nature", "kelp sway"), ("nature", "grotto drip"),
       ("sea", "yalik oars"), ("sea", "sloop sail flutter"), ("sea", "bot sail flutter"), ("sea", "buoy bob"), ("sea", "Eleonora ghost ship"),
       ("sea", "iceberg bob"), ("sea", "steamer smoke"), ("sea", "sea garden bob"),
       ("story", "Rann stone glow"), ("story", "Nine Maidens glow"), ("story", "raven circling"), ("story", "bell station bubbles"), ("story", "chest open")]
for target, action in ENV:
    anim("environment", target, action, 1, 4 if target in ("water", "fire") else 6, "animate-with-text-v3", action,
         "P1" if target in ("lighthouse", "water") and action in ("lamp flame", "deep water", "shallow water", "shore foam") else "P3")
for fx in ["water splash", "dust puff", "stone sparks", "wood chips", "ink cloud", "bubbles", "fog wisps", "lightning",
           "hit flash", "heal sparkle", "level up", "fish bite !", "pickup sparkle", "snatch feathers", "soil clod"]:
    anim("effects", "fx", fx, 1, 6, "animate-with-text-v3", fx, "P2")


# ================================================================ output
def write_csv(path, rows):
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def batched_calls(rows):
    """PixelLab calls if every batchable asset (≤42 px → 64 per call, ≤85 → 16) is generated in shared calls."""
    small = sum(r["images"] for r in rows if "пакет" in r["method"] and _max_side(r["size"]) <= 42)
    mid = sum(r["images"] for r in rows if "пакет" in r["method"] and 42 < _max_side(r["size"]) <= 85)
    single = [r for r in rows if "пакет" not in r["method"]]
    return math.ceil(small / 64), math.ceil(mid / 16), single


def _max_side(size):
    import re
    nums = [int(n) for n in re.findall(r"\d+", size.split("×")[0].split("(")[0])]
    return max(nums) if nums else 64


os.makedirs(OUT, exist_ok=True)
write_csv(os.path.join(OUT, "assets.csv"), assets)
write_csv(os.path.join(OUT, "animations.csv"), anims)

groups = {}
for r in assets:
    g = groups.setdefault(r["group"], {"entries": 0, "images": 0})
    g["entries"] += 1
    g["images"] += r["images"]
agroups = {}
for r in anims:
    g = agroups.setdefault(r["group"], {"entries": 0, "dirs": 0})
    g["entries"] += 1
    g["dirs"] += r["directions"]
total_images = sum(g["images"] for g in groups.values())
total_anim = sum(g["dirs"] for g in agroups.values())
by_prio = {}
for r in assets:
    by_prio.setdefault(r["priority"], [0, 0])[0] += r["images"]
for r in anims:
    by_prio.setdefault(r["priority"], [0, 0])[1] += r["directions"]
small_calls, mid_calls, single = batched_calls(assets)
single_images = sum(r["images"] for r in single)
template_dirs = sum(r["directions"] for r in anims if "template" in r["method"])
custom_dirs = total_anim - template_dirs

summary = {
    "groups": groups, "anim_groups": agroups, "images": total_images, "animations": total_anim,
    "cost_art": total_images * RATE_ART, "cost_anim": total_anim * RATE_ANIM,
    "by_priority": by_prio, "batch_small_calls": small_calls, "batch_mid_calls": mid_calls,
    "single_images": single_images, "template_dirs": template_dirs, "custom_dirs": custom_dirs,
}
with open(os.path.join(OUT, "summary.json"), "w", encoding="utf-8") as f:
    json.dump(summary, f, ensure_ascii=False, indent=1)
print(json.dumps(summary, ensure_ascii=False, indent=1))
