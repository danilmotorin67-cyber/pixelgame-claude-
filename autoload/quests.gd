extends Node

var states: Dictionary = {}

func start(id: String) -> void:
	states[id] = {"step": 0, "done": false}
	Events.quest_started.emit(id)

func step(id: String) -> void:
	if not states.has(id):
		start(id)
	states[id]["step"] = int(states[id].get("step", 0)) + 1
	Events.quest_step_done.emit(id)

func complete(id: String) -> void:
	states[id] = {"step": 99, "done": true}
	Events.quest_completed.emit(id)

func state(id: String) -> String:
	if not states.has(id):
		return "none"
	return "done" if states[id].get("done", false) else "active"

func serialize() -> Dictionary:
	return {"states": states}

func deserialize(d: Dictionary) -> void:
	states = d.get("states", {})
