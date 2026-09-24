extends Node

const DEFAULT_PLACED := {"cape": [["workbench", 560, 372], ["hearth", 536, 330], ["compost_pit", 648, 392]]}
const PLACE_REACH := 48.0

# Station objects per map: {uid, id, x, y, queue: [{recipe, ready_at}], slots: [...]}.
var placed: Dictionary = {}
var learned: Dictionary = {}
var next_uid: int = 1


func _ready() -> void:
	reset()


func reset() -> void:
	placed.clear()
	learned.clear()
	next_uid = 1
	for map_id in DEFAULT_PLACED:
		for entry in DEFAULT_PLACED[map_id]:
			_add(map_id, str(entry[0]), int(entry[1]), int(entry[2]))


func now() -> int:
	return Clock.day_index * Clock.MINUTES_PER_DAY + Clock.minutes


func station(id: String) -> Dictionary:
	return Data.by_id("stations", id)


func _add(map_id: String, id: String, x: int, y: int) -> Dictionary:
	var obj := {"uid": next_uid, "id": id, "x": x, "y": y, "queue": []}
	next_uid += 1
	if str(station(id).get("kind", "")) == "storage":
		var slots: Array = []
		for i in int(station(id).get("slots", 24)):
			slots.append({"id": "", "count": 0, "quality": 0})
		obj["slots"] = slots
	if not placed.has(map_id):
		placed[map_id] = []
	placed[map_id].append(obj)
	return obj


func find(map_id: String, uid: int) -> Dictionary:
	for obj in placed.get(map_id, []):
		if int(obj["uid"]) == uid:
			return obj
	return {}


func learn(recipe_id: String) -> void:
	learned[recipe_id] = true


func knows(recipe: Dictionary) -> bool:
	return str(recipe.get("unlock", "")) == "start" or learned.has(str(recipe.get("id", "")))


func recipes_for(station_id: String) -> Array:
	var list: Array = []
	for table in ["recipes_craft", "recipes_cook"]:
		for recipe in Data.all(table):
			if str(recipe.get("station", "")) == station_id and knows(recipe):
				list.append(recipe)
	return list


func has_ingredients(recipe: Dictionary) -> bool:
	for need in recipe.get("in", []):
		if Inventory.count_matching(str(need[0])) < int(need[1]):
			return false
	return true


func _fuel_for(station_id: String) -> String:
	for fuel in station(station_id).get("fuel", []):
		if Inventory.count_of(str(fuel)) > 0:
			return str(fuel)
	return ""


# Workbench and hearth: instant, consumes ingredients (and one fuel at the hearth).
func make(recipe_id: String) -> String:
	var recipe := _recipe(recipe_id)
	if recipe.is_empty() or not knows(recipe):
		return "unknown"
	var info := station(str(recipe["station"]))
	if str(info.get("kind", "")) not in ["instant", "cook"]:
		return "unknown"
	if not has_ingredients(recipe):
		return "ingredients"
	var fuel := ""
	if info.has("fuel"):
		fuel = _fuel_for(str(recipe["station"]))
		if fuel == "":
			return "fuel"
	var out: Array = recipe["out"]
	if not Inventory.can_fit(str(out[0]), int(out[1])):
		return "space"
	for need in recipe["in"]:
		Inventory.take_matching(str(need[0]), int(need[1]))
	if fuel != "":
		Inventory.take(fuel, 1)
	Inventory.add(str(out[0]), int(out[1]))
	if str(info["kind"]) == "instant":
		Skills.add_xp("crafting", 2 + recipe["in"].size())
	return "ok"


func _recipe(recipe_id: String) -> Dictionary:
	for table in ["recipes_craft", "recipes_cook"]:
		var recipe := Data.by_id(table, recipe_id)
		if not recipe.is_empty():
			return recipe
	return {}


# Process stations queue up to three jobs that run one after another in game time.
func start(obj: Dictionary, recipe_id: String) -> String:
	var recipe := _recipe(recipe_id)
	if recipe.is_empty() or str(recipe["station"]) != str(obj["id"]) or not knows(recipe):
		return "unknown"
	var queue: Array = obj["queue"]
	if queue.size() >= int(station(str(obj["id"])).get("queue", 3)):
		return "full"
	if not has_ingredients(recipe):
		return "ingredients"
	for need in recipe["in"]:
		Inventory.take_matching(str(need[0]), int(need[1]))
	var begin := now()
	if not queue.is_empty():
		begin = maxi(begin, int(queue[-1]["ready_at"]))
	queue.append({"recipe": recipe_id, "ready_at": begin + int(recipe.get("minutes", 60))})
	return "ok"


func ready_jobs(obj: Dictionary) -> int:
	var n := 0
	for job in obj.get("queue", []):
		if int(job["ready_at"]) <= now():
			n += 1
	return n


func collect(obj: Dictionary) -> int:
	var queue: Array = obj.get("queue", [])
	var taken := 0
	while not queue.is_empty() and int(queue[0]["ready_at"]) <= now():
		var recipe := _recipe(str(queue[0]["recipe"]))
		var out: Array = recipe["out"]
		if not Inventory.can_fit(str(out[0]), int(out[1])):
			break
		Inventory.add(str(out[0]), int(out[1]))
		Skills.add_xp("crafting", clampi(int(recipe.get("minutes", 60)) / 720, 1, 5))
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


func can_place_at(map_id: String, at: Vector2) -> bool:
	for obj in placed.get(map_id, []):
		if Vector2(float(obj["x"]), float(obj["y"])).distance_to(at) < 16.0:
			return false
	return true


func place_selected(map_id: String, at: Vector2) -> bool:
	var index := Inventory.selected_hotbar
	var id := str(Inventory.slots[index]["id"])
	var station_id := str(Data.by_id("items", id).get("place", ""))
	var snapped := Vector2(floorf(at.x / 16.0) * 16.0 + 8.0, floorf(at.y / 16.0) * 16.0 + 8.0)
	if station_id == "" or not can_place_at(map_id, snapped) or not Inventory.take_slot(index, 1):
		return false
	_add(map_id, station_id, int(snapped.x), int(snapped.y))
	return true


func pick_up(map_id: String, obj: Dictionary) -> bool:
	var item := str(station(str(obj["id"])).get("item", ""))
	if item == "" or not Inventory.can_fit(item, 1):
		return false
	for slot in obj.get("slots", []):
		if str(slot["id"]) != "":
			return false
	placed[map_id].erase(obj)
	Inventory.add(item, 1)
	return true


func store(obj: Dictionary, index: int) -> bool:
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	if id == "" or not obj.has("slots"):
		return false
	var count := int(slot["count"])
	var quality := int(slot["quality"])
	var stack := int(Data.by_id("items", id).get("stack", 99))
	var room := 0
	for s in obj["slots"]:
		if str(s["id"]) == "":
			room += stack
		elif str(s["id"]) == id and int(s["quality"]) == quality:
			room += maxi(stack - int(s["count"]), 0)
	if room < count:
		return false
	Inventory.take_slot(index, count)
	var left := count
	for pass_empty in [false, true]:
		for s in obj["slots"]:
			if left <= 0:
				break
			var fits: bool = (str(s["id"]) == "") if pass_empty \
				else (str(s["id"]) == id and int(s["quality"]) == quality)
			if fits:
				var n := mini(stack - int(s["count"]), left)
				s["id"] = id
				s["quality"] = quality
				s["count"] = int(s["count"]) + n
				left -= n
	return true


func retrieve(obj: Dictionary, index: int) -> bool:
	var slots: Array = obj.get("slots", [])
	if index < 0 or index >= slots.size() or str(slots[index]["id"]) == "":
		return false
	var s: Dictionary = slots[index]
	if not Inventory.can_fit(str(s["id"]), int(s["count"]), int(s["quality"])):
		return false
	Inventory.add(str(s["id"]), int(s["count"]), int(s["quality"]))
	s["id"] = ""
	s["count"] = 0
	s["quality"] = 0
	return true


func serialize() -> Dictionary:
	return {"placed": placed, "learned": learned, "next_uid": next_uid}


func deserialize(d: Dictionary) -> void:
	reset()
	if not d.has("placed"):
		return
	placed.clear()
	var saved: Dictionary = d.get("placed", {})
	for map_id in saved:
		var list: Array = []
		for obj in saved[map_id]:
			var restored := {"uid": int(obj["uid"]), "id": str(obj["id"]), "x": int(obj["x"]),
				"y": int(obj["y"]), "queue": []}
			for job in obj.get("queue", []):
				restored["queue"].append({"recipe": str(job["recipe"]), "ready_at": int(job["ready_at"])})
			if obj.has("slots"):
				var slots: Array = []
				for s in obj["slots"]:
					slots.append({"id": str(s["id"]), "count": int(s["count"]), "quality": int(s["quality"])})
				restored["slots"] = slots
			list.append(restored)
		placed[map_id] = list
	learned = d.get("learned", {}).duplicate()
	next_uid = maxi(int(d.get("next_uid", 1)), 1)
