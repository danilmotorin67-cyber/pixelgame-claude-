extends Area2D
class_name SeaEventObject

# One of the events of 16.6 on the water: E from the boat (cargo, a bottle, seals, a stranded fisherman,
# the ghost ship's chest); some are met just by sailing close (birds, whales, orcas, the Eleonora).
const TOUCH := ["bird_frenzy", "whales", "orcas", "ghost_ship"]

var entry: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _say(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint and text != "":
		hint.text = text


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 4.0) != int((_t - delta) * 4.0):
		queue_redraw()
	if bool(entry.get("done", false)) or str(entry["id"]) not in TOUCH:
		return
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player and player.global_position.distance_to(global_position) < 48.0:
		_say(Sea.meet(entry))
		var map := get_parent()
		if str(entry["id"]) == "ghost_ship" and map and map.has_method("rebuild_events"):
			map.rebuild_events()


func interact(_player: Player) -> void:
	_say(Sea.meet(entry))
	queue_redraw()


func _draw() -> void:
	if bool(entry.get("done", false)) and str(entry["id"]) not in ["seals"]:
		return
	var bob := sin(_t * 3.0) * 1.5
	match str(entry["id"]):
		"cargo":
			draw_rect(Rect2(-6, -5 + bob, 12, 9), Color("#8c6a4e"))
		"bottle", "eleonora_chest":
			draw_rect(Rect2(-2, -6 + bob, 4, 9), Color("#6fa07a") if str(entry["id"]) == "bottle" else Color("#6b4a32"))
		"bird_frenzy":
			for i in 6:
				draw_rect(Rect2(Vector2.from_angle(_t + i) * 14.0 + Vector2(0, -10), Vector2(3, 1)), Color("#f0e7cc"))
		"seals":
			draw_circle(Vector2(-6, bob), 4, Color("#6b6058"))
			draw_circle(Vector2(6, 2 + bob), 4, Color("#6b6058"))
		"whales", "orcas":
			draw_rect(Rect2(-14, bob, 28, 5), Color("#2a2a30"))
			draw_rect(Rect2(-2, -8 + bob, 2, 8), Color(0.9, 0.95, 1.0, 0.7))
		"ghost_ship":
			draw_rect(Rect2(-16, bob, 32, 6), Color(0.8, 0.85, 0.9, 0.35))
			draw_rect(Rect2(-1, -18 + bob, 2, 18), Color(0.8, 0.85, 0.9, 0.35))
		"fisher_in_trouble":
			draw_rect(Rect2(-8, bob, 16, 5), Color("#8c6a4e"))
			draw_circle(Vector2(0, -3 + bob), 3, Color("#e0c0a0"))
