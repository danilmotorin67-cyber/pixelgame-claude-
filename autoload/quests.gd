extends Node

# Quest states: {"steps": [done step ids], "done": bool}. Steps finish on matching events ("on"), when their
# condition holds ("check", polled hourly and after every event) or by a hand-in ("deliver", see Story);
# a step with "after" waits for that step. Journal marks: ⚑ story (lighthouse), ◎ side (shell), ✝ ghost (candle).
const MARKS := {"main": "⚑ ", "side": "◎ ", "ghost": "✝ ", "club": "◎ "}
var states: Dictionary = {}


func _ready() -> void:
	Events.body_moved.connect(func(id: String, where: String) -> void: notify("body_moved", id, {"where": where}))
	Events.body_examined.connect(func(id: String) -> void: notify("body_examined", id))
	Events.body_buried.connect(func(id: String, _q: int) -> void: notify("body_buried", id))
	Events.body_identified.connect(func(id: String, correct: bool) -> void: notify("body_identified", id, {"correct": correct}))
	Events.item_added.connect(func(id: String, n: int) -> void: notify("item_added", id, {"n": n}))
	Events.lamp_lit.connect(func(_on_time: bool) -> void: notify("lamp_lit", ""))
	Events.quest_event.connect(func(name: String, arg: String) -> void: notify(name, arg))
	Events.fish_caught.connect(func(id: String, q: int, _size: float) -> void: notify("fish_caught", id, {"quality": q}))
	Events.crop_harvested.connect(func(id: String, q: int) -> void: notify("crop_harvested", id, {"quality": q}))
	Events.boss_defeated.connect(func(id: String) -> void: notify("boss", id))
	Events.blessing_gained.connect(func(id: String) -> void: notify("blessing", id))
	Events.ghost_laid_to_rest.connect(func(id: String) -> void: notify("ghost_laid", id))
	Events.hour_changed.connect(func(_h: int) -> void: poll())


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
	poll()


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
			if not _eligible(id, step):
				continue
			if step.has("arg") and str(step["arg"]) != arg:
				continue
			if step.has("min_quality") and int(extra.get("quality", 0)) < int(step["min_quality"]):
				continue
			if step.has("where") and str(step["where"]) != str(extra.get("where", "")):
				continue
			if step.has("correct") and bool(step["correct"]) != bool(extra.get("correct", false)):
				continue
			if step.has("count"):
				var counts: Dictionary = states[id].get("counts", {})
				counts[str(step["id"])] = int(counts.get(str(step["id"]), 0)) + (int(extra.get("n", 1)) if step.has("count_n") else 1)
				states[id]["counts"] = counts
				if int(counts[str(step["id"])]) < int(step["count"]):
					continue
			states[id]["steps"].append(str(step["id"]))
			Events.quest_step_done.emit(id)
		if states[id]["steps"].size() >= info.get("steps", []).size():
			complete(id)
	if event != "poll":
		poll()


func _eligible(id: String, step: Dictionary) -> bool:
	return not step.has("after") or states[id]["steps"].has(str(step["after"]))


# "check" steps finish when their condition holds; completing a quest can start or satisfy others, so repeat.
func poll() -> void:
	var changed := true
	var guard := 0
	while changed and guard < 8:
		changed = false
		guard += 1
		for id in states.keys():
			if bool(states[id]["done"]):
				continue
			var info := quest(id)
			for step in info.get("steps", []):
				if not step.has("check") or states[id]["steps"].has(str(step["id"])) or not _eligible(id, step):
					continue
				if ConditionContext.check(str(step["check"])):
					states[id]["steps"].append(str(step["id"]))
					Events.quest_step_done.emit(id)
					changed = true
			if states[id]["steps"].size() >= info.get("steps", []).size() and not bool(states[id]["done"]):
				complete(id)
				changed = true


# A hand-in step ("deliver") this NPC can take now: [quest id, step] pairs.
func deliveries(npc: String) -> Array:
	var out: Array = []
	for id in states.keys():
		if bool(states[id]["done"]):
			continue
		for step in quest(id).get("steps", []):
			if str(step.get("deliver", "")) == npc and not states[id]["steps"].has(str(step["id"])) and _eligible(id, step) \
					and ConditionContext.check(str(step.get("when", ""))):
				out.append([id, step])
	return out


func can_deliver(step: Dictionary) -> bool:
	for need in step.get("items", []):
		if Inventory.count_matching(str(need[0])) < int(need[1]):
			return false
	return Economy.can_pay(int(step.get("money", 0)))


func deliver(id: String, step_id: String) -> bool:
	for step in quest(id).get("steps", []):
		if str(step["id"]) != step_id or not can_deliver(step) or state(id) != "active" or step_done(id, step_id):
			continue
		for need in step.get("items", []):
			Inventory.take_matching(str(need[0]), int(need[1]))
		Economy.pay(int(step.get("money", 0)))
		states[id]["steps"].append(step_id)
		Effects.apply(step.get("effects", []))
		Events.quest_step_done.emit(id)
		if states[id]["steps"].size() >= quest(id).get("steps", []).size():
			complete(id)
		poll()
		return true
	return false


func complete(id: String) -> void:
	if not states.has(id):
		states[id] = {"steps": [], "done": false}
	if bool(states[id]["done"]):
		return
	states[id]["done"] = true
	Effects.apply(quest(id).get("rewards", []))
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
		if bool(info.get("hidden", false)):
			continue
		out.append(("✓ " if bool(states[id]["done"]) else "• ") + str(MARKS.get(str(info.get("type", "side")), "")) + Loc.t(str(info.get("title", id))))
		if bool(states[id]["done"]):
			continue
		for step in info.get("steps", []):
			if not _eligible(id, step):
				continue
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
