extends Control
class_name SeaChartPanel

var _was_paused: bool = false


static func toggle(hud: CanvasLayer) -> void:
	var existing := hud.get_node_or_null("SeaChartPanel")
	if existing:
		existing.close()
		return
	var panel := SeaChartPanel.new()
	panel.name = "SeaChartPanel"
	hud.add_child(panel)


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(80, 20)
	size = Vector2(320, 230)


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#d8c49a"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#6b4a32"), false, 2.0)
	var map_size: Array = SeaChart.cfg("size")
	var scale := minf((size.x - 20) / float(map_size[0]), (size.y - 30) / float(map_size[1]))
	var origin := Vector2(10, 20)
	var chunk := int(SeaChart.cfg("chunk"))
	for cy in range(0, int(map_size[1]), chunk):
		for cx in range(0, int(map_size[0]), chunk):
			var key := "%d,%d" % [cx / chunk, cy / chunk]
			var cell := Rect2(origin + Vector2(cx, cy) * scale, Vector2(chunk, chunk) * scale)
			draw_rect(cell, Color("#8fb0c0") if Sea.revealed.has(key) else Color("#8c7a66"))
	draw_rect(Rect2(origin, Vector2(float(map_size[0]), float(SeaChart.cfg("coast_rows"))) * scale), Color("#4e6e3a"))
	var zone_y := origin.y + float(SeaChart.cfg("zone2_row")) * scale
	draw_line(Vector2(origin.x, zone_y), Vector2(origin.x + float(map_size[0]) * scale, zone_y), Color("#6b4a32"), 1.0)
	for place in SeaChart.cfg("places"):
		var at: Array = SeaChart.cfg("places")[place]["at"]
		var p := origin + Vector2(int(at[0]), int(at[1])) * scale
		if Sea.revealed.has(SeaChart.chunk_key(SeaChart.place_pos(place))):
			draw_circle(p, 2.5, Color("#9b2f2a"))
			draw_string(ThemeDB.fallback_font, p + Vector2(4, 3), Loc.t("sea." + place), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color("#2a2a30"))
	var scene := get_tree().current_scene
	if Router.current_map == "sea" and scene and scene.get_node_or_null("Player"):
		var boat_at: Vector2 = scene.get_node("Player").global_position / 16.0
		draw_circle(origin + boat_at * scale, 3.0, Color("#ffc85a"))
	draw_string(ThemeDB.fallback_font, Vector2(10, 14), "Морская карта · M — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color("#2a2a30"))
