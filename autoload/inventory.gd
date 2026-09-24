extends Node

var slots: Array = []
const MAX_SLOTS := 36
const HOTBAR := 12
const START_CAPACITY := 12
var capacity: int = START_CAPACITY
var selected_hotbar: int = 0

func _ready() -> void:
	reset()


func reset() -> void:
	slots.clear()
	selected_hotbar = 0
	capacity = START_CAPACITY
	for i in MAX_SLOTS:
		slots.append({"id": "", "count": 0, "quality": 0, "meta": {}})
	Events.inventory_changed.emit()


func select_hotbar(index: int) -> void:
	selected_hotbar = posmod(index, HOTBAR)
	Events.inventory_changed.emit()


func selected_id() -> String:
	return str(slots[selected_hotbar]["id"])

func add(id: String, count: int = 1, quality: int = 0) -> int:
	if count <= 0 or not Data.exists("items", id):
		return 0
	var stack := int(Data.by_id("items", id).get("stack", 99))
	var left := count
	var open_slots := slots.slice(0, capacity)
	for s in open_slots:
		if s["id"] == id and int(s["quality"]) == quality:
			var can := maxi(stack - int(s["count"]), 0)
			var n := mini(can, left)
			s["count"] = int(s["count"]) + n
			left -= n
			if left <= 0:
				break
	if left > 0:
		for s in open_slots:
			if s["id"] == "":
				var n := mini(stack, left)
				s["id"] = id
				s["count"] = n
				s["quality"] = quality
				left -= n
				if left <= 0:
					break
	var added := count - left
	if added > 0:
		Events.item_added.emit(id, added)
		Events.inventory_changed.emit()
	return added

func can_fit(id: String, count: int, quality: int = 0) -> bool:
	var stack := int(Data.by_id("items", id).get("stack", 99))
	var room := 0
	for index in capacity:
		var s: Dictionary = slots[index]
		if s["id"] == "":
			room += stack
		elif s["id"] == id and int(s["quality"]) == quality:
			room += maxi(stack - int(s["count"]), 0)
	return room >= count


func upgrade_capacity(new_capacity: int) -> bool:
	if new_capacity <= capacity or new_capacity > MAX_SLOTS:
		return false
	capacity = new_capacity
	Events.inventory_changed.emit()
	return true


# Picking up a find: foraging XP and +2% per foraging level for a double find (25.2).
func forage(id: String, xp: int) -> bool:
	if not can_fit(id, 1):
		return false
	var amount := 1
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 613 + Clock.day_index * 977 + Clock.minutes * 31 + count_of(id), 2147483647)
	if rng.randf() < 0.02 * float(Skills.level("foraging")) and can_fit(id, 2):
		amount = 2
	var quality := 0
	var item := Data.by_id("items", id)
	if Skills.has_profession("herbalist") and str(item.get("category", "")) == "forage" and "seaweed" not in item.get("tags", []) \
			and rng.randf() < 0.3:
		quality = 1
	add(id, amount, quality)
	Skills.add_xp("foraging", xp)
	# 26.1: every new kind of find is a land note.
	if not Game.flag("foraged_" + id):
		Game.set_flag("foraged_" + id)
		Knowledge.add_points("land", 1)
	return true


# `need` is an item id or `tag:<tag>` (33.4).
func matches(id: String, need: String) -> bool:
	if id == "":
		return false
	if need.begins_with("tag:"):
		return need.substr(4) in Data.by_id("items", id).get("tags", [])
	return id == need


# A slot fits `need`: alternatives split by "|", each an id or tag with an optional "@quality" floor.
func slot_matches(index: int, need: String) -> bool:
	var id := str(slots[index]["id"])
	for alt in need.split("|"):
		var parts := alt.split("@")
		if matches(id, parts[0]) and (parts.size() < 2 or int(slots[index]["quality"]) >= int(parts[1])):
			return true
	return false


func count_matching(need: String) -> int:
	var n := 0
	for index in capacity:
		if slot_matches(index, need):
			n += int(slots[index]["count"])
	return n


func take_matching(need: String, count: int) -> bool:
	if count_matching(need) < count:
		return false
	var left := count
	for index in capacity:
		if left <= 0:
			break
		if slot_matches(index, need):
			var n := mini(int(slots[index]["count"]), left)
			take_slot(index, n)
			left -= n
	return true


# Takes `count` matching items from the best stacks first; returns the lowest quality taken (-1 if short).
func take_matching_best(need: String, count: int) -> int:
	if count_matching(need) < count:
		return -1
	var left := count
	var lowest := 3
	while left > 0:
		var best := -1
		for index in capacity:
			if slot_matches(index, need) and (best < 0 or int(slots[index]["quality"]) > int(slots[best]["quality"])):
				best = index
		var n := mini(int(slots[best]["count"]), left)
		lowest = mini(lowest, int(slots[best]["quality"]))
		take_slot(best, n)
		left -= n
	return lowest


func count_of(id: String) -> int:
	var n := 0
	for s in slots:
		if s["id"] == id:
			n += int(s["count"])
	return n

func take(id: String, count: int = 1) -> bool:
	if count_of(id) < count:
		return false
	var left := count
	for s in slots:
		if s["id"] == id:
			var n := mini(int(s["count"]), left)
			s["count"] = int(s["count"]) - n
			left -= n
			if int(s["count"]) <= 0:
				s["id"] = ""
				s["quality"] = 0
				s["meta"] = {}
			if left <= 0:
				Events.inventory_changed.emit()
				return true
	return left <= 0

func take_slot(index: int, count: int) -> bool:
	if index < 0 or index >= slots.size() or count <= 0:
		return false
	var s: Dictionary = slots[index]
	if str(s["id"]) == "" or int(s["count"]) < count:
		return false
	s["count"] = int(s["count"]) - count
	if int(s["count"]) <= 0:
		s["id"] = ""
		s["quality"] = 0
		s["meta"] = {}
	Events.inventory_changed.emit()
	return true

func serialize() -> Dictionary:
	return {"slots": slots, "selected_hotbar": selected_hotbar, "capacity": capacity}

func deserialize(d: Dictionary) -> void:
	var loaded = d.get("slots", [])
	if loaded is Array and loaded.size() == MAX_SLOTS:
		slots = loaded
		for slot in slots:
			slot["count"] = int(slot.get("count", 0))
			slot["quality"] = int(slot.get("quality", 0))
	var used := 0
	for index in slots.size():
		if str(slots[index].get("id", "")) != "":
			used = index + 1
	capacity = clampi(maxi(int(d.get("capacity", START_CAPACITY)), used), START_CAPACITY, MAX_SLOTS)
	selected_hotbar = clampi(int(d.get("selected_hotbar", 0)), 0, HOTBAR - 1)
	Events.inventory_changed.emit()
