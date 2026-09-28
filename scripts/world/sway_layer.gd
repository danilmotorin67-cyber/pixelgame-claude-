extends Node2D
class_name SwayLayer

# Trees, reeds and the like that sway in the wind: the static ground drawing leaves them out and lists them
# here ([art id, bottom] pairs); this layer redraws only them every frame, the ones near the camera.
var items: Array = []
var _time := 0.0


func _process(delta: float) -> void:
	if not Clock.paused:
		_time += delta
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var view := Rect2(-1e6, -1e6, 2e6, 2e6)
	if camera:
		view = Rect2(camera.get_screen_center_position() - Screen.BASE, Screen.BASE * 2.0)
	var lean := PropArt.wind_lean()
	for item in items:
		var bottom: Vector2 = item[1]
		if view.has_point(bottom):
			PropArt.draw_sway(self, str(item[0]), bottom, _time, lean)
