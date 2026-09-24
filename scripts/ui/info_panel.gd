extends PanelContainer
class_name InfoPanel

# A generic tower panel: a title, a body that can be rebuilt, and action buttons.
var title_text: String = ""
var body_source: Callable
var actions: Array = []
var list_source: Callable
var _was_paused: bool = false
var _body: Label
var _list: ItemList
var _status: Label


static func open(hud: CanvasLayer, title: String, body: Callable, buttons: Array = [],
		list: Callable = Callable()) -> InfoPanel:
	var existing := hud.get_node_or_null("InfoPanel")
	if existing:
		existing.free()
	var panel := InfoPanel.new()
	panel.name = "InfoPanel"
	panel.title_text = title
	panel.body_source = body
	panel.actions = buttons
	panel.list_source = list
	hud.add_child(panel)
	return panel


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(60, 20)
	custom_minimum_size = Vector2(360, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121a26")
	style.border_color = Color("#b08f6c")
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color("#ffe9a8"))
	column.add_child(title)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(350, 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 8)
	_body.add_theme_color_override("font_color", Color("#eadcb8"))
	column.add_child(_body)
	if list_source.is_valid():
		_list = ItemList.new()
		_list.custom_minimum_size = Vector2(350, 90)
		_list.add_theme_font_size_override("font_size", 8)
		column.add_child(_list)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 8)
	_status.add_theme_color_override("font_color", Color("#dfe9ea"))
	column.add_child(_status)
	var buttons := HFlowContainer.new()
	buttons.custom_minimum_size = Vector2(350, 0)
	column.add_child(buttons)
	for action in actions:
		var button := Button.new()
		button.text = str(action[0])
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(func() -> void: press(str(action[0])))
		buttons.add_child(button)
	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 8)
	close_button.pressed.connect(close)
	buttons.add_child(close_button)
	refresh()
	if _list and _list.item_count > 0:
		_list.select(0)


func refresh() -> void:
	_body.text = str(body_source.call()) if body_source.is_valid() else ""
	if _list:
		var picked := _list.get_selected_items()
		_list.clear()
		for line in list_source.call():
			_list.add_item(str(line))
		if not picked.is_empty() and _list.item_count > 0:
			_list.select(mini(picked[0], _list.item_count - 1))


func selected_index() -> int:
	if _list == null:
		return -1
	var picked := _list.get_selected_items()
	return -1 if picked.is_empty() else picked[0]


func select(index: int) -> void:
	if _list and index >= 0 and index < _list.item_count:
		_list.select(index)


# Runs the named action; its callable receives this panel and returns a status line.
func press(label: String) -> String:
	for action in actions:
		if str(action[0]) == label:
			var status := str(action[1].call(self))
			_status.text = status
			refresh()
			return status
	return ""


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
