extends Node

var flags: Dictionary = {}
var counters: Dictionary = {}
var stats: Dictionary = {}
var act: int = 0
var honor: int = 0
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


func reset() -> void:
	flags.clear()
	counters.clear()
	stats.clear()
	act = 0
	honor = 0
	hero = {"name": "Смотритель", "gender": "m", "love": "",
		"skin": 1, "hair": 0, "hair_color": 0, "eyes": 0,
		"shirt": 0, "pants": 0, "shoes": 0}
	world_seed = randi()
	playtime_sec = 0.0
	player_state = {}


func serialize() -> Dictionary:
	return {
		"flags": flags, "counters": counters, "stats": stats,
		"act": act, "honor": honor, "hero": hero,
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
	hero = d.get("hero", hero)
	for key in ["skin", "hair", "hair_color", "eyes", "shirt", "pants", "shoes"]:
		if hero.has(key):
			hero[key] = int(hero[key])
	world_seed = int(d.get("world_seed", 1))
	playtime_sec = float(d.get("playtime_sec", 0.0))
	player_state = d.get("player_state", {}).duplicate(true)
