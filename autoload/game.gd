extends Node

var flags: Dictionary = {}
var counters: Dictionary = {}
var stats: Dictionary = {}
var act: int = 0
var honor: int = 0
var luck: float = 0.0
var hero: Dictionary = {
	"name": "Смотритель",
	"gender": "m",
	"love": "",
	"skin": 1,
	"hair": 0,
	"hair_color": 0,
	"eyes": 0,
	"shirt": 0,
	"pants": 0,
	"shoes": 0,
}
var world_seed: int = 1
var playtime_sec: float = 0.0
var player_state: Dictionary = {}


func _process(delta: float) -> void:
	if not Clock.paused:
		playtime_sec += delta


func flag(id: String) -> bool:
	return bool(flags.get(id, false))


func set_flag(id: String, v: bool = true) -> void:
	flags[id] = v


func stat(name: String) -> int:
	return int(stats.get(name, 0))


func add_stat(name: String, n: int = 1) -> void:
	stats[name] = stat(name) + n


func add_honor(n: int) -> void:
	honor = clampi(honor + n, -100, 100)


func balance(key: String, fallback: Variant) -> Variant:
	var table: Variant = Data.tables.get("balance", {})
	return table.get(key, fallback) if table is Dictionary else fallback


func max_energy() -> float:
	return float(balance("energy_max", 270)) + float(balance("energy_star_amber", 30)) \
		* float(clampi(int(counters.get("star_amber", 0)), 0, 7))


# Energy for one action of spec 8.1, reduced by the linked skill down to 1.
func action_cost(action: String, cold: float = 0.0) -> float:
	var info: Dictionary = balance("energy_actions", {}).get(action, {})
	var cost := float(info.get("cost", 0))
	if info.has("skill"):
		cost = maxf(1.0, cost - float(info.get("per_level", 0.0)) * float(Skills.level(str(info["skill"]))))
	if cold >= float(balance("cold_energy_threshold", 50)):
		cost *= float(balance("cold_energy_mult", 1.25))
	return cost


func roll_luck(index: int, aurora_bonus: bool) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(world_seed * 40503 + index * 7919 + 313, 2147483647)
	luck = rng.randf_range(-0.1, 0.1) + (0.05 if aurora_bonus else 0.0)
	return luck


func reset() -> void:
	flags.clear()
	counters.clear()
	stats.clear()
	act = 0
	honor = 0
	luck = 0.0
	hero = {"name": "Смотритель", "gender": "m", "love": "",
		"skin": 1, "hair": 0, "hair_color": 0, "eyes": 0,
		"shirt": 0, "pants": 0, "shoes": 0}
	world_seed = randi()
	playtime_sec = 0.0
	player_state = {}


func serialize() -> Dictionary:
	return {
		"flags": flags, "counters": counters, "stats": stats,
		"act": act, "honor": honor, "luck": luck, "hero": hero,
		"world_seed": world_seed, "playtime_sec": playtime_sec,
		"player_state": player_state,
	}


func deserialize(d: Dictionary) -> void:
	flags = d.get("flags", {})
	counters = d.get("counters", {})
	stats = d.get("stats", {})
	for key in counters:
		counters[key] = int(counters[key])
	for key in stats:
		stats[key] = int(stats[key])
	act = int(d.get("act", 0))
	honor = int(d.get("honor", 0))
	luck = clampf(float(d.get("luck", 0.0)), -0.1, 0.15)
	hero = d.get("hero", hero)
	for key in ["skin", "hair", "hair_color", "eyes", "shirt", "pants", "shoes"]:
		if hero.has(key):
			hero[key] = int(hero[key])
	world_seed = int(d.get("world_seed", 1))
	playtime_sec = float(d.get("playtime_sec", 0.0))
	player_state = d.get("player_state", {}).duplicate(true)
