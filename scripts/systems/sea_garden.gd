class_name SeaGarden
extends RefCounted

# 13.10: a 12×8 patch of sea by the cape pier. Kelp lines, mussel ropes and oyster cages are set and
# harvested from the boat; a storm may tear one loose (a thread mends it); kelp grows half as fast in winter.
const TILE := 16
const KINDS := {
	"kelp_line": {"first": 12, "every": 6, "item": "kelp", "amount": [5, 8]},
	"mussel_rope": {"first": 14, "every": 1, "item": "mussels", "amount": [1, 3]},
	"oyster_cage": {"first": 21, "every": 3, "item": "oyster", "amount": [1, 1], "pearl": 0.03},
}
const STORM_LOSS := 0.1


static func area() -> Rect2i:
	var at: Array = SeaChart.cfg("places")["sea_garden"]["at"]
	return Rect2i(int(at[0]) - 6, int(at[1]) - 3, 12, 8)


static func days(kind: String, key: String) -> int:
	var n := int(KINDS[kind][key])
	return n * 2 if kind == "kelp_line" and Clock.season == "winter" else n


static func at_cell(cell: Vector2i) -> Dictionary:
	for g in Sea.sea_garden:
		if int(g["x"]) == cell.x and int(g["y"]) == cell.y:
			return g
	return {}


# "ok", "area" (outside the patch or on land), "taken" or "unknown".
static func place(item_id: String, at: Vector2) -> String:
	var kind := str(Data.by_id("items", item_id).get("sea_garden", ""))
	if not KINDS.has(kind):
		return "unknown"
	var cell := Vector2i(floori(at.x / TILE), floori(at.y / TILE))
	if not area().has_point(cell) or SeaChart.is_land(at):
		return "area"
	if not at_cell(cell).is_empty():
		return "taken"
	if not Inventory.take(item_id, 1):
		return "unknown"
	Sea.sea_garden.append({"kind": kind, "x": cell.x, "y": cell.y, "planted": Clock.day_index,
		"next": Clock.day_index + days(kind, "first"), "ready": false, "broken": false})
	return "ok"


static func night(storm: bool) -> void:
	for g in Sea.sea_garden:
		var rng := RandomNumberGenerator.new()
		rng.seed = posmod(Game.world_seed * 887 + Clock.day_index * 53 + int(g["x"]) * 7 + int(g["y"]), 2147483647)
		if bool(g["broken"]):
			continue
		if storm and rng.randf() < STORM_LOSS:
			g["broken"] = true
			g["ready"] = false
			continue
		if Clock.day_index >= int(g["next"]):
			g["ready"] = true


# Interacting from the boat: mend a torn object with a thread, or take the harvest.
static func work(g: Dictionary) -> String:
	if bool(g["broken"]):
		if not Inventory.take("thread", 1):
			return "Сорвано штормом. Починить — 1 нитки."
		g["broken"] = false
		g["next"] = maxi(int(g["next"]), Clock.day_index + 1)
		return "Починено."
	if not bool(g["ready"]):
		return "Растёт. Ещё %d дн." % maxi(0, int(g["next"]) - Clock.day_index)
	var info: Dictionary = KINDS[str(g["kind"])]
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 613 + Clock.day_index * 31 + int(g["x"]) * 3 + int(g["y"]), 2147483647)
	var n := rng.randi_range(int(info["amount"][0]), int(info["amount"][1]))
	if not Inventory.can_fit(str(info["item"]), n):
		return "Рюкзак полон."
	Inventory.add(str(info["item"]), n)
	var text := "%s ×%d" % [Crafting.item_name(str(info["item"])), n]
	if rng.randf() < float(info.get("pearl", 0.0)) and Inventory.add("pearl", 1) == 1:
		text += " и жемчужина!"
	g["ready"] = false
	g["next"] = Clock.day_index + days(str(g["kind"]), "every")
	Skills.add_xp("fishing", 5)
	return "Собрано: " + text
