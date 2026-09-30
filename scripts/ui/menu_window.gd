class_name MenuWindow
extends PanelContainer

# A window of the title screen: a framed panel in the middle with a heading, its own rows and «Назад».
# Esc (ui_cancel) closes it too; `closed` tells the title screen to give the focus back to its menu.
signal closed

const WIDTH := 330.0
var body: VBoxContainer
var _heading: Label


func _init(heading: String) -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_heading = Label.new()
	_heading.text = heading
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 16)
	_heading.add_theme_color_override("font_color", UiKit.GOLD)
	column.add_child(_heading)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	column.add_child(body)
	var back := Button.new()
	back.text = "Назад"
	back.set_meta("sfx", "")  # close() plays ui_back
	back.pressed.connect(close)
	column.add_child(back)


func _ready() -> void:
	reset_size()
	position = ((Screen.BASE - size) / 2.0).round()
	call_deferred("focus_first")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	AudioMgr.play_sfx("ui_back")
	closed.emit()
	queue_free()


# Keeps the window centred when its rows change.
func refit() -> void:
	reset_size()
	position = ((Screen.BASE - size) / 2.0).round()


func focus_first() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		if b.visible and not b.disabled:
			b.grab_focus()
			return


func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func add_label(text: String, color := UiKit.PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 16, 0)
	l.add_theme_color_override("font_color", color)
	body.add_child(l)
	return l
