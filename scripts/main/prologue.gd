extends Control

# Prologue "The Letter" (5.1): Kronvald, the Neptune & Partners office, rain. Three stamps, two letters, the
# talk with Stern, the keeper's form, the steamer Gull in the fog. Then Spring 1, 17:00, the cape.
# Each step has its full-screen illustration (tools/build_illustrations.py); the text sits in a panel at the
# bottom that grows upward to fit, and the pictures cross-fade from one step to the next.
const FADE := 0.6
var step: int = 0
var stamped: int = 0
var hero: Dictionary = {"name": "Смотритель", "gender": "m", "love": ""}
var _text: Label
var _buttons: HFlowContainer
var _name: LineEdit
var _love: LineEdit
var _panel: PanelContainer
var _picture: TextureRect
var _previous: TextureRect
var _shown := ""


func _ready() -> void:
	Screen.layout_root(self)
	Clock.paused = true
	var bg := ColorRect.new()
	bg.color = Color("#10161f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_previous = _frame()
	_picture = _frame()
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(Screen.BASE.x - 16, 0)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	_text = Label.new()
	_text.custom_minimum_size = Vector2(Screen.BASE.x - 32, 0)
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
	_buttons.custom_minimum_size = Vector2(Screen.BASE.x - 32, 0)
	column.add_child(_buttons)
	show_step()


func _frame() -> TextureRect:
	var rect := TextureRect.new()
	rect.size = Screen.BASE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


# The illustration of this step, faded in over the last one; kept as it is while the step only changes text.
func _show_picture(id: String) -> void:
	if id == _shown:
		return
	_shown = id
	var path := "res://assets/sprites/illustrations/%s.png" % id
	var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
	_previous.texture = _picture.texture
	_previous.modulate.a = 1.0
	_picture.texture = tex
	_picture.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_picture, "modulate:a", 1.0, FADE)


# The panel hugs its text at the bottom of the screen; on the form it moves up so the form stays in view.
func _fit() -> void:
	_panel.reset_size()
	_panel.position = Vector2(8, 6 if step == 4 else Screen.BASE.y - _panel.size.y - 6)


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
	_show_picture("prologue_%d" % (step + 1))
	call_deferred("_fit")
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
