extends Node2D

var elapsed: float = 0.0
# A storm's lightning: a jagged bolt and (unless flashes are turned off in the settings) a white flash.
var _next_bolt := 4.0
var _bolt_t := 0.0
var _bolt: PackedVector2Array = PackedVector2Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.get_screen_center_position() - Screen.BASE / 2.0
	if Weather.current in ["rain", "storm", "snow", "blizzard", "fog"] or Router.current_map == "sea":
		if not Clock.paused:
			elapsed += delta
			_storm(delta)
		queue_redraw()


func _storm(delta: float) -> void:
	_bolt_t = maxf(0.0, _bolt_t - delta)
	if Weather.current != "storm" or Router.current_map in ["deep", "grotto"] or Router.current_map.begins_with("lh_"):
		return
	_next_bolt -= delta
	if _next_bolt > 0.0:
		return
	_next_bolt = _rng.randf_range(5.0, 12.0)
	_bolt_t = 0.35
	AudioMgr.play_sfx("thunder_near", -3.0)
	_bolt = PackedVector2Array()
	var x := _rng.randf_range(60.0, 420.0)
	var y := -4.0
	while y < 150.0:
		_bolt.append(Vector2(x, y))
		x += _rng.randf_range(-12.0, 12.0)
		y += _rng.randf_range(10.0, 22.0)


func _draw() -> void:
	if _bolt_t > 0.0:
		if Settings.lightning_flash:
			draw_rect(Rect2(0, 0, 480, 270), Color(0.9, 0.93, 1.0, 0.45 * _bolt_t / 0.35))
		if _bolt_t > 0.2 and _bolt.size() > 1:
			draw_polyline(_bolt, Color(1.0, 1.0, 0.92), 2.0)
			draw_polyline(_bolt, Color(0.75, 0.85, 1.0, 0.6), 4.0)
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
		# In the Hmar (not plain fog) pale faces drift at the edge of sight.
		if kind != "fog":
			for i in 5:
				var angle := elapsed * 0.05 + float(i) * TAU / 5.0
				var at := Vector2(240, 135) + Vector2(cos(angle) * 120.0, sin(angle) * 80.0)
				CastSprite.draw(self, "hmar_faces", "drift", "south", elapsed + float(i) * 0.6, at)
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
