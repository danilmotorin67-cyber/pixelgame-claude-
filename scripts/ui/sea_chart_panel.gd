extends Control
class_name SeaChartPanel

# The sea chart (M) as an old pilot chart on parchment: hatched where the keeper has not sailed,
# washed blue by zone where he has, the coast along the top, the zone borders dashed, reefs, the
# known places, the dock and the boat; beside it the legend, the places found and the raven's sight.
const SHEET := Rect2(34, 6, 412, 258)
const MAP := Rect2(48, 24, 180, 210)
const INK := Color("#3a2a20")
const FADED := Color("#8a7458")
const RED := Color("#9b2f2a")
const FOG := Color("#dccaa2")
const LAND := Color("#7a964c")
const ZONES := [Color("#a9cbc6"), Color("#8db4b9"), Color("#7299a8")]
const ZONE_NAMES := ["I · ближние воды", "II · за Зубами", "III · открытое море"]

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
	position = Vector2.ZERO
	size = Screen.BASE
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _text(at: Vector2, text: String, color := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, font_size := 8) -> void:
	draw_string(UiKit.font(), at, text, align, width, font_size, color)


static func zone_of_row(row: float) -> int:
	if row >= float(SeaChart.cfg("zone3_row")):
		return 2
	return 1 if row >= float(SeaChart.cfg("zone2_row")) else 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.5))
	draw_style_box(UiKit.box("paper"), SHEET)
	var map_size: Array = SeaChart.cfg("size")
	var scale := minf(MAP.size.x / float(map_size[0]), MAP.size.y / float(map_size[1]))
	var origin := MAP.position
	var extent := Vector2(float(map_size[0]), float(map_size[1])) * scale
	var chunk := int(SeaChart.cfg("chunk"))
	# Water by zone where sailed, hatched fog elsewhere.
	for cy in range(0, int(map_size[1]), chunk):
		for cx in range(0, int(map_size[0]), chunk):
			var cell := Rect2(origin + Vector2(cx, cy) * scale, Vector2(chunk, chunk) * scale)
			if Sea.revealed.has("%d,%d" % [cx / chunk, cy / chunk]):
				draw_rect(cell, ZONES[zone_of_row(cy + chunk / 2.0)])
				if (cx / chunk + cy / chunk) % 3 == 0:
					var w := cell.position + Vector2(3, cell.size.y / 2.0)
					draw_line(w, w + Vector2(2, -1), Color(1, 1, 1, 0.5), 1.0)
					draw_line(w + Vector2(2, -1), w + Vector2(4, 0), Color(1, 1, 1, 0.5), 1.0)
			else:
				draw_rect(cell, FOG)
				for k in range(0, int(cell.size.x), 4):
					draw_line(cell.position + Vector2(k, cell.size.y), cell.position + Vector2(minf(k + cell.size.y, cell.size.x), maxf(cell.size.y - (cell.size.x - k), 0.0)),
						Color(0.54, 0.45, 0.35, 0.18), 1.0)
	# The coast of the island along the top.
	var coast := float(SeaChart.cfg("coast_rows")) * scale
	draw_rect(Rect2(origin, Vector2(extent.x, coast)), LAND)
	draw_rect(Rect2(origin + Vector2(0, coast - 1), Vector2(extent.x, 1)), Color("#4e6e3a"))
	_text(origin + Vector2(4, coast - 1), "Вороний мыс", Color("#1f2e22"))
	# Zone borders, dashed, with their numerals.
	for key in ["zone2_row", "zone3_row"]:
		var y := origin.y + float(SeaChart.cfg(key)) * scale
		for x in range(0, int(extent.x), 6):
			draw_line(Vector2(origin.x + x, y), Vector2(origin.x + minf(x + 3, extent.x), y), Color("#6b4a32"), 1.0)
		_text(Vector2(origin.x + extent.x - 12, y - 2), "II" if key == "zone2_row" else "III", Color("#6b4a32"))
	# Reefs where sailed.
	for r in SeaChart.cfg("reefs"):
		var rp := Vector2(float(r[0]), float(r[1]))
		if Sea.revealed.has(SeaChart.chunk_key(rp * 16.0)):
			var p := origin + rp * scale
			draw_line(p + Vector2(-1.5, -1.5), p + Vector2(1.5, 1.5), INK, 1.0)
			draw_line(p + Vector2(-1.5, 1.5), p + Vector2(1.5, -1.5), INK, 1.0)
	# The dock, the places, the boat.
	var dock: Array = SeaChart.cfg("dock")
	var dp := origin + Vector2(float(dock[0]), float(dock[1])) * scale
	draw_rect(Rect2(dp - Vector2(2, 2), Vector2(4, 4)), Color("#6b4a32"))
	for place in SeaChart.cfg("places"):
		if not Sea.revealed.has(SeaChart.chunk_key(SeaChart.place_pos(place))):
			continue
		var at: Array = SeaChart.cfg("places")[place]["at"]
		var p := origin + Vector2(int(at[0]), int(at[1])) * scale
		draw_circle(p, 3.0, INK)
		draw_circle(p, 2.0, RED)
		var label := Loc.t("sea." + place)
		var w := UiKit.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var lx := p.x + 5 if p.x + 5 + w < origin.x + extent.x else p.x - 5 - w
		_text(Vector2(lx, p.y + 3), label, INK)
	var scene := get_tree().current_scene
	if Router.current_map == "sea" and scene and scene.get_node_or_null("Player"):
		var boat := origin + (scene.get_node("Player") as Node2D).global_position / 16.0 * scale
		draw_colored_polygon(PackedVector2Array([boat + Vector2(0, -4), boat + Vector2(3, 3), boat + Vector2(-3, 3)]), INK)
		draw_colored_polygon(PackedVector2Array([boat + Vector2(0, -3), boat + Vector2(2, 2), boat + Vector2(-2, 2)]), Color("#ffc85a"))
	draw_rect(Rect2(origin - Vector2(1, 1), extent + Vector2(2, 2)), INK, false, 1.0)
	UiKit.draw_icon(self, "tab_compass", origin + Vector2(extent.x - 26, coast + 4), 24.0)
	# The legend column.
	var x := MAP.end.x + 18
	var width := SHEET.end.x - 14 - x
	_text(Vector2(x, 38), "Морская карта", RED, width, HORIZONTAL_ALIGNMENT_LEFT, 16)
	var y := 56.0
	for i in 3:
		draw_rect(Rect2(x, y - 6, 10, 7), ZONES[i])
		draw_rect(Rect2(x, y - 6, 10, 7), INK, false, 1.0)
		_text(Vector2(x + 14, y), ZONE_NAMES[i], INK, width - 14)
		y += 11
	draw_rect(Rect2(x, y - 6, 10, 7), FOG)
	draw_rect(Rect2(x, y - 6, 10, 7), INK, false, 1.0)
	_text(Vector2(x + 14, y), "ещё не хожено", FADED, width - 14)
	y += 18
	_text(Vector2(x, y), "Места", RED)
	y += 11
	for place in SeaChart.cfg("places"):
		var info: Dictionary = SeaChart.cfg("places")[place]
		var known := Sea.revealed.has(SeaChart.chunk_key(SeaChart.place_pos(place)))
		if not known and bool(info.get("secret", false)):
			continue
		_text(Vector2(x, y), ("• " + Loc.t("sea." + place)) if known else "• ???", INK if known else FADED, width)
		y += 10
	var sight := raven_lines()
	y = SHEET.end.y - 18 - sight.size() * 10
	for line in sight:
		_text(Vector2(x, y), str(line), INK, width)
		y += 10
	_text(Vector2(x, SHEET.end.y - 14), "M — закрыть", FADED, width)


# 25 (Foraging 10) / the Raven's Eye charm: today's raven marks and the bottles on the beaches.
static func raven_lines() -> Array:
	if not Farm.raven_sight():
		return []
	var marks: Array = []
	for map_id in Farm.raven_marks:
		var n: int = (Farm.raven_marks[map_id] as Array).size()
		if n > 0:
			marks.append("%s ×%d" % [str(MapInfo.region(map_id).get("title", map_id)), n])
	var bottles: Array = []
	for map_id in Sea.gifts:
		for gift in Sea.gifts[map_id]:
			if str(gift.get("item", "")) == "message_bottle":
				var title := str(MapInfo.region(map_id).get("title", map_id)) if map_id != "cape" else "мыс"
				if title not in bottles:
					bottles.append(title)
	return ["Вороньи метки: " + (", ".join(marks) if not marks.is_empty() else "нет"),
		"Бутылки на берегу: " + (", ".join(bottles) if not bottles.is_empty() else "нет")]
