extends Control
class_name EnergyHud

var energy := 270.0
var maximum := 270.0
# 8.3: the Cold, a thin blue column beside the energy (frosty white at the Shivers).
var cold := 0.0


func set_energy(value: float, max_value: float) -> void:
	energy = value
	maximum = maxf(max_value, 1.0)
	queue_redraw()


func set_cold(value: float) -> void:
	cold = value
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 22, 65), Color("#121a26"))
	draw_rect(Rect2(0, 0, 22, 1), Color("#b08f6c"))
	draw_rect(Rect2(0, 64, 22, 1), Color("#b08f6c"))
	draw_rect(Rect2(6, 5, 10, 53), Color("#45464e"))
	var height := int(51.0 * clampf(energy / maximum, 0.0, 1.0))
	if height > 0:
		var tired := energy <= maximum * float(Game.balance("fatigue_share", 0.15))
		draw_rect(Rect2(7, 57 - height, 8, height), Color("#b04a3a") if tired else Color("#e9a64a"))
		draw_rect(Rect2(7, 57 - height, 2, height), Color("#ffc85a"))
	draw_rect(Rect2(9, 60, 5, 1), Color("#ffe9a8"))
	if cold > 0.5:
		var h := int(51.0 * clampf(cold / 100.0, 0.0, 1.0))
		draw_rect(Rect2(17, 7, 3, 51), Color("#24405a"))
		draw_rect(Rect2(17, 58 - h, 3, h), Color("#e8f4f8") if cold >= 100.0 else (Color("#6fb3c9") if cold >= 50.0 else Color("#3f7f8f")))
