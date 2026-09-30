extends Node

var language: String = "ru"
var ui_scale: int = 2
var shake: bool = true
var lightning_flash: bool = true
var master_vol: float = 1.0
var music_vol: float = 0.8
var sfx_vol: float = 1.0
var save_anytime: bool = false
var fortuna_reminder: bool = true
var fishing_assist: bool = false
var fullscreen: bool = true

# The settings are the player's, not the save's: they live in their own file, read at start and written on
# every change (from the title screen or the journal).
const PREFS := "user://settings.json"
var prefs_path := PREFS

func _ready() -> void:
	load_prefs()
	apply_language()
	apply_audio()
	apply_window()
	if DisplayServer.get_name() != "headless":
		get_tree().root.size_changed.connect(_fit_scale)
		_fit_scale()
	# The pixel font and the PixelLab frames style every window and HUD panel.
	UiKit.install(get_tree())


# The game speaks Russian unless the player picks English (34).
func apply_language() -> void:
	TranslationServer.set_locale(language if language in ["ru", "en"] else "ru")


# F11 or Alt+Enter anywhere switches between full screen and a maximized window, and is remembered.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		fullscreen = not fullscreen
		save_prefs()
		get_viewport().set_input_as_handled()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


# The picture is drawn at 960×540 and scaled up whole times (×2, ×3) while that fills the window, so the
# pixels stay even; a window a little short of the next whole step (a maximized window under the taskbar)
# would drop to far less, so then the picture scales to fit instead.
func _fit_scale() -> void:
	var root := get_tree().root
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 960),
		ProjectSettings.get_setting("display/window/size/viewport_height", 540))
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if whole_scale(Vector2(root.size), base) \
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


# Whole-times scaling suits a window when it still fills at least 90% of what fitting would.
static func whole_scale(window: Vector2, base: Vector2) -> bool:
	var fit := minf(window.x / base.x, window.y / base.y)
	return floorf(fit) >= 1.0 and floorf(fit) / fit >= 0.9


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_vol, 0.0001)))
		AudioServer.set_bus_mute(bus, master_vol <= 0.0)
	for name in ["Music", "SFX", "Ambience", "UI"]:
		var index := AudioServer.get_bus_index(name)
		var vol := music_vol if name == "Music" else sfx_vol
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(vol, 0.0001)))
			AudioServer.set_bus_mute(index, vol <= 0.0)


func has_prefs() -> bool:
	return FileAccess.file_exists(prefs_path)


func load_prefs() -> void:
	if not has_prefs():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(prefs_path))
	if parsed is Dictionary:
		deserialize(parsed)


func save_prefs() -> void:
	var file := FileAccess.open(prefs_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(serialize(), "\t"))
	apply_language()
	apply_audio()
	apply_window()


func serialize() -> Dictionary:
	return {
		"language": language, "ui_scale": ui_scale, "shake": shake,
		"lightning_flash": lightning_flash, "master_vol": master_vol,
		"music_vol": music_vol, "sfx_vol": sfx_vol, "save_anytime": save_anytime,
		"fortuna_reminder": fortuna_reminder, "fishing_assist": fishing_assist, "fullscreen": fullscreen,
	}

func deserialize(d: Dictionary) -> void:
	language = str(d.get("language", "ru"))
	ui_scale = int(d.get("ui_scale", 2))
	shake = bool(d.get("shake", true))
	lightning_flash = bool(d.get("lightning_flash", true))
	master_vol = float(d.get("master_vol", 1.0))
	music_vol = float(d.get("music_vol", 0.8))
	sfx_vol = float(d.get("sfx_vol", 1.0))
	save_anytime = bool(d.get("save_anytime", false))
	fortuna_reminder = bool(d.get("fortuna_reminder", true))
	fishing_assist = bool(d.get("fishing_assist", false))
	fullscreen = bool(d.get("fullscreen", fullscreen))
	apply_language()
