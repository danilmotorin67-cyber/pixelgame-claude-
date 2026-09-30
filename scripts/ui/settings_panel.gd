class_name SettingsPanel
extends MenuWindow

# The settings from the title screen (34): language, the three volumes and the comfort switches. Every
# change is written to the player's settings file at once (Settings.save_prefs).
const SWITCHES := [["fullscreen", "Полный экран (F11)"], ["shake", "Тряска экрана"], ["lightning_flash", "Вспышки молний"],
	["fortuna_reminder", "Напоминание Фортуны"], ["fishing_assist", "Помощь в рыбалке"],
	["save_anytime", "Сохранение в любой момент"]]
const VOLUMES := [["master_vol", "Громкость"], ["music_vol", "Музыка"], ["sfx_vol", "Звуки"]]


func _init() -> void:
	super("Настройки")


func _ready() -> void:
	var language := Button.new()
	language.text = _language_text()
	language.pressed.connect(func() -> void:
		Settings.language = "en" if Settings.language == "ru" else "ru"
		Settings.save_prefs()
		language.text = _language_text())
	body.add_child(language)
	for v in VOLUMES:
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = str(v[1])
		name.custom_minimum_size = Vector2(110, 0)
		row.add_child(name)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.1
		slider.value = float(Settings.get(str(v[0])))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 12)
		var shown := Label.new()
		shown.custom_minimum_size = Vector2(34, 0)
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		shown.text = "%d%%" % roundi(slider.value * 100.0)
		slider.value_changed.connect(func(value: float) -> void:
			Settings.set(str(v[0]), value)
			Settings.save_prefs()
			shown.text = "%d%%" % roundi(value * 100.0))
		row.add_child(slider)
		row.add_child(shown)
		body.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	for s in SWITCHES:
		var check := CheckBox.new()
		check.text = str(s[1])
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.button_pressed = bool(Settings.get(str(s[0])))
		check.toggled.connect(func(on: bool) -> void:
			Settings.set(str(s[0]), on)
			Settings.save_prefs())
		grid.add_child(check)
	add_label("Настройки общие для всех сохранений.", UiKit.MUTED)
	super()


static func _language_text() -> String:
	return "Язык: " + ("русский" if Settings.language == "ru" else "English")
