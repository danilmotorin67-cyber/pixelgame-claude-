extends Node

var playing: bool = false
var seen: Dictionary = {}


func reset() -> void:
	playing = false
	seen.clear()


func play(_id: String) -> void:
	playing = true
	playing = false


func serialize() -> Dictionary:
	return {"seen": seen}


func deserialize(d: Dictionary) -> void:
	seen = d.get("seen", {}).duplicate()
