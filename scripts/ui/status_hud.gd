extends Control
class_name StatusHud

# 30.1, top right: the day and the time with the weather, the tide (arrow, level, next peak) with
# the moon, and the money underneath. Everything is read from the clock when it redraws.
const WEEKDAYS := {"mon": "Пн", "tue": "Вт", "wed": "Ср", "thu": "Чт", "fri": "Пт", "sat": "Сб", "sun": "Вс"}
const SEASONS := {"spring": "Весна", "summer": "Лето", "autumn": "Осень", "winter": "Зима"}
const WEATHER_NAMES := {"clear": "Ясно", "cloud": "Облачно", "rain": "Дождь", "fog": "Туман", "storm": "Шторм",
	"snow": "Снег", "blizzard": "Метель"}
const WIDTH := 124.0
const PANEL_H := 52.0
const TIDE := Color("#6fb0b3")
const WARM := Color("#ffe9a8")

var _minute := -1


func _process(_delta: float) -> void:
	if Clock.minutes != _minute:
		_minute = Clock.minutes
		queue_redraw()


func weather_icon() -> String:
	if Weather.hmar_night and (Clock.hour >= 21 or Clock.hour < 5):
		return "weather_hmar"
	if Weather.aurora and (Clock.hour >= 20 or Clock.hour < 5):
		return "weather_aurora"
	return "weather_" + ("snow" if Weather.current == "blizzard" else Weather.current)


# The moon's age: new on day 2, full on day 16 of the 28-day season (Clock.moon_name).
static func moon_phase() -> int:
	return posmod(roundi(float(Clock.day - 2) / 28.0 * 8.0), 8)


func _text(at: Vector2, text: String, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := UiKit.font()
	draw_string(font, at + Vector2(0, 1), text, align, width, 8, Color(0, 0, 0, 0.55))
	draw_string(font, at, text, align, width, 8, color)


func _draw() -> void:
	draw_style_box(UiKit.box("panel"), Rect2(0, 0, WIDTH, PANEL_H))
	# Row 1: weather, day, time.
	UiKit.draw_icon(self, weather_icon(), Vector2(6, 4))
	_text(Vector2(25, 15), "%s, %s %d" % [WEEKDAYS.get(Clock.weekday, Clock.weekday), SEASONS.get(Clock.season, Clock.season),
		Clock.day], UiKit.PAPER)
	_text(Vector2(0, 15), "%02d:%02d" % [Clock.hour, Clock.minute], WARM, WIDTH - 7, HORIZONTAL_ALIGNMENT_RIGHT)
	# Row 2: tide arrow, water level, next high water, moon.
	UiKit.draw_icon(self, "tide_up" if Clock.tide_rising() else "tide_down", Vector2(6, 20))
	var level := clampf((Clock.tide_height() + 2.0) / 4.0, 0.0, 1.0)
	draw_rect(Rect2(25, 26, 32, 5), UiKit.INK)
	draw_rect(Rect2(26, 27, 30.0 * level, 3), TIDE)
	var peak := Clock.next_high_tide()
	_text(Vector2(61, 31), "↑%02d:%02d" % [peak / 60, peak % 60], Color("#cfe6e2"))
	UiKit.draw_icon(self, "moon_%d" % moon_phase(), Vector2(WIDTH - 22, 20))
	# Row 3: the words for both.
	_text(Vector2(0, 46), "%s · %s" % [WEATHER_NAMES.get(Weather.current, ""), Clock.moon_name()], Color("#9fb1b8"), WIDTH,
		HORIZONTAL_ALIGNMENT_CENTER)
	# Money under the panel.
	var money := "%d кр" % Economy.money
	var w := UiKit.font().get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 30.0
	draw_style_box(UiKit.box("panel"), Rect2(WIDTH - w, PANEL_H + 2, w, 20))
	UiKit.draw_icon(self, "hud_coin", Vector2(WIDTH - w + 5, PANEL_H + 4))
	_text(Vector2(WIDTH - w + 22, PANEL_H + 16), money, Color("#ffc85a"))
