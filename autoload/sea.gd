extends Node

var mercy: float = 20.0
var blessings: Array = []
var boat: String = ""
var revealed: Dictionary = {}

func serialize() -> Dictionary:
	return {"mercy": mercy, "blessings": blessings, "boat": boat, "revealed": revealed}

func deserialize(d: Dictionary) -> void:
	mercy = float(d.get("mercy", 20.0))
	blessings = d.get("blessings", [])
	boat = str(d.get("boat", ""))
	revealed = d.get("revealed", {})
