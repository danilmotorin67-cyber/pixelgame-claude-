extends Label
class_name RitualChecklist


static func lines() -> Array[String]:
	var out: Array[String] = []
	var fog := Lighthouse.foggy()
	var items := [
		["Заправить резервуар", Lighthouse.fuel_nights > 0.0 or Lighthouse.lamp_on],
		["Зажечь лампу", Lighthouse.lamp_on],
		["Завести механизм", Lighthouse.wound()],
		["Протереть стёкла", Lighthouse.cleanliness >= 6.0 or Lighthouse.cleanliness >= Lighthouse.glass_cap()],
	]
	if fog:
		items.append(["Туманный сигнал: колокол у двери", Lighthouse.bell_hours.has(Clock.hour) or Lighthouse.signal_level() >= 2])
	items.append(["Запись в вахтенный журнал", Lighthouse.log_day == Clock.day_index])
	for item in items:
		out.append(("✓ " if bool(item[1]) else "□ ") + str(item[0]))
	return out


func _ready() -> void:
	position = Vector2(318, 66)
	size = Vector2(158, 90)
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", Color("#eadcb8"))
	add_theme_stylebox_override("normal", UiKit.box("tooltip"))


func _process(_delta: float) -> void:
	text = "Вахта\n" + "\n".join(lines())
