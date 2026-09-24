extends Area2D
class_name RockObject

var rock: Dictionary = {}


func _ready() -> void:
	collision_layer = 9
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 10)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-7, -5, 14, 9), Color("#6f6a60"))
	draw_rect(Rect2(-5, -6, 8, 3), Color("#9a9ca3"))
	draw_rect(Rect2(-3, -5, 3, 1), Color("#c9c8c2"))


func use_tool(player: Player, tool: String) -> String:
	if tool != "tool_pick":
		return ""
	if player.energy <= 0.0:
		return "Нужен отдых, сил на работу нет."
	player.spend_energy("pick")
	var got := Farm.hit_rock(Router.current_map, rock)
	if got > 0:
		queue_free()
		return "Камень: +%d" % got
	return "Камень треснул."
