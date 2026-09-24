extends Area2D
class_name WaterPump


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 14)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-2, -12, 4, 14), Color("#45464e"))
	draw_rect(Rect2(-6, -12, 8, 2), Color("#45464e"))
	draw_rect(Rect2(-4, 2, 8, 3), Color("#2f5a76"))


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node("HUD/Hint") as Label
	hint.text = "Ведро пресной воды набрано." if Inventory.add("fresh_water", 1) == 1 else "Некуда налить."
