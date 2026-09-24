extends Node

const FIRST_NAMES := ["Ян", "Ларс", "Нильс", "Эрик", "Бьорн", "Сванте", "Олле", "Мартен", "Гуннар", "Ивар",
	"Кнут", "Халле", "Торд", "Арвид", "Ингрид", "Марта", "Сигне", "Хельга", "Карин", "Ульф"]
const LAST_NAMES := ["Берг", "Хольм", "Линд", "Стрём", "Вик", "Ског", "Ольсен", "Нюберг", "Ек", "Дал",
	"Сунд", "Фальк", "Эдлунд", "Ховде", "Ранд", "Тофт"]
const CLUE_POOLS := {
	"tattoo": ["anchor", "swallow", "mermaid", "compass", "heart", "ship", "fish"],
	"clothes": ["whaler_jacket", "fisher_sweater", "navy_coat", "oilskin", "merchant_vest", "stoker_apron"],
	"papers": ["ticket_kronwald", "letter_home", "cargo_invoice", "pay_book"],
	"body": ["tall", "short", "broad", "scar_left_hand", "scar_face", "missing_finger", "broken_nose", "grey_beard"],
}
const SHIP_CLOTHES := {"fishing_boat": "fisher_sweater", "merchant_brig": "merchant_vest", "whaler": "whaler_jacket",
	"collier": "stoker_apron", "queen": "navy_coat"}

var bodies: Array = []
var graves: Array = []
var peace: float = 0.0
# Drowned crews from wrecks waiting to wash ashore: {ship, arrive (day index), beach, registry}.
var incoming: Array = []
var registry_extra: Array = []
var laid_ghosts: Array = []
var replies: Array = []
var carried: String = ""
var next_id: int = 1
var penalties: Dictionary = {}


func cfg(key: String) -> Variant:
	return Game.balance("graveyard", {}).get(key)


func _ready() -> void:
	reset()


func reset() -> void:
	bodies.clear()
	incoming.clear()
	registry_extra.clear()
	laid_ghosts.clear()
	replies.clear()
	carried = ""
	next_id = 1
	graves.clear()
	for plot in int(cfg("cols")) * int(cfg("rows")):
		graves.append(_empty_grave(plot))
	for plot in int(cfg("old_graves")):
		graves[plot]["old"] = true
		graves[plot]["quality"] = 0
	peace = 0.0
	recalc_peace()


func _empty_grave(plot: int) -> Dictionary:
	return {"plot": plot, "old": false, "repaired": false, "body": "", "dug": 0, "open": false,
		"filled": false, "marker": "", "quality": 0, "name": "", "weeds": false, "sunk": false}


# 11.11: Ilm's extension grows the graveyard to 24 / 40 / 60 plots, row by row below the old ones.
func extend_plots(total: int) -> void:
	while graves.size() < total:
		graves.append(_empty_grave(graves.size()))


# The graveyard is laid out in fenced blocks of 12 plots (4 × 3); extensions add blocks east and south.
const BLOCK_OFFSETS := [Vector2(0, 0), Vector2(184, 0), Vector2(368, 0), Vector2(0, 192), Vector2(184, 192)]


func block_count() -> int:
	return ceili(float(graves.size()) / float(int(cfg("cols")) * int(cfg("rows"))))


func block_origin(block: int) -> Vector2:
	var origin: Array = cfg("origin")
	return Vector2(float(origin[0]), float(origin[1])) + BLOCK_OFFSETS[clampi(block, 0, BLOCK_OFFSETS.size() - 1)]


func plot_position(plot: int) -> Vector2:
	var size: Array = cfg("plot")
	var cols := int(cfg("cols"))
	var per_block := cols * int(cfg("rows"))
	var index := plot % per_block
	return block_origin(plot / per_block) + Vector2(float(index % cols) * float(size[0]) + float(size[0]) / 2.0,
		float(index / cols) * float(size[1]) + float(size[1]) / 2.0)


func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 69069 + Clock.day_index * 10007 + next_id * 131 + salt, 2147483647)
	return rng


# ---- registry and identities ----

func registry() -> Array:
	var out: Array = Data.all("registry").duplicate()
	out.append_array(registry_extra)
	return out


func registry_entry(id: String) -> Dictionary:
	for entry in registry():
		if str(entry.get("id", "")) == id:
			return entry
	return {}


func _person(rng: RandomNumberGenerator, ship_type: String, ship: String) -> Dictionary:
	var first: String = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
	var last: String = LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
	var clues: Array = ["initials:%s.%s." % [first.left(1), last.left(1)]]
	clues.append("clothes:" + str(SHIP_CLOTHES.get(ship_type, CLUE_POOLS["clothes"][rng.randi_range(0, 5)])))
	clues.append("body:" + str(CLUE_POOLS["body"][rng.randi_range(0, CLUE_POOLS["body"].size() - 1)]))
	if rng.randf() < 0.7:
		clues.append("tattoo:" + str(CLUE_POOLS["tattoo"][rng.randi_range(0, CLUE_POOLS["tattoo"].size() - 1)]))
	if rng.randf() < 0.4:
		clues.append("papers:" + str(CLUE_POOLS["papers"][rng.randi_range(0, CLUE_POOLS["papers"].size() - 1)]))
	var entry := {"id": "reg_gen_%d" % next_id, "name": "%s %s" % [first, last], "ship": ship,
		"age": rng.randi_range(16, 62), "clues": clues,
		"family": {"money": rng.randi_range(1, 8) * 100}}
	next_id += 1
	registry_extra.append(entry)
	return entry


# Each season the directorate adds 3-6 missing people to the registry (11.7).
func season_additions(index: int) -> void:
	var rng := _rng(index + 5)
	for n in rng.randi_range(3, 6):
		_person(rng, "", "")


# ---- bodies ----

func body(id: String) -> Dictionary:
	for b in bodies:
		if str(b["id"]) == id:
			return b
	return {}


func _new_body(id: String, reg: Dictionary, story: bool, rng: RandomNumberGenerator) -> Dictionary:
	var clues: Array = reg.get("clues", []).duplicate()
	var visible: Array = []
	var hidden: Array = []
	if reg.has("clues_visible"):
		visible = reg["clues_visible"].duplicate()
		hidden = reg.get("clues_hidden", []).duplicate()
	else:
		for i in range(clues.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Variant = clues[i]
			clues[i] = clues[j]
			clues[j] = tmp
		var shown := clampi(rng.randi_range(1, 3), 1, clues.size())
		visible = clues.slice(0, shown)
		hidden = clues.slice(shown, mini(clues.size(), shown + rng.randi_range(0, 2)))
	return {"id": id, "registry": str(reg.get("id", "")), "story": story, "where": "shore", "map": "",
		"x": 0.0, "y": 0.0, "preservation": 100.0, "arrived": Clock.day_index, "visible": visible,
		"hidden": hidden, "revealed": [], "items": reg.get("items", []).duplicate(), "searched": false,
		"examined": false, "washed": false, "sewn": false, "stitch": false, "coffin": 0, "funeral": false,
		"identified_as": "", "letter_sent": false, "restless": false, "whispered": false,
		"whisper": reg.get("whisper", {}).duplicate(), "ghost": str(reg.get("ghost", ""))}


func _beach_spot(map_id: String, rng: RandomNumberGenerator) -> Vector2:
	var beach: Dictionary = Data.tables.get("forage", {}).get("beaches", {}).get(map_id, {})
	var columns: Array = beach.get("columns", [4, 40])
	var row0 := Sea.first_row(map_id)
	return Vector2(rng.randi_range(int(columns[0]), int(columns[1])) * 16 + 8, (row0 - 1) * 16 + 8)


func spawn_body(reg: Dictionary, map_id: String, story: bool = false, id: String = "") -> Dictionary:
	var rng := _rng(17)
	if id == "":
		id = "body_%d" % next_id
		next_id += 1
	var b := _new_body(id, reg, story, rng)
	b["map"] = map_id
	var spot := _beach_spot(map_id, rng)
	b["x"] = spot.x
	b["y"] = spot.y
	bodies.append(b)
	Events.body_spawned.emit(id)
	return b


func _parse_date(date: String) -> int:
	var parts := date.split(".")
	if parts.size() != 3:
		return -1
	var season_index := Clock.SEASONS.find(parts[1])
	return (int(parts[0].substr(1)) - 1) * Clock.DAYS_PER_YEAR + season_index * Clock.DAYS_PER_SEASON + int(parts[2]) - 1


func is_buried(b: Dictionary) -> bool:
	return str(b["where"]) == "grave"


# Night step 6: bodies decay, the unburied turn restless, the sea returns the drowned.
func advance_night(storm: bool) -> Array:
	var arrived: Array = []
	var decay: Dictionary = cfg("decay")
	for b in bodies:
		if is_buried(b):
			continue
		var place := "morgue" if str(b["where"]) == "morgue" else "shore"
		if place == "morgue" and Buildings.level("ice_house") > 0:
			place = "icehouse"
		b["preservation"] = maxf(0.0, float(b["preservation"]) - float(decay.get(place, 10)))
		if Clock.day_index - int(b["arrived"]) >= int(cfg("restless_days")):
			b["restless"] = true
	var keep: Array = []
	for entry in incoming:
		if int(entry["arrive"]) <= Clock.day_index:
			var map_id := str(entry["beach"])
			if map_id == "lagoon":
				map_id = "cape"
			var reg := registry_entry(str(entry.get("registry", "")))
			if reg.is_empty():
				reg = _person(_rng(23), str(entry.get("type", "")), str(entry["ship"]))
			arrived.append(spawn_body(reg, map_id)["id"])
		else:
			keep.append(entry)
	incoming = keep
	if Clock.day == 1:
		season_additions(Clock.day_index)
	for story in Data.all("bodies"):
		if _parse_date(str(story.get("arrive", {}).get("date", ""))) == Clock.day_index and body(str(story["id"])).is_empty():
			var reg := registry_entry(str(story.get("registry", "")))
			var merged := reg.duplicate(true)
			for key in ["clues_visible", "clues_hidden", "items", "whisper", "ghost"]:
				if story.has(key):
					merged[key] = story[key]
			var b := spawn_body(merged, str(story["arrive"].get("beach", "cape")), true, str(story["id"]))
			arrived.append(b["id"])
	if storm and _rng(29).randf() < float(cfg("storm_body")):
		var missing: Array = []
		for reg in registry():
			if not _registry_used(str(reg["id"])) and not bool(reg.get("alive", false)) and not reg.has("story"):
				missing.append(reg)
		var rng := _rng(31)
		var reg: Dictionary = missing[rng.randi_range(0, missing.size() - 1)] if not missing.is_empty() \
			else _person(rng, "", "")
		var beaches := ["cape", "wreck_bay", "seal_shore"]
		arrived.append(spawn_body(reg, beaches[rng.randi_range(0, 2)])["id"])
	_grave_care(storm)
	return arrived


func _registry_used(reg_id: String) -> bool:
	for b in bodies:
		if str(b["registry"]) == reg_id:
			return true
	for entry in incoming:
		if str(entry.get("registry", "")) == reg_id:
			return true
	return false


# Weekly weeds on 10% of graves, storms sink 10% of them (11.5).
func _grave_care(storm: bool) -> void:
	var occupied: Array = []
	for g in graves:
		if str(g["body"]) != "" or (bool(g["old"]) and bool(g["repaired"])):
			occupied.append(g)
	if occupied.is_empty():
		return
	var rng := _rng(37)
	if Clock.weekday == "mon":
		for n in maxi(1, int(round(float(occupied.size()) * float(cfg("weeds_share"))))):
			occupied[rng.randi_range(0, occupied.size() - 1)]["weeds"] = true
	if storm:
		for n in maxi(1, int(round(float(occupied.size()) * float(cfg("sink_share"))))):
			occupied[rng.randi_range(0, occupied.size() - 1)]["sunk"] = true


# ---- preparation (11.4) ----

func preparation(b: Dictionary) -> int:
	var prep: Dictionary = cfg("prep")
	var cloth := (int(prep["wash"]) if bool(b["washed"]) else 0) + (int(prep["sew"]) if bool(b["sewn"]) else 0) \
		+ (int(prep["stitch"]) if bool(b["stitch"]) else 0)
	if float(b["preservation"]) <= 0.0:
		cloth = mini(cloth, 20)
	var total := cloth + int(b["coffin"]) + (int(prep["funeral"]) if bool(b["funeral"]) else 0)
	return mini(total, int(cfg("prep_max")))


func examine(b: Dictionary, magnifier: bool = false) -> Array:
	if str(b["where"]) != "morgue" or bool(b["examined"]):
		return []
	var found: Array = []
	for clue in b["visible"]:
		if not b["revealed"].has(clue):
			b["revealed"].append(clue)
			found.append(clue)
	var chance := 0.3 + 0.05 * float(Skills.level("keeping")) + (0.2 if magnifier else 0.0)
	var rng := _rng(41)
	for clue in b["hidden"]:
		if rng.randf() < chance and not b["revealed"].has(clue):
			b["revealed"].append(clue)
			found.append(clue)
	b["examined"] = true
	Skills.add_xp("keeping", 5)
	Events.body_examined.emit(str(b["id"]))
	return found


# The belongings go to the family box, or into the keeper's pocket for 3 honour.
func search(b: Dictionary, keep: bool) -> Array:
	if bool(b["searched"]) or str(b["where"]) != "morgue":
		return []
	b["searched"] = true
	var items: Array = b["items"].duplicate()
	if keep:
		for id in items:
			Inventory.add(str(id), 1)
		Game.add_honor(-3 * items.size())
		b["items"] = []
	return items


func wash(b: Dictionary) -> bool:
	if bool(b["washed"]) or str(b["where"]) != "morgue" or not Inventory.take("fresh_water", 1):
		return false
	b["washed"] = true
	Skills.add_xp("keeping", 5)
	Events.quest_event.emit("body_washed", str(b["id"]))
	return true


func sew(b: Dictionary, stitch: bool) -> bool:
	if bool(b["sewn"]) or str(b["where"]) != "morgue":
		return false
	if Inventory.count_of("canvas") < 1 or Inventory.count_of("thread") < 1:
		return false
	Inventory.take("canvas", 1)
	Inventory.take("thread", 1)
	b["sewn"] = true
	b["stitch"] = stitch
	Skills.add_xp("keeping", 10 if stitch else 5)
	Events.quest_event.emit("body_sewn", str(b["id"]))
	return true


func coffin(b: Dictionary, item_id: String) -> bool:
	var points := int(Data.by_id("items", item_id).get("coffin", 0))
	if points <= 0 or int(b["coffin"]) > 0 or str(b["where"]) != "morgue" or not Inventory.take(item_id, 1):
		return false
	b["coffin"] = points
	return true


# The keeper's own funeral needs "The Keeper's Word" and a candle (Benedict's is at the chapel).
func self_funeral(b: Dictionary) -> bool:
	if bool(b["funeral"]) or not Game.flag("keeper_word") or not Inventory.take("wax_candle", 1):
		return false
	b["funeral"] = true
	Skills.add_xp("keeping", 10)
	Knowledge.add_points("rest", 1)
	return true


func chapel_funeral() -> String:
	if Clock.weekday != "sun" or Clock.hour < 10 or Clock.hour >= 12:
		return "hours"
	var target: Dictionary = {}
	for b in bodies:
		if str(b["where"]) == "morgue" and not bool(b["funeral"]):
			target = b
			break
	if target.is_empty():
		return "nobody"
	if not Economy.can_pay(int(cfg("funeral_price"))) or Inventory.count_of("wax_candle") < int(cfg("funeral_candles")):
		return "cost"
	Economy.pay(int(cfg("funeral_price")))
	Inventory.take("wax_candle", int(cfg("funeral_candles")))
	target["funeral"] = true
	Skills.add_xp("keeping", 10)
	return "ok"


# ---- carrying ----

func pick_up(b: Dictionary) -> bool:
	if carried != "" or is_buried(b):
		return false
	b["where"] = "carried"
	carried = str(b["id"])
	return true


func put_down(map_id: String, at: Vector2) -> bool:
	var b := body(carried)
	if b.is_empty():
		return false
	b["where"] = "ground"
	b["map"] = map_id
	b["x"] = at.x
	b["y"] = at.y
	carried = ""
	return true


func morgue_count() -> int:
	var n := 0
	for b in bodies:
		if str(b["where"]) == "morgue":
			n += 1
	return n


func store_in_morgue() -> bool:
	var b := body(carried)
	if b.is_empty():
		return false
	b["where"] = "morgue"
	carried = ""
	Events.body_moved.emit(str(b["id"]), "morgue")
	return true


func take_from_morgue(b: Dictionary) -> bool:
	if str(b["where"]) != "morgue" or carried != "":
		return false
	b["where"] = "carried"
	carried = str(b["id"])
	return true


# ---- identification (11.7) ----

func candidates(b: Dictionary, use_filter: bool) -> Array:
	var out: Array = []
	for reg in registry():
		if reg.has("story_only") or (_assigned_elsewhere(str(reg["id"]), str(b["id"]))):
			continue
		var fits := true
		if use_filter:
			for clue in b["revealed"]:
				fits = fits and reg.get("clues", []).has(clue)
		if fits:
			out.append(reg)
	return out


func _assigned_elsewhere(reg_id: String, body_id: String) -> bool:
	for other in bodies:
		if str(other["id"]) != body_id and str(other["identified_as"]) == reg_id:
			return true
	return false


func identify(b: Dictionary, reg_id: String) -> bool:
	if registry_entry(reg_id).is_empty() or _assigned_elsewhere(reg_id, str(b["id"])):
		return false
	if str(b["identified_as"]) != "" and bool(b["letter_sent"]) and not bool(b.get("wrong_revealed", false)):
		return false
	var fixing := bool(b.get("wrong_revealed", false))
	if fixing and not _pay_plaque(b):
		return false
	b["identified_as"] = reg_id
	b["letter_sent"] = false
	b["wrong_revealed"] = false
	if b.has("plot"):
		var g: Dictionary = graves[int(b["plot"])]
		g["name"] = str(registry_entry(reg_id)["name"])
		update_quality(int(b["plot"]))
		recalc_peace()
	Events.body_identified.emit(str(b["id"]), reg_id == str(b["registry"]))
	return true


# A wrong name is fixed by replacing the plaque: one unit of the marker's material.
func _pay_plaque(b: Dictionary) -> bool:
	if not b.has("plot"):
		return true
	var marker := str(graves[int(b["plot"])]["marker"])
	match marker:
		"", "mound":
			return marker == "" or Inventory.take("stone", 1)
		"wooden_cross", "carved_cross":
			return Inventory.take("boards", 1)
	return true


# The directorate posts a letter to the family for 20 kr; the answer comes in 3-7 days.
func send_family_letter(b: Dictionary) -> bool:
	if str(b["identified_as"]) == "" or bool(b["letter_sent"]) or not Economy.pay(int(cfg("family_letter"))):
		return false
	b["letter_sent"] = true
	var story := Data.by_id("bodies", str(b["id"]))
	var reply: Dictionary = story.get("family_reply", {})
	var due := Clock.day_index + _rng(43).randi_range(3, 7)
	if reply.has("date"):
		due = maxi(_parse_date(str(reply["date"])), Clock.day_index + 1)
	replies.append({"body": str(b["id"]), "reg": str(b["identified_as"]), "due": due})
	Events.quest_event.emit("family_letter_sent", str(b["id"]))
	return true


# Night mail: families answer; a wrong name comes back as "our Jan is alive".
func deliver_replies(night_index: int) -> void:
	var keep: Array = []
	for r in replies:
		if int(r["due"]) > night_index:
			keep.append(r)
			continue
		var b := body(str(r["body"]))
		if b.is_empty():
			continue
		var reg := registry_entry(str(r["reg"]))
		if str(r["reg"]) == str(b["registry"]):
			var story := Data.by_id("bodies", str(b["id"]))
			var reply: Dictionary = story.get("family_reply", {})
			var money := int(reply.get("money", reg.get("family", {}).get("money", 200)))
			var items: Array = []
			if reply.has("item"):
				items.append([str(reply["item"]), 1])
			Mail.send(str(reply.get("text", "mail.family_thanks")), [str(reg["name"])], money, items)
			Game.add_honor(5)
			Knowledge.add_points("rest", 1)
			Skills.add_xp("keeping", 20)
			b["confirmed"] = true
			Events.quest_event.emit("family_answered", str(b["id"]))
		else:
			Mail.send("mail.family_wrong", [str(reg["name"])])
			Game.add_honor(-5)
			b["wrong_revealed"] = true
	replies = keep


# First night in the morgue, 0:00-2:00: the body whispers one more clue; 30% of whispers lie.
func whisper(b: Dictionary) -> String:
	if bool(b["whispered"]) or str(b["where"]) != "morgue" or Clock.day_index != int(b["arrived"]) \
			or Clock.minutes >= 120:
		return ""
	b["whispered"] = true
	var story: Dictionary = b.get("whisper", {})
	if story.has("text"):
		if story.has("clue") and not b["revealed"].has(str(story["clue"])):
			b["revealed"].append(str(story["clue"]))
		return Loc.t(str(story["text"]))
	var rng := _rng(47)
	var pool: Array = []
	for clue in b["hidden"] + b["visible"]:
		if not b["revealed"].has(clue):
			pool.append(clue)
	if rng.randf() < 0.3 or pool.is_empty():
		var kinds: Array = CLUE_POOLS.keys()
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var fake := "%s:%s" % [kind, CLUE_POOLS[kind][rng.randi_range(0, CLUE_POOLS[kind].size() - 1)]]
		return Loc.t("whisper.says") % clue_text(fake)
	var truth: String = pool[rng.randi_range(0, pool.size() - 1)]
	b["revealed"].append(truth)
	return Loc.t("whisper.says") % clue_text(truth)


static func clue_text(clue: String) -> String:
	var kind := clue.get_slice(":", 0)
	var value := clue.get_slice(":", 1)
	var key := "clue.%s.%s" % [kind, value]
	var full := Loc.t(key)
	if full != key:
		return full
	return Loc.t("clue." + kind) % value


# ---- graves (11.5) ----

func dig_hits_needed() -> int:
	var hits: Array = cfg("dig_hits")
	return int(hits[clampi(int(Game.counters.get("shovel_level", 0)), 0, hits.size() - 1)])


func dig(plot: int) -> String:
	var g: Dictionary = graves[plot]
	if bool(g["old"]) or str(g["body"]) != "" or bool(g["open"]):
		return "taken"
	g["dug"] = int(g["dug"]) + 1
	if int(g["dug"]) >= dig_hits_needed():
		g["open"] = true
		Events.quest_event.emit("grave_dug", str(plot))
		return "open"
	return "digging"


func lay(plot: int) -> bool:
	var g: Dictionary = graves[plot]
	var b := body(carried)
	if b.is_empty() or not bool(g["open"]) or str(g["body"]) != "":
		return false
	g["body"] = str(b["id"])
	b["where"] = "grave"
	b["plot"] = plot
	carried = ""
	return true


func fill(plot: int) -> bool:
	var g: Dictionary = graves[plot]
	if str(g["body"]) == "" or bool(g["filled"]):
		return false
	g["filled"] = true
	var b := body(str(g["body"]))
	g["name"] = str(registry_entry(str(b["identified_as"])).get("name", "")) if str(b["identified_as"]) != "" else ""
	update_quality(plot)
	var quality := int(g["quality"])
	Skills.add_xp("keeping", 25 + quality / 4)
	var notes := 2 + (1 if str(b["identified_as"]) != "" else 0) + (1 if quality >= 70 else 0)
	Knowledge.add_points("rest", notes)
	var pay := 100 if Game.flag("paperwork") else int(cfg("burial_pay"))
	Mail.send("mail.burial_pay", [pay], pay)
	Game.add_stat("burials")
	Events.body_buried.emit(str(b["id"]), quality)
	recalc_peace()
	return true


func marker_points(marker: String) -> int:
	var table: Dictionary = cfg("markers")
	if table.has(marker):
		return int(table[marker]["points"])
	return int(Data.by_id("items", marker).get("marker", 0))


func place_marker(plot: int, marker: String) -> bool:
	var g: Dictionary = graves[plot]
	if not bool(g["filled"]) or str(g["marker"]) != "":
		return false
	var table: Dictionary = cfg("markers")
	if marker == "mound":
		if not Inventory.take("stone", int(table["mound"]["stone"])):
			return false
	elif marker_points(marker) <= 0 or not Inventory.take(marker, 1):
		return false
	g["marker"] = marker
	update_quality(plot)
	Events.quest_event.emit("grave_marked", str(g["body"]))
	recalc_peace()
	return true


func update_quality(plot: int) -> void:
	var g: Dictionary = graves[plot]
	if bool(g["old"]):
		g["quality"] = int(cfg("old_repaired_quality")) if bool(g["repaired"]) else 0
		return
	var b := body(str(g["body"]))
	if b.is_empty():
		g["quality"] = 0
		return
	var named := str(b["identified_as"]) != "" and str(b["identified_as"]) == str(b["registry"])
	g["quality"] = clampi(preparation(b) + marker_points(str(g["marker"])) + (int(cfg("name_points")) if named else 0), 0, 100)


func repair_old(plot: int) -> bool:
	var g: Dictionary = graves[plot]
	if not bool(g["old"]) or bool(g["repaired"]) or Inventory.count_of("tool_scythe") < 1:
		return false
	if not Inventory.take("stone", int(cfg("old_repair_stone"))):
		return false
	g["repaired"] = true
	g["weeds"] = false
	update_quality(plot)
	recalc_peace()
	return true


func tend(plot: int, tool: String) -> bool:
	var g: Dictionary = graves[plot]
	if tool == "tool_scythe" and bool(g["weeds"]):
		g["weeds"] = false
	elif tool == "tool_shovel" and bool(g["sunk"]):
		g["sunk"] = false
	else:
		return false
	recalc_peace()
	return true


# Exhuming at night brings the body back as remains; without a quest it costs 10 honour.
func exhume(plot: int, by_quest: bool = false) -> bool:
	var g: Dictionary = graves[plot]
	if str(g["body"]) == "" or not Clock.is_night() or carried != "":
		return false
	var b := body(str(g["body"]))
	b["where"] = "carried"
	b["preservation"] = 0.0
	b.erase("plot")
	carried = str(b["id"])
	graves[plot] = _empty_grave(plot)
	if not by_quest:
		Game.add_honor(-10)
	recalc_peace()
	return true


func neglected(g: Dictionary) -> bool:
	return (bool(g["old"]) and not bool(g["repaired"])) or bool(g["weeds"]) or bool(g["sunk"])


# Peace = 0.6 × average grave quality + beauty + laid ghosts (≤15) + bonuses − penalties (11.6).
func recalc_peace() -> float:
	var total := 0.0
	var count := 0
	var neglect := 0
	for g in graves:
		if bool(g["old"]) or bool(g["filled"]):
			total += float(g["quality"])
			count += 1
		if neglected(g):
			neglect += 1
	var average := total / float(count) if count > 0 else 0.0
	var unburied := 0
	var on_shore := 0
	var restless := 0
	for b in bodies:
		if is_buried(b):
			continue
		if Clock.day_index - int(b["arrived"]) > 2:
			unburied += 1
		if str(b["where"]) == "shore" and Clock.day_index - int(b["arrived"]) >= 1:
			on_shore += 1
		if bool(b["restless"]):
			restless += 1
	var bonus := 0.0
	if Game.flag("twenty_buried"):
		bonus += 20.0
	if Game.flag("elmo_bell"):
		bonus += 10.0
	bonus += minf(10.0, 5.0 * float(Game.counters.get("drowned_rites", 0)))
	penalties = {"unburied": mini(30, 3 * unburied), "shore": 10 * on_shore, "neglect": 2 * neglect,
		"restless": 5 * restless}
	var minus := 0.0
	for key in penalties:
		minus += float(penalties[key])
	peace = clampf(0.6 * average + beauty() + minf(15.0, float(laid_ghosts.size())) + bonus - minus, 0.0, 100.0)
	return peace


const DECOR_BEAUTY := {"fence_wood": 0.2, "fence_stone": 0.3, "fence_iron": 0.45, "stone_path": 0.1, "bench": 1.0,
	"memory_lantern": 1.0, "statue_mourning": 3.0}


# 11.11/P12: fences, paths, benches, lanterns and the statue within the graveyard, and the small chapel (+5).
func beauty() -> float:
	var total := float(Game.counters.get("graveyard_beauty", 0)) / 10.0
	var size: Array = cfg("plot")
	var block := Vector2(float(size[0]) * float(cfg("cols")), float(size[1]) * float(cfg("rows")))
	for obj in Crafting.placed.get("cape", []):
		var bonus := float(DECOR_BEAUTY.get(str(obj.get("item", "")), 0.0))
		if bonus <= 0.0:
			continue
		var at := Vector2(float(obj["x"]), float(obj["y"]))
		for b in block_count():
			if Rect2(block_origin(b) - Vector2(40, 40), block + Vector2(80, 80)).has_point(at):
				total += bonus
				break
	if Buildings.level("chapel") > 0:
		total += 5.0
	return clampf(total, 0.0, 25.0)


# ---- named ghosts (11.8) ----

func ghost_plot(ghost: Dictionary) -> int:
	if ghost.has("old_grave"):
		return int(ghost["old_grave"])
	var b := body(str(ghost.get("body", "")))
	return int(b.get("plot", -1))


# Ghosts rise at night by their graves once buried (or, for the old keepers, once the grave is tended).
func present_ghosts() -> Array:
	var out: Array = []
	for ghost in Data.all("ghosts"):
		if laid_ghosts.has(str(ghost["id"])):
			continue
		var plot := ghost_plot(ghost)
		if plot < 0:
			continue
		var g: Dictionary = graves[plot]
		var ready := bool(g["repaired"]) if ghost.has("old_grave") else bool(g["filled"])
		if ready:
			out.append(ghost)
	return out


func talk_ghost(ghost_id: String) -> String:
	var ghost := Data.by_id("ghosts", ghost_id)
	if ghost.is_empty() or laid_ghosts.has(ghost_id):
		return ""
	var quest := str(ghost["quest"])
	var lines: Dictionary = ghost["lines"]
	match Quests.state(quest):
		"none":
			Quests.start(quest)
			return Loc.t(str(lines["greet"]))
		"active":
			return Loc.t(str(lines["waiting"]))
	laid_ghosts.append(ghost_id)
	Knowledge.add_points("rest", 5)
	Skills.add_xp("keeping", 50)
	for gift in ghost.get("gift", []):
		if Inventory.add(str(gift[0]), int(gift[1])) != int(gift[1]):
			Mail.send("mail.ghost_gift", [], 0, [gift])
	if ghost_id == "ghost_ulrika":
		if Game.flag("keeper_word"):
			Knowledge.add_points("rest", 20)
		Game.set_flag("keeper_word")
	recalc_peace()
	Events.ghost_laid_to_rest.emit(ghost_id)
	return Loc.t(str(lines["done"]))


func serialize() -> Dictionary:
	return {"bodies": bodies, "graves": graves, "peace": peace, "incoming": incoming,
		"registry_extra": registry_extra, "laid_ghosts": laid_ghosts, "replies": replies,
		"carried": carried, "next_id": next_id}


func deserialize(d: Dictionary) -> void:
	reset()
	if d.has("graves") and d["graves"] is Array and d["graves"].size() == graves.size():
		graves = d["graves"].duplicate(true)
		for g in graves:
			for key in ["plot", "dug", "quality"]:
				g[key] = int(g.get(key, 0))
	bodies = d.get("bodies", []).duplicate(true)
	for b in bodies:
		b["arrived"] = int(b.get("arrived", 0))
		b["coffin"] = int(b.get("coffin", 0))
		b["preservation"] = float(b.get("preservation", 100.0))
		if b.has("plot"):
			b["plot"] = int(b["plot"])
	for entry in d.get("incoming", []):
		incoming.append({"ship": str(entry["ship"]), "arrive": int(entry["arrive"]), "beach": str(entry["beach"]),
			"registry": str(entry.get("registry", "")), "type": str(entry.get("type", ""))})
	registry_extra = d.get("registry_extra", []).duplicate(true)
	for entry in registry_extra:
		entry["age"] = int(entry.get("age", 0))
		if entry.has("family"):
			entry["family"]["money"] = int(entry["family"].get("money", 0))
	laid_ghosts = d.get("laid_ghosts", []).duplicate()
	replies = d.get("replies", []).duplicate(true)
	for r in replies:
		r["due"] = int(r["due"])
	carried = str(d.get("carried", ""))
	next_id = maxi(int(d.get("next_id", 1)), 1)
	peace = float(d.get("peace", 0.0))
