extends Node

# Animals of section 14: bought from Margit, housed in Ilm's buildings, fed with hay from the hayloft
# (sheep and goats graze seaweed on the shore pasture), petted daily; products wait in the house's box.
const PET_FRIENDSHIP := 15
const MAX_FRIENDSHIP := 1000
const BIG_EGG_FRIENDSHIP := 200

var herd: Array = []
var next_id: int = 1
# Products waiting to be collected, per home building: {home: [[item, count, quality], ...]}.
var boxes: Dictionary = {}
var manure: float = 0.0
var riding: bool = false


func _ready() -> void:
	reset()


func reset() -> void:
	herd.clear()
	boxes.clear()
	next_id = 1
	manure = 0.0
	riding = false


func kind_info(kind: String) -> Dictionary:
	return Data.by_id("animals", kind)


func count_in(home: String) -> int:
	var n := 0
	for a in herd:
		if str(kind_info(str(a["kind"])).get("home", "")) == home:
			n += 1
	return n


func free_nests() -> Array:
	var used := {}
	for a in herd:
		if a.has("nest"):
			used[int(a["nest"])] = true
	return Crafting.objects("cape", "eider_nest").filter(func(o: Dictionary) -> bool: return not used.has(int(o["uid"])))


# "" when Margit can sell this animal now, otherwise why not.
func buy_reason(kind: String) -> String:
	var info := kind_info(kind)
	if info.is_empty():
		return "unknown"
	if Clock.day_index < int(info.get("after_day", 0)):
		return "season"
	var home := str(info["home"])
	if home == "eider_nest":
		if free_nests().is_empty():
			return "home"
	elif Buildings.level(home) < int(info.get("level", 1)) or count_in(home) >= Buildings.capacity(home):
		return "home"
	if not Economy.can_pay(int(info["price"])):
		return "money"
	return ""


func buy(kind: String, animal_name: String = "") -> String:
	var reason := buy_reason(kind)
	if reason != "":
		return reason
	var info := kind_info(kind)
	Economy.pay(int(info["price"]))
	var animal := {"id": next_id, "kind": kind, "name": animal_name if animal_name != "" else Loc.t(str(info["name"])),
		"friendship": 0, "fed": -1, "petted": -1, "last": Clock.day_index, "bought": Clock.day_index}
	if str(info["home"]) == "eider_nest":
		animal["nest"] = int(free_nests()[0]["uid"])
	next_id += 1
	var first := true
	for a in herd:
		first = first and str(a["kind"]) != kind
	herd.append(animal)
	if first:
		Knowledge.add_points("land", 3)
	return "ok"


func find(id: int) -> Dictionary:
	for a in herd:
		if int(a["id"]) == id:
			return a
	return {}


func pet(id: int) -> bool:
	var a := find(id)
	if a.is_empty() or int(a["petted"]) == Clock.day_index:
		return false
	a["petted"] = Clock.day_index
	var gain := PET_FRIENDSHIP * (2 if Skills.has_profession("herder") else 1)
	a["friendship"] = mini(MAX_FRIENDSHIP, int(a["friendship"]) + gain)
	Skills.add_xp("farming", 2)
	return true


func outdoors() -> bool:
	return Clock.hour >= 7 and Clock.hour < 18 and Weather.current not in ["storm", "blizzard", "rain", "snow"]


# 14.3: feed from the hayloft; sheep and goats graze seaweed on the pasture (not in winter or storms).
func _feed(a: Dictionary, weather_today: String) -> bool:
	var info := kind_info(str(a["kind"]))
	if str(info.get("feed", "")) == "":
		return true
	if bool(info.get("seaweed", false)) and Buildings.level("pasture") > 0 and Clock.season != "winter" \
			and weather_today not in ["storm", "blizzard"]:
		return true
	if Buildings.hay > 0:
		Buildings.hay -= 1
		return true
	return false


func _quality(a: Dictionary, rng: RandomNumberGenerator, wool_or_milk: bool) -> int:
	var f := float(a["friendship"]) / float(MAX_FRIENDSHIP)
	var excellent := 0.1 * f + (0.25 if wool_or_milk and Skills.has_profession("surf_shepherd") else 0.0)
	if rng.randf() < excellent:
		return 2
	if rng.randf() < 0.2 + 0.5 * f:
		return 1
	return 0


# Night step: animals eat, make their products into the box of their house, the barn fills with manure.
func night(weather_today: String) -> Dictionary:
	var made := 0
	var hungry := 0
	for a in herd:
		var info := kind_info(str(a["kind"]))
		var rng := RandomNumberGenerator.new()
		rng.seed = posmod(Game.world_seed * 3571 + Clock.day_index * 409 + int(a["id"]) * 31, 2147483647)
		if str(a["kind"]) == "eider":
			if Clock.season == "spring" and int(a.get("down_year", 0)) != Clock.year:
				a["down_year"] = Clock.year
				a["down"] = 2 if Skills.has_profession("down_keeper") else 1
				made += 1
			continue
		var fed := _feed(a, weather_today)
		if not fed:
			hungry += 1
			a["friendship"] = maxi(0, int(a["friendship"]) - 10)
			continue
		a["fed"] = Clock.day_index
		manure += float(info.get("manure", 0.0))
		var every := int(info.get("every", 0))
		if every <= 0 or Clock.day_index - int(a["last"]) < every:
			continue
		a["last"] = Clock.day_index
		var product := str(info["product"])
		if info.has("big") and int(a["friendship"]) >= BIG_EGG_FRIENDSHIP and rng.randf() < 0.5:
			product = str(info["big"])
		var quality := _quality(a, rng, product in ["wool", "milk", "goat_milk"])
		_put(str(info["home"]), product, 1, quality)
		if info.has("extra") and rng.randf() < float(info.get("extra_chance", 0.0)):
			_put(str(info["home"]), str(info["extra"]), 1, 0)
		made += 1
	while manure >= 1.0:
		manure -= 1.0
		_put("barn", "manure", 1, 0)
	return {"products": made, "hungry": hungry}


func _put(home: String, id: String, count: int, quality: int) -> void:
	var box: Array = boxes.get(home, [])
	for entry in box:
		if str(entry[0]) == id and int(entry[2]) == quality:
			entry[1] = int(entry[1]) + count
			boxes[home] = box
			return
	box.append([id, count, quality])
	boxes[home] = box


func box_count(home: String) -> int:
	var n := 0
	for entry in boxes.get(home, []):
		n += int(entry[1])
	return n


# Collecting from the box by the coop or barn: farming XP 5 per animal product (25.2).
func collect(home: String) -> int:
	var box: Array = boxes.get(home, [])
	var taken := 0
	while not box.is_empty() and Inventory.can_fit(str(box[0][0]), int(box[0][1]), int(box[0][2])):
		Inventory.add(str(box[0][0]), int(box[0][1]), int(box[0][2]))
		if str(box[0][0]) != "manure":
			Skills.add_xp("farming", 5 * int(box[0][1]))
		taken += int(box[0][1])
		box.pop_front()
	boxes[home] = box
	return taken


func nest_eider(nest: Dictionary) -> Dictionary:
	for a in herd:
		if int(a.get("nest", -1)) == int(nest.get("uid", -2)):
			return a
	return {}


func nest_status(nest: Dictionary) -> String:
	var a := nest_eider(nest)
	if a.is_empty():
		return "Ящик пуст. Гагу продаёт Маргит (после Птичьего дня)."
	if int(a.get("down", 0)) > 0:
		return "%s оставила пух." % str(a["name"])
	return "%s высиживает. Пух — раз в год, весной." % str(a["name"])


func collect_nest(nest: Dictionary) -> int:
	var a := nest_eider(nest)
	var n := int(a.get("down", 0))
	if n <= 0 or not Inventory.can_fit("eider_down", n):
		return 0
	Inventory.add("eider_down", n)
	a["down"] = 0
	Skills.add_xp("farming", 5)
	return n


func has_pony() -> bool:
	for a in herd:
		if str(a["kind"]) == "pony":
			return true
	return false


func toggle_ride() -> bool:
	if not has_pony() or Router.current_map == "sea" or MapInfo.is_interior(Router.current_map):
		riding = false
		return false
	riding = not riding
	return riding


func ride_speed() -> float:
	return float(kind_info("pony").get("speed", 1.6))


func serialize() -> Dictionary:
	return {"herd": herd, "next_id": next_id, "boxes": boxes, "manure": manure}


func deserialize(d: Dictionary) -> void:
	reset()
	for a in d.get("herd", []):
		if a is Dictionary and not kind_info(str(a.get("kind", ""))).is_empty():
			var copy: Dictionary = a.duplicate(true)
			for key in ["id", "friendship", "fed", "petted", "last", "bought"]:
				copy[key] = int(copy.get(key, 0))
			herd.append(copy)
	next_id = int(d.get("next_id", herd.size() + 1))
	var saved: Dictionary = d.get("boxes", {})
	for home in saved:
		var list: Array = []
		for entry in saved[home]:
			list.append([str(entry[0]), int(entry[1]), int(entry[2])])
		boxes[str(home)] = list
	manure = float(d.get("manure", 0.0))
