extends Node2D
class_name StorySpots

# The story's places on the current map (spots, ghosts away from graves, the festival stand); rebuilt every hour
# and whenever the story moves.
var map_id: String = ""


func _ready() -> void:
	name = "StorySpots"
	Events.hour_changed.connect(func(_h: int) -> void: refresh())
	Events.quest_step_done.connect(func(_q: String) -> void: call_deferred("refresh"))
	Events.quest_started.connect(func(_q: String) -> void: call_deferred("refresh"))
	Events.festival_started.connect(func(_f: String) -> void: call_deferred("refresh"))
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	for spot in Story.spots_on(map_id):
		var at: Array = spot.get("at", [0, 0])
		var pos := Vector2(int(at[0]) * 16 + 8, int(at[1]) * 16 + 8)
		if str(spot.get("kind", "")) == "ghost":
			if Graveyard.laid_ghosts.has(str(spot["ghost"])) or Game.flag("ghosts_gone"):
				continue
			var ghost := GhostObject.new()
			ghost.ghost_id = str(spot["ghost"])
			ghost.position = pos
			add_child(ghost)
			continue
		var obj := StoryObject.new()
		obj.spot = spot
		obj.position = pos
		add_child(obj)
	var f := Festivals.today()
	if not f.is_empty() and str(f.get("map", "")) == map_id and Festivals.open_now(f):
		var stand := StoryObject.new()
		stand.spot = {"id": "festival_" + str(f["id"]), "kind": "festival", "title": "festival.%s.name" % f["id"]}
		var s: Array = f.get("stand", [30, 30])
		stand.position = Vector2(int(s[0]) * 16 + 8, int(s[1]) * 16 + 8)
		add_child(stand)
