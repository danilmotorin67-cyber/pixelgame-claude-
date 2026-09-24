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
		if str(home["map"]) != "away" and not NPCs.is_static(id):
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
					if bool(NPCs.info(id).get("visitor", false)) or id == "npc_tuve" or NPCs.is_static(id):
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


func _check_friendship() -> void:
	_fresh()
	Clock.day_index = 3
	_check(Relationships.talk("npc_hedda") and not Relationships.talk("npc_hedda") and Relationships.points["npc_hedda"] == 20,
		"talking: +20 once a day")
	_check(Relationships.taste("npc_hedda", "grog") == "love" and Relationships.taste("npc_hedda", "fish_halibut", 2) == "love"
		and Relationships.taste("npc_hedda", "fish_halibut", 1) == "like" and Relationships.taste("npc_hedda", "fish_cod", 0) == "neutral", "Hedda loves an excellent halibut and likes any good fish")
	_check(Relationships.taste("npc_hedda", "heather_bouquet") == "dislike" and Relationships.taste("npc_hedda", "old_boot") == "hate",
		"flowers and rubbish")
	_check(Relationships.taste("npc_helga", "lutefisk") == "love" and Relationships.taste("npc_karl", "lutefisk") == "hate",
		"only Helga loves lutefisk")
	_check(Relationships.taste("npc_karl", "keeper_soup") == "like" and Relationships.taste("npc_karl", "stone") == "neutral",
		"dishes please everyone; a stone is just a stone")
	Inventory.add("amber", 5)
	var slot := func(id: String) -> int:
		return Inventory.slots.find_custom(func(s: Dictionary) -> bool: return s["id"] == id)
	var gift := Relationships.give("npc_hedda", slot.call("amber"))
	_check(bool(gift["ok"]) and str(gift["reaction"]) == "love" and Relationships.points["npc_hedda"] == 100, "amber for Hedda: +80")
	_check(str(Relationships.give("npc_hedda", slot.call("amber"))["reason"]) == "today", "one gift a day")
	Clock.day_index = 4
	Relationships.gifted_today.clear()
	Relationships.give("npc_hedda", slot.call("amber"))
	Clock.day_index = 5
	Relationships.gifted_today.clear()
	_check(str(Relationships.give("npc_hedda", slot.call("amber"))["reason"]) == "week", "two gifts a week")
	Clock.day_index = 3 * 28 - 8 # autumn 21, Hedda's birthday
	Relationships.gifted_today.clear()
	var before := int(Relationships.points["npc_hedda"])
	_check(bool(Relationships.give("npc_hedda", slot.call("amber"))["ok"]) and int(Relationships.points["npc_hedda"]) == before + 640,
		"on the birthday a gift counts eight times, past the weekly limit")
	Relationships.set_hearts("npc_sigrid", 9)
	_check(Relationships.hearts_of("npc_sigrid") == 9 and Relationships.dating.has("npc_sigrid"), "romance past 8 hearts means dating")
	Relationships.reset()
	Relationships.add_friendship("npc_sigrid", 5000)
	_check(Relationships.hearts_of("npc_sigrid") == 8, "a romance stops at 8 hearts before the bouquet")
	Relationships.add_friendship("npc_halvdan", 5000)
	_check(Relationships.hearts_of("npc_halvdan") == 6, "Halvdan stops at 6 hearts")
	Relationships.points["npc_karl"] = 3 * 250
	Clock.day_index = 8
	Relationships.night()
	_check(Relationships.points["npc_karl"] == 748, "two points a day fade without a talk")
	var key := Dialogue.talk_line("npc_karl")
	_check(key != "" and Loc.t(key) != key, "everyone has something to say")
	_check(Dialogue.talk_line("npc_karl") == key or Dialogue.lines("npc_karl", "again").size() > 0, "the day's line repeats")
	Game.hero["gender"] = "f"
	Game.hero["name"] = "Ада"
	_check(Loc.format("{name}, {внук|внучка} Агаты") == "Ада, внучка Агаты", "name and gender tags (2.4)")
	Game.hero["gender"] = "m"
	_check(Loc.format("{внук|внучка}") == "внук", "the male form")


func _check_scenes() -> void:
	_fresh()
	Clock.day_index = 5
	Clock.minutes = 20 * 60
	_check(Cutscenes.pending("village_tavern") == "", "no scene before four hearts")
	Relationships.set_hearts("npc_hedda", 4)
	_check(Cutscenes.pending("village_tavern") == "ev_hedda_2", "the lower heart scene comes first")
	Cutscenes.seen["ev_hedda_2"] = 1
	_check(Cutscenes.pending("village_tavern") == "ev_hedda_4", "at four hearts Hedda's story waits in the tavern")
	_check(Cutscenes.pending("village") == "", "only in the tavern")
	Clock.minutes = 12 * 60
	_check(Cutscenes.pending("village_tavern") == "", "only in the evening")
	Clock.minutes = 20 * 60
	var before := int(Relationships.points["npc_hedda"])
	var said := Cutscenes.simulate("ev_hedda_4", [0])
	_check(Game.flag("hedda_testimony_told") and int(Relationships.points["npc_hedda"]) == before + 80,
		"the warm answer: +80 and her testimony")
	_check(Cutscenes.pending("village_tavern") == "" and Cutscenes.seen.has("ev_hedda_4"), "each scene plays once")
	Cutscenes.reset()
	Game.flags.clear()
	said = Cutscenes.simulate("ev_hedda_4", [2])
	_check(not Game.flag("hedda_testimony_told") and said.size() < 8, "the cold answer ends it")


# Every scene parses, runs to the end on every first choice, and its lines exist in both languages.
func _check_all_scenes() -> void:
	for e in Cutscenes.all():
		var id := str(e["id"])
		_check(ConditionContext.valid(str(e.get("trigger", {}).get("when", ""))), id + " has a broken trigger")
		_check(MapInfo.exists(str(e["trigger"].get("map", "cape"))) or str(e["trigger"].get("map", "")) == "cape", id + " is on an unknown map")
		for pick in 3:
			_fresh()
			var said := Cutscenes.simulate(id, [pick, pick, pick])
			_check(not said.is_empty() and Cutscenes.seen.has(id), "%s plays through with choice %d" % [id, pick])
			for key in said:
				_check(Loc.has(str(key)), "%s: missing text %s" % [id, key])


func _check_shops() -> void:
	_fresh()
	Clock.day_index = 4 # friday
	Clock.set_time(12, 0)
	var ids: Array = []
	for shop in Data.all("shops"):
		ids.append(str(shop["id"]))
	for id in ["shop_berg", "shop_smith", "shop_erland", "shop_ilm", "shop_margit", "shop_tavern", "shop_chapel",
			"shop_office", "shop_helga", "shop_grim", "shop_sandro"]:
		_check(ids.has(id), "21.3 lists " + id)
	var wares := Economy.shop_stock("shop_sandro")
	_check(wares.size() == 10 and Economy.shop_closed_reason("shop_sandro") == "", "the Pyostraya brings 10 wares on Fridays")
	Clock.day_index = 12
	var next_week := Economy.shop_stock("shop_sandro")
	_check(Economy.shop_closed_reason("shop_sandro") == "day" and JSON.stringify(next_week) != JSON.stringify(wares), "other wares next week")
	Clock.day_index = 0
	var armeria := func() -> bool:
		for e in Economy.shop_stock("shop_berg"):
			if str(e.get("item", "")) == "bouquet_armeria":
				return true
		return false
	_check(not armeria.call(), "no armeria bouquet before 8 hearts")
	Relationships.set_hearts("npc_einar", 8)
	_check(armeria.call(), "the bouquet goes on sale at 8 hearts with anyone")
	Economy.money = 100
	Clock.set_time(14, 0)
	var rumor: Dictionary = Economy.shop_stock("shop_tavern").filter(func(e: Dictionary) -> bool: return e.has("service"))[0]
	_check(Economy.buy("shop_tavern", rumor) == "ok" and Economy.last_service.begins_with("Бьорн"), "Bjorn tells the rumour of the day")
	Inventory.add("overgrown_chest", 1)
	var chest: Dictionary = Economy.shop_stock("shop_smith").filter(func(e: Dictionary) -> bool: return e.has("service"))[0]
	_check(Economy.buy("shop_smith", chest) == "ok" and Inventory.count_of("overgrown_chest") == 0 and Economy.money == 75,
		"Tora opens an overgrown chest for 25 kr")
	_check(Economy.buy("shop_smith", chest) == "nothing", "no chest, no service")
	Relationships.set_hearts("npc_karl", 0)
	var info: Dictionary = Data.by_id("npcs", "npc_karl")
	if info.has("letters"):
		var need := int(info["letters"].keys()[0])
		Relationships.set_hearts("npc_karl", need)
		var before := Mail.letters.size()
		_check(Relationships.night_letters() >= 1 and Mail.letters.size() > before, "Karl writes at %d hearts" % need)
		_check(Relationships.night_letters() == 0, "each letter comes once")
	Clock.day_index = 6 # sunday
	_check(Mail.sunday_gazette() and str(Mail.letters[-1]["text"]) == "mail.gazette", "the Sunday paper")


func _run() -> void:
	_check_data()
	_check_week()
	_check_places()
	_check_friendship()
	_check_scenes()
	_check_shops()
	_check_all_scenes()
	print("M6 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
