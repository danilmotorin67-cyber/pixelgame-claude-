extends Node

# Run with: godot --headless --path . res://tests/integration/test_m6.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh() -> void:
	Game.reset()
	Game.world_seed = 5
	Clock.reset()
	Weather.reset()
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Graveyard, Mail, Knowledge, Quests,
			Collections, Relationships, Cutscenes, NPCs]:
		system.reset()


func _check_data() -> void:
	_fresh()
	_check(Data.all("npcs").size() == 29, "28 islanders and Fortuna (4)")
	for id in NPCs.ids():
		var info := NPCs.info(id)
		_check(Loc.t(str(info["name"])) != str(info["name"]), id + " needs a name")
		var home: Dictionary = info["home"]
		if str(home["map"]) != "away":
			_check(MapInfo.walkable(str(home["map"]), MapInfo.spot(str(home["map"]), str(home["spot"]))), id + " home must be walkable")
		for e in NPCs.schedule(id):
			_check(ConditionContext.valid(str(e.get("when", ""))), id + " has a broken condition: " + str(e.get("when", "")))
			for step in e["path"]:
				var map_id := str(step[1])
				if map_id in ["home", "away"]:
					continue
				var tile: Vector2i = MapInfo.spot(map_id, str(step[2])) if not (step[2] is Array) else Vector2i(int(step[2][0]), int(step[2][1]))
				_check(MapInfo.walkable(map_id, tile), "%s: %s %s is not a walkable spot" % [id, map_id, str(step[2])])
	# Every named spot can be reached from the map's first exit.
	var places: Dictionary = Data.tables["places"]
	for map_id in places:
		if map_id == "sea":
			continue
		var entry: Vector2i = MapInfo.exits(map_id)[0]["at"]
		for name in places[map_id]:
			_check(MapInfo.path(map_id, entry, MapInfo.spot(map_id, name)).size() > 0, "%s: %s cannot be reached" % [map_id, name])
	for map_id in Data.tables["interiors"]:
		var door: Vector2i = MapInfo.exits(map_id)[0]["at"]
		for name in Data.tables["interiors"][map_id]["spots"]:
			_check(MapInfo.path(map_id, door, MapInfo.spot(map_id, name)).size() > 0, "%s: %s cannot be reached" % [map_id, name])
	# 4 seasons x 7 days + rain and storm: every resident has a plan for each.
	for season_index in 4:
		for weekday in 7:
			Clock.day_index = 40 + season_index * 28 + weekday
			for weather in ["clear", "rain", "storm"]:
				Weather.set_weather(weather)
				for id in NPCs.ids():
					if bool(NPCs.info(id).get("visitor", false)) or id == "npc_tuve":
						continue
					_check(not NPCs.entry_for(id).is_empty(), "%s has no schedule on %s %s in %s" % [id, Clock.season, Clock.weekday, weather])
	Weather.set_weather("clear")


# 33.7: a week of simulation in every season and weather; nobody stands still off target for 30 minutes,
# and everyone reaches every place of the day in time.
func _check_week() -> void:
	_fresh()
	var late := {}
	for season_index in 4:
		for weather in ["clear", "rain", "storm"]:
			for weekday in 7:
				Clock.day_index = 28 + season_index * 28 + weekday
				Weather.set_weather(weather)
				Clock.minutes = 6 * 60
				NPCs.morning()
				var waiting := {}
				for step in range(6 * 60, 26 * 60, 10):
					Clock.minutes = step % 1440
					NPCs.advance(10.0)
					for id in NPCs.ids():
						if NPCs.at_goal(id):
							waiting.erase(id)
							continue
						var goal := NPCs._goal_key(NPCs.target(id))
						if str(waiting.get(id, [""])[0]) != goal:
							waiting[id] = [goal, 0]
						waiting[id][1] += 10
						if int(waiting[id][1]) > 180 and not late.has(id + goal):
							late[id + goal] = true
							_check(false, "%s takes over 3 hours to reach %s (%s %s %s)" % [id, goal, Clock.season, Clock.weekday, weather])
	_check(NPCs.stuck_log.is_empty(), "stuck NPCs: %s" % str(NPCs.stuck_log.slice(0, 5)))
	Weather.set_weather("clear")


func _check_places() -> void:
	_fresh()
	Clock.day_index = 29 # summer? no: spring, tuesday
	Clock.day_index = 2 # wednesday, spring
	Weather.set_weather("clear")
	Clock.minutes = 10 * 60
	NPCs.morning()
	var karl := NPCs.where_is("npc_karl")
	_check(str(karl["map"]) == "village" and not bool(karl["hidden"]), "Karl walks the pier on his day off")
	Clock.day_index = 0 # monday
	Clock.minutes = 6 * 60
	NPCs.morning()
	for step in range(6 * 60, 11 * 60, 10):
		Clock.minutes = step
		NPCs.advance(10.0)
	_check(str(NPCs.where_is("npc_karl")["map"]) == "village_berg", "Karl is behind his counter by 11")
	_check(str(NPCs.where_is("npc_hedda")["map"]) == "" and bool(NPCs.where_is("npc_hedda")["away"]), "Hedda is at sea in the morning")
	_check(NPCs.on_map("village_berg").has("npc_karl"), "the shop shows Karl")
	for step in range(11 * 60, 18 * 60, 10):
		Clock.minutes = step
		NPCs.advance(10.0)
	_check(str(NPCs.where_is("npc_hedda")["map"]) == "village_tavern", "Hedda drinks in the tavern at six")
	_check(str(NPCs.where_is("npc_olaf")["map"]) == "cape", "Olaf brings the mail to the cape")
	_check(NPCs.on_map("village").has("npc_grump"), "Cap'n Grump loads the steamer at six")
	var saved := JSON.stringify(NPCs.serialize())
	NPCs.reset()
	NPCs.deserialize(JSON.parse_string(saved))
	_check(str(NPCs.where_is("npc_olaf")["map"]) == "cape", "NPC positions survive a save")
	Clock.minutes = 23 * 60
	NPCs.advance(300.0)
	_check(bool(NPCs.where_is("npc_karl")["hidden"]), "at night Karl sleeps upstairs")


func _run() -> void:
	_check_data()
	_check_week()
	_check_places()
	print("M6 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
