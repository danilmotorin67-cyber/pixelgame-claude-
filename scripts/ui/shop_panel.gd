extends PanelContainer
class_name ShopPanel

var shop_id: String = ""
var _entries: Array = []
var _was_paused: bool = false
var _list: ItemList
var _status: Label


static func open(hud: CanvasLayer, id: String) -> ShopPanel:
	var existing := hud.get_node_or_null("ShopPanel") as ShopPanel
	if existing:
		existing.queue_free()
	var panel := ShopPanel.new()
	panel.name = "ShopPanel"
	panel.shop_id = id
	hud.add_child(panel)
	return panel


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
	var info := Economy.shop(shop_id)
	column.add_child(_label("%s · %d:00–%d:00" % [info.get("name", ""), int(info.get("open", 0)),
		int(info.get("close", 0))], Color("#ffe9a8")))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(290, 110)
	_list.add_theme_font_size_override("font_size", 8)
	_list.item_activated.connect(func(_index: int) -> void: buy_selected(1))
	column.add_child(_list)
	_status = _label("", Color("#dfe9ea"))
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	buttons.add_child(_button("Купить", func() -> void: buy_selected(1)))
	buttons.add_child(_button("×5", func() -> void: buy_selected(5)))
	if not info.get("buys", []).is_empty():
		buttons.add_child(_button("Продать с панели", sell_selected_hotbar))
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


func refresh() -> void:
	_entries = Economy.shop_stock(shop_id)
	_list.clear()
	for entry in _entries:
		_list.add_item("%s — %d кр" % [entry_name(entry), int(entry["price"])])


static func entry_name(entry: Dictionary) -> String:
	if str(entry.get("upgrade", "")) == "backpack":
		return "Рюкзак на %d мест" % int(entry["slots"])
	var id := str(entry["item"])
	return Loc.t(str(Data.by_id("items", id).get("name", id)))


func buy_selected(count: int) -> String:
	var picked := _list.get_selected_items()
	if picked.is_empty():
		return "unknown"
	var entry: Dictionary = _entries[picked[0]]
	var result := Economy.buy(shop_id, entry, count)
	match result:
		"ok":
			_status.text = "Куплено: %s ×%d. Осталось %d кр." % [entry_name(entry), count, Economy.money]
		"money":
			_status.text = "Не хватает крон."
		"space":
			_status.text = "Рюкзак полон."
		_:
			_status.text = "Этого сейчас нет."
	refresh()
	if _list.item_count > 0:
		_list.select(mini(picked[0], _list.item_count - 1))
	return result


func sell_selected_hotbar() -> int:
	var income := Economy.sell_to_shop(shop_id, Inventory.selected_hotbar)
	_status.text = "Продано за %d кр." % income if income > 0 else "Здесь такое не покупают."
	return income


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
