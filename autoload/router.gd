extends Node

const ISLAND_MAPS := ["cape", "village", "moor", "birch", "seal_shore",
	"wreck_bay", "bird_cliffs", "lagoon"]
const TOWER_MAPS := ["lh_1", "lh_2", "lh_3", "lh_4"]
const TOWER_SCENE := "res://scenes/world/lighthouse_interior.tscn"
const SEA_SCENE := "res://scenes/world/sea.tscn"
const DEEP_SCENE := "res://scenes/world/deep.tscn"
# Totems of 19.6 land here: the cape house, the grotto shore of the bay, the chapel porch.
const WARP_SPAWNS := {"cape": Vector2(600, 360), "wreck_bay": Vector2(11 * 16 + 8, 24 * 16 + 8), "village": Vector2(17 * 16 + 8, 43 * 16 + 8)}

var current_map: String = ""
var spawn: Vector2 = Vector2(600, 360)


func serialize() -> Dictionary:
	return {"current_map": current_map, "spawn_x": spawn.x, "spawn_y": spawn.y}


func deserialize(d: Dictionary) -> void:
	current_map = str(d.get("current_map", "cape"))
	spawn = Vector2(float(d.get("spawn_x", 600)), float(d.get("spawn_y", 360)))


func _default_spawn(id: String) -> Vector2:
	if id == "cape":
		return Vector2(600, 360)
	if TOWER_MAPS.has(id):
		return Vector2(10 * 16 + 8, 9 * 16 + 8)
	if MapInfo.is_interior(id):
		var inside := MapInfo.size(id)
		return Vector2((inside.x / 2 + 0.5) * 16, (inside.y - 2 + 0.5) * 16)
	if id == "sea":
		var dock: Array = Game.balance("sea", {}).get("dock", [45, 7])
		return Vector2(int(dock[0]) * 16 + 8, int(dock[1]) * 16 + 8)
	var entry: Dictionary = Data.tables.get("regions", {}).get(id, {})
	var size: Array = entry.get("size", [50, 40])
	return Vector2(int(size[0]) * 8, int(size[1]) * 8)


func goto_map(id: String, pos: Vector2 = Vector2.ZERO) -> bool:
	if not ISLAND_MAPS.has(id) and not TOWER_MAPS.has(id) and id not in ["sea", "deep", "grotto"] and not MapInfo.is_interior(id):
		return false
	var path := "res://scenes/world/island_region.tscn"
	if id == "cape":
		path = "res://scenes/world/cape.tscn"
	elif TOWER_MAPS.has(id):
		path = TOWER_SCENE
	elif id == "sea":
		path = SEA_SCENE
	elif id == "deep":
		path = DEEP_SCENE
	elif id == "grotto":
		path = "res://scenes/world/grotto.tscn"
	if not ResourceLoader.exists(path):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var previous_map := current_map
	var previous_spawn := spawn
	var previous_state := Game.player_state.duplicate(true)
	var active := tree.current_scene
	var from_world := false
	if active:
		var player: Player = active.get_node_or_null("Player") as Player
		if player:
			from_world = true
			Game.player_state = player.serialize_state()
	if pos == Vector2.ZERO and from_world:
		pos = _default_spawn(id)
	if pos != Vector2.ZERO:
		spawn = pos
		var state := Game.player_state.duplicate(true)
		state["x"] = pos.x
		state["y"] = pos.y
		Game.player_state = state
	current_map = id
	if tree.change_scene_to_file(path) != OK:
		current_map = previous_map
		spawn = previous_spawn
		Game.player_state = previous_state
		return false
	return true
