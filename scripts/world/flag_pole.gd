extends Node2D
class_name FlagPole

# A pennant on a pole (PixelLab loop props/flag_pole_work), fluttering faster the harder the wind blows.
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta * (0.6 + 0.5 * PropArt.wind_lean())
	queue_redraw()


func _draw() -> void:
	if not PropArt.draw_loop(self, "flag_pole_work", Vector2.ZERO, _time, 6.0):
		PropArt.draw(self, "flag_pole", Vector2.ZERO)
