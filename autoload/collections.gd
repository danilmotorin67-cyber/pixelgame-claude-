extends Node

var found: Dictionary = {}

func mark(kind: String, id: String) -> void:
	if not found.has(kind):
		found[kind] = {}
	found[kind][id] = true

func reset() -> void:
	found.clear()


func has(kind: String, id: String) -> bool:
	return found.has(kind) and found[kind].has(id)


func serialize() -> Dictionary:
	return {"found": found}

func deserialize(d: Dictionary) -> void:
	found = d.get("found", {}).duplicate(true)
