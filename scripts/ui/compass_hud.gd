extends Panel
class_name CompassHud

# Native-resolution indicator bars use the three story colors of full.md.
var light: float = 0.0
var peace: float = 0.0
var sea: float = 20.0


func set_values(new_light: float, new_peace: float, new_sea: float) -> void:
	light = new_light
	peace = new_peace
	sea = new_sea
	queue_redraw()


func _draw() -> void:
	var values := [light, peace, sea]
	var colors := [Color("#ffc85a"), Color("#a06a9e"), Color("#6fb0b3")]
	for index in 3:
		var x := 10 + index * 68
		draw_rect(Rect2(x, 24, 59, 5), Color("#121a26"))
		draw_rect(Rect2(x + 1, 25, 57, 3), Color("#45464e"))
		var width := int(57.0 * clampf(values[index] / 100.0, 0.0, 1.0))
		if width > 0:
			draw_rect(Rect2(x + 1, 25, width, 3), colors[index])
