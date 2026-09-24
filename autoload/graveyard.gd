extends Node

var bodies: Array = []
var graves: Array = []
var peace: float = 0.0

func serialize() -> Dictionary:
	return {"bodies": bodies, "graves": graves, "peace": peace}

func deserialize(d: Dictionary) -> void:
	bodies = d.get("bodies", [])
	graves = d.get("graves", [])
	peace = float(d.get("peace", 0.0))
