extends Node

var herd: Array = []

func serialize() -> Dictionary:
	return {"herd": herd}

func deserialize(d: Dictionary) -> void:
	herd = d.get("herd", [])
