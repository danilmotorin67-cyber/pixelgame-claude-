extends Node

var found: Dictionary = {}

func mark(kind: String, id: String) -> void:
	if not found.has(kind):
		found[kind] = {}
	found[kind][id] = true

func serialize() -> Dictionary:
	return {"found": found}

func deserialize(d: Dictionary) -> void:
	found = d.get("found", {})
