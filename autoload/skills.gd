extends Node

const NAMES: PackedStringArray = ["keeping", "fishing", "farming", "foraging", "mining", "combat", "social"]
var xp: Dictionary = {}
var levels: Dictionary = {}
var professions: Dictionary = {}

func _ready() -> void:
	for n in NAMES:
		xp[n] = 0
		levels[n] = 0

func add_xp(skill: String, amount: int) -> void:
	xp[skill] = int(xp.get(skill, 0)) + amount
	var lv := _level_from_xp(int(xp[skill]))
	if lv != int(levels.get(skill, 0)):
		levels[skill] = lv
		Events.level_up.emit(skill, lv)

func _level_from_xp(v: int) -> int:
	var need := 100
	var lv := 0
	var rest := v
	while rest >= need and lv < 10:
		rest -= need
		lv += 1
		need = int(need * 1.35)
	return lv

func serialize() -> Dictionary:
	return {"xp": xp, "levels": levels, "professions": professions}

func deserialize(d: Dictionary) -> void:
	xp = d.get("xp", xp)
	levels = d.get("levels", levels)
	professions = d.get("professions", professions)
