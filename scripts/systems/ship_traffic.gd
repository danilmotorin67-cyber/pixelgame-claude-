class_name ShipTraffic

const WEATHER_BASE := {"clear": 0.01, "cloud": 0.02, "rain": 0.04, "fog": 0.10, "storm": 0.15,
	"snow": 0.02, "blizzard": 0.15}
const HMAR_BASE := 0.25
const BAD_WEATHER := ["rain", "fog", "storm", "blizzard"]
const BODY_BEACHES := [["cape", 40], ["wreck_bay", 30], ["seal_shore", 20], ["lagoon", 10]]


static func _rng(a: int, b: int, c: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 1664525 + a * 1013904223 + b * 22695477 + c, 2147483647)
	return rng


static func _season_of(index: int) -> String:
	return Clock.SEASONS[(index % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON]


# The ships that pass the cape on the night after day `index` (the pilot calendar reads this).
static func ships_for_night(index: int) -> Array:
	var list: Array = []
	var rng := _rng(index, 0, 17)
	var day := 1 + index % Clock.DAYS_PER_SEASON
	for ship in Data.all("ships"):
		if bool(ship.get("daytime", false)):
			continue
		if ship.has("seasons") and _season_of(index) not in ship["seasons"]:
			continue
		var passes := false
		if ship.has("day"):
			passes = day == int(ship["day"])
		elif ship.has("chance"):
			passes = rng.randf() < float(ship["chance"])
		elif ship.has("per_week"):
			var week := index / 7
			var wrng := _rng(week, str(ship["id"]).hash() % 1000, 29)
			var bounds: Array = ship["per_week"]
			var nights: Array = [0, 1, 2, 3, 4, 5, 6]
			for i in range(nights.size() - 1, 0, -1):
				var j := wrng.randi_range(0, i)
				var tmp: int = nights[i]
				nights[i] = nights[j]
				nights[j] = tmp
			passes = nights.slice(0, wrng.randi_range(int(bounds[0]), int(bounds[1]))).has(index % 7)
		if passes:
			var names: Array = ship.get("names", [ship["name"]])
			list.append({"type": str(ship["id"]), "name": str(names[rng.randi_range(0, names.size() - 1)])})
	return list


static func calendar(from_index: int, nights: int = 7) -> Array:
	var out: Array = []
	for offset in nights:
		out.append({"day_index": from_index + offset, "ships": ships_for_night(from_index + offset)})
	return out


static func base_chance(weather: String, hmar: bool) -> float:
	return HMAR_BASE if hmar else float(WEATHER_BASE.get(weather, 0.02))


# P = base × (1 − power/100) × 2 × moon; a dark night: base × 3 + 10% (10.11).
static func wreck_chance(weather: String, hmar: bool, burning: bool, power: float, new_moon: bool) -> float:
	var base := base_chance(weather, hmar)
	# Burun, the breaker-daughter: storms wreck a fifth fewer ships (12.4).
	if weather in ["storm", "blizzard"] and Sea.blessings.has("burun"):
		base *= 0.8
	if not burning:
		return base * 3.0 + 0.10
	return base * (1.0 - clampf(power, 0.0, 100.0) / 100.0) * 2.0 * (1.2 if new_moon else 1.0)


static func pick_beach(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(0, 99)
	for entry in BODY_BEACHES:
		roll -= int(entry[1])
		if roll < 0:
			return str(entry[0])
	return "cape"
