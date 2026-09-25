extends Area2D
class_name TowerObject

const WIND_TURNS := 3.0
const PARTS := {"stairs": "Лестница", "masonry": "Кладка", "paint": "Покраска", "glass": "Стёкла фонарной"}

var kind: String = ""
var _keeper: Player
var _held: float = 0.0
var _winding: bool = false
var _wind_angle: float = 0.0
var _last_angle: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 18)
	collision.shape = shape
	add_child(collision)


func _hint(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = text


func _hud() -> CanvasLayer:
	return get_tree().current_scene.get_node("HUD")


func _draw() -> void:
	match kind:
		"stairs_up", "stairs_down":
			for step in 4:
				draw_rect(Rect2(-8 + step * 2, -8 + step * 4, 16 - step * 4, 3), Color("#c9c8c2"))
		"exit_door", "gallery":
			draw_rect(Rect2(-8, -8, 16, 14), Color("#4a3428"))
			draw_rect(Rect2(3, -2, 2, 2), Color("#ffc85a"))
		"fortuna":
			draw_rect(Rect2(-5, -8, 10, 16), Color("#8c6a4e"))
			draw_rect(Rect2(-4, -8, 8, 5), Color("#d8c49a"))
			draw_rect(Rect2(-6, 0, 12, 3), Color("#c9a24a"))
		"barrel":
			draw_rect(Rect2(-6, -8, 12, 14), Color("#6b4a32"))
			draw_rect(Rect2(-6, -4, 12, 1), Color("#45464e"))
			draw_rect(Rect2(-6, 2, 12, 1), Color("#45464e"))
		"repair":
			draw_rect(Rect2(-8, -8, 16, 10), Color("#b08f6c"))
			draw_rect(Rect2(-6, -6, 12, 1), Color("#4a3428"))
			draw_rect(Rect2(-6, -3, 9, 1), Color("#4a3428"))
		"desk":
			draw_rect(Rect2(-12, -4, 24, 6), Color("#8c6a4e"))
			draw_rect(Rect2(-4, -7, 8, 3), Color("#eadcb8"))
		"bunk":
			draw_rect(Rect2(-12, -6, 24, 12), Color("#6b4a32"))
			draw_rect(Rect2(-10, -4, 20, 8), Color("#829f9c"))
		"barometer":
			draw_circle(Vector2.ZERO, 6.0, Color("#c9a24a"))
			draw_circle(Vector2.ZERO, 4.0, Color("#eadcb8"))
		"calendar":
			draw_rect(Rect2(-6, -8, 12, 14), Color("#eadcb8"))
			draw_rect(Rect2(-6, -8, 12, 3), Color("#9b2f2a"))
		"lamp":
			draw_rect(Rect2(-6, -2, 12, 8), Color("#45464e"))
			draw_rect(Rect2(-4, -9, 8, 7), Color("#ffe9a8") if Lighthouse.lamp_on else Color("#6f6a60"))
		"mechanism":
			draw_circle(Vector2.ZERO, 7.0, Color("#45464e"))
			draw_line(Vector2.ZERO, Vector2(cos(_wind_angle), sin(_wind_angle)) * 6.0, Color("#c9a24a"), 2.0)
		"glass":
			draw_rect(Rect2(-7, -8, 14, 12), Color("#2f5a76"))
			draw_rect(Rect2(-5, -6, 4, 3), Color("#9fd8d0"))


func interact(player: Player) -> void:
	if Clock.paused:
		return
	var part := Inventory.selected_id()
	if Data.by_id("items", part).has("install") and kind in ["lamp", "mechanism", "lens", "repair", "barrel"]:
		var name_text := Loc.t(str(Data.by_id("items", part)["name"]))
		match Lighthouse.install_part(part):
			"ok":
				_hint("Установлено: %s. Сила огня теперь %d." % [name_text, int(Lighthouse.base_power())])
			"worse":
				_hint("Стоящее сейчас не хуже.")
			"space":
				_hint("Старую деталь некуда убрать: рюкзак полон.")
		return
	match kind:
		"stairs_up":
			Router.goto_map("lh_%d" % (LighthouseFloorInfo.number() + 1), Vector2(3 * 16 + 8, 3 * 16 + 8))
		"stairs_down":
			Router.goto_map("lh_%d" % (LighthouseFloorInfo.number() - 1), Vector2(16 * 16 + 8, 3 * 16 + 8))
		"exit_door":
			Router.goto_map("cape", Vector2(724, 290))
		"fortuna":
			var scene := Story.fortuna_scene()
			if scene != "":
				Cutscenes.play(scene)
			elif Story.fortuna_fate == "released":
				InfoPanel.open(_hud(), "Фортуна", func() -> String: return Loc.t("fortuna.release"))
			else:
				InfoPanel.open(_hud(), "Фортуна", func() -> String: return Dialogue.fortuna_talk())
		"barrel":
			_open_barrel()
		"repair":
			_open_repairs()
		"desk":
			_open_desk()
		"bunk":
			Night.end_day(false, true)
		"barometer":
			InfoPanel.open(_hud(), "Барометр", barometer_text)
		"calendar":
			InfoPanel.open(_hud(), "Лоцманский календарь", calendar_text)
		"lamp":
			_use_lamp(player)
		"mechanism":
			_start_winding(player)
		"glass":
			if Lighthouse.cleanliness >= Lighthouse.glass_cap():
				_hint("Стёкла чистые, насколько позволяет их состояние.")
			elif player.energy <= 0.0:
				_hint("Нужен отдых, сил на работу нет.")
			elif Lighthouse.clean_glass():
				player.spend_energy("clean_glass")
				_hint("Стёкла протёрты: чистота %d." % int(Lighthouse.cleanliness))
			else:
				_hint("Нужна ветошь.")
		"gallery":
			InfoPanel.open(_hud(), "Галерея", spyglass_text, [["Смотреть в трубу", func(p: InfoPanel) -> String:
				if not Spyglass.has_glass():
					return "Без трубы видно только море."
				p.close()
				SpyglassView.open(_hud())
				return ""]])


static func barometer_text() -> String:
	var lines: Array[String] = []
	var names := {"clear": "ясно", "cloud": "облачно", "rain": "дождь", "fog": "туман", "storm": "шторм",
		"snow": "снег", "blizzard": "метель"}
	for offset in range(1, 8):
		lines.append("Через %d дн.: %s" % [offset, names.get(Weather.barometer(offset), "")])
	return "Стрелка дрожит, но в целом уверена.\n" + "\n".join(lines)


static func calendar_text() -> String:
	var lines: Array[String] = []
	for night in ShipTraffic.calendar(Clock.day_index):
		var names: Array[String] = []
		for ship in night["ships"]:
			names.append(Loc.t(str(ship["name"])))
		var index := int(night["day_index"])
		lines.append("%s %d: %s" % [Loc.t("season." + Clock.SEASONS[(index % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON]),
			1 + index % Clock.DAYS_PER_SEASON, ", ".join(names) if not names.is_empty() else "никого"])
	return "\n".join(lines)


static func spyglass_text() -> String:
	if Inventory.count_of("spyglass") <= 0 and not Game.flag("spyglass_installed"):
		return "Море до горизонта. Без подзорной трубы видно только его."
	var names: Array[String] = []
	for ship in ShipTraffic.ships_for_night(Clock.day_index):
		names.append(Loc.t(str(ship["name"])))
	var text := "Сегодня ночью: %s." % (", ".join(names) if not names.is_empty() else "никого")
	if Clock.minutes >= Lighthouse.sunset_minutes() - 30:
		var names_weather := {"clear": "ясно", "cloud": "облачно", "rain": "дождь", "fog": "туман",
			"storm": "шторм", "snow": "снег", "blizzard": "метель"}
		text += "\nЗавтра на горизонте: %s." % names_weather.get(Weather.weather_for_day(Clock.day_index + 1), "")
	else:
		text += "\nПогоду на завтра видно только на закате."
	return text


func _open_barrel() -> void:
	var body := func() -> String:
		if Lighthouse.barrel.is_empty():
			return "Бочка пуста. Слитое при смене топлива хранится здесь без потерь."
		var lines: Array[String] = []
		for id in Lighthouse.barrel:
			lines.append("%s: ночей — %.1f" % [Loc.t(str(Data.by_id("items", id).get("name", id))), float(Lighthouse.barrel[id])])
		return "\n".join(lines)
	var pour := func(_panel: InfoPanel) -> String:
		for id in Lighthouse.barrel.keys():
			var poured := Lighthouse.refill_from_barrel(str(id))
			if poured > 0.0:
				return "Залито в резервуар: ночей — %.1f." % poured
		return "Резервуар полон или занят другим топливом."
	InfoPanel.open(_hud(), "Бочка кладовой", body, [["Залить в резервуар", pour]])


static func repair_lines() -> Array:
	var out: Array = []
	for part in PARTS:
		var info: Dictionary = Lighthouse.REPAIRS[part]
		var done := Game.flag(str(info["flag"])) if info.has("flag") else int(Lighthouse.tower.get(part, 0)) >= 2
		var needs: Array[String] = []
		for need in info["items"]:
			needs.append("%s ×%d" % [Loc.t(str(Data.by_id("items", str(need[0])).get("name", need[0]))), int(need[1])])
		out.append("%s — %s" % [PARTS[part], "готово" if done else ", ".join(needs)])
	return out


func _open_repairs() -> void:
	var body := func() -> String:
		if not Knowledge.has_unlock("tower_repair"):
			return "Ремонт по уставу — после узла M5 древа знаний (стол в вахтенной)."
		return "Состояние башни: %d из 10." % Lighthouse.tower_points()
	var fix := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		if index < 0:
			return "Выберите часть."
		match Lighthouse.repair(str(PARTS.keys()[index])):
			"ok":
				return "Отремонтировано."
			"done":
				return "Уже в порядке."
			"locked":
				return "Нужен узел M5."
			_:
				return "Не хватает материалов."
	InfoPanel.open(_hud(), "Ремонт башни", body, [["Починить выбранное", fix]], func() -> Array: return repair_lines())


func _open_desk() -> void:
	var body := func() -> String:
		return "Записи: ⚓ %d · 🌿 %d · 🕯 %d. Журнал: %s." % [Knowledge.sea_pts, Knowledge.land_pts,
			Knowledge.rest_pts, "запись сделана" if Lighthouse.log_day == Clock.day_index else "сегодня пусто"]
	var write := func(_panel: InfoPanel) -> String:
		return "Запись сделана." if Lighthouse.write_log() else "Сегодня уже писали."
	var study := func(_panel: InfoPanel) -> String:
		var gain := Knowledge.study(Inventory.selected_id())
		return "Изучено: +%d." % gain if gain > 0 else "Нечего изучать: выберите на панели новый предмет."
	var tree := func(_panel: InfoPanel) -> String:
		(func() -> void: KnowledgeBook.open(_hud())).call_deferred()
		return ""
	InfoPanel.open(_hud(), "Стол смотрителя", body,
		[["Записать в журнал", write], ["Изучить выбранное", study], ["Древо знаний (K)", tree]])


func _use_lamp(player: Player) -> void:
	if Lighthouse.lamp_on:
		_hint("Огонь горит · сила %d" % int(Lighthouse.base_power()))
		return
	if Lighthouse.fuel_nights <= 0.0:
		var poured := Lighthouse.refill()
		_hint("Резервуар заправлен: ночей — %.0f. Удерживайте E, чтобы зажечь." % Lighthouse.fuel_nights if poured > 0
			else "Нужно топливо: рыбий жир, ворвань или керосин.")
		return
	_keeper = player
	_held = 0.0


func hold_seconds() -> float:
	return 4.0 if Weather.current in ["storm", "blizzard"] else 2.0


func _start_winding(player: Player) -> void:
	if Lighthouse.wound():
		_hint("Механизм заведён.")
		return
	if player.energy <= 0.0:
		_hint("Нужен отдых, сил на работу нет.")
		return
	_keeper = player
	_winding = true
	_wind_angle = 0.0
	_last_angle = (get_global_mouse_position() - global_position).angle()
	_hint("Заводка: три круга мышью вокруг механизма.")


# Mouse (or stick) circles around the mechanism; three full turns wind it (10.1).
func add_rotation(radians: float) -> bool:
	if not _winding:
		return false
	_wind_angle += absf(radians)
	queue_redraw()
	if _wind_angle >= TAU * WIND_TURNS:
		_winding = false
		if Lighthouse.wind() and _keeper:
			_keeper.spend_energy("wind_mechanism")
		_hint("Механизм заведён · сила %d" % int(Lighthouse.base_power()))
		return true
	_hint("Заводка: %.1f из 3 оборотов" % (_wind_angle / TAU))
	return false


func _process(delta: float) -> void:
	if _winding:
		if _keeper == null or _keeper.global_position.distance_to(global_position) > 40.0:
			_winding = false
			return
		var angle := (get_global_mouse_position() - global_position).angle()
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if stick.length() > 0.5:
			angle = stick.angle()
		add_rotation(wrapf(angle - _last_angle, -PI, PI))
		_last_angle = angle
		return
	if kind != "lamp" or _keeper == null:
		return
	if Clock.paused or not Input.is_action_pressed("interact") or \
			_keeper.global_position.distance_to(global_position) > 40.0:
		_keeper = null
		_hint("Спичка погасла. Удерживайте E дольше.")
		return
	_held += delta
	if _held >= hold_seconds():
		_keeper = null
		if Lighthouse.light_lamp():
			queue_redraw()
			_hint("Огонь зажжён · сила %d" % int(Lighthouse.base_power()))
	else:
		_hint("Удерживайте E: %.1f / %.0f с" % [_held, hold_seconds()])
