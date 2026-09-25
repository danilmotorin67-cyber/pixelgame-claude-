extends Node2D
class_name Pickups

const TILE := 16


func _ready() -> void:
	name = "Pickups"
	Events.tide_changed.connect(_on_tide_changed)
	Events.night_resolved.connect(func(_report: Dictionary) -> void: rebuild())
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var map_id := Router.current_map
	var row0 := Sea.first_row(map_id)
	for gift in Sea.gifts.get(map_id, []):
		_spawn(gift, Vector2(int(gift["x"]) * TILE + 8, (row0 + int(gift["row"])) * TILE + 8), true)
	for spot in Farm.wild.get(map_id, []):
		_spawn(spot, Vector2(int(spot["x"]) * TILE + 8, int(spot["y"]) * TILE + 8), false)
	Sea.ensure_pools()
	for pool in Sea.pools.get(map_id, []):
		_feature("pool", pool, Vector2(int(pool["x"]) * TILE + 8, (row0 + int(pool["row"])) * TILE + 8))
	for spot in Sea.clams:
		if str(spot["map"]) == map_id:
			_feature("clam", spot, Vector2(int(spot["x"]) * TILE + 8, (row0 + int(spot["row"])) * TILE + 8))
	for g in Sea.gear:
		if str(g["map"]) == map_id:
			_feature(str(g["kind"]), g, Vector2(float(g["x"]), float(g["y"])))
	if map_id == "wreck_bay":
		for i in Crafting.HULLS.size():
			if Crafting.hull_standing(i):
				var hull := BigHull.new()
				hull.index = i
				hull.position = Vector2(int(Crafting.HULLS[i][0]) * TILE + 8, int(Crafting.HULLS[i][1]) * TILE + 8)
				add_child(hull)
	_on_tide_changed(Clock.tide_height())


func _spawn(entry: Dictionary, at: Vector2, beach: bool) -> void:
	var spot := PickupSpot.new()
	spot.entry = entry
	spot.beach = beach
	spot.position = at
	add_child(spot)


func _feature(kind: String, entry: Dictionary, at: Vector2) -> void:
	var node := ShoreFeature.new()
	node.kind = kind
	node.entry = entry
	node.position = at
	add_child(node)


func _on_tide_changed(_level: float) -> void:
	for spot in get_children():
		if spot is PickupSpot and spot.beach:
			spot.set_available(Sea.is_dry(spot.entry))
		elif spot is ShoreFeature:
			spot.refresh()
