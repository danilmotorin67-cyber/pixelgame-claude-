extends Control
class_name EnergyHud

var energy := 270.0


func set_energy(value: float) -> void:
	energy = value
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 22, 65), Color("#121a26"))
	draw_rect(Rect2(0, 0, 22, 1), Color("#b08f6c"))
	draw_rect(Rect2(0, 64, 22, 1), Color("#b08f6c"))
	draw_rect(Rect2(6, 5, 10, 53), Color("#45464e"))
	var height := int(51.0 * clampf(energy / 270.0, 0.0, 1.0))
	if height > 0:
		draw_rect(Rect2(7, 57 - height, 8, height), Color("#e9a64a"))
		draw_rect(Rect2(7, 57 - height, 2, height), Color("#ffc85a"))
	draw_rect(Rect2(9, 60, 5, 1), Color("#ffe9a8"))
