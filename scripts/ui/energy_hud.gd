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
	# The amber column in its frame, the flame above it; the Cold as a thin column beside it.
	draw_style_box(UiKit.box("panel"), Rect2(0, 0, 22, 72))
	if not UiKit.draw_icon(self, "hud_energy", Vector2(3, 3)):
		draw_rect(Rect2(8, 7, 6, 8), Color("#ffc85a"))
	draw_rect(Rect2(6, 20, 10, 47), UiKit.INK)
	var height := roundi(45.0 * clampf(energy / maximum, 0.0, 1.0))
	if height > 0:
		var tired := energy <= maximum * float(Game.balance("fatigue_share", 0.15))
		draw_rect(Rect2(7, 66 - height, 8, height), Color("#b04a3a") if tired else Color("#e9a64a"))
		draw_rect(Rect2(7, 66 - height, 2, height), Color("#ffc85a"))
		draw_rect(Rect2(7, 66 - height, 8, 1), Color("#ffe9a8"))
	if cold > 0.5:
		var h := roundi(45.0 * clampf(cold / 100.0, 0.0, 1.0))
		draw_rect(Rect2(17, 21, 3, 45), Color("#24405a"))
		draw_rect(Rect2(17, 66 - h, 3, h), Color("#e8f4f8") if cold >= 100.0 else (Color("#6fb3c9") if cold >= 50.0 else Color("#3f7f8f")))
		UiKit.draw_icon(self, "hud_cold", Vector2(12, 60), 10.0)
