extends Area2D
class_name SeaGardenObject

# A kelp line, mussel rope or oyster cage in the sea garden; E from the boat mends or harvests it.
var entry: Dictionary = {}


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	var color := {"kelp_line": Color("#4e6e3a"), "mussel_rope": Color("#2a2a40"), "oyster_cage": Color("#9a9ca3")}.get(str(entry.get("kind", "")), Color.WHITE) as Color
	draw_circle(Vector2(0, -2), 3, Color("#e9643a") if not bool(entry.get("broken", false)) else Color("#6b6b73"))
	draw_rect(Rect2(-6, 2, 12, 2), color)
	if bool(entry.get("ready", false)):
		draw_circle(Vector2(6, -6), 2, Color("#ffc85a"))


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	var text := SeaGarden.work(entry)
	if hint:
		hint.text = text
	queue_redraw()
