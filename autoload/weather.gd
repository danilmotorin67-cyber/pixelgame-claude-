extends Node

const TYPES := ["clear", "cloud", "rain", "fog", "storm", "snow", "blizzard"]
const WEIGHTS := [
	[35, 25, 25, 10, 5, 0, 0],
	[50, 20, 15, 10, 5, 0, 0],
	[20, 25, 25, 10, 20, 0, 0],
	[30, 25, 0, 5, 0, 30, 10],
]
const HMAR_MIN_GAP_DAYS := 4

var current: String = "clear"
var calm: bool = false
var aurora: bool = false
var wind: float = 0.0
var wind_direction: int = 0
var wind_strength: int = 0
var hmar_night: bool = false
var last_hmar_day: int = -100
var forecast: Array = []
var requested_calm: int = -1
var forced: Dictionary = {}


func _day_rng(index: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(int(Game.world_seed) * 65537 + index * 1000003 + salt, 2147483647)
	return rng


func _season_of(index: int) -> int:
	return (index % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON


func weather_for_day(index: int) -> String:
	if index < 3 or index == requested_calm:
		return "clear"
	var story := Story.weather_on(index)
	if story != "":
		return story
	if forced.has(str(index)):
		return str(forced[str(index)])
	var season_idx := _season_of(index)
	var weights: Array = WEIGHTS[season_idx].duplicate()
	# 12.2: a hostile sea brings half again as many storms, a generous one 30% fewer.
	var storm_mult := 1.5 if Sea.mercy < 20.0 else (0.7 if Sea.mercy >= 60.0 else 1.0)
	if storm_mult != 1.0:
		for i in weights.size():
			weights[i] = int(weights[i]) * 10
		weights[4] = int(round(weights[4] * storm_mult))
		weights[6] = int(round(weights[6] * storm_mult))
	var day_of_season := index % Clock.DAYS_PER_SEASON + 1
	if season_idx == 2 and day_of_season >= 8 and day_of_season <= 14:
		weights[4] *= 2
	var festival := Clock.festival_on(index)
	if not festival.is_empty() and not bool(festival.get("story", false)):
		weights[4] = 0
		weights[6] = 0
	var roll := _day_rng(index, 19).randi_range(0, _weight_total(weights) - 1)
	for i in TYPES.size():
		roll -= int(weights[i])
		if roll < 0:
			return TYPES[i]
	return "clear"


func calm_on(index: int) -> bool:
	# Summer: 10% of all days are calm, i.e. one clear day in five; or the calm asked of Rann.
	if index == requested_calm:
		return true
	return _season_of(index) == 1 and weather_for_day(index) == "clear" \
		and _day_rng(index, 23).randf() < 0.2


func aurora_on(index: int) -> bool:
	if _season_of(index) != 3:
		return false
	if bool(Clock.festival_on(index).get("aurora", false)):
		return true
	return weather_for_day(index) == "clear" and _day_rng(index, 29).randf() < 0.3


func hmar_chance(index: int) -> float:
	if Story.hmar_on(index):
		return 1.0
	# Random Hmar Nights begin after the first White Hmar (Q2.2) — or with Act III whatever happened.
	if Game.act < 2 or (Game.act < 3 and not Game.flag("hmar_open")) or index - last_hmar_day < HMAR_MIN_GAP_DAYS:
		return 0.0
	if Finale.hmar_mult() <= 0.0:
		return 0.0
	var festival := Clock.festival_on(index)
	if not festival.is_empty() and not bool(festival.get("story", false)):
		return 0.0
	var chance := 0.05 + (100.0 - clampf(Graveyard.peace, 0.0, 100.0)) / 1000.0
	var d := index % Clock.DAYS_PER_SEASON + 1
	if d <= 3 or d >= 26:
		chance += 0.05
	if Game.flag("twenty_buried"):
		chance *= 0.7
	chance *= Community.hmar_mult() * Finale.hmar_mult()
	return chance


func _weight_total(weights: Array) -> int:
	var total := 0
	for weight in weights:
		total += int(weight)
	return total


func reset() -> void:
	calm = false
	aurora = false
	hmar_night = false
	last_hmar_day = -100
	requested_calm = -1
	forced.clear()
	forecast.clear()


func start_day(index: int) -> void:
	set_weather(weather_for_day(index))
	calm = calm_on(index)
	aurora = aurora_on(index)
	var rng := _day_rng(index, 71)
	wind_direction = rng.randi_range(0, 7)
	wind_strength = 0 if calm else rng.randi_range(0, 3)
	wind = float(wind_strength) / 3.0
	hmar_night = _day_rng(index, 131).randf() < hmar_chance(index)
	if hmar_night:
		last_hmar_day = index
	forecast_refresh(index)


func forecast_refresh(index: int = -1) -> void:
	if index < 0:
		index = Clock.day_index
	forecast.clear()
	for offset in range(1, 8):
		forecast.append(weather_for_day(index + offset))


# Barometer reading for `offset` days ahead (1..7): right 85% of the time, 95% with the telegraph.
func barometer(offset: int) -> String:
	var target := Clock.day_index + clampi(offset, 1, 7)
	var truth := weather_for_day(target)
	var accuracy := 0.95 if Game.flag("telegraph_working") else 0.85
	var rng := _day_rng(target, 37 + offset)
	if rng.randf() < accuracy:
		return truth
	var options: Array[String] = []
	var weights: Array = WEIGHTS[_season_of(target)]
	for i in TYPES.size():
		if int(weights[i]) > 0 and TYPES[i] != truth:
			options.append(TYPES[i])
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else truth


# A scene or a story night decides tomorrow's weather ("calm" is a clear day without wind).
func force(index: int, id: String) -> void:
	if id == "calm":
		requested_calm = index
	elif TYPES.has(id):
		forced[str(index)] = id
	forecast_refresh()


func set_weather(id: String) -> void:
	if not TYPES.has(id):
		return
	current = id
	Events.weather_changed.emit(id)


func serialize() -> Dictionary:
	return {"current": current, "calm": calm, "aurora": aurora, "wind": wind,
		"wind_direction": wind_direction, "wind_strength": wind_strength,
		"hmar_night": hmar_night, "last_hmar_day": last_hmar_day, "forecast": forecast,
		"requested_calm": requested_calm, "forced": forced}


func deserialize(d: Dictionary) -> void:
	var saved := str(d.get("current", "clear"))
	current = saved if TYPES.has(saved) else "clear"
	calm = bool(d.get("calm", false))
	aurora = bool(d.get("aurora", false))
	wind = float(d.get("wind", 0.0))
	wind_direction = int(d.get("wind_direction", 0))
	wind_strength = int(d.get("wind_strength", 0))
	hmar_night = bool(d.get("hmar_night", false))
	last_hmar_day = int(d.get("last_hmar_day", -100))
	forecast = d.get("forecast", []).duplicate()
	requested_calm = int(d.get("requested_calm", -1))
	forced = d.get("forced", {}).duplicate()
	Events.weather_changed.emit(current)
