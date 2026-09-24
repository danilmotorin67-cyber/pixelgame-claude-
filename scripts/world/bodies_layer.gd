extends Node2D
class_name BodiesLayer


func _ready() -> void:
	name = "BodiesLayer"
	rebuild()
	Events.night_resolved.connect(func(_r: Dictionary) -> void: rebuild())
	Events.hour_changed.connect(func(_h: int) -> void: rebuild_ghosts())


func rebuild() -> void:
	for child in get_children():
		child.free()
	var map_id := Router.current_map
	for b in Graveyard.bodies:
		if str(b["map"]) == map_id and str(b["where"]) in ["shore", "ground"]:
			var node := BodyObject.new()
			node.body_id = str(b["id"])
			node.position = Vector2(float(b["x"]), float(b["y"]))
			add_child(node)
	for rock in Farm.rocks.get(map_id, []):
		var stone := RockObject.new()
		stone.rock = rock
		stone.position = Vector2(int(rock["x"]) * 16 + 8, int(rock["y"]) * 16 + 8)
		add_child(stone)
	rebuild_ghosts()


func rebuild_ghosts() -> void:
	for child in get_children():
		if child is GhostObject:
			child.free()
	if Router.current_map != "cape" or not Clock.is_night():
		return
	for ghost in Graveyard.present_ghosts():
		var node := GhostObject.new()
		node.ghost_id = str(ghost["id"])
		node.position = Graveyard.plot_position(Graveyard.ghost_plot(ghost)) + Vector2(0, -20)
		add_child(node)
