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
	_on_tide_changed(Clock.tide_height())


func _spawn(entry: Dictionary, at: Vector2, beach: bool) -> void:
	var spot := PickupSpot.new()
	spot.entry = entry
	spot.beach = beach
	spot.position = at
	add_child(spot)


func _on_tide_changed(_level: float) -> void:
	for spot in get_children():
		if spot is PickupSpot and spot.beach:
			spot.set_available(Sea.is_dry(spot.entry))
