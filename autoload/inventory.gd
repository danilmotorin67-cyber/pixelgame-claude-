extends Node

var slots: Array = []
const MAX_SLOTS := 36
const HOTBAR := 12
var selected_hotbar: int = 0

func _ready() -> void:
	reset()


func reset() -> void:
	slots.clear()
	selected_hotbar = 0
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
	for s in slots:
		if s["id"] == id and int(s["quality"]) == quality:
			var can := maxi(stack - int(s["count"]), 0)
			var n := mini(can, left)
			s["count"] = int(s["count"]) + n
			left -= n
			if left <= 0:
				break
	if left > 0:
		for s in slots:
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

func serialize() -> Dictionary:
	return {"slots": slots, "selected_hotbar": selected_hotbar}

func deserialize(d: Dictionary) -> void:
	var loaded = d.get("slots", [])
	if loaded is Array and loaded.size() == MAX_SLOTS:
		slots = loaded
		for slot in slots:
			slot["count"] = int(slot.get("count", 0))
			slot["quality"] = int(slot.get("quality", 0))
	selected_hotbar = clampi(int(d.get("selected_hotbar", 0)), 0, HOTBAR - 1)
	Events.inventory_changed.emit()
