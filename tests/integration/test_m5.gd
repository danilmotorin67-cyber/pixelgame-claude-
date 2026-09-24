extends Node

# Run with: godot --headless --path . res://tests/integration/test_m5.tscn
const SEA_ONLY := ["sea_z1", "sea_z2", "sea_z3", "sea_teeth", "dead_fire", "ice_field", "tidepool"]
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
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Graveyard, Mail, Knowledge, Quests, Collections]:
		system.reset()


func _good_context(fish: Dictionary) -> Dictionary:
	var hours: Array = fish["hours"][0]
	var tide := 0.0
	match str(fish.get("tide", "any")):
		"high":
			tide = 1.0
		"low":
			tide = -1.0
	return {"tags": fish["where"].duplicate(), "season": fish["seasons"][0],
		"day": int(fish.get("days", [10, 10])[0]), "hour": int(hours[0]) % 24,
		"weather": "clear" if str(fish["weather"]) == "any" else str(fish["weather"]), "tide": tide, "rising": false,
		"lantern": bool(fish.get("lantern", false)), "hmar": bool(fish.get("hmar", false))}


# Every map-reachable "where" tag appears for some water spot on the island.
func _reachable_tags() -> Dictionary:
	var tags := {}
	Clock.set_time(12, 0)
	for map_id in ["cape", "village", "seal_shore", "wreck_bay", "lagoon", "moor", "birch"]:
		var info: Dictionary = Data.tables["regions"].get(map_id, {})
		var size: Array = info.get("size", [90, 70])
		for y in range(0, int(size[1]) * 16, 8):
			for x in range(0, int(size[0]) * 16, 16):
				for tag in Fishing.spot_tags(map_id, Vector2(x, y)):
					tags[tag] = true
	Clock.day_index = 3 * 28 + 10
	for tag in Fishing.spot_tags("lagoon", Vector2(200, 36 * 16)):
		tags[tag] = true
	Clock.day_index = 0
	return tags


func _check_every_fish() -> void:
	_fresh()
	var fish_list := Data.all("fish")
	_check(fish_list.size() == 38, "33 rod fish and 5 legends (15.4)")
	var reachable := _reachable_tags()
	for tag in ["coast", "rocky", "pier", "sand", "lagoon", "ice", "lake", "stream", "estuary", "seal_rock"]:
		_check(reachable.has(tag), "some island water must count as " + tag)
	for fish in fish_list:
		var id := str(fish["id"])
		_check(Data.exists("items", id) and Loc.t(str(Data.by_id("items", id)["name"])) != str(Data.by_id("items", id)["name"]),
			id + " needs a named item")
		var ctx := _good_context(fish)
		_check(Fishing.bites(fish, ctx), id + " must bite in its own conditions")
		var here := false
		for tag in fish["where"]:
			here = here or reachable.has(tag) or SEA_ONLY.has(tag)
		_check(here, id + " must live somewhere reachable")
		var off_season := ctx.duplicate()
		var other: Array = ["spring", "summer", "autumn", "winter"].filter(func(s: String) -> bool: return s not in fish["seasons"])
		if not other.is_empty():
			off_season["season"] = other[0]
			_check(not Fishing.bites(fish, off_season), id + " must not bite out of season")
		var hours: Array = fish["hours"][0]
		if int(hours[1]) - int(hours[0]) < 24:
			var late := ctx.duplicate()
			late["hour"] = (int(fish["hours"][-1][1]) + 1) % 24
			var covered := false
			for window in fish["hours"]:
				covered = covered or (late["hour"] >= int(window[0]) and late["hour"] < int(window[1])) \
					or (late["hour"] + 24 >= int(window[0]) and late["hour"] + 24 < int(window[1]))
			if not covered:
				_check(not Fishing.bites(fish, late), id + " must not bite outside its hours")
		if str(fish["tide"]) == "low":
			var high := ctx.duplicate()
			high["tide"] = 1.0
			_check(not Fishing.bites(fish, high), id + " needs low water")
		if str(fish["weather"]) != "any":
			var dry := ctx.duplicate()
			dry["weather"] = "cloud"
			_check(not Fishing.bites(fish, dry), id + " needs its weather")
		var sim := FishingSim.new(fish, {"seed": 7, "difficulty": Fishing.difficulty(fish)})
		_check(sim.autoplay(90.0) == "caught", id + " can be landed with steady play")
	var salmon := Data.by_id("fish", "fish_salmon")
	var ctx := _good_context(salmon)
	ctx["day"] = 22
	_check(not Fishing.bites(salmon, ctx), "salmon run only on Autumn 15-21")
	var squid := Data.by_id("fish", "fish_squid")
	ctx = _good_context(squid)
	ctx["lantern"] = false
	_check(not Fishing.bites(squid, ctx), "squid need a lantern at night")
	Game.set_flag("caught_fish_old_codger")
	_check(not Fishing.bites(Data.by_id("fish", "fish_old_codger"), _good_context(Data.by_id("fish", "fish_old_codger"))),
		"a legend is caught only once")


func _check_minigame_rules() -> void:
	_fresh()
	var cod := Data.by_id("fish", "fish_cod")
	var sim := FishingSim.new(cod, {"seed": 3})
	_check(is_equal_approx(sim.progress, 30.0) and sim.green_low == 35.0 and sim.green_high == 75.0,
		"start at 30% progress with the green zone 35-75")
	for n in 120:
		sim.step(1.0 / 60.0, true)
	_check(sim.tension > 75.0, "holding reels in and raises the tension")
	var snap := FishingSim.new(cod, {"seed": 3})
	snap.tension = 100.0
	var outcome := ""
	for n in 60:
		outcome = snap.step(1.0 / 60.0, true)
		if outcome != "":
			break
	_check(outcome == "snapped", "tension held at 100 for 0.4 s snaps the line")
	var helped := FishingSim.new(cod, {"seed": 3, "assist": true})
	helped.tension = 100.0
	for n in 60:
		helped.step(1.0 / 60.0, true)
	_check(helped.result != "snapped" and helped.green_high - helped.green_low == 80.0, "assist mode: double zone, no snapping")
	var skilled := FishingSim.new(cod, {"seed": 3, "level": 5, "green": 10})
	_check(is_equal_approx(skilled.green_high - skilled.green_low, 65.0), "+3 per fishing level, +10 for silk line")
	var slack := FishingSim.new(cod, {"seed": 3})
	slack.tension = 10.0
	var before := slack.progress
	for n in 30:
		slack.step(1.0 / 60.0, false)
	_check(slack.progress < before and not slack.perfect, "slack line below 20 loses the fish slowly")
	var perfect := FishingSim.new(cod, {"seed": 3})
	perfect.autoplay()
	_check(perfect.result == "caught" and perfect.perfect, "a calm cod can be landed perfectly")

	Inventory.add("fish_capelin", 1)
	Inventory.add("float_guard", 1)
	_check(Fishing.bait_for("rod_agatha") == "" and Fishing.bait_for("rod_composite") == "fish_capelin",
		"Agatha's rod takes no bait; live capelin is the best bait")
	_check(Fishing.tackles_for("rod_reel") == ["float_guard"] and Fishing.tackles_for("rod_composite").is_empty(),
		"only rods with tackle slots use tackle")
	var got := Fishing.land(cod, true, ["float_guard"], "fish_capelin")
	_check(got["quality"] >= 1 and int(Skills.xp["fishing"]) == int(round((3 + 35 / 2) * 1.5)),
		"a perfect catch: quality +1 and XP x1.5")
	_check(Knowledge.sea_pts == 2 and Collections.has("fish", "fish_cod") and Inventory.count_of("fish_capelin") == 0,
		"a new species: +2 sea notes and the collection; the bait is used")
	for n in 9:
		Fishing.land(cod, false, [], "")
	_check(Knowledge.sea_pts == 3, "every tenth fish: +1 sea note")
	for n in 18:
		Fishing.land(cod, false, ["float_guard"], "")
	_check(Inventory.count_of("float_guard") == 1, "tackle lasts 20 fish")
	Fishing.land(cod, false, ["float_guard"], "")
	_check(Inventory.count_of("float_guard") == 0, "tackle wears out after 20 fish")
	Game.counters["fish_today"] = 61
	var mercy := Sea.mercy
	Sea.night_mercy()
	_check(Sea.mercy == mercy - 1.0 and int(Game.counters["fish_today"]) == 0, "more than 60 fish a day angers Rann")


func _check_q1_3() -> void:
	_fresh()
	Clock.day_index = 1
	_check("q1_3_rod" in Quests.check_starts() and str(Mail.letters[-1]["text"]) == "mail.q1_3_erland",
		"Erland writes on Spring 2 about Agatha's rod")
	Router.current_map = "village"
	var village: Node = load("res://scenes/world/island_region.tscn").instantiate()
	get_tree().root.add_child(village)
	get_tree().current_scene = village
	await get_tree().process_frame
	Clock.set_time(10, 0)
	village.get_node("Terrain/Shop_shop_erland").interact(village.get_node("Player"))
	_check(Inventory.count_of("rod_agatha") == 1 and Quests.step_done("q1_3_rod", "rod"), "Erland hands over the rod")
	var cod := Data.by_id("fish", "fish_cod")
	for n in 3:
		Fishing.land(cod, false, [], "")
	_check(Quests.state("q1_3_rod") == "done" and Inventory.count_of("bait") == 20
		and Crafting.knows(Data.by_id("recipes_cook", "cook_keeper_soup")), "three fish: 20 bait and the keeper's soup")
	village.queue_free()
	await get_tree().process_frame


func _run() -> void:
	_check_every_fish()
	_check_minigame_rules()
	await _check_q1_3()
	print("M5 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
