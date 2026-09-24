extends Node

var queues: Dictionary = {}

func serialize() -> Dictionary:
	return {"queues": queues}

func deserialize(d: Dictionary) -> void:
	queues = d.get("queues", {})
