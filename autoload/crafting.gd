extends Node

# Stations of 19.2: instant benches, cooking, timed process stations (queue of 3), storage, cellar barrels,
# hives, garden fixtures, trees and decorations, all placed objects of a map.
const DEFAULT_PLACED := {"cape": [["workbench", 560, 372], ["hearth", 536, 330], ["compost_pit", 648, 392],
	["cutting_table", 520, 372]]}
const PLACE_REACH := 48.0
const PLACE_MAPS := ["cape", "cape_workshop"]
const HIVE_MAPS := ["cape", "moor"]
const CELLAR_STEPS := [19, 38, 56]
const HIVE_DAYS := 4
const OUTDOOR_WET := ["rain", "storm", "snow", "blizzard", "fog"]
const DOUBLE_BATCH := ["smelt_iron", "smelt_iron_baron", "smelt_copper", "smelt_silver", "smelt_gold", "alloy_brass", "alloy_bronze"]
const GATHER_BEACHES := ["cape", "seal_shore", "wreck_bay", "village"]
const BIRCH_CHOPS_PER_DAY := 6

# Station objects per map: {uid, id, x, y, queue: [{recipe, ready_at, quality, mult}], slots: [...]}.
var placed: Dictionary = {}
var learned: Dictionary = {}
var next_uid: int = 1
# Items made so far (26.1: a new dish +1 land note, a new artisan good +2, every 10 crafted things +1).
var made: Dictionary = {}
var crafted_total: int = 0
var last_energy: float = 0.0


func _ready() -> void:
	reset()
	Events.hour_changed.connect(func(_h: int) -> void: sweep_receivers())


func reset() -> void:
	placed.clear()
	learned.clear()
	made.clear()
	crafted_total = 0
	next_uid = 1
	last_energy = 0.0
	for map_id in DEFAULT_PLACED:
		for entry in DEFAULT_PLACED[map_id]:
			_add(map_id, str(entry[0]), int(entry[1]), int(entry[2]))


func now() -> int:
	return Clock.day_index * Clock.MINUTES_PER_DAY + Clock.minutes


func station(id: String) -> Dictionary:
	return Data.by_id("stations", id)


func kind_of(obj: Dictionary) -> String:
	return str(station(str(obj.get("id", ""))).get("kind", ""))


func _add(map_id: String, id: String, x: int, y: int) -> Dictionary:
	var obj := {"uid": next_uid, "id": id, "x": x, "y": y, "queue": []}
	next_uid += 1
	var info := station(id)
	if info.has("slots"):
		var slots: Array = []
		for i in int(info["slots"]):
			slots.append({"id": "", "count": 0, "quality": 0})
		obj["slots"] = slots
	match str(info.get("kind", "")):
		"hive":
			obj["next"] = Clock.day_index + hive_days()
			obj["stock"] = []
			obj["made"] = 0
		"fixture":
			obj["water"] = int(Game.balance("garden", {}).get("water_days", {}).get(id, 0))
	if not placed.has(map_id):
		placed[map_id] = []
	placed[map_id].append(obj)
	return obj


func add_prefilled(map_id: String, id: String, x: int, y: int, items: Array) -> Dictionary:
	var obj := _add(map_id, id, x, y)
	for index in mini(items.size(), obj.get("slots", []).size()):
		obj["slots"][index] = {"id": str(items[index][0]), "count": int(items[index][1]), "quality": 0}
	return obj


func find(map_id: String, uid: int) -> Dictionary:
	for obj in placed.get(map_id, []):
		if int(obj["uid"]) == uid:
			return obj
	return {}


func objects(map_id: String, id: String) -> Array:
	return placed.get(map_id, []).filter(func(o: Dictionary) -> bool: return str(o["id"]) == id)


# ---- recipes and what the keeper knows ----

func learn(recipe_id: String) -> void:
	learned[recipe_id] = true


# `unlock` lists alternatives separated by "|": start, learn (letters, quests, pages), gazette, node:ID,
# skill:NAME:LEVEL, hearts:NPC:N (arrives by letter), flag:ID, profession:ID.
func knows(recipe: Dictionary) -> bool:
	if learned.has(str(recipe.get("id", ""))):
		return true
	for alt in str(recipe.get("unlock", "start")).split("|"):
		var parts := alt.split(":")
		match parts[0]:
			"start":
				return true
			"node":
				if Knowledge.unlocked.has(parts[1]):
					return true
			"skill":
				if Skills.base_level(parts[1]) >= int(parts[2]):
					return true
			"flag":
				if Game.flag(parts[1]):
					return true
			"profession":
				if Skills.has_profession(parts[1]):
					return true
	return false


func _recipe(recipe_id: String) -> Dictionary:
	for table in ["recipes_craft", "recipes_cook"]:
		var recipe := Data.by_id(table, recipe_id)
		if not recipe.is_empty():
			return recipe
	return {}


func all_recipes() -> Array:
	return Data.all("recipes_craft") + Data.all("recipes_cook")


func station_makes(station_id: String, recipe: Dictionary) -> bool:
	var home := str(recipe.get("station", ""))
	return home == station_id or home in station(station_id).get("also", [])


func recipes_for(station_id: String) -> Array:
	var list: Array = []
	for recipe in all_recipes():
		if station_makes(station_id, recipe) and knows(recipe):
			list.append(recipe)
	return list


func has_ingredients(recipe: Dictionary, mult: int = 1) -> bool:
	for need in recipe.get("in", []):
		if Inventory.count_matching(str(need[0])) < int(need[1]) * mult:
			return false
	return true


# Night step (mail): recipes promised in 20 for N hearts arrive by letter once the friendship is there.
func recipe_letters() -> int:
	var sent := 0
	for recipe in all_recipes():
		var id := str(recipe["id"])
		if learned.has(id):
			continue
		for alt in str(recipe.get("unlock", "")).split("|"):
			var parts := alt.split(":")
			if parts[0] == "hearts" and Relationships.hearts_of(parts[1]) >= int(parts[2]):
				learn(id)
				var npc_name := Loc.t(str(Data.by_id("npcs", parts[1]).get("name", parts[1])))
				Mail.send("mail.recipe_letter", [npc_name, item_name(str(recipe["out"][0]))])
				sent += 1
	return sent


# The Sunday gazette prints one kitchen column a week, going round the "gazette" recipes.
func gazette_recipe() -> String:
	var pool: Array = []
	for recipe in all_recipes():
		if str(recipe.get("unlock", "")) == "gazette":
			pool.append(str(recipe["id"]))
	if pool.is_empty():
		return ""
	var id: String = pool[posmod(Clock.day_index / 7, pool.size())]
	learn(id)
	return id


static func item_name(id: String) -> String:
	if id.begins_with("tag:"):
		return Loc.t("tag." + id.substr(4))
	return Loc.t(str(Data.by_id("items", id).get("name", id)))


# ---- fuel, speed, quality ----

func _fuel_options(station_id: String) -> Array:
	var out: Array = []
	for fuel in station(station_id).get("fuel", []):
		out.append([str(fuel[0]), int(fuel[1])] if fuel is Array else [str(fuel), 1])
	return out


func fuel_for(station_id: String) -> Array:
	for option in _fuel_options(station_id):
		if Inventory.count_of(str(option[0])) >= int(option[1]):
			return option
	return []


func fuel_text(station_id: String) -> String:
	var parts: Array[String] = []
	for option in _fuel_options(station_id):
		parts.append("%s ×%d" % [item_name(str(option[0])), int(option[1])])
	return " или ".join(parts)


# 25.2: stations work 2% faster per Crafting level; Craftsman +25%; Margit's thread +10%.
func speed_factor() -> float:
	var faster := 1.0 + (0.25 if Skills.has_profession("craftsman") else 0.0) + Game.effect("station_speed")
	return (1.0 - 0.02 * float(Skills.base_level("crafting"))) / faster


func job_minutes(recipe: Dictionary) -> int:
	return maxi(1, int(round(float(recipe.get("minutes", 60)) * speed_factor())))


func _double_batch(recipe: Dictionary) -> bool:
	return str(recipe["id"]) in DOUBLE_BATCH and (Inventory.count_of("forge_tongs") > 0 or Skills.has_profession("artel")) \
		and has_ingredients(recipe, 2)


# Takes the ingredients; the main (first) one is taken from the best stack and sets the product's quality.
func _take_ingredients(recipe: Dictionary, mult: int) -> int:
	var quality := 0
	var first := true
	for need in recipe["in"]:
		var q := Inventory.take_matching_best(str(need[0]), int(need[1]) * mult) if first \
			else (0 if Inventory.take_matching(str(need[0]), int(need[1]) * mult) else 0)
		if first:
			quality = maxi(q, 0)
		first = false
	return quality


func _product_quality(out_id: String, quality: int) -> int:
	if not bool(Data.by_id("items", out_id).get("quality", false)):
		return 0
	if Skills.has_profession("optician") and out_id in ["glass", "prism"]:
		return maxi(quality, 1)
	return quality


func _note_made(out_id: String, n: int) -> void:
	var item := Data.by_id("items", out_id)
	var first := not made.has(out_id)
	made[out_id] = int(made.get(out_id, 0)) + n
	if first and item.has("dish"):
		Knowledge.add_points("land", 1)
	elif first and (str(item.get("category", "")) == "artisan" or bool(item.get("artisan", false))):
		Knowledge.add_points("land", 2)
	var before := crafted_total / 10
	crafted_total += n
	if crafted_total / 10 > before:
		Knowledge.add_points("land", crafted_total / 10 - before)


# ---- instant benches and cooking ----

# Workbench, sawhorse, cutting table, hearth and stove: instant; `count` repeats up to the station's batch.
func make(recipe_id: String, count: int = 1, station_id: String = "") -> String:
	var recipe := _recipe(recipe_id)
	if recipe.is_empty() or not knows(recipe):
		return "unknown"
	var sid := station_id if station_id != "" else str(recipe["station"])
	if not station_makes(sid, recipe):
		return "unknown"
	var info := station(sid)
	if str(info.get("kind", "")) not in ["instant", "cook"]:
		return "unknown"
	count = clampi(count, 1, int(info.get("batch", 1)))
	last_energy = 0.0
	for n in count:
		var result := _make_once(recipe, sid, info)
		if result != "ok":
			return "ok" if n > 0 else result
	return "ok"


func _make_once(recipe: Dictionary, sid: String, info: Dictionary) -> String:
	if not has_ingredients(recipe):
		return "ingredients"
	var fuel: Array = []
	if info.has("fuel"):
		fuel = fuel_for(sid)
		if fuel.is_empty():
			return "fuel"
	var out: Array = recipe["out"]
	if not Inventory.can_fit(str(out[0]), int(out[1])):
		return "space"
	for extra in recipe.get("extra", []):
		if not Inventory.can_fit(str(extra[0]), int(extra[1])):
			return "space"
	var quality := _product_quality(str(out[0]), _take_ingredients(recipe, 1))
	if not fuel.is_empty():
		Inventory.take(str(fuel[0]), int(fuel[1]))
	Inventory.add(str(out[0]), int(out[1]), quality)
	for extra in recipe.get("extra", []):
		Inventory.add(str(extra[0]), int(extra[1]))
	last_energy += float(recipe.get("energy", 0))
	if str(info["kind"]) == "instant":
		Skills.add_xp("crafting", 2 + recipe["in"].size())
	_note_made(str(out[0]), int(out[1]))
	return "ok"


# ---- process stations ----

func start(obj: Dictionary, recipe_id: String) -> String:
	var recipe := _recipe(recipe_id)
	if recipe.is_empty() or not station_makes(str(obj["id"]), recipe) or not knows(recipe):
		return "unknown"
	var info := station(str(obj["id"]))
	var queue: Array = obj["queue"]
	if queue.size() >= int(info.get("queue", 3)):
		return "full"
	if not has_ingredients(recipe):
		return "ingredients"
	var fuel: Array = []
	if info.has("fuel"):
		fuel = fuel_for(str(obj["id"]))
		if fuel.is_empty():
			return "fuel"
	var mult := 2 if _double_batch(recipe) else 1
	var quality := _take_ingredients(recipe, mult)
	if not fuel.is_empty():
		Inventory.take(str(fuel[0]), int(fuel[1]))
	var begin := now()
	if not queue.is_empty():
		begin = maxi(begin, int(queue[-1]["ready_at"]))
	queue.append({"recipe": recipe_id, "ready_at": begin + job_minutes(recipe), "quality": quality, "mult": mult})
	Skills.add_xp("crafting", 2 + recipe["in"].size())
	return "ok"


func ready_jobs(obj: Dictionary) -> int:
	var n := 0
	for job in obj.get("queue", []):
		if int(job["ready_at"]) <= now():
			n += 1
	return n


# What a finished job yields: [[id, count, quality], ...] (deterministic per job).
func job_outputs(obj: Dictionary, job: Dictionary) -> Array:
	var recipe := _recipe(str(job["recipe"]))
	var out: Array = recipe["out"]
	var mult := int(job.get("mult", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 131 + int(job["ready_at"]) * 7 + int(obj.get("uid", 0)), 2147483647)
	var count := int(out[1]) * mult
	if recipe.has("out_range"):
		count = 0
		for m in mult:
			count += rng.randi_range(int(recipe["out_range"][0]), int(recipe["out_range"][1]))
	var id := str(out[0])
	if id == "prism" and Skills.has_profession("optician") and rng.randf() < 0.25:
		count += 1
	var result: Array = [[id, count, _product_quality(id, int(job.get("quality", 0)))]]
	for extra in recipe.get("extra", []):
		result.append([str(extra[0]), int(extra[1]) * mult, 0])
	return result


func _job_xp(job: Dictionary) -> int:
	return clampi(int(_recipe(str(job["recipe"])).get("minutes", 60)) / 720, 1, 5)


func collect(obj: Dictionary) -> int:
	var queue: Array = obj.get("queue", [])
	var taken := 0
	while not queue.is_empty() and int(queue[0]["ready_at"]) <= now():
		var outs := job_outputs(obj, queue[0])
		var fits := true
		for o in outs:
			fits = fits and Inventory.can_fit(str(o[0]), int(o[1]), int(o[2]))
		if not fits:
			break
		for o in outs:
			Inventory.add(str(o[0]), int(o[1]), int(o[2]))
			_note_made(str(o[0]), int(o[1]))
		Skills.add_xp("crafting", _job_xp(queue[0]))
		queue.pop_front()
		taken += 1
	return taken


# Night step 5: count what finished overnight for the morning report.
func finished_overnight() -> int:
	var total := 0
	for map_id in placed:
		for obj in placed[map_id]:
			total += ready_jobs(obj)
	return total


# ---- storage (chests, receiver chests, cellar barrels) ----

func _room(slots: Array, id: String, quality: int) -> int:
	var stack := int(Data.by_id("items", id).get("stack", 99))
	var room := 0
	for s in slots:
		if str(s["id"]) == "":
			room += stack
		elif str(s["id"]) == id and int(s["quality"]) == quality:
			room += maxi(stack - int(s["count"]), 0)
	return room


func _put(slots: Array, id: String, count: int, quality: int) -> void:
	var stack := int(Data.by_id("items", id).get("stack", 99))
	var left := count
	for pass_empty in [false, true]:
		for s in slots:
			if left <= 0:
				break
			var fits: bool = (str(s["id"]) == "") if pass_empty else (str(s["id"]) == id and int(s["quality"]) == quality)
			if fits:
				var n := mini(stack - int(s["count"]), left)
				s["id"] = id
				s["quality"] = quality
				s["count"] = int(s["count"]) + n
				left -= n


func cellar_accepts(obj: Dictionary, id: String) -> bool:
	for need in station(str(obj["id"])).get("ages", []):
		if Inventory.matches(id, str(need)):
			return true
	return false


func store(obj: Dictionary, index: int) -> bool:
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	if id == "" or not obj.has("slots"):
		return false
	var count := int(slot["count"])
	var quality := int(slot["quality"])
	if kind_of(obj) == "cellar":
		var cask: Dictionary = obj["slots"][0]
		if not cellar_accepts(obj, id) or str(cask["id"]) != "":
			return false
		Inventory.take_slot(index, count)
		obj["slots"][0] = {"id": id, "count": count, "quality": quality, "base": quality, "since": Clock.day_index}
		return true
	if _room(obj["slots"], id, quality) < count:
		return false
	Inventory.take_slot(index, count)
	_put(obj["slots"], id, count, quality)
	return true


func retrieve(obj: Dictionary, index: int) -> bool:
	var slots: Array = obj.get("slots", [])
	if index < 0 or index >= slots.size() or str(slots[index]["id"]) == "":
		return false
	var s: Dictionary = slots[index]
	if not Inventory.can_fit(str(s["id"]), int(s["count"]), int(s["quality"])):
		return false
	Inventory.add(str(s["id"]), int(s["count"]), int(s["quality"]))
	slots[index] = {"id": "", "count": 0, "quality": 0}
	return true


# 19.2: the receiver chest gathers finished work from stations within its radius (in tiles).
func sweep_receivers() -> int:
	var moved := 0
	for map_id in placed:
		for chest in placed[map_id]:
			var radius := int(station(str(chest["id"])).get("collects", 0))
			if radius <= 0:
				continue
			var at := Vector2(float(chest["x"]), float(chest["y"]))
			for obj in placed[map_id]:
				if obj == chest or not obj.has("queue") or at.distance_to(Vector2(float(obj["x"]), float(obj["y"]))) > radius * 16.0 + 8.0:
					continue
				var queue: Array = obj["queue"]
				while not queue.is_empty() and int(queue[0]["ready_at"]) <= now():
					var outs := job_outputs(obj, queue[0])
					var fits := true
					for o in outs:
						fits = fits and _room(chest["slots"], str(o[0]), int(o[2])) >= int(o[1])
					if not fits:
						break
					for o in outs:
						_put(chest["slots"], str(o[0]), int(o[1]), int(o[2]))
						_note_made(str(o[0]), int(o[1]))
					Skills.add_xp("crafting", _job_xp(queue[0]))
					queue.pop_front()
					moved += 1
	return moved


# ---- the night: cellars age, hives fill, trees grow, wet weather slows the drying racks ----

func night(weather_today: String) -> Dictionary:
	var report := {"honey": 0, "fruit": 0, "aged": 0}
	for map_id in placed:
		for obj in placed[map_id]:
			match kind_of(obj):
				"cellar":
					report["aged"] += _age_cask(obj)
				"hive":
					report["honey"] += _hive_night(map_id, obj)
				"tree":
					report["fruit"] += _tree_night(map_id, obj, weather_today)
				"process":
					if bool(station(str(obj["id"])).get("outdoor", false)) and weather_today in OUTDOOR_WET:
						for job in obj["queue"]:
							if int(job["ready_at"]) > now():
								job["ready_at"] = int(job["ready_at"]) + 12 * 60
	sweep_receivers()
	return report


func _age_cask(obj: Dictionary) -> int:
	var cask: Dictionary = obj["slots"][0]
	if str(cask["id"]) == "":
		return 0
	var days := Clock.day_index - int(cask.get("since", Clock.day_index))
	var steps := 0
	for threshold in CELLAR_STEPS:
		if days >= threshold:
			steps += 1
	var quality := mini(3, int(cask.get("base", 0)) + steps)
	if quality != int(cask["quality"]):
		cask["quality"] = quality
		return 1
	return 0


func hive_days() -> int:
	return 3 if Skills.base_level("farming") >= 9 else HIVE_DAYS


# 14.2: honey every 4 days but not in winter; heather on the moor, sea buckthorn within 5 tiles.
func honey_kind(map_id: String, obj: Dictionary) -> String:
	if map_id == "moor":
		return "heather_honey"
	for other in placed.get(map_id, []):
		if kind_of(other) == "tree" and str(other.get("tree", "")) == "tree_buckthorn" and bool(other.get("grown", false)) \
				and Vector2(float(other["x"]), float(other["y"])).distance_to(Vector2(float(obj["x"]), float(obj["y"]))) <= 5 * 16 + 8:
			return "buckthorn_honey"
	return "honey"


func _hive_night(map_id: String, obj: Dictionary) -> int:
	if Clock.season == "winter" or Clock.day_index < int(obj.get("next", 0)):
		return 0
	obj["next"] = Clock.day_index + hive_days()
	var stock: Array = obj["stock"]
	stock.append([honey_kind(map_id, obj), 1])
	obj["made"] = int(obj.get("made", 0)) + 1
	if int(obj["made"]) % 3 == 0:
		stock.append(["beeswax", 1])
	return 1


func take_stock(obj: Dictionary) -> int:
	var stock: Array = obj.get("stock", [])
	var taken := 0
	while not stock.is_empty() and Inventory.can_fit(str(stock[0][0]), int(stock[0][1])):
		Inventory.add(str(stock[0][0]), int(stock[0][1]))
		if str(stock[0][0]).ends_with("honey"):
			Skills.add_xp("farming", 5)
		stock.pop_front()
		taken += 1
	return taken


# ---- trees and bushes (13.9) ----

func tree_info(obj: Dictionary) -> Dictionary:
	return Data.by_id("trees", str(obj.get("tree", "")))


func _tree_night(map_id: String, obj: Dictionary, weather_today: String) -> int:
	var info := tree_info(obj)
	obj["age"] = int(obj.get("age", 0)) + 1
	if not bool(obj.get("grown", false)):
		obj["grown"] = int(obj["age"]) >= int(info.get("days", 28))
		return 0
	if Clock.season not in info.get("seasons", []):
		obj["fruit"] = 0
		return 0
	if bool(info.get("storm_drop", false)) and weather_today == "storm" and not sheltered(map_id, Vector2(float(obj["x"]), float(obj["y"]))):
		obj["fruit"] = 0
		return 0
	if Clock.day_index - int(obj.get("last_fruit", -100)) >= int(info.get("every", 1)) and int(obj.get("fruit", 0)) == 0:
		obj["fruit"] = 1
		obj["last_fruit"] = Clock.day_index
		return 1
	return 0


func pick_fruit(obj: Dictionary) -> int:
	var info := tree_info(obj)
	if int(obj.get("fruit", 0)) <= 0 or not Inventory.can_fit(str(info["fruit"]), 5):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 97 + Clock.day_index * 13 + int(obj["uid"]), 2147483647)
	var span: Array = info.get("yield", [1, 3])
	var n := rng.randi_range(int(span[0]), int(span[1]))
	var quality := 1 if Skills.has_profession("herbalist") and rng.randf() < 0.3 else 0
	Inventory.add(str(info["fruit"]), n, quality)
	obj["fruit"] = 0
	Skills.add_xp("foraging", 7)
	return n


# 13.3: stone walls shelter radius 4, sea-buckthorn hedges radius 5.
func sheltered(map_id: String, at: Vector2) -> bool:
	for obj in placed.get(map_id, []):
		var radius := 0
		if str(obj["id"]) == "stone_wall":
			radius = 4
		elif kind_of(obj) == "tree" and str(obj.get("tree", "")) == "tree_buckthorn" and bool(obj.get("grown", false)):
			radius = 5
		if radius > 0 and at.distance_to(Vector2(float(obj["x"]), float(obj["y"]))) <= radius * 16.0 + 8.0:
			return true
	return false


# ---- placing and picking up ----

func can_place_at(map_id: String, at: Vector2) -> bool:
	for obj in placed.get(map_id, []):
		if Vector2(float(obj["x"]), float(obj["y"])).distance_to(at) < 16.0:
			return false
	return true


func place_selected(map_id: String, at: Vector2) -> bool:
	var index := Inventory.selected_hotbar
	var id := str(Inventory.slots[index]["id"])
	var item := Data.by_id("items", id)
	var station_id := str(item.get("place", ""))
	var tree_id := str(item.get("plant", ""))
	var snapped := Vector2(floorf(at.x / 16.0) * 16.0 + 8.0, floorf(at.y / 16.0) * 16.0 + 8.0)
	if station_id == "" and tree_id == "":
		return false
	var maps: Array = HIVE_MAPS if station_id == "beehive" else PLACE_MAPS
	if tree_id != "":
		maps = ["cape"]
	if map_id not in maps or not can_place_at(map_id, snapped) or not Inventory.take_slot(index, 1):
		return false
	if tree_id != "":
		var tree := _add(map_id, "tree", int(snapped.x), int(snapped.y))
		tree["tree"] = tree_id
		tree["age"] = 0
		tree["grown"] = false
		tree["fruit"] = 0
		return true
	var obj := _add(map_id, station_id, int(snapped.x), int(snapped.y))
	if station_id == "decor":
		obj["item"] = id
	return true


func pick_up(map_id: String, obj: Dictionary) -> bool:
	var item := str(obj.get("item", station(str(obj["id"])).get("item", "")))
	if kind_of(obj) == "tree":
		item = ""
	if item == "" or not Inventory.can_fit(item, 1) or not obj.get("queue", []).is_empty():
		return false
	for slot in obj.get("slots", []):
		if str(slot["id"]) != "":
			return false
	if not obj.get("stock", []).is_empty():
		return false
	placed[map_id].erase(obj)
	Inventory.add(item, 1)
	return true


# ---- gathering for the chains (19.1, 19.3) ----

# A shovel on the dry sand of a beach strip gives 1-2 sand.
func dig_sand(map_id: String, at: Vector2) -> int:
	if map_id not in GATHER_BEACHES:
		return 0
	var cell := Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
	var row0 := Sea.first_row(map_id)
	if row0 < 0 or cell.y < row0 - 2 or cell.y >= row0 + Sea.SHORE_ROWS or Fishing.is_water(map_id, at):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 29 + Clock.day_index * 101 + cell.x * 7 + cell.y * 3 + Clock.minutes, 2147483647)
	var n := rng.randi_range(1, 2)
	if not Inventory.can_fit("sand", n):
		return 0
	Inventory.add("sand", n)
	Skills.add_xp("foraging", 1)
	return n


# A bucket (or the belt keg) scoops seawater anywhere the sea reaches.
func scoop_seawater(map_id: String, at: Vector2, amount: int) -> int:
	if map_id in ["moor", "birch"] or not Fishing.is_water(map_id, at) or not Inventory.can_fit("seawater", amount):
		return 0
	Inventory.add("seawater", amount)
	return amount


# An axe in the birch grove fells a few birches a day: a log, bark and chips.
func fell_birch(map_id: String, at: Vector2) -> Dictionary:
	if map_id != "birch" or Fishing.is_water(map_id, at):
		return {}
	var key := "birch_chops_%d" % Clock.day_index
	if int(Game.counters.get(key, 0)) >= BIRCH_CHOPS_PER_DAY:
		return {"done": true}
	if not Inventory.can_fit("birch_log", 1) or not Inventory.can_fit("birch_bark", 1) or not Inventory.can_fit("birch_chips", 2):
		return {}
	Game.counters[key] = int(Game.counters.get(key, 0)) + 1
	Inventory.add("birch_log", 1)
	Inventory.add("birch_bark", 1)
	Inventory.add("birch_chips", 2)
	Skills.add_xp("foraging", 3)
	return {"log": 1}


# ---- save ----

# JSON brings whole numbers back as floats; saved objects keep them as ints.
static func _ints(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = _ints(value[key])
		return out
	if value is Array:
		var list: Array = []
		for entry in value:
			list.append(_ints(entry))
		return list
	return value


func serialize() -> Dictionary:
	return {"placed": placed, "learned": learned, "next_uid": next_uid, "made": made, "crafted_total": crafted_total}


func deserialize(d: Dictionary) -> void:
	reset()
	if not d.has("placed"):
		return
	placed.clear()
	var saved: Dictionary = d.get("placed", {})
	for map_id in saved:
		var list: Array = []
		for obj in saved[map_id]:
			if not (obj is Dictionary) or station(str(obj.get("id", ""))).is_empty():
				continue
			var restored: Dictionary = _ints(obj)
			var queue: Array = []
			for job in obj.get("queue", []):
				queue.append({"recipe": str(job["recipe"]), "ready_at": int(job["ready_at"]),
					"quality": int(job.get("quality", 0)), "mult": int(job.get("mult", 1))})
			restored["queue"] = queue
			list.append(restored)
		placed[map_id] = list
	for map_id in DEFAULT_PLACED:
		for entry in DEFAULT_PLACED[map_id]:
			var present := false
			for obj in placed.get(map_id, []):
				present = present or str(obj["id"]) == str(entry[0])
			if not present:
				_add(map_id, str(entry[0]), int(entry[1]), int(entry[2]))
	learned = d.get("learned", {}).duplicate()
	made = _ints(d.get("made", {}))
	crafted_total = int(d.get("crafted_total", 0))
	next_uid = maxi(int(d.get("next_uid", 1)), next_uid)
