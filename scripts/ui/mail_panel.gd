extends PanelContainer
class_name MailPanel

var _was_paused: bool = false
var _list: ItemList
var _text: Label
var _order: Array = []


static func open(hud: CanvasLayer) -> MailPanel:
	var existing := hud.get_node_or_null("MailPanel")
	if existing:
		existing.free()
	var panel := MailPanel.new()
	panel.name = "MailPanel"
	hud.add_child(panel)
	return panel


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(70, 24)
	custom_minimum_size = Vector2(340, 196)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121a26")
	style.border_color = Color("#b08f6c")
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(330, 70)
	_list.add_theme_font_size_override("font_size", 8)
	_list.item_selected.connect(func(_i: int) -> void: open_selected())
	column.add_child(_list)
	_text = Label.new()
	_text.custom_minimum_size = Vector2(330, 84)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 8)
	_text.add_theme_color_override("font_color", Color("#eadcb8"))
	column.add_child(_text)
	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 8)
	close_button.pressed.connect(close)
	column.add_child(close_button)
	refresh()
	if _list.item_count > 0:
		_list.select(0)
		open_selected()
	else:
		_text.text = "Ящик пуст. Даже счетов нет."


func refresh() -> void:
	_list.clear()
	_order = Mail.letters.duplicate()
	_order.reverse()
	for letter in _order:
		var season_day := "%s %d" % [Loc.t("season." + Clock.SEASONS[(int(letter["day"]) % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON]),
			1 + int(letter["day"]) % Clock.DAYS_PER_SEASON]
		var sender := Mail.text_of(letter).get_slice(".", 0)
		_list.add_item("%s%s · %s" % ["● " if not bool(letter["read"]) else "   ", season_day, sender])


func open_selected() -> void:
	var picked := _list.get_selected_items()
	if picked.is_empty():
		return
	var letter: Dictionary = _order[picked[0]]
	var extra := ""
	if not bool(letter["read"]):
		extra = "" if Mail.read(letter) else "\n(Вложение не помещается в рюкзак.)"
	_text.text = Mail.text_of(letter) + extra
	refresh()
	_list.select(picked[0])


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
