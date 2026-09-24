extends Node

var unlocked: Dictionary = {}

func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	Events.achievement_unlocked.emit(id)

func serialize() -> Dictionary:
	return {"unlocked": unlocked}

func deserialize(d: Dictionary) -> void:
	unlocked = d.get("unlocked", {})
