extends Area2D
class_name TowerBell


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 14)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-1, -12, 2, 4), Color("#45464e"))
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-3, -8), Vector2(3, -8), Vector2(5, 0)]),
		Color("#c9a24a"))


func interact(_player: Player) -> void:
	var hint: Label = get_tree().current_scene.get_node("HUD/Hint")
	if not Lighthouse.foggy():
		hint.text = "Колокол нужен в туман и в Ночи Хмари."
	elif Lighthouse.ring_bell():
		hint.text = "Колокол звонит над туманом. Следующий раз — через час."
	else:
		hint.text = "В этот час уже звонили."
