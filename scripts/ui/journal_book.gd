extends Control
class_name JournalBook

# 30.2 «Журнал смотрителя» (I or Esc): a leather book with brass corners, cream pages and a column of
# tabs. Skills, relationships, tasks, collections, the Compass and settings are pages of the book;
# the backpack, knowledge, map, calendar and letters open their own windows; the last tab saves.
const TABS := [
	["tab_inventory", "Рюкзак"], ["tab_skills", "Навыки"], ["tab_knowledge", "Знания"],
	["tab_relations", "Отношения"], ["tab_quests", "Задания"], ["tab_collections", "Коллекции"],
	["tab_map", "Карта"], ["tab_calendar", "Календарь"], ["tab_compass", "Компас"],
	["tab_letters", "Письма"], ["tab_settings", "Настройки"], ["tab_save", "Сохранить"],
]
const PAGES := ["tab_skills", "tab_relations", "tab_quests", "tab_collections", "tab_compass", "tab_settings"]
const INK := Color("#3a2a20")
const FADED := Color("#7a6450")
const RED := Color("#9b2f2a")
const LEFT := Rect2(28, 18, 196, 234)
const RIGHT := Rect2(224, 18, 196, 234)
const TAB_X := 424.0
const PARTS := {"fish": "Рыбы и раки", "cooking": "Кухня", "crafting": "Ремесло", "cabinet": "Кабинет находок",
	"skills": "Навыки на 10", "friends": "Друзья на 10 сердец", "ghosts": "Упокоенные призраки",
	"blessings": "Благословения", "letters": "Письма, страницы, сказы", "great_eye": "Великое Око",
	"rooms": "Комнаты общины", "two_fires": "Два огня", "sightings": "Наблюдения"}
const SETTINGS := [["shake", "Тряска экрана"], ["lightning_flash", "Вспышки молний"],
	["fortuna_reminder", "Напоминание Фортуны"], ["fishing_assist", "Помощь в рыбалке"]]

var tab := "tab_skills"
var _hud: CanvasLayer
var _was_paused := false
var _status := ""


static func toggle(hud: CanvasLayer, page := "") -> void:
	var existing := hud.get_node_or_null("JournalBook") as JournalBook
	if existing:
		existing.close()
		return
	var book := JournalBook.new()
	book.name = "JournalBook"
	book._hud = hud
	if page != "":
		book.tab = page
	hud.add_child(book)


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
	if event.is_action_pressed("pause") or event.is_action_pressed("open_journal"):
		get_viewport().set_input_as_handled()
		close()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if p.x >= TAB_X and p.x < TAB_X + 22:
		var index := int((p.y - 22.0) / 19.0)
		if index >= 0 and index < TABS.size() and p.y >= 22.0:
			open_tab(str(TABS[index][0]))
	elif tab == "tab_settings" and RIGHT.has_point(p):
		var row := int((p.y - RIGHT.position.y - 30.0) / 16.0)
		if row >= 0 and row < SETTINGS.size():
			var key := str(SETTINGS[row][0])
			Settings.set(key, not bool(Settings.get(key)))
			Settings.save_prefs()
	elif tab == "tab_settings" and LEFT.has_point(p) and p.y > LEFT.position.y + 150.0:
		Settings.language = "en" if Settings.language == "ru" else "ru"
		Settings.save_prefs()
	accept_event()
	queue_redraw()


# A page tab turns the page; the others hand over to their own window (or save the game).
func open_tab(id: String) -> void:
	_status = ""
	AudioMgr.play_sfx("ui_page")
	if id in PAGES:
		tab = id
		queue_redraw()
		return
	var hud := _hud
	match id:
		"tab_save":
			_status = "Журнал сохранён." if Save.save_game() else "Сохранить не вышло."
			queue_redraw()
			return
		"tab_inventory":
			close()
			if hud.get_parent().has_method("toggle_inventory"):
				hud.get_parent().call("toggle_inventory")
		"tab_knowledge":
			close()
			KnowledgeBook.open(hud)
		"tab_map":
			close()
			SeaChartPanel.toggle(hud)
		"tab_calendar":
			close()
			CalendarPanel.toggle(hud)
		"tab_letters":
			close()
			MailPanel.open(hud)


func _text(at: Vector2, text: String, color := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(UiKit.font(), at, text, align, width, 8, color)


func _bar(at: Vector2, width: float, share: float, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("#c9b48c"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2((width - 2.0) * clampf(share, 0.0, 1.0), 2)), color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.55))
	draw_style_box(UiKit.box("book_left"), LEFT)
	draw_style_box(UiKit.box("book_right"), RIGHT)
	for i in TABS.size():
		var r := Rect2(TAB_X, 22 + i * 19, 18, 18)
		draw_style_box(UiKit.box("slot_selected" if TABS[i][0] == tab else "slot"), r)
		if not UiKit.draw_icon(self, str(TABS[i][0]), r.position + Vector2(1, 1)):
			_text(r.position + Vector2(3, 12), str(TABS[i][1]).left(1), UiKit.PAPER)
	var title := ""
	for t in TABS:
		if t[0] == tab:
			title = str(t[1])
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 20), title, RED)
	draw_rect(Rect2(LEFT.position.x + 14, LEFT.position.y + 24, 60, 1), RED)
	call("_page_" + tab.trim_prefix("tab_"))
	if _status != "":
		_text(Vector2(RIGHT.position.x + 14, RIGHT.end.y - 14), _status, RED)


func _page_skills() -> void:
	var y := LEFT.position.y + 40
	for id in Skills.NAMES:
		var level := Skills.level(str(id))
		var xp := int(Skills.xp.get(id, 0))
		var lo := 0 if level <= 0 else Skills.THRESHOLDS[mini(level, 10) - 1]
		var hi: int = Skills.THRESHOLDS[mini(level, 9)]
		_text(Vector2(LEFT.position.x + 14, y), Loc.t("skill." + str(id)))
		_text(Vector2(LEFT.position.x + 14, y), "ур. %d" % level, FADED, LEFT.size.x - 30, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Vector2(LEFT.position.x + 14, y + 4), LEFT.size.x - 30, 1.0 if level >= 10 else float(xp - lo) / float(maxi(hi - lo, 1)),
			Color("#4e6e3a"))
		y += 25
	var x := RIGHT.position.x + 14
	_text(Vector2(x, RIGHT.position.y + 20), "Профессии", RED)
	var ry := RIGHT.position.y + 38
	for id in Skills.NAMES:
		for prof in Skills.professions.get(id, []):
			_text(Vector2(x, ry), "• " + Loc.t("profession.%s.name" % str(prof)), INK, RIGHT.size.x - 28)
			ry += 12
	if ry == RIGHT.position.y + 38:
		_text(Vector2(x, ry), "Пока ни одной: они приходят", FADED)
		_text(Vector2(x, ry + 11), "на 5-м и 10-м уровне навыка.", FADED)


func _page_relations() -> void:
	var rows := []
	for npc in Data.all("npcs"):
		if not bool(npc.get("visitor", false)):
			rows.append(npc)
	for i in rows.size():
		var page := LEFT if i < 14 else RIGHT
		var col := (i % 14) / 7
		var row := i % 7
		var at := page.position + Vector2(12 + col * 90, (38 if page == LEFT else 22) + row * 27)
		var id := str(rows[i]["id"])
		draw_rect(Rect2(at, Vector2(20, 22)), Color("#2b3346"))
		CastSprite.draw_portrait(self, id, Rect2(at + Vector2(2, 2), Vector2(16, 18)))
		_text(at + Vector2(24, 9), Loc.t(str(rows[i]["name"])).get_slice(" ", 0), INK, 66)
		var hearts := Relationships.hearts_of(id)
		_text(at + Vector2(24, 19), "♥".repeat(mini(hearts, 10)) if hearts > 0 else "—", RED if hearts > 0 else FADED, 66)


func _page_quests() -> void:
	var lines: Array = Quests.journal_lines()
	if lines.is_empty():
		lines = ["Пока никаких поручений. Наслаждайтесь."]
	var font := UiKit.font()
	var y := LEFT.position.y + 40
	var page := LEFT
	for line in lines:
		var h := font.get_multiline_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, page.size.x - 30, 8).y
		if y + h > page.end.y - 12:
			if page == RIGHT:
				break
			page = RIGHT
			y = RIGHT.position.y + 22
		var done := str(line).begins_with("✓")
		draw_multiline_string(font, Vector2(page.position.x + 14, y), str(line), HORIZONTAL_ALIGNMENT_LEFT, page.size.x - 30, 8, -1,
			FADED if done else INK)
		y += h + 3


func _page_collections() -> void:
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 42), "Совершенство смотрителя", INK)
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 66), "%d%%" % Perfection.percent(), RED)
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 90), "Сто процентов зажгут", FADED)
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 101), "Золотой фонарь на мысу.", FADED)
	var parts := Perfection.parts()
	var y := RIGHT.position.y + 22
	for key in parts:
		_text(Vector2(RIGHT.position.x + 14, y), str(PARTS.get(key, key)), INK, 120)
		_text(Vector2(RIGHT.position.x + 14, y), "%d%%" % roundi(float(parts[key][0]) * 100.0), FADED, RIGHT.size.x - 30,
			HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Vector2(RIGHT.position.x + 14, y + 3), RIGHT.size.x - 30, float(parts[key][0]), Color("#c9a24a"))
		y += 15


func _page_compass() -> void:
	var rows := [["hud_light", "Свет", Lighthouse.fire_power, Color("#e9a64a"), "Сила Огня маяка этой ночью."],
		["hud_peace", "Покой", Graveyard.peace, Color("#a06a9e"), "Как спят мёртвые на погосте."],
		["hud_sea", "Море", Sea.mercy, Color("#3f7f8f"), "Милость Ранн к смотрителю."]]
	var y := LEFT.position.y + 40
	for r in rows:
		UiKit.draw_icon(self, str(r[0]), Vector2(LEFT.position.x + 14, y - 4))
		_text(Vector2(LEFT.position.x + 34, y + 4), "%s  %d" % [r[1], int(r[2])])
		_bar(Vector2(LEFT.position.x + 34, y + 8), LEFT.size.x - 50, float(r[2]) / 100.0, r[3])
		_text(Vector2(LEFT.position.x + 34, y + 22), str(r[4]), FADED, LEFT.size.x - 50)
		y += 44
	var x := RIGHT.position.x + 14
	_text(Vector2(x, RIGHT.position.y + 22), "Честь", RED)
	_text(Vector2(x, RIGHT.position.y + 40), str(Game.honor), INK)
	_text(Vector2(x, RIGHT.position.y + 62), "Деньги: %d кр" % Economy.money, INK)
	_text(Vector2(x, RIGHT.position.y + 76), "День %d · %s" % [Clock.day, Clock.moon_name()], INK)


func _page_settings() -> void:
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 42), "Время в журнале стоит.", FADED)
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 56), "Щелчок по строке меняет её.", FADED)
	_text(Vector2(LEFT.position.x + 14, LEFT.position.y + 166), "Язык: " + ("русский" if Settings.language == "ru" else "English"), INK)
	var y := RIGHT.position.y + 30
	for s in SETTINGS:
		var on := bool(Settings.get(str(s[0])))
		_text(Vector2(RIGHT.position.x + 14, y + 8), str(s[1]), INK)
		_text(Vector2(RIGHT.position.x + 14, y + 8), "да" if on else "нет", RED if on else FADED, RIGHT.size.x - 30,
			HORIZONTAL_ALIGNMENT_RIGHT)
		y += 16
