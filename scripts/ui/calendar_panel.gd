extends Panel
class_name CalendarPanel

# The season at a glance (30.x): 4 weeks of 7 days with festivals and the islanders' birthdays.
const SEASON_NAMES := {"spring": "Весна", "summer": "Лето", "autumn": "Осень", "winter": "Зима"}
const DAYS := ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
const CELL := Vector2(52, 30)
const ORIGIN := Vector2(12, 34)

var season_index: int = 0
var _was_paused: bool = false
var _title: Label
var _notes: Label


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
	position = Vector2(52, 14)
	size = Vector2(388, 238)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121a26")
	style.border_color = Color("#b08f6c")
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	_title = Label.new()
	_title.position = Vector2(12, 6)
	_title.size = Vector2(364, 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", Color("#ffe9a8"))
	add_child(_title)
	_notes = Label.new()
	_notes.position = Vector2(12, 190)
	_notes.size = Vector2(364, 44)
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.add_theme_font_size_override("font_size", 7)
	_notes.add_theme_color_override("font_color", Color("#dfe9ea"))
	add_child(_notes)
	refresh()


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


func refresh() -> void:
	_title.text = "%s · год %d   (← →)" % [SEASON_NAMES[season_name()], Clock.year]
	var lines: Array[String] = []
	var fest := festivals()
	for day in fest:
		lines.append("%d — %s" % [day, Loc.t("festival.%s.name" % fest[day]["id"]) if Loc.has("festival.%s.name" % fest[day]["id"]) else str(fest[day].get("name", fest[day]["id"]))])
	var bdays := birthdays()
	var names: Array[String] = []
	for day in bdays:
		for id in bdays[day]:
			names.append("%s %d" % [Loc.t(str(Data.by_id("npcs", id)["name"])), day])
	_notes.text = "Праздники: %s\nДни рождения: %s" % [", ".join(lines) if not lines.is_empty() else "нет", ", ".join(names) if not names.is_empty() else "нет"]
	queue_redraw()


func _draw() -> void:
	var fest := festivals()
	var bdays := birthdays()
	for i in 7:
		draw_string(ThemeDB.fallback_font, ORIGIN + Vector2(i * CELL.x + 18, 0), DAYS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#b08f6c"))
	for d in range(1, 29):
		var cell := Vector2(((d - 1) % 7) * CELL.x, ((d - 1) / 7) * CELL.y) + ORIGIN + Vector2(0, 6)
		var today := season_index == Clock.season_index and d == Clock.day
		draw_rect(Rect2(cell, CELL - Vector2(3, 3)), Color("#2a3a50") if today else Color("#1b2433"))
		if fest.has(d):
			draw_rect(Rect2(cell, CELL - Vector2(3, 3)), Color("#c9a24a"), false, 1.0)
		draw_string(ThemeDB.fallback_font, cell + Vector2(3, 10), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#f0e7cc"))
		var k := 0
		for id in bdays.get(d, []):
			var look: Dictionary = Data.by_id("npcs", id).get("look", {})
			var at := cell + Vector2(6 + k * 12, 14)
			draw_rect(Rect2(at, Vector2(9, 9)), Color(str(look.get("skin", "#e0c0a0"))))
			draw_rect(Rect2(at, Vector2(9, 3)), Color(str(look.get("hair", "#4a3a2a"))))
			k += 1
		if fest.has(d):
			draw_string(ThemeDB.fallback_font, cell + Vector2(34, 10), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffc85a"))


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
