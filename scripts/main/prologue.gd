extends Control

# Prologue "The Letter" (5.1): Kronvald, the Neptune & Partners office, rain. Three stamps, two letters, the
# talk with Stern, the keeper's form, the steamer Gull in the fog. Then Spring 1, 17:00, the cape.
var step: int = 0
var stamped: int = 0
var hero: Dictionary = {"name": "Смотритель", "gender": "m", "love": ""}
var _text: Label
var _buttons: HFlowContainer
var _name: LineEdit
var _love: LineEdit


func _ready() -> void:
	Clock.paused = true
	var bg := ColorRect.new()
	bg.color = Color("#10161f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := VBoxContainer.new()
	column.position = Vector2(24, 20)
	column.custom_minimum_size = Vector2(432, 230)
	add_child(column)
	_text = Label.new()
	_text.custom_minimum_size = Vector2(432, 150)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 9)
	_text.add_theme_color_override("font_color", Color("#eadcb8"))
	column.add_child(_text)
	_name = LineEdit.new()
	_name.placeholder_text = Loc.t("prologue.form.name")
	_name.visible = false
	column.add_child(_name)
	_love = LineEdit.new()
	_love.placeholder_text = Loc.t("prologue.form.love")
	_love.visible = false
	column.add_child(_love)
	_buttons = HFlowContainer.new()
	_buttons.custom_minimum_size = Vector2(432, 0)
	column.add_child(_buttons)
	show_step()


func _button(label: String, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(action)
	_buttons.add_child(b)


func show_step() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	_name.visible = false
	_love.visible = false
	match step:
		0:
			_text.text = Loc.t("prologue.office") + (("\n\n" + Loc.t("prologue.case.%d" % stamped)) if stamped > 0 else "")
			_button(Loc.t("prologue.stamp") % (stamped + 1), func() -> void:
				stamped += 1
				if stamped >= 3:
					step = 1
				show_step())
		1:
			_text.text = Loc.t("prologue.case.3") + "\n\n" + Loc.t("prologue.stern_passes")
			_button(Loc.t("prologue.next"), func() -> void: _go(2))
		2:
			_text.text = Loc.t("prologue.letter.office") + "\n\n" + Loc.t("prologue.letter.agatha")
			_button(Loc.t("prologue.next"), func() -> void: _go(3))
		3:
			_text.text = Loc.t("prologue.stern_talk")
			for i in 3:
				var phrase := Loc.t("prologue.phrase.%d" % (i + 1))
				_button(phrase, func() -> void:
					hero["stern_phrase"] = phrase
					_go(4))
		4:
			_text.text = Loc.t("prologue.form")
			_name.visible = true
			_love.visible = true
			_button(Loc.t("prologue.grandson"), func() -> void:
				hero["gender"] = "m"
				_sign())
			_button(Loc.t("prologue.granddaughter"), func() -> void:
				hero["gender"] = "f"
				_sign())
		5:
			_text.text = Loc.t("prologue.steamer")
			_button(Loc.t("prologue.arrive"), func() -> void: finish())


func _go(n: int) -> void:
	step = n
	show_step()


func _sign() -> void:
	if _name.text.strip_edges() != "":
		hero["name"] = _name.text.strip_edges()
	hero["love"] = _love.text.strip_edges()
	_go(5)


func finish() -> void:
	NewGame.start(hero)
	get_tree().change_scene_to_file("res://scenes/world/cape.tscn")
