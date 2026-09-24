extends Node

var positions: Dictionary = {}

func serialize() -> Dictionary:
	return {"positions": positions}

func deserialize(d: Dictionary) -> void:
	positions = d.get("positions", {})
