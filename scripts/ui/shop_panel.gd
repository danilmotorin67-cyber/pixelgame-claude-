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
	if shop_id == "shop_chapel":
		buttons.add_child(_button("Отпевание", func() -> void:
			_status.text = {"ok": "Бенедикт отпел тело из покойницкой.", "hours": "Отпевания — по воскресеньям с 10 до 12.",
				"nobody": "В покойницкой некого отпевать.", "cost": "Нужно 50 кр и 2 свечи."}.get(Graveyard.chapel_funeral(), "")))
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
	if str(entry.get("upgrade", "")) == "boathouse":
		return "Лодочный сарай ур. 2 и шлюпка (200 досок)"
	if entry.has("service"):
		return Loc.t("service." + str(entry["service"]))
	if entry.has("building"):
		var id_b := str(entry["building"])
		var next := Buildings.next_level_info(id_b)
		var parts: Array[String] = []
		for need in next.get("items", []):
			parts.append("%s ×%d" % [Crafting.item_name(str(need[0])), int(need[1])])
		var level_text := " ур. %d" % (Buildings.level(id_b) + 1) if Buildings.max_level(id_b) > 1 else ""
		return "Постройка: %s%s (%s; %d дн.)" % [Loc.t("building." + id_b), level_text, ", ".join(parts) if not parts.is_empty() else "без материалов", int(next.get("days", 1))]
	if entry.has("tool_upgrade"):
		var tool_id := str(entry["tool_upgrade"])
		var cost := Buildings.tool_upgrade_price(tool_id)
		var tiers := ["медная", "железная", "серебряная", "из лунного серебра"]
		return "Улучшить: %s → %s (5 × %s, %d дн.)" % [Crafting.item_name(tool_id), tiers[Buildings.tool_level(tool_id)],
			Crafting.item_name(str(cost[0])), 1 if Game.flag("family_tongs") else 2]
	if entry.has("animal"):
		return Loc.t("animal." + str(entry["animal"]))
	if entry.has("recipe"):
		return "Рецепт: " + Crafting.item_name(str(Crafting._recipe(str(entry["recipe"])).get("out", ["", 1])[0]))
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
			if entry.has("building"):
				_status.text = "Ильм взялся за работу: готово через %d дн." % Buildings.days_left()
			elif entry.has("animal"):
				_status.text = "Маргит приведёт его к вам на мыс сегодня же."
			else:
				_status.text = Economy.last_service if entry.has("service") else "Куплено: %s ×%d. Осталось %d кр." % [entry_name(entry), count, Economy.money]
		"money":
			_status.text = "Не хватает крон."
		"space":
			_status.text = "Рюкзак полон."
		"materials":
			_status.text = "Не хватает материалов."
		"nothing":
			_status.text = "Для этой услуги нечего предъявить."
		"busy":
			_status.text = "Тора уже куёт другой инструмент." if entry.has("tool_upgrade") else "Ильм уже строит: ещё %d дн." % Buildings.days_left()
		"home":
			_status.text = "Для него нет места: нужна постройка или свободное место в ней."
		"season":
			_status.text = "Пока не продаётся."
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
