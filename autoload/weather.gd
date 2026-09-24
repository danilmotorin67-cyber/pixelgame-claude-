extends Node

const TYPES := ["clear", "cloud", "rain", "fog", "storm", "snow", "blizzard"]
const WEIGHTS := [
	[35, 25, 25, 10, 5, 0, 0],
	[50, 20, 15, 10, 5, 0, 0],
	[20, 25, 25, 10, 20, 0, 0],
	[30, 25, 0, 5, 0, 30, 10],
]

var current: String = "clear"
var wind: float = 0.0
var wind_direction: int = 0
var wind_strength: int = 0
var hmar_night: bool = false
var forecast: Array = []


func _day_rng(index: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(int(Game.world_seed) * 65537 + index * 1000003 + salt, 2147483647)
	return rng


func weather_for_day(index: int) -> String:
	if index < 3:
		return "clear"
	var season_idx := (index % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON
	var weights: Array = WEIGHTS[season_idx].duplicate()
	var day_of_season := index % Clock.DAYS_PER_SEASON + 1
	if season_idx == 2 and day_of_season >= 8 and day_of_season <= 14:
		weights[4] *= 2
	var roll := _day_rng(index, 19).randi_range(0, _weight_total(weights) - 1)
	for i in TYPES.size():
		roll -= int(weights[i])
		if roll < 0:
			return TYPES[i]
	return "clear"


func _weight_total(weights: Array) -> int:
	var total := 0
	for weight in weights:
		total += int(weight)
	return total


func start_day(index: int) -> void:
	set_weather(weather_for_day(index))
	var rng := _day_rng(index, 71)
	wind_direction = rng.randi_range(0, 7)
	wind_strength = rng.randi_range(0, 3)
	wind = float(wind_strength) / 3.0
	hmar_night = false
	forecast.clear()
	for offset in range(1, 8):
		forecast.append(weather_for_day(index + offset))


func set_weather(id: String) -> void:
	if not TYPES.has(id):
		return
	current = id
	Events.weather_changed.emit(id)


func serialize() -> Dictionary:
	return {"current": current, "wind": wind, "wind_direction": wind_direction,
		"wind_strength": wind_strength, "hmar_night": hmar_night, "forecast": forecast}


func deserialize(d: Dictionary) -> void:
	var saved := str(d.get("current", "clear"))
	current = saved if TYPES.has(saved) else "clear"
	wind = float(d.get("wind", 0.0))
	wind_direction = int(d.get("wind_direction", 0))
	wind_strength = int(d.get("wind_strength", 0))
	hmar_night = bool(d.get("hmar_night", false))
	forecast = d.get("forecast", []).duplicate()
	Events.weather_changed.emit(current)
