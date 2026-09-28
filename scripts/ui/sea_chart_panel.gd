extends Control
class_name SeaChartPanel

# The map (M), two tabs on one parchment sheet. «Остров» is the island chart (IslandChart): the whole island
# with the keeper on it. «Море» is the sea chart as an old pilot chart: hatched where the keeper has not
# sailed, the chart itself where the keeper has, the coast along the top, the zone borders dashed, reefs, the
# known places, the dock and the boat, over the PixelLab picture of the sea (tools/sea_chart.py). Beside each the legend, the places found and the raven's sight.
# It opens on the tab of where the keeper is; Tab or the arrows switch, a click on a tab too.
const SHEET := Rect2(34, 6, 412, 258)
const MAP := Rect2(48, 24, 180, 210)
const INK := Color("#3a2a20")
const FADED := Color("#8a7458")
const RED := Color("#9b2f2a")
const FOG := Color("#dccaa2")
const LAND := Color("#7a964c")
const ZONES := [Color("#5c798b"), Color("#375473"), Color("#2b3c58")]
const ZONE_NAMES := ["I · ближние воды", "II · за Зубами", "III · открытое море"]
const SEA_ART := "res://assets/sprites/ui/sea_chart.png"
const TABS := [["island", "Остров"], ["sea", "Море"]]
const TAB_Y := 10.0
const ISLAND_AT := Vector2(46, 22)

var tab := "island"
var zoom := 1
var _was_paused: bool = false


static func toggle(hud: CanvasLayer) -> void:
	var existing := hud.get_node_or_null("SeaChartPanel")
	if existing:
		existing.close()
		return
	var panel := SeaChartPanel.new()
	panel.name = "SeaChartPanel"
	panel.tab = "sea" if Router.current_map in ["sea", "deep"] else "island"
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


func _process(_delta: float) -> void:
	if tab == "island":
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()
		switch_tab("sea" if tab == "island" else "island")
		return
	if tab == "island" and (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z
			or event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		get_viewport().set_input_as_handled()
		if event is InputEventMouseButton:
			zoom = 2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		else:
			zoom = 3 - zoom
		queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := get_local_mouse_position()
		for i in TABS.size():
			if _tab_rect(i).has_point(at):
				get_viewport().set_input_as_handled()
				switch_tab(str(TABS[i][0]))


func switch_tab(id: String) -> void:
	tab = id
	queue_redraw()


func _tab_rect(i: int) -> Rect2:
	return Rect2(SHEET.end.x - 14 - 116 + i * 60, TAB_Y, 56, 13)


static var _art: Texture2D


static func _sea_art() -> Texture2D:
	if _art == null and ResourceLoader.exists(SEA_ART):
		_art = load(SEA_ART) as Texture2D
	return _art


# Light text with an ink rim, readable on the water.
func _label(at: Vector2, text: String) -> void:
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_text(at + d, text, INK)
	_text(at, text, Color("#f4f7f6"))


func _draw_tabs() -> void:
	for i in TABS.size():
		var r := _tab_rect(i)
		var on := str(TABS[i][0]) == tab
		draw_rect(r, Color("#eadcb8") if on else Color("#c9b48c"))
		draw_rect(r, INK if on else FADED, false, 1.0)
		if on:
			draw_line(r.position + Vector2(1, r.size.y), r.end - Vector2(1, 0), Color("#eadcb8"), 1.0)
		_text(Vector2(r.position.x, r.position.y + 10), str(TABS[i][1]), RED if on else FADED, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _text(at: Vector2, text: String, color := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, font_size := 8) -> void:
	draw_string(UiKit.font(), at, text, align, width, font_size, color)


static func zone_of_row(row: float) -> int:
	if row >= float(SeaChart.cfg("zone3_row")):
		return 2
	return 1 if row >= float(SeaChart.cfg("zone2_row")) else 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.5))
	draw_style_box(UiKit.box("paper"), SHEET)
	_draw_tabs()
	if tab == "island":
		_draw_island()
	else:
		_draw_sea()


# The island tab: the chart on the left, the legend on the right.
func _draw_island() -> void:
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") as Node2D if scene else null
	var at := player.global_position if player else Vector2.ZERO
	var extent := IslandChart.size()
	IslandChart.draw(self, Rect2(ISLAND_AT, extent), zoom, Router.current_map, at)
	draw_rect(Rect2(ISLAND_AT - Vector2(1, 1), extent + Vector2(2, 2)), INK, false, 1.0)
	var x := ISLAND_AT.x + extent.x + 14
	var width := SHEET.end.x - 14 - x
	_text(Vector2(x, 38), "Карта острова", RED, width, HORIZONTAL_ALIGNMENT_LEFT, 16)
	var where := IslandChart.keeper(Router.current_map, at)
	var y := 54.0
	_text(Vector2(x, y), "Вы здесь:", FADED, width)
	y += 10
	var here := IslandChart.title(str(where[0])) if not where.is_empty() else ("в море" if Router.current_map == "sea" else "в Глуби")
	_text(Vector2(x, y), here, INK, width)
	y += 16
	_text(Vector2(x, y), "Места", RED)
	y += 11
	for id in Router.ISLAND_MAPS:
		var known := IslandChart.seen(id)
		_text(Vector2(x, y), ("• " + str(MapInfo.region(id).get("title", id))) if known else "• ???", INK if known else FADED, width)
		y += 10
	var sight := raven_lines()
	y = SHEET.end.y - 28 - sight.size() * 10
	for line in sight:
		_text(Vector2(x, y), str(line), INK, width)
		y += 10
	# The key to the marks under the chart.
	var ky := ISLAND_AT.y + extent.y + 16
	IslandChart.keeper_pin(self, Vector2(ISLAND_AT.x + 4, ky - 3))
	_text(Vector2(ISLAND_AT.x + 12, ky), "вы", INK)
	draw_rect(Rect2(ISLAND_AT.x + 34, ky - 7, 8, 6), IslandChart.FOG)
	draw_rect(Rect2(ISLAND_AT.x + 34, ky - 7, 8, 6), FADED, false, 1.0)
	_text(Vector2(ISLAND_AT.x + 46, ky), "ещё не бывали", FADED)
	if Farm.raven_sight():
		IslandChart.raven_mark(self, Vector2(ISLAND_AT.x + 128, ky - 3))
		_text(Vector2(ISLAND_AT.x + 134, ky), "вороны", INK)
		IslandChart.bottle(self, Vector2(ISLAND_AT.x + 174, ky - 3))
		_text(Vector2(ISLAND_AT.x + 180, ky), "бутылки", INK)
	_text(Vector2(ISLAND_AT.x, ky + 14), "Колесо или Z — %s" % ("отдалить" if zoom > 1 else "приблизить"), FADED, extent.x)
	_text(Vector2(x, SHEET.end.y - 14), "M — закрыть · Tab — море", FADED, width)


func _draw_sea() -> void:
	var map_size: Array = SeaChart.cfg("size")
	var scale := minf(MAP.size.x / float(map_size[0]), MAP.size.y / float(map_size[1]))
	var origin := MAP.position
	var extent := Vector2(float(map_size[0]), float(map_size[1])) * scale
	var chunk := int(SeaChart.cfg("chunk"))
	# The PixelLab chart (tools/sea_chart.py) where sailed; hatched fog elsewhere, the coast always shown.
	var coast := float(SeaChart.cfg("coast_rows")) * scale
	var art := _sea_art()
	if art:
		draw_texture_rect(art, Rect2(origin, extent), false)
	for cy in range(0, int(map_size[1]), chunk):
		for cx in range(0, int(map_size[0]), chunk):
			var cell := Rect2(origin + Vector2(cx, cy) * scale, Vector2(chunk, chunk) * scale)
			if Sea.revealed.has("%d,%d" % [cx / chunk, cy / chunk]):
				if art == null:
					draw_rect(cell, ZONES[zone_of_row(cy + chunk / 2.0)])
				continue
			if cy == 0:
				cell = Rect2(cell.position + Vector2(0, coast), cell.size - Vector2(0, coast))
			draw_rect(cell, FOG)
			for k in range(0, int(cell.size.x), 4):
				draw_line(cell.position + Vector2(k, cell.size.y), cell.position + Vector2(minf(k + cell.size.y, cell.size.x), maxf(cell.size.y - (cell.size.x - k), 0.0)),
					Color(0.54, 0.45, 0.35, 0.18), 1.0)
	# The coast of the island along the top.
	if art == null:
		draw_rect(Rect2(origin, Vector2(extent.x, coast)), LAND)
	_label(origin + Vector2(4, coast + 2), "Вороний мыс")
	# Zone borders, dashed, with their numerals.
	for key in ["zone2_row", "zone3_row"]:
		var y := origin.y + float(SeaChart.cfg(key)) * scale
		for x in range(0, int(extent.x), 6):
			draw_line(Vector2(origin.x + x, y), Vector2(origin.x + minf(x + 3, extent.x), y), Color(0.95, 0.9, 0.75, 0.55), 1.0)
		_label(Vector2(origin.x + extent.x - 14, y - 2), "II" if key == "zone2_row" else "III")
	# The dock, the places, the boat.
	var dock: Array = SeaChart.cfg("dock")
	var dp := origin + Vector2(float(dock[0]), float(dock[1])) * scale
	draw_rect(Rect2(dp - Vector2(2, 2), Vector2(4, 4)), Color("#6b4a32"))
	# The known places: a red pin each, the name beside it where it clashes with no other name.
	var taken: Array[Rect2] = [Rect2(origin + Vector2(2, coast - 6), Vector2(70, 10))]
	var bounds := Rect2(origin, extent)
	for place in SeaChart.cfg("places"):
		if not Sea.revealed.has(SeaChart.chunk_key(SeaChart.place_pos(place))):
			continue
		var at: Array = SeaChart.cfg("places")[place]["at"]
		var p := origin + Vector2(int(at[0]), int(at[1])) * scale
		draw_circle(p, 2.5, INK)
		draw_circle(p, 1.5, RED)
		var label := Loc.t("sea." + place)
		var w := UiKit.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var spot := Vector2(p.x + 5, p.y + 3)
		for c in [Vector2(p.x + 5, p.y + 3), Vector2(p.x - 5 - w, p.y + 3), Vector2(p.x - w / 2.0, p.y + 13), Vector2(p.x - w / 2.0, p.y - 6)]:
			var box := Rect2(c - Vector2(1, 8), Vector2(w + 2, 10))
			if bounds.encloses(box) and taken.all(func(t: Rect2) -> bool: return not t.intersects(box)):
				spot = c
				break
		spot = spot.round()
		taken.append(Rect2(spot - Vector2(1, 8), Vector2(w + 2, 10)))
		_label(spot, label)
	var scene := get_tree().current_scene
	if Router.current_map == "sea" and scene and scene.get_node_or_null("Player"):
		var boat := origin + (scene.get_node("Player") as Node2D).global_position / 16.0 * scale
		draw_colored_polygon(PackedVector2Array([boat + Vector2(0, -4), boat + Vector2(3, 3), boat + Vector2(-3, 3)]), INK)
		draw_colored_polygon(PackedVector2Array([boat + Vector2(0, -3), boat + Vector2(2, 2), boat + Vector2(-2, 2)]), Color("#ffc85a"))
	draw_rect(Rect2(origin - Vector2(1, 1), extent + Vector2(2, 2)), INK, false, 1.0)
	UiKit.draw_icon(self, "tab_compass", origin + extent - Vector2(26, 26), 24.0)
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
	_text(Vector2(x, SHEET.end.y - 14), "M — закрыть · Tab — остров", FADED, width)


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
