extends Node2D
class_name BoatArt


func _draw() -> void:
	var player := get_parent() as Player
	var heading := player.boat_heading
	var angle := heading.angle() - PI / 2.0
	draw_set_transform(Vector2(0, -2), angle, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 18), Vector2(-9, 8), Vector2(-9, -14), Vector2(9, -14), Vector2(9, 8)]),
		Color("#6b4a32"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 15), Vector2(-7, 7), Vector2(-7, -12), Vector2(7, -12), Vector2(7, 7)]),
		Color("#b08f6c"))
	draw_rect(Rect2(-7, -2, 14, 2), Color("#6b4a32"))
	if player.sail_up:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(0, 4), Vector2(10, 2)]), Color("#eadcb8"))
		draw_line(Vector2(0, -18), Vector2(0, 6), Color("#45464e"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
