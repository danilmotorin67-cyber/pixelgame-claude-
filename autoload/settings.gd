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

# The settings are the player's, not the save's: they live in their own file, read at start and written on
# every change (from the title screen or the journal).
const PREFS := "user://settings.json"
var prefs_path := PREFS

func _ready() -> void:
	load_prefs()
	apply_language()
	apply_audio()
	# The pixel font and the PixelLab frames style every window and HUD panel.
	UiKit.install(get_tree())


# The game speaks Russian unless the player picks English (34).
func apply_language() -> void:
	TranslationServer.set_locale(language if language in ["ru", "en"] else "ru")


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_vol, 0.0001)))
		AudioServer.set_bus_mute(bus, master_vol <= 0.0)
	for name in ["Music", "SFX"]:
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


func serialize() -> Dictionary:
	return {
		"language": language, "ui_scale": ui_scale, "shake": shake,
		"lightning_flash": lightning_flash, "master_vol": master_vol,
		"music_vol": music_vol, "sfx_vol": sfx_vol, "save_anytime": save_anytime,
		"fortuna_reminder": fortuna_reminder, "fishing_assist": fishing_assist,
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
	apply_language()
