extends PanelContainer
class_name StationPanel

const RESULT_TEXT := {"ok": "Готово.", "ingredients": "Не хватает ингредиентов.", "fuel": "Нужен плавник для огня.",
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


func kind() -> String:
	return str(Crafting.station(str(obj().get("id", ""))).get("kind", ""))


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(90, 30)
	custom_minimum_size = Vector2(300, 182)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121a26")
	style.border_color = Color("#b08f6c")
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_label(Loc.t(str(Crafting.station(str(obj()["id"])).get("name", ""))), Color("#ffe9a8")))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(290, 110)
	_list.add_theme_font_size_override("font_size", 8)
	_list.item_activated.connect(func(_i: int) -> void: act())
	column.add_child(_list)
	_status = _label("", Color("#dfe9ea"))
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	match kind():
		"storage":
			buttons.add_child(_button("Взять", act))
			buttons.add_child(_button("Положить с панели", store_selected_hotbar))
			buttons.add_child(_button("Убрать сундук", pick_up))
		"process":
			buttons.add_child(_button("Загрузить", act))
			buttons.add_child(_button("Забрать", collect))
		_:
			buttons.add_child(_button("Сделать", act))
			if int(Crafting.station(str(obj()["id"])).get("batch", 1)) > 1:
				buttons.add_child(_button("×5", func() -> void: act(5)))
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
	if id.begins_with("tag:"):
		return Loc.t("tag." + id.substr(4))
	return Loc.t(str(Data.by_id("items", id).get("name", id)))


func refresh() -> void:
	var selected := _list.get_selected_items()
	_list.clear()
	_rows.clear()
	var current := obj()
	if kind() == "storage":
		for index in current["slots"].size():
			var s: Dictionary = current["slots"][index]
			if str(s["id"]) != "":
				_rows.append(index)
				_list.add_item("%s ×%d" % [item_name(str(s["id"])), int(s["count"])])
		if _rows.is_empty():
			_list.add_item("Сундук пуст.")
	else:
		for recipe in Crafting.recipes_for(str(current["id"])):
			_rows.append(str(recipe["id"]))
			var parts: Array[String] = []
			for need in recipe["in"]:
				parts.append("%s ×%d" % [item_name(str(need[0])), int(need[1])])
			var out: Array = recipe["out"]
			var mark := "" if Crafting.has_ingredients(recipe) else "  (нет)"
			_list.add_item("%s ×%d ← %s%s" % [item_name(str(out[0])), int(out[1]), ", ".join(parts), mark])
		if kind() == "process":
			var queue: Array = current["queue"]
			for job in queue:
				var left := int(job["ready_at"]) - Crafting.now()
				_status.text = "В работе: %d · %s" % [queue.size(),
					"готово" if left <= 0 else "ещё %d ч" % ceili(float(left) / 60.0)]
			if queue.is_empty():
				_status.text = "Пусто."
	if not selected.is_empty() and _list.item_count > 0:
		_list.select(mini(selected[0], _list.item_count - 1))


func act(count: int = 1) -> String:
	var picked := _list.get_selected_items()
	if picked.is_empty() or picked[0] >= _rows.size():
		return "unknown"
	var result := "unknown"
	match kind():
		"storage":
			result = "ok" if Crafting.retrieve(obj(), int(_rows[picked[0]])) else "space"
		"process":
			result = Crafting.start(obj(), str(_rows[picked[0]]))
		_:
			result = Crafting.make(str(_rows[picked[0]]), count)
	refresh()
	if kind() != "process" or result != "ok":
		_status.text = RESULT_TEXT.get(result, "")
	return result


func collect() -> int:
	var taken := Crafting.collect(obj())
	refresh()
	_status.text = "Забрано: %d." % taken if taken > 0 else "Ещё не готово."
	return taken


func store_selected_hotbar() -> bool:
	var ok := Crafting.store(obj(), Inventory.selected_hotbar)
	refresh()
	_status.text = "Положено." if ok else "Не помещается или нечего класть."
	return ok


func pick_up() -> void:
	if Crafting.pick_up(Router.current_map, obj()):
		_rebuild_world()
		close()
	else:
		_status.text = "Сначала опустошите сундук."


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
