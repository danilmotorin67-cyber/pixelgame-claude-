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

func _ready() -> void:
	apply_language()


# The game speaks Russian unless the player picks English (34).
func apply_language() -> void:
	TranslationServer.set_locale(language if language in ["ru", "en"] else "ru")


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
