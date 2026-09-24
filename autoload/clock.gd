extends Node

const MINUTES_PER_DAY := 24 * 60
const DAYS_PER_SEASON := 28
const DAYS_PER_YEAR := 112
const WAKE_MINUTE := 6 * 60
const FAINT_MINUTE := 2 * 60
const TIDE_PERIOD_HOURS := 12.42
const SEASONS: PackedStringArray = ["spring", "summer", "autumn", "winter"]

var day_index: int = 0
var minutes: int = WAKE_MINUTE
var paused: bool = true
var seconds_per_10min: float = 7.0
var _acc: float = 0.0

var year: int:
	get:
		return 1 + day_index / DAYS_PER_YEAR

var season_index: int:
	get:
		return (day_index % DAYS_PER_YEAR) / DAYS_PER_SEASON

var season: String:
	get:
		return SEASONS[season_index]

var day: int:
	get:
		return 1 + (day_index % DAYS_PER_SEASON)

var weekday_index: int:
	get:
		return day_index % 7

var weekday: String:
	get:
		return ["mon", "tue", "wed", "thu", "fri", "sat", "sun"][weekday_index]

var hour: int:
	get:
		return minutes / 60

var minute: int:
	get:
		return minutes % 60


func _process(delta: float) -> void:
	if paused:
		return
	_acc += delta
	while _acc >= seconds_per_10min and not paused:
		_acc -= seconds_per_10min
		advance(10)


func advance(mins: int) -> void:
	var left := maxi(mins, 0)
	while left > 0 and not paused:
		var step := mini(left, 10)
		left -= step
		var old_hour := hour
		var old_minutes := minutes
		minutes = (minutes + step) % MINUTES_PER_DAY
		Events.time_tick.emit(step)
		Events.tide_changed.emit(tide_height())
		if hour != old_hour:
			Events.hour_changed.emit(hour)
		if old_minutes < FAINT_MINUTE and minutes >= FAINT_MINUTE:
			Night.end_day(true)
			return


func start_next_day() -> void:
	Events.day_ending.emit()
	day_index += 1
	minutes = WAKE_MINUTE
	_acc = 0.0
	Weather.start_day(day_index)
	if day == 1:
		Events.season_changed.emit(season)
	Events.day_started.emit(day_index)
	Events.tide_changed.emit(tide_height())


func reset() -> void:
	day_index = 0
	minutes = 17 * 60
	seconds_per_10min = 7.0
	_acc = 0.0
	paused = true


func set_time(h: int, m: int = 0) -> void:
	minutes = clampi(h, 0, 23) * 60 + clampi(m, 0, 59)
	_acc = 0.0
	Events.tide_changed.emit(tide_height())


func goto_date(y: int, season_name: String, d: int) -> void:
	var si := SEASONS.find(season_name)
	if si < 0:
		si = 0
	day_index = (maxi(y, 1) - 1) * DAYS_PER_YEAR + si * DAYS_PER_SEASON + clampi(d, 1, 28) - 1
	minutes = WAKE_MINUTE
	_acc = 0.0
	Events.day_started.emit(day_index)
	Events.tide_changed.emit(tide_height())


func is_night() -> bool:
	return hour >= 21 or hour < 6


func moon() -> int:
	return day


func moon_name() -> String:
	if day <= 3 or day >= 26:
		return "Новолуние"
	if day <= 7:
		return "Серп растёт"
	if day <= 10:
		return "Первая четверть"
	if day <= 14:
		return "Луна растёт"
	if day <= 17:
		return "Полнолуние"
	if day <= 21:
		return "Луна убывает"
	if day <= 24:
		return "Последняя четверть"
	return "Серп убывает"


func _season_t0(index: int) -> float:
	# One fixed phase per season and year, derived from the world's save seed.
	var season_number := index / DAYS_PER_SEASON
	var n := posmod(int(Game.world_seed) * 1103515245 + season_number * 12345, 2147483647)
	return float(n % 1200) / 100.0


func _tide_t0(index: int) -> float:
	var d := index % DAYS_PER_SEASON + 1
	if index == 14: # Q1.10: low tide at 12:40 on Spring 15, year one.
		return 12.0 + 40.0 / 60.0 - TIDE_PERIOD_HOURS / 2.0
	if index == DAYS_PER_YEAR + 2 * DAYS_PER_SEASON + 27: # Q4.5.
		return 1.25 - TIDE_PERIOD_HOURS / 2.0
	return _season_t0(index) + 0.84 * float(d - 1)


func tide_amplitude(index: int = -1) -> float:
	if index < 0:
		index = day_index
	if index == DAYS_PER_YEAR + 2 * DAYS_PER_SEASON + 27:
		return 2.0
	var d := index % DAYS_PER_SEASON + 1
	return 1.0 + 0.4 * cos(TAU * float(d - 1) / 14.0)


func tide_height_at(index: int, at_minutes: int) -> float:
	var t := float(at_minutes) / 60.0
	return tide_amplitude(index) * cos(TAU * (t - _tide_t0(index)) / TIDE_PERIOD_HOURS)


func tide_height() -> float:
	return tide_height_at(day_index, minutes)


func tide_rising() -> bool:
	return tide_height_at(day_index, minutes + 1) > tide_height()


func next_high_tide() -> int:
	var t := float(minutes) / 60.0
	var phase := _tide_t0(day_index)
	var cycles: float = floorf((t - phase) / TIDE_PERIOD_HOURS) + 1.0
	var peak: float = phase + cycles * TIDE_PERIOD_HOURS
	if peak >= 24.0:
		phase = _tide_t0(day_index + 1)
		peak = phase + ceil(-phase / TIDE_PERIOD_HOURS) * TIDE_PERIOD_HOURS
	return int(round(peak * 60.0)) % MINUTES_PER_DAY


func serialize() -> Dictionary:
	return {"day_index": day_index, "minutes": minutes, "seconds_per_10min": seconds_per_10min}


func deserialize(d: Dictionary) -> void:
	day_index = maxi(int(d.get("day_index", 0)), 0)
	minutes = clampi(int(d.get("minutes", WAKE_MINUTE)), 0, MINUTES_PER_DAY - 1)
	seconds_per_10min = clampf(float(d.get("seconds_per_10min", 7.0)), 5.0, 14.0)
	_acc = 0.0
	paused = true
