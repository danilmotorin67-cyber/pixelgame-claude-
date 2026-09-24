extends Node2D
class_name Stations


func _ready() -> void:
	name = "Stations"
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	for obj in Crafting.placed.get(Router.current_map, []):
		var node := StationObject.new()
		node.uid = int(obj["uid"])
		node.station_id = str(obj["id"])
		node.position = Vector2(float(obj["x"]), float(obj["y"]))
		add_child(node)
