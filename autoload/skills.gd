extends Node

const NAMES: PackedStringArray = ["farming", "fishing", "seafaring", "diving", "crafting", "foraging", "keeping"]
const THRESHOLDS: Array[int] = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]

var xp: Dictionary = {}
var levels: Dictionary = {}
var professions: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	xp.clear()
	levels.clear()
	professions.clear()
	for n in NAMES:
		xp[n] = 0
		levels[n] = 0


func level(skill: String) -> int:
	return int(levels.get(skill, 0))


func add_xp(skill: String, amount: int) -> void:
	if not NAMES.has(skill) or amount <= 0:
		return
	xp[skill] = int(xp.get(skill, 0)) + amount


func level_for_xp(value: int) -> int:
	var lv := 0
	for need in THRESHOLDS:
		if value >= need:
			lv += 1
	return lv


# New levels are only counted while the keeper sleeps (25.1).
func apply_levels() -> Array:
	var gained: Array = []
	for n in NAMES:
		var lv := level_for_xp(int(xp.get(n, 0)))
		while level(n) < lv:
			levels[n] = level(n) + 1
			gained.append({"skill": n, "level": level(n)})
			Events.level_up.emit(n, level(n))
	return gained


func serialize() -> Dictionary:
	return {"xp": xp, "levels": levels, "professions": professions}


func deserialize(d: Dictionary) -> void:
	reset()
	var saved_xp: Dictionary = d.get("xp", {})
	var saved_levels: Dictionary = d.get("levels", {})
	for n in NAMES:
		xp[n] = int(saved_xp.get(n, 0))
		levels[n] = clampi(int(saved_levels.get(n, 0)), 0, 10)
	professions = d.get("professions", {}).duplicate()
