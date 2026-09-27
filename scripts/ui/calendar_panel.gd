extends Control
class_name CalendarPanel

# The season at a glance: a parchment calendar of 4 weeks × 7 days with the festivals (a gold star)
# and the islanders' birthdays (their faces); hovering a day names what falls on it. ← → turn the season.
const SEASON_NAMES := {"spring": "Весна", "summer": "Лето", "autumn": "Осень", "winter": "Зима"}
const DAYS := ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
const SHEET := Rect2(40, 8, 400, 254)
const CELL := Vector2(52, 34)
const ORIGIN := Vector2(58, 52)
const INK := Color("#3a2a20")
const FADED := Color("#8a7458")
const RED := Color("#9b2f2a")
const LINE := Color("#c9b48c")

var season_index: int = 0
var _was_paused: bool = false
var _hover := -1


static func toggle(hud: CanvasLayer) -> void:
	var existing := hud.get_node_or_null("CalendarPanel")
	if existing:
		existing.close()
		return
	var panel := CalendarPanel.new()
	panel.name = "CalendarPanel"
	panel.season_index = Clock.season_index
	hud.add_child(panel)


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2.ZERO
	size = Screen.BASE
	mouse_filter = Control.MOUSE_FILTER_STOP


func season_name() -> String:
	return Clock.SEASONS[season_index]


func festivals() -> Dictionary:
	var out := {}
	for f in Data.all("festivals"):
		if str(f.get("season", "")) == season_name():
			out[int(f["day"])] = f
	return out


func birthdays() -> Dictionary:
	var out := {}
	for npc in Data.all("npcs"):
		var b: Dictionary = npc.get("birthday", {})
		if b.is_empty() or str(b["season"]) != season_name() or bool(npc.get("secret", false)) and not Game.flag("tuve_met"):
			continue
		if not out.has(int(b["day"])):
			out[int(b["day"])] = []
		out[int(b["day"])].append(str(npc["id"]))
	return out


func festival_name(f: Dictionary) -> String:
	var key := "festival.%s.name" % f["id"]
	return Loc.t(key) if Loc.has(key) else str(f.get("name", f["id"]))


func refresh() -> void:
	queue_redraw()


func day_at(p: Vector2) -> int:
	var rel := p - ORIGIN
	if rel.x < 0 or rel.y < 0:
		return -1
	var col := int(rel.x / CELL.x)
	var row := int(rel.y / CELL.y)
	return row * 7 + col + 1 if col < 7 and row < 4 else -1


# The day's line under the grid: its festival and birthdays.
func day_note(d: int) -> String:
	var parts: Array[String] = []
	var fest := festivals()
	if fest.has(d):
		parts.append("праздник «%s»" % festival_name(fest[d]))
	for id in birthdays().get(d, []):
		parts.append("день рождения: %s" % Loc.t(str(Data.by_id("npcs", id)["name"])))
	return "%d %s — %s" % [d, SEASON_NAMES[season_name()].to_lower(), ", ".join(parts) if not parts.is_empty() else "обычный день"]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var d := day_at(event.position)
		if d != _hover:
			_hover = d
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if p.y < ORIGIN.y - 12 and p.y > SHEET.position.y:
			season_index = posmod(season_index + (-1 if p.x < SHEET.get_center().x else 1), 4)
			refresh()
		accept_event()


func _text(at: Vector2, text: String, color := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, font_size := 8) -> void:
	draw_string(UiKit.font(), at, text, align, width, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.5))
	draw_style_box(UiKit.box("paper"), SHEET)
	var fest := festivals()
	var bdays := birthdays()
	# Title with the season arrows.
	_text(Vector2(SHEET.position.x, 30), "%s · год %d" % [SEASON_NAMES[season_name()], Clock.year], RED, SHEET.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, 16)
	_text(Vector2(SHEET.position.x + 22, 28), "◀", FADED)
	_text(Vector2(SHEET.end.x - 30, 28), "▶", FADED)
	for i in 7:
		_text(ORIGIN + Vector2(i * CELL.x, -4), DAYS[i], RED if i >= 5 else FADED, CELL.x - 2, HORIZONTAL_ALIGNMENT_CENTER)
	for d in range(1, 29):
		var cell := Rect2(ORIGIN + Vector2(((d - 1) % 7) * CELL.x, ((d - 1) / 7) * CELL.y), CELL - Vector2(2, 2))
		var this_season := season_index == Clock.season_index
		var today := this_season and d == Clock.day
		var past := this_season and d < Clock.day
		draw_rect(cell, Color("#e9d9b2") if not past else Color("#ddcca4"))
		if fest.has(d):
			draw_rect(cell, Color(0.94, 0.72, 0.3, 0.28))
		if d == _hover:
			draw_rect(cell, Color(1, 1, 1, 0.25))
		draw_rect(cell, RED if today else LINE, false, 1.0)
		if today:
			draw_rect(cell.grow(-1), RED, false, 1.0)
		_text(cell.position + Vector2(3, 9), str(d), FADED if past else INK)
		if past:
			draw_line(cell.position + Vector2(cell.size.x - 9, 4), cell.position + Vector2(cell.size.x - 4, 9), FADED, 1.0)
		if fest.has(d):
			UiKit.draw_icon(self, "star_gold", cell.position + Vector2(cell.size.x - 13, 1), 12.0)
		var k := 0
		for id in bdays.get(d, []):
			var at := cell.position + Vector2(3 + k * 17, cell.size.y - 18)
			draw_rect(Rect2(at, Vector2(16, 17)), Color("#2b3346"))
			CastSprite.draw_portrait(self, str(id), Rect2(at, Vector2(16, 17)))
			k += 1
	# The foot of the sheet: the hovered day, or the season's list.
	var foot := Vector2(ORIGIN.x, ORIGIN.y + 4 * CELL.y + 14)
	var width := 7 * CELL.x
	if _hover > 0:
		draw_multiline_string(UiKit.font(), foot, day_note(_hover), HORIZONTAL_ALIGNMENT_LEFT, width, 8, 2, INK)
		return
	var lines: Array[String] = []
	for day in fest:
		lines.append("%d — %s" % [day, festival_name(fest[day])])
	var names: Array[String] = []
	for day in bdays:
		for id in bdays[day]:
			names.append("%s %d" % [Loc.t(str(Data.by_id("npcs", id)["name"])), day])
	_text(foot, "Праздники: " + (", ".join(lines) if not lines.is_empty() else "нет"), INK, width)
	draw_multiline_string(UiKit.font(), foot + Vector2(0, 12), "Дни рождения: " + (", ".join(names) if not names.is_empty() else "нет"),
		HORIZONTAL_ALIGNMENT_LEFT, width, 8, 2, FADED)


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_calendar") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		season_index = posmod(season_index - 1, 4)
		refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		season_index = posmod(season_index + 1, 4)
		refresh()
		get_viewport().set_input_as_handled()
