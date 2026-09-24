extends Node

var states: Dictionary = {}


func reset() -> void:
	states.clear()


func start(id: String) -> void:
	states[id] = {"step": 0, "done": false}
	for flag in Data.by_id("quests", id).get("flags", []):
		Game.set_flag(str(flag))
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


# Night step 12: quests whose start condition (33.4) now holds begin; returns their ids.
func check_starts() -> Array:
	var started: Array = []
	for quest in Data.all("quests"):
		var id := str(quest.get("id", ""))
		if id == "" or states.has(id) or not quest.has("start"):
			continue
		var expression := Expression.new()
		if expression.parse(str(quest["start"]), ["day_index", "hour", "day", "season", "act", "year"]) != OK:
			continue
		var result: Variant = expression.execute([Clock.day_index, Clock.hour, Clock.day, Clock.season,
			Game.act, Clock.year], null, false)
		if not expression.has_execute_failed() and bool(result):
			start(id)
			started.append(id)
	return started


func serialize() -> Dictionary:
	return {"states": states}


func deserialize(d: Dictionary) -> void:
	states = d.get("states", {}).duplicate(true)
