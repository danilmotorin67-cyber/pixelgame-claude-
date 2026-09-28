extends Control

# The title screen: the backdrop, the name of the game, the menu and the version in the corner.
# «Продолжить» loads the latest save; «Новая игра» and «Загрузить» go through the slot list; «Настройки»
# and «Авторы» open their windows. Leaving the screen fades to black.
#
# The backdrop is a stand-in until the title illustration exists: assets/sprites/illustrations/title.png
# (the `title` frame of docs/art/ILLUSTRATIONS_GPT_IMAGE.md) replaces it by itself once it is built.
const BACKDROP := "res://assets/sprites/illustrations/title.png"
const FADE := 0.35

var _menu: VBoxContainer
var _logo_nodes: Array[Control] = []
var _buttons := {}
var _window: MenuWindow
var _busy := false


func _ready() -> void:
	Screen.layout_root(self)
	Clock.paused = true
	_backdrop()
	_logo()
	_build_menu()
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	version.add_theme_color_override("font_color", UiKit.MUTED)
	version.position = Vector2(Screen.BASE.x - 8, Screen.BASE.y - 14)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)
	version.position.x = Screen.BASE.x - 8 - version.get_combined_minimum_size().x
	_refresh()
	_fade_in()


# The stand-in: a night sky over a dark sea, with the title picture over it once there is one.
func _backdrop() -> void:
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#0b0e14"))
	gradient.set_color(1, Color("#1b2b3c"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 64
	sky.texture = tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Screen.BASE
	add_child(sky)
	if ResourceLoader.exists(BACKDROP):
		var art := TextureRect.new()
		art.texture = load(BACKDROP) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.size = Screen.BASE
		add_child(art)


func _logo() -> void:
	var name := Label.new()
	name.text = "СОЛЁНЫЙ СВЕТ"
	name.add_theme_font_size_override("font_size", 32)
	name.add_theme_color_override("font_color", Color("#ffc85a"))
	name.add_theme_color_override("font_shadow_color", Color("#2b1f1a"))
	name.add_theme_constant_override("shadow_offset_x", 2)
	name.add_theme_constant_override("shadow_offset_y", 2)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.position = Vector2(0, 36)
	name.size = Vector2(Screen.BASE.x, 36)
	add_child(name)
	_logo_nodes.append(name)
	var sub := Label.new()
	sub.text = "Хроники смотрителя маяка"
	sub.add_theme_color_override("font_color", UiKit.PAPER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 78)
	sub.size = Vector2(Screen.BASE.x, 12)
	add_child(sub)
	_logo_nodes.append(sub)


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 5)
	_menu.custom_minimum_size = Vector2(140, 0)
	add_child(_menu)
	for entry in [["continue", "Продолжить", _on_continue], ["new", "Новая игра", _on_new_game],
			["load", "Загрузить", _on_load], ["settings", "Настройки", _on_settings],
			["credits", "Авторы", _on_credits], ["quit", "Выход", _on_quit]]:
		var b := Button.new()
		b.name = str(entry[0]).capitalize()
		b.text = str(entry[1])
		b.pressed.connect(func() -> void:
			AudioMgr.play_sfx("ui_click")
			(entry[2] as Callable).call())
		_menu.add_child(b)
		_buttons[entry[0]] = b
	_menu.reset_size()
	_menu.position = Vector2(((Screen.BASE.x - _menu.size.x) / 2.0), 120).round()


func _refresh() -> void:
	var has_save := Save.latest_slot() >= 0
	(_buttons["continue"] as Button).disabled = not has_save
	(_buttons["load"] as Button).disabled = not has_save
	_menu.visible = _window == null
	# A window takes the middle of the screen; the name steps aside for it.
	for node in _logo_nodes:
		node.visible = _window == null
	if _window == null:
		(_buttons["continue" if has_save else "new"] as Button).grab_focus()


func _open(window: MenuWindow) -> void:
	_window = window
	window.closed.connect(func() -> void:
		_window = null
		_refresh())
	add_child(window)
	_refresh()


func _on_continue() -> void:
	var slot := Save.latest_slot()
	if slot >= 0:
		_leave(func() -> void: _load(slot))


func _on_new_game() -> void:
	var list := SlotList.new("new")
	list.chosen.connect(func(slot: int) -> void:
		Save.current_slot = slot
		_leave(func() -> void: get_tree().change_scene_to_file("res://scenes/main/prologue.tscn")))
	_open(list)


func _on_load() -> void:
	var list := SlotList.new("load")
	list.chosen.connect(func(slot: int) -> void: _leave(func() -> void: _load(slot)))
	_open(list)


func _on_settings() -> void:
	_open(SettingsPanel.new())


func _on_credits() -> void:
	_open(CreditsPanel.new())


func _on_quit() -> void:
	_leave(func() -> void: get_tree().quit())


func _load(slot: int) -> void:
	if Save.load_game(slot):
		Router.goto_map(Router.current_map)


# Fades to black, then does `then` (once, however often it is asked).
func _leave(then: Callable) -> void:
	if _busy:
		return
	_busy = true
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.size = Screen.BASE
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, FADE)
	tween.tween_callback(then)


func _fade_in() -> void:
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.size = Screen.BASE
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 0.0, FADE)
	tween.tween_callback(black.queue_free)
