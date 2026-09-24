extends Node2D
class_name Farmstead

# Ilm's buildings and the animals on the cape; rebuilt each morning as buildings are finished.


func _ready() -> void:
	name = "Farmstead"
	rebuild()
	Events.night_resolved.connect(func(_r: Dictionary) -> void: rebuild())
	Events.hour_changed.connect(func(h: int) -> void:
		if h == 7 or h == 18:
			rebuild())


func rebuild() -> void:
	for child in get_children():
		child.free()
	for b in Data.all("buildings"):
		var id := str(b["id"])
		if Buildings.level(id) <= 0 or not BuildingObject.LOOK.has(id):
			continue
		var node := BuildingObject.new()
		node.name = "Building_" + id
		node.building = id
		node.position = BuildingObject.home_of(id)
		add_child(node)
		if id == "well":
			var pump := WaterPump.new()
			pump.name = "WellPump"
			pump.position = node.position + Vector2(0, 14)
			add_child(pump)
	if not Animals.outdoors():
		return
	var index := 0
	for a in Animals.herd:
		var info := Animals.kind_info(str(a["kind"]))
		var home := str(info.get("home", ""))
		var at := BuildingObject.home_of(home)
		if home == "eider_nest":
			var nest := Crafting.find("cape", int(a.get("nest", -1)))
			if nest.is_empty():
				continue
			at = Vector2(float(nest["x"]), float(nest["y"])) + Vector2(0, -12)
		elif at == Vector2.ZERO:
			continue
		elif bool(info.get("seaweed", false)) and Buildings.level("pasture") > 0:
			at = BuildingObject.home_of("pasture")
		var rng := RandomNumberGenerator.new()
		rng.seed = int(a["id"]) * 977 + Clock.day_index
		var animal := AnimalObject.new()
		animal.animal_id = int(a["id"])
		animal.position = at + Vector2(rng.randf_range(-40, 40), rng.randf_range(28, 52)) if home != "eider_nest" else at
		animal.name = "Animal_%d" % int(a["id"])
		add_child(animal)
		index += 1
