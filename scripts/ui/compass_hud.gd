extends Panel
class_name CompassHud

# 30.1, top left: the keeper's Compass — Light (amber, lamp), Peace (lilac, candle), Sea (teal, wave),
# each an icon, its value and a short bar, in the compass-rose frame.
const ICONS := ["hud_light", "hud_peace", "hud_sea"]
const COLORS := [Color("#ffc85a"), Color("#a06a9e"), Color("#6fb0b3")]
const CELL := 47.0
var light: float = 0.0
var peace: float = 0.0
var sea: float = 20.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box("compass"))


func set_values(new_light: float, new_peace: float, new_sea: float) -> void:
	light = new_light
	peace = new_peace
	sea = new_sea
	queue_redraw()


func _draw() -> void:
	var values := [light, peace, sea]
	var font := UiKit.font()
	for index in 3:
		var x := 7.0 + index * CELL
		if not UiKit.draw_icon(self, ICONS[index], Vector2(x, 7)):
			draw_rect(Rect2(x + 4, 11, 8, 8), COLORS[index])
		var value := int(values[index])
		draw_string(font, Vector2(x + 18, 15), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(x + 18, 14), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLORS[index].lightened(0.25))
		draw_rect(Rect2(x + 18, 17, 24, 5), UiKit.INK)
		var width := roundf(22.0 * clampf(float(values[index]) / 100.0, 0.0, 1.0))
		if width > 0:
			draw_rect(Rect2(x + 19, 18, width, 3), COLORS[index])
			draw_rect(Rect2(x + 19, 18, width, 1), COLORS[index].lightened(0.35))
