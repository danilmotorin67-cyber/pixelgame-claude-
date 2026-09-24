extends Node

# Ilm's buildings (21.5): one order at a time, paid in crowns and materials; the work starts the day after
# payment and takes the listed days. Levels go 0 (not built) .. N.
var levels: Dictionary = {}
# {id, level, done_day} or {}.
var order: Dictionary = {}
var hay: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	levels.clear()
	order.clear()
	hay = 0


func info(id: String) -> Dictionary:
	return Data.by_id("buildings", id)


func level(id: String) -> int:
	return int(levels.get(id, 0))


func max_level(id: String) -> int:
	return info(id).get("levels", []).size()


func next_level_info(id: String) -> Dictionary:
	var lv := level(id)
	var list: Array = info(id).get("levels", [])
	return list[lv] if lv < list.size() else {}


# "" when Ilm can take the order now, otherwise why not.
func blocked_reason(id: String) -> String:
	var b := info(id)
	if b.is_empty():
		return "unknown"
	if not order.is_empty():
		return "busy"
	if level(id) >= max_level(id):
		return "done"
	var req := str(b.get("requires", ""))
	if req.begins_with("node:") and not Knowledge.unlocked.has(req.substr(5)):
		return "blueprint"
	if id == "boathouse" and Sea.boat != "sloop":
		return "boat"
	if id == "bot" and Sea.boat == "bot":
		return "done"
	var next := next_level_info(id)
	if not Economy.can_pay(int(next.get("price", 0))):
		return "money"
	for need in next.get("items", []):
		if Inventory.count_of(str(need[0])) < int(need[1]):
			return "materials"
	return ""


func place_order(id: String) -> String:
	var reason := blocked_reason(id)
	if reason != "":
		return reason
	var next := next_level_info(id)
	for need in next.get("items", []):
		Inventory.take(str(need[0]), int(need[1]))
	Economy.pay(int(next.get("price", 0)))
	order = {"id": id, "level": level(id) + 1, "done_day": Clock.day_index + 1 + int(next.get("days", 1))}
	return "ok"


func days_left() -> int:
	return maxi(0, int(order.get("done_day", 0)) - Clock.day_index) if not order.is_empty() else 0


# Night step: Ilm finishes the building; its effects start the next morning.
func night() -> String:
	if order.is_empty() or Clock.day_index < int(order["done_day"]):
		return ""
	var id := str(order["id"])
	levels[id] = int(order["level"])
	order.clear()
	_apply(id)
	Skills.add_xp("crafting", 20)
	return id


func _apply(id: String) -> void:
	var lv := level(id)
	var data: Dictionary = info(id)["levels"][lv - 1]
	var gifts: Array = data.get("gives", [])
	if not gifts.is_empty():
		Mail.send("mail.building_done", [Loc.t(str(info(id)["name"]))], 0, gifts)
	match id:
		"graveyard_ext":
			Graveyard.extend_plots(int(data.get("plots", 12)))
		"boathouse", "bot":
			Sea.set_boat("bot")
		"greenhouse_small":
			Farm.open_plot("greenhouse_small")
		"cranberry_bog":
			var bog := Crafting._add("cape", "tree", 360, 520)
			bog["tree"] = "bog_cranberry"
			bog["age"] = 0
			bog["grown"] = false
			bog["fruit"] = 0
	Game.set_flag("built_" + id)


func capacity(id: String) -> int:
	var lv := level(id)
	if lv <= 0:
		return 0
	return int(info(id)["levels"][lv - 1].get("capacity", 0))


func hay_capacity() -> int:
	return capacity("hayloft")


# The hayloft takes hay (and kelp for the Surf Shepherd, 25.2) as feed.
func store_feed(id: String, count: int) -> int:
	if level("hayloft") <= 0:
		return 0
	if id != "hay" and not (id == "kelp" and Skills.has_profession("surf_shepherd")):
		return 0
	var n := mini(count, hay_capacity() - hay)
	if n <= 0 or not Inventory.take(id, n):
		return 0
	hay += n
	return n


func serialize() -> Dictionary:
	return {"levels": levels, "order": order, "hay": hay}


func deserialize(d: Dictionary) -> void:
	reset()
	var saved: Dictionary = d.get("levels", {})
	for id in saved:
		if not info(str(id)).is_empty():
			levels[str(id)] = int(saved[id])
	var o: Dictionary = d.get("order", {})
	if o.has("id") and not info(str(o["id"])).is_empty():
		order = {"id": str(o["id"]), "level": int(o["level"]), "done_day": int(o["done_day"])}
	hay = int(d.get("hay", 0))
