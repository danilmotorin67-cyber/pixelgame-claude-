extends Node2D
class_name NpcLayer

# Shows the islanders whose logical position is on this map (33.7).
var map_id: String = ""
var _actors: Dictionary = {}


func _ready() -> void:
	name = "NpcLayer"
	y_sort_enabled = true
	NPCs.sync()
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var here := NPCs.on_map(map_id)
	for id in _actors.keys():
		if not here.has(id):
			_actors[id].queue_free()
			_actors.erase(id)
	for id in here:
		if not _actors.has(id):
			var actor := NpcActor.new()
			actor.setup(id)
			add_child(actor)
			_actors[id] = actor


func actor(id: String) -> NpcActor:
	return _actors.get(id, null)
