extends Node

# Schedules and movement of the islanders (33.7). Every NPC has one logical position that moves
# tile by tile along AStarGrid2D paths and between maps by their exits, whether or not the map is
# loaded; the on-screen actors only draw it. Schedule times before 6:00 belong to the previous day.
const SPEED := 2.0 # tiles per game minute
const STUCK_MINUTES := 30.0
const DAY_START := 6 * 60

var state: Dictionary = {}
var positions: Dictionary = {} # kept for old saves
var stuck_log: Array = []
var _last_total: float = -1.0
var _entry_cache: Dictionary = {}


func _ready() -> void:
	Events.day_started.connect(func(_i: int) -> void: morning())
	Events.weather_changed.connect(func(_w: String) -> void: _entry_cache.clear())
	Events.time_tick.connect(func(_m: int) -> void: sync())


func info(id: String) -> Dictionary:
	return Data.by_id("npcs", id)


# Everyone with a place in the world; Fortuna hangs on the tower wall and is drawn by the tower.
func ids() -> Array:
	var out: Array = []
	for npc in Data.all("npcs"):
		if str(npc.get("home", {}).get("map", "")) != "lh_1":
			out.append(str(npc["id"]))
	return out


func is_static(id: String) -> bool:
	return bool(info(id).get("static", false))


func schedule(id: String) -> Array:
	return Data.tables.get("schedules", {}).get(id, {}).get("entries", [])


static func parse_time(t: String) -> int:
	var parts := t.split(":")
	var m := int(parts[0]) * 60 + int(parts[1])
	return m + 1440 if m < DAY_START else m


# Minutes since 6:00 of the schedule day: the small hours count as the end of yesterday.
func now_minutes() -> int:
	return Clock.minutes + 1440 if Clock.minutes < DAY_START else Clock.minutes


# The day's entry: matching days, seasons and condition, highest priority (recomputed on weather change).
func entry_for(id: String) -> Dictionary:
	var key := "%s@%d" % [id, Clock.day_index]
	if _entry_cache.has(key):
		return _entry_cache[key]
	var best: Dictionary = Festivals.schedule_entry(id)
	var best_priority := int(best.get("priority", -1000000))
	for e in schedule(id):
		if e.has("days") and Clock.weekday not in e["days"]:
			continue
		if e.has("seasons") and Clock.season not in e["seasons"]:
			continue
		if not ConditionContext.check(str(e.get("when", ""))):
			continue
		var priority := int(e.get("priority", 0))
		if priority > best_priority:
			best = e
			best_priority = priority
	_entry_cache[key] = best
	return best


func _home(id: String) -> Dictionary:
	var home: Dictionary = info(id).get("home", {})
	var map_id := str(home.get("map", "away"))
	if map_id == "away":
		return {"away": true}
	return {"map": map_id, "tile": MapInfo.spot(map_id, str(home.get("spot", ""))), "hidden": true, "face": "down", "anim": "sleep"}


func _resolve(id: String, step: Array) -> Dictionary:
	var map_id := str(step[1])
	if map_id == "home":
		return _home(id)
	if map_id == "away":
		return {"away": true}
	var tile := Vector2i(-1, -1)
	if step[2] is Array:
		tile = Vector2i(int(step[2][0]), int(step[2][1]))
	elif step[2] != null:
		tile = MapInfo.spot(map_id, str(step[2]))
	return {"map": map_id, "tile": tile, "hidden": str(step[4]) == "sleep", "face": str(step[3]), "anim": str(step[4])}


# Where the NPC should be now: the latest step that has begun, or home before the first one.
func target(id: String) -> Dictionary:
	if is_static(id):
		var home := _home(id)
		home["hidden"] = false
		home["anim"] = ""
		return home
	var path: Array = entry_for(id).get("path", [])
	var now := now_minutes()
	var found: Dictionary = _home(id)
	for step in path:
		if parse_time(str(step[0])) <= now:
			found = _resolve(id, step)
	return found


func _arrival(id: String) -> Dictionary:
	var arrive: Dictionary = info(id).get("arrive", {"map": "village", "spot": "pier"})
	return {"map": str(arrive["map"]), "tile": MapInfo.spot(str(arrive["map"]), str(arrive["spot"]))}


func _place(id: String, where: Dictionary) -> void:
	var s: Dictionary = state.get(id, {})
	if bool(where.get("away", false)):
		s["away"] = true
		s["hidden"] = true
		s["map"] = ""
	else:
		s["away"] = false
		s["map"] = str(where["map"])
		s["tile"] = where["tile"]
		s["hidden"] = bool(where.get("hidden", false))
	s["path"] = []
	s["route"] = []
	s["goal"] = ""
	s["frac"] = 0.0
	s["face"] = str(where.get("face", "down"))
	s["anim"] = str(where.get("anim", ""))
	s["idle"] = 0.0
	state[id] = s


# Morning: everyone starts where the day's first moment puts them (usually at home).
func morning() -> void:
	_entry_cache.clear()
	for id in ids():
		_place(id, target(id))
	_last_total = _total()


func reset() -> void:
	state.clear()
	stuck_log.clear()
	_entry_cache.clear()
	_last_total = -1.0


func _total() -> float:
	var t := float(Clock.day_index * 1440 + Clock.minutes)
	if not Clock.paused:
		t += Clock._acc / maxf(Clock.seconds_per_10min, 0.001) * 10.0
	return t


func _process(_delta: float) -> void:
	if not Clock.paused:
		sync()


# Advances everyone by the game time passed since the last call.
func sync() -> void:
	var now := _total()
	if _last_total < 0.0 or state.is_empty():
		morning()
		return
	var passed := now - _last_total
	_last_total = now
	if passed <= 0.0:
		return
	if passed > 600.0:
		morning()
		return
	advance(passed)


func _goal_key(where: Dictionary) -> String:
	if bool(where.get("away", false)):
		return "away"
	return "%s:%d,%d" % [where["map"], where["tile"].x, where["tile"].y]


func at_goal(id: String) -> bool:
	var s: Dictionary = state.get(id, {})
	var where := target(id)
	if bool(where.get("away", false)):
		return bool(s.get("away", false))
	return not bool(s.get("away", false)) and str(s.get("map", "")) == str(where["map"]) and s.get("tile") == where["tile"]


func advance(minutes: float) -> void:
	for id in ids():
		if not state.has(id):
			_place(id, target(id))
		_step(id, minutes)


func _step(id: String, minutes: float) -> void:
	var s: Dictionary = state[id]
	var where := target(id)
	var key := _goal_key(where)
	if key != str(s.get("goal", "")):
		s["goal"] = key
		s["path"] = []
		s["route"] = []
		s["idle"] = 0.0
		if not bool(where.get("away", false)):
			s["hidden"] = false
	if bool(where.get("away", false)):
		if not bool(s.get("away", false)):
			_place(id, where)
			state[id]["goal"] = key
		return
	if bool(s.get("away", false)):
		var arrive := _arrival(id)
		s["away"] = false
		s["hidden"] = false
		s["map"] = arrive["map"]
		s["tile"] = arrive["tile"]
		s["path"] = []
	if at_goal(id):
		s["hidden"] = bool(where.get("hidden", false))
		s["face"] = str(where.get("face", "down"))
		s["anim"] = str(where.get("anim", ""))
		s["idle"] = 0.0
		s["frac"] = 0.0
		return
	s["anim"] = "walk"
	var budget := minutes * SPEED + float(s.get("frac", 0.0))
	var moved := false
	var guard := 0
	while budget >= 1.0 and guard < 2000:
		guard += 1
		if at_goal(id):
			break
		if (s["path"] as Array).is_empty():
			if not _plan(id, where):
				break
			if (s["path"] as Array).is_empty():
				continue
		var next: Vector2i = s["path"].pop_front()
		var d: Vector2i = next - (s["tile"] as Vector2i)
		if d != Vector2i.ZERO:
			s["face"] = "right" if d.x > 0 else ("left" if d.x < 0 else ("down" if d.y > 0 else "up"))
			budget -= 1.0
		s["tile"] = next
		moved = true
		_cross_exit(id)
	s["frac"] = budget if budget < 1.0 else 0.0
	if moved:
		s["idle"] = 0.0
	elif not at_goal(id):
		s["idle"] = float(s.get("idle", 0.0)) + minutes
		if float(s["idle"]) > STUCK_MINUTES:
			stuck_log.append({"npc": id, "day": Clock.day_index, "minute": Clock.minutes, "map": s["map"], "tile": s["tile"], "goal": key})
			s["idle"] = 0.0
	if at_goal(id):
		s["hidden"] = bool(where.get("hidden", false))
		s["face"] = str(where.get("face", "down"))
		s["anim"] = str(where.get("anim", ""))


# Next leg: within the goal's map straight to it, else to the exit on the way there.
func _plan(id: String, where: Dictionary) -> bool:
	var s: Dictionary = state[id]
	var here := str(s["map"])
	var goal_map := str(where["map"])
	if here == goal_map:
		s["path"] = _trim(MapInfo.path(here, s["tile"], where["tile"]))
		return not (s["path"] as Array).is_empty()
	var steps := MapInfo.route(here, goal_map)
	if steps.is_empty():
		return false
	var exit: Dictionary = steps[0]
	s["exit"] = exit
	if s["tile"] == exit["at"]:
		s["path"] = [exit["at"]]
		return true
	s["path"] = _trim(MapInfo.path(here, s["tile"], exit["at"]))
	return not (s["path"] as Array).is_empty()


func _trim(p: Array[Vector2i]) -> Array:
	var out: Array = []
	for i in range(1, p.size()):
		out.append(p[i])
	return out


func _cross_exit(id: String) -> void:
	var s: Dictionary = state[id]
	var exit: Dictionary = s.get("exit", {})
	if exit.is_empty() or s["tile"] != exit["at"] or s.get("path", []).size() > 0:
		return
	s["map"] = str(exit["to"])
	s["tile"] = exit["spawn"]
	s["exit"] = {}
	s["path"] = []


func on_map(map_id: String) -> Array:
	var out: Array = []
	for id in state:
		var s: Dictionary = state[id]
		if not bool(s.get("away", false)) and not bool(s.get("hidden", false)) and str(s.get("map", "")) == map_id:
			out.append(id)
	return out


func where_is(id: String) -> Dictionary:
	return state.get(id, {})


func serialize() -> Dictionary:
	var out := {}
	for id in state:
		var s: Dictionary = state[id]
		var tile: Vector2i = s.get("tile", Vector2i.ZERO)
		out[id] = {"map": s.get("map", ""), "x": tile.x, "y": tile.y, "hidden": s.get("hidden", false),
			"away": s.get("away", false)}
	return {"state": out}


func deserialize(d: Dictionary) -> void:
	reset()
	var saved: Dictionary = d.get("state", {})
	for id in saved:
		var e: Dictionary = saved[id]
		state[id] = {"map": str(e["map"]), "tile": Vector2i(int(e["x"]), int(e["y"])), "hidden": bool(e["hidden"]),
			"away": bool(e["away"]), "path": [], "route": [], "goal": "", "frac": 0.0, "face": "down", "anim": "", "idle": 0.0}
	_last_total = _total()
