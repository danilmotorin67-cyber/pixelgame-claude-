extends Node2D

var elapsed: float = 0.0


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.get_screen_center_position() - get_viewport_rect().size / 2.0
	if Weather.current in ["rain", "storm", "snow", "blizzard", "fog"] or Router.current_map == "sea":
		if not Clock.paused:
			elapsed += delta
		queue_redraw()


func _draw() -> void:
	var kind := Weather.current
	# At sea, fog and the Hmar close in around the boat (not for the Fog Navigator).
	if Router.current_map == "sea" and SeaChart.view_narrowed():
		var mist := Color(0.62, 0.66, 0.68) if kind == "fog" else Color(0.16, 0.14, 0.2)
		for y in range(0, 270, 10):
			for x in range(0, 480, 10):
				var d := Vector2(x + 5, y + 5).distance_to(Vector2(240, 135))
				var a := clampf((d - 70.0) / 60.0, 0.0, 0.85)
				if a > 0.0:
					draw_rect(Rect2(x, y, 10, 10), Color(mist, a))
	if kind == "fog":
		for band in 4:
			draw_rect(Rect2(0, 40 + band * 57, 480, 8), Color(0.79, 0.83, 0.81, 0.12))
		return
	if kind not in ["rain", "storm", "snow", "blizzard"]:
		return
	var snow := kind in ["snow", "blizzard"]
	var amount := 85 if kind in ["storm", "blizzard"] else 45
	var speed := 30.0 if snow else 115.0
	for i in amount:
		var x := fposmod(float(i * 131 % 479) + elapsed * (55.0 if snow else 80.0), 480.0)
		var y := fposmod(float(i * 73 % 269) + elapsed * speed, 270.0)
		if snow:
			draw_rect(Rect2(x, y, 2, 2), Color(0.89, 0.93, 0.94, 0.8))
		else:
			draw_line(Vector2(x, y), Vector2(x - 2, y + 5),
				Color(0.66, 0.78, 0.89, 0.7), 1.0)
