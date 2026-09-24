extends Area2D
class_name DeepEntrance

# 17.2: the Well of the Drowned in the bay — anchor over it and go down (from the deepest bell station, 17.2/S5).


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, Color(0.05, 0.1, 0.15, 0.8), 6.0)
	draw_circle(Vector2.ZERO, 10.0, Color(0.02, 0.05, 0.08, 0.9))


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if Deep.max_level() <= 0:
		if hint:
			hint.text = "Колодец Утопленников. Без водолазного колокола вниз не спуститься."
		return
	var starts := Deep.start_levels()
	var from_level: int = starts[-1]
	if Deep.begin(from_level) == "ok":
		Router.goto_map("deep", Deep.cell_center(Deep.data["entry"]))
