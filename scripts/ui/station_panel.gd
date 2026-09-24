extends PanelContainer
class_name StationPanel

const RESULT_TEXT := {"ok": "Готово.", "ingredients": "Не хватает ингредиентов.", "fuel": "Нужно топливо.",
	"space": "Рюкзак полон.", "full": "Очередь полна: три задания.", "unknown": "Так не выйдет."}

var uid: int = 0
var _was_paused: bool = false
var _list: ItemList
var _status: Label
var _rows: Array = []


static func open(hud: CanvasLayer, object_uid: int) -> StationPanel:
	var existing := hud.get_node_or_null("StationPanel")
	if existing:
		existing.free()
	var panel := StationPanel.new()
	panel.name = "StationPanel"
	panel.uid = object_uid
	hud.add_child(panel)
	return panel


func obj() -> Dictionary:
	return Crafting.find(Router.current_map, uid)


func station_id() -> String:
	return str(obj().get("id", ""))


func kind() -> String:
	return Crafting.kind_of(obj())


func title() -> String:
	var current := obj()
	if kind() == "tree":
		return Loc.t(str(Data.by_id("items", str(Crafting.tree_info(current).get("sapling", ""))).get("name", "")))
	if kind() == "decor":
		return Crafting.item_name(str(current.get("item", "")))
	return Loc.t(str(Crafting.station(station_id()).get("name", "")))


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(80, 26)
	custom_minimum_size = Vector2(320, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121a26")
	style.border_color = Color("#b08f6c")
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_label(title(), Color("#ffe9a8")))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(310, 110)
	_list.add_theme_font_size_override("font_size", 8)
	_list.item_activated.connect(func(_i: int) -> void: act())
	column.add_child(_list)
	_status = _label("", Color("#dfe9ea"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(310, 0)
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	match kind():
		"storage", "cellar":
			buttons.add_child(_button("Взять", act))
			buttons.add_child(_button("Положить с панели", store_selected_hotbar))
			buttons.add_child(_button("Убрать", pick_up))
		"process":
			buttons.add_child(_button("Загрузить", act))
			buttons.add_child(_button("Забрать", collect))
			buttons.add_child(_button("Убрать", pick_up))
		"hive":
			buttons.add_child(_button("Забрать мёд", collect))
			buttons.add_child(_button("Убрать", pick_up))
		"tree":
			buttons.add_child(_button("Собрать", collect))
		"fixture":
			buttons.add_child(_button("Долить воды", refill))
			buttons.add_child(_button("Убрать", pick_up))
		"decor":
			buttons.add_child(_button("Убрать", pick_up))
		"nest":
			buttons.add_child(_button("Собрать пух", collect))
			buttons.add_child(_button("Убрать", pick_up))
		_:
			buttons.add_child(_button("Сделать", act))
			if int(Crafting.station(station_id()).get("batch", 1)) > 1:
				buttons.add_child(_button("×5", func() -> void: act(5)))
			if Crafting.station(station_id()).has("item"):
				buttons.add_child(_button("Убрать", pick_up))
	buttons.add_child(_button("Закрыть", close))
	refresh()
	if _list.item_count > 0:
		_list.select(0)
	_list.grab_focus()


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(action)
	return button


static func item_name(id: String) -> String:
	return Crafting.item_name(id)


func _slot_text(s: Dictionary) -> String:
	var q := int(s.get("quality", 0))
	return "%s ×%d%s" % [item_name(str(s["id"])), int(s["count"]), (" · " + Loc.t("quality.%d" % q)) if q > 0 else ""]


func refresh() -> void:
	var selected := _list.get_selected_items()
	_list.clear()
	_rows.clear()
	var current := obj()
	match kind():
		"storage", "cellar":
			for index in current["slots"].size():
				var s: Dictionary = current["slots"][index]
				if str(s["id"]) != "":
					_rows.append(index)
					_list.add_item(_slot_text(s))
			if _rows.is_empty():
				_list.add_item("Пусто.")
			if kind() == "cellar":
				_status.text = "Аквавит, вино и сыр: ступень качества примерно каждые 19 дней, до безупречного за 56."
		"hive":
			for entry in current.get("stock", []):
				_list.add_item("%s ×%d" % [item_name(str(entry[0])), int(entry[1])])
			_status.text = "Зимой пчёлы спят." if Clock.season == "winter" \
				else "Следующий мёд через %d дн." % maxi(0, int(current.get("next", 0)) - Clock.day_index)
		"tree":
			var info := Crafting.tree_info(current)
			if not bool(current.get("grown", false)):
				_status.text = "Растёт: %d из %d дней." % [int(current.get("age", 0)), int(info.get("days", 28))]
			elif int(current.get("fruit", 0)) > 0:
				_status.text = "Плоды созрели: %s." % item_name(str(info["fruit"]))
			else:
				_status.text = "Плодов пока нет."
		"fixture":
			var id := station_id()
			_status.text = "Ветряк качает воду, пока есть ветер." if id == "wind_pump" else (
				"Вода: на %d дн. Дождь наполняет; 5 вёдер пресной воды — тоже." % int(current.get("water", 0))
				if id in ["watering_barrel", "cistern"] else "Стоит и работает.")
		"decor":
			_status.text = "Украшение. Можно убрать обратно в рюкзак."
		"nest":
			_status.text = Animals.nest_status(current)
		_:
			for recipe in Crafting.recipes_for(station_id()):
				_rows.append(str(recipe["id"]))
				var parts: Array[String] = []
				for need in recipe["in"]:
					parts.append("%s ×%d" % [item_name(str(need[0])), int(need[1])])
				var out: Array = recipe["out"]
				var mark := "" if Crafting.has_ingredients(recipe) else "  (нет)"
				_list.add_item("%s ×%d ← %s%s" % [item_name(str(out[0])), int(out[1]), ", ".join(parts), mark])
			if _rows.is_empty():
				_list.add_item("Рецептов пока нет.")
			if kind() == "process":
				var queue: Array = current["queue"]
				var text := "Пусто."
				if not queue.is_empty():
					var left := int(queue[-1]["ready_at"]) - Crafting.now()
					text = "В работе: %d · %s" % [queue.size(), "готово" if left <= 0 else "ещё %d ч" % ceili(float(left) / 60.0)]
				if Crafting.station(station_id()).has("fuel"):
					text += " · топливо: " + Crafting.fuel_text(station_id())
				_status.text = text
	if not selected.is_empty() and _list.item_count > 0:
		_list.select(mini(selected[0], _list.item_count - 1))


func _player() -> Player:
	return get_tree().current_scene.get_node_or_null("Player") as Player if get_tree().current_scene else null


func act(count: int = 1) -> String:
	var picked := _list.get_selected_items()
	if picked.is_empty() or picked[0] >= _rows.size():
		return "unknown"
	var result := "unknown"
	match kind():
		"storage", "cellar":
			result = "ok" if Crafting.retrieve(obj(), int(_rows[picked[0]])) else "space"
		"process":
			result = Crafting.start(obj(), str(_rows[picked[0]]))
		_:
			var player := _player()
			var recipe := Crafting._recipe(str(_rows[picked[0]]))
			if player and float(recipe.get("energy", 0)) > 0.0 and player.energy <= 0.0:
				_status.text = "Нужен отдых, сил на работу нет."
				return "energy"
			result = Crafting.make(str(_rows[picked[0]]), count, station_id())
			if player and Crafting.last_energy > 0.0:
				player.spend_raw(Crafting.last_energy)
	refresh()
	if kind() != "process" or result != "ok":
		var text: String = RESULT_TEXT.get(result, "")
		if result == "fuel":
			text = "Нужно топливо: %s." % Crafting.fuel_text(station_id())
		_status.text = text
	return result


func collect() -> int:
	var taken := 0
	match kind():
		"hive":
			taken = Crafting.take_stock(obj())
		"tree":
			taken = Crafting.pick_fruit(obj())
		"nest":
			taken = Animals.collect_nest(obj())
		_:
			taken = Crafting.collect(obj())
	refresh()
	_status.text = "Забрано: %d." % taken if taken > 0 else "Ещё не готово или некуда положить."
	return taken


func refill() -> void:
	var current := obj()
	var days := int(Game.balance("garden", {}).get("water_days", {}).get(station_id(), 0))
	if days <= 0 or Inventory.count_of("fresh_water") < 5:
		_status.text = "Нужно 5 вёдер пресной воды (колонка у дома)."
		return
	Inventory.take("fresh_water", 5)
	current["water"] = days
	refresh()


func store_selected_hotbar() -> bool:
	var ok := Crafting.store(obj(), Inventory.selected_hotbar)
	refresh()
	if not ok:
		_status.text = "В бочку погреба — аквавит, вино или сыр, по одной партии." if kind() == "cellar" \
			else "Не помещается или нечего класть."
	return ok


func pick_up() -> void:
	if Crafting.pick_up(Router.current_map, obj()):
		_rebuild_world()
		close()
	else:
		_status.text = "Сначала опустошите и дождитесь конца работы."


func _rebuild_world() -> void:
	var stations := get_tree().current_scene.get_node_or_null("Stations") as Stations
	if stations:
		stations.rebuild()


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
