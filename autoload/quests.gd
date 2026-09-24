extends Node

# Quest states: {"steps": [done step ids], "done": bool}. Steps finish in any order on matching events.
var states: Dictionary = {}


func _ready() -> void:
	Events.body_moved.connect(func(id: String, where: String) -> void: notify("body_moved", id, {"where": where}))
	Events.body_examined.connect(func(id: String) -> void: notify("body_examined", id))
	Events.body_buried.connect(func(id: String, _q: int) -> void: notify("body_buried", id))
	Events.body_identified.connect(func(id: String, correct: bool) -> void: notify("body_identified", id, {"correct": correct}))
	Events.item_added.connect(func(id: String, _n: int) -> void: notify("item_added", id))
	Events.lamp_lit.connect(func(_on_time: bool) -> void: notify("lamp_lit", ""))
	Events.quest_event.connect(func(name: String, arg: String) -> void: notify(name, arg))
	Events.fish_caught.connect(func(id: String, _q: int, _size: float) -> void: notify("fish_caught", id))


func reset() -> void:
	states.clear()


func quest(id: String) -> Dictionary:
	return Data.by_id("quests", id)


func start(id: String) -> void:
	if states.has(id):
		return
	var info := quest(id)
	states[id] = {"steps": [], "done": false, "counts": {}}
	if info.has("mail_on_start"):
		Mail.send(str(info["mail_on_start"]))
	for flag in info.get("flags", []):
		Game.set_flag(str(flag))
	for entry in info.get("on_start", []):
		if str(entry[0]) == "shore":
			Sea.schedule_gift(str(entry[1]), str(entry[2]), Clock.day_index + randi_range(1, int(entry[3])))
	Events.quest_started.emit(id)


func state(id: String) -> String:
	if not states.has(id):
		return "none"
	return "done" if bool(states[id]["done"]) else "active"


func step_done(id: String, step_id: String) -> bool:
	return states.has(id) and states[id]["steps"].has(step_id)


func notify(event: String, arg: String, extra: Dictionary = {}) -> void:
	for id in states.keys():
		if bool(states[id]["done"]):
			continue
		var info := quest(id)
		for step in info.get("steps", []):
			if states[id]["steps"].has(str(step["id"])) or str(step.get("on", "")) != event:
				continue
			if step.has("arg") and str(step["arg"]) != arg:
				continue
			if step.has("where") and str(step["where"]) != str(extra.get("where", "")):
				continue
			if step.has("correct") and bool(step["correct"]) != bool(extra.get("correct", false)):
				continue
			if step.has("count"):
				var counts: Dictionary = states[id].get("counts", {})
				counts[str(step["id"])] = int(counts.get(str(step["id"]), 0)) + 1
				states[id]["counts"] = counts
				if int(counts[str(step["id"])]) < int(step["count"]):
					continue
			states[id]["steps"].append(str(step["id"]))
			Events.quest_step_done.emit(id)
		if states[id]["steps"].size() >= info.get("steps", []).size():
			complete(id)


func complete(id: String) -> void:
	if not states.has(id):
		states[id] = {"steps": [], "done": false}
	if bool(states[id]["done"]):
		return
	states[id]["done"] = true
	for reward in quest(id).get("rewards", []):
		match str(reward[0]):
			"xp":
				Skills.add_xp(str(reward[1]), int(reward[2]))
			"points":
				Knowledge.add_points(str(reward[1]), int(reward[2]))
			"money":
				Economy.add(int(reward[1]))
			"item":
				if Inventory.add(str(reward[1]), int(reward[2])) != int(reward[2]):
					Mail.send("mail.quest_parcel", [], 0, [[str(reward[1]), int(reward[2])]])
			"flag":
				Game.set_flag(str(reward[1]))
			"mail":
				Mail.send(str(reward[1]))
			"recipe":
				Crafting.learn(str(reward[1]))
	Events.quest_completed.emit(id)


# Night step 12: quests whose start condition (33.4) now holds begin; returns their ids.
func check_starts() -> Array:
	var started: Array = []
	for info in Data.all("quests"):
		var id := str(info.get("id", ""))
		if id == "" or states.has(id) or not info.has("start"):
			continue
		if ConditionContext.check(str(info["start"])):
			start(id)
			started.append(id)
	return started


func journal_lines() -> Array:
	var out: Array = []
	for id in states:
		var info := quest(id)
		if info.is_empty():
			continue
		out.append(("✓ " if bool(states[id]["done"]) else "• ") + Loc.t(str(info.get("title", id))))
		if bool(states[id]["done"]):
			continue
		for step in info.get("steps", []):
			out.append(("    ✓ " if states[id]["steps"].has(str(step["id"])) else "    □ ") + Loc.t(str(step.get("text", ""))))
	return out


func serialize() -> Dictionary:
	return {"states": states}


func deserialize(d: Dictionary) -> void:
	states.clear()
	var saved: Dictionary = d.get("states", {})
	for id in saved:
		var entry: Dictionary = saved[id]
		var counts := {}
		var saved_counts: Dictionary = entry.get("counts", {})
		for key in saved_counts:
			counts[str(key)] = int(saved_counts[key])
		states[str(id)] = {"steps": entry.get("steps", []).duplicate(), "done": bool(entry.get("done", false)),
			"counts": counts}
