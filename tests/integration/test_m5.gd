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


func _tide_minute(index: int, low: bool) -> int:
	var best := 0
	for minute in range(0, 1440, 10):
		var h := Clock.tide_height_at(index, minute)
		if (low and h < Clock.tide_height_at(index, best)) or (not low and h > Clock.tide_height_at(index, best)):
			best = minute
	return best


func _check_gear() -> void:
	_fresh()
	Clock.day_index = 2
	var high := _tide_minute(2, false)
	Clock.set_time(high / 60, high % 60)
	Inventory.add("trap", 2)
	Inventory.add("bait", 3)
	_check(not Sea.place_gear("trap", "cape", Vector2(600, 400)), "a trap is not set on dry land")
	_check(Sea.place_gear("trap", "cape", Vector2(600, 56 * 16 + 8)), "a trap goes into the water by the cape")
	var trap: Dictionary = Sea.gear[0]
	_check(Sea.bait_trap(trap) and Inventory.count_of("bait") == 2 and not Sea.bait_trap(trap), "one bait per trap")
	Clock.day_index = 3
	Sea.night_gear()
	_check(trap["catch"].size() == 1 and str(trap["catch"][0][0]) in ["lobster", "mussels", "rock_crab", "trash"],
		"by morning the rocky cape trap holds a catch")
	var got := Sea.lift_gear(trap)
	_check(got.size() == 1 and Inventory.count_of(str(got[0][0])) >= 1 and int(Skills.xp["fishing"]) == 5,
		"lifting a trap: the catch and 5 fishing XP")
	Sea.night_gear()
	_check(trap["catch"].is_empty(), "an unbaited trap stays empty")

	Inventory.add("set_net", 1)
	var low := _tide_minute(3, true)
	Clock.set_time(high / 60, high % 60)
	_check(not Sea.place_gear("net", "seal_shore", Vector2(20 * 16, 30 * 16)), "nets are set at low tide")
	Clock.set_time(low / 60, low % 60)
	_check(Sea.place_gear("net", "seal_shore", Vector2(20 * 16, 30 * 16)), "a net on the tidal strip at low tide")
	var net: Dictionary = Sea.gear[-1]
	_check(Sea.lift_gear(net).is_empty(), "a net is not lifted on the same low water")
	Clock.day_index = 4
	var next_low := _tide_minute(4, true)
	Clock.set_time(next_low / 60, next_low % 60)
	var fish_before := int(Collections.found.get("fish", {}).size())
	var catch := Sea.lift_gear(net)
	var fish_count := 0
	for entry in catch:
		if str(entry[0]).begins_with("fish_"):
			fish_count += 1
	_check(fish_count >= 3 and fish_count <= 6 and Inventory.count_of("set_net") == 1, "the next low tide: 3-6 fish, and the net back")

	Sea.ensure_pools()
	_check(Sea.pools["cape"].size() >= 6 and Sea.pools["seal_shore"].size() <= 10, "6-10 rock pools per rocky beach")
	var pool: Dictionary = Sea.pools["seal_shore"][0]
	_check(Sea.net_pool(pool).is_empty(), "no hand net, no catch")
	Inventory.add("hand_net", 1)
	Clock.set_time(high / 60, high % 60)
	_check(Sea.net_pool(pool).is_empty(), "pools are under water at high tide")
	Clock.set_time(next_low / 60, next_low % 60)
	var pool_catch := Sea.net_pool(pool)
	_check(pool_catch.size() >= 1 and pool_catch.size() <= 3 and Sea.net_pool(pool).is_empty(), "1-3 creatures, once a day")
	var scorpion := false
	for seed_value in 60:
		Game.world_seed = seed_value
		Sea.pools_fished.clear()
		Inventory.reset()
		Inventory.add("hand_net", 1)
		for id in Sea.net_pool(pool):
			scorpion = scorpion or id == "fish_sea_scorpion"
	_check(scorpion, "the sea scorpion lives in spring rock pools")
	Inventory.reset()
	Game.world_seed = 5
	Sea._spawn_clams(4)
	_check(Sea.clams.size() >= 3, "clam bubbles on the Seal Shore sand")
	_check(Sea.dig_clam(Sea.clams[0]) and Inventory.count_of("mya_clam") == 1, "the shovel finds a soft-shell clam")

	Sea.mercy = 10.0
	Game.world_seed = 5
	var lost := 0
	for n in 200:
		Sea.gear = [{"kind": "trap", "map": "cape", "x": 8.0 * n, "y": 900.0, "baited": false, "catch": [],
			"set_day": 0, "set_minute": 0}]
		Clock.day_index = 10 + n
		Sea.night_gear()
		if Sea.gear.is_empty():
			lost += 1
	_check(lost >= 8 and lost <= 35, "a hostile sea takes about 10%% of gear (%d/200)" % lost)
	Sea.mercy = 30.0
	Clock.day_index = 0


func _check_boat() -> void:
	_fresh()
	Clock.day_index = 2
	Quests.check_starts()
	_check(Quests.state("q1_6_boat") == "active", "Q1.6 starts on the third day with Ilm's letter")
	_check(Sea.can_sail() == "no_boat", "no boat, no sailing")
	_check(not Sea.order_boat(), "Ilm needs the driftwood, resin and money first")
	Inventory.add("driftwood", 20)
	Inventory.add("resin", 5)
	Economy.money = 500
	_check(Sea.order_boat() and Economy.money == 200 and Inventory.count_of("driftwood") == 0, "the dinghy costs 20 driftwood, 5 resin, 300 kr")
	_check(Quests.step_done("q1_6_boat", "order"), "ordering ticks the quest step")
	Clock.day_index = 3
	Sea.night_boats()
	_check(Sea.boat == "", "the dinghy is not ready the next morning")
	Clock.day_index = 4
	Sea.night_boats()
	_check(Sea.boat == "yalik" and Sea.hold.size() == 12, "two days later the dinghy with a 12-slot hold")
	_check(Quests.state("q1_6_boat") == "done" and Game.flag("sea_zone_1"), "Q1.6 is done and zone 1 is open")
	_check(Sea.can_sail(1) == "" and Sea.can_sail(2) == "zone", "the dinghy only goes into zone 1")
	Weather.current = "storm"
	_check(Sea.can_sail() == "storm", "no putting out in a storm")
	Weather.current = "clear"

	Weather.calm = false
	Weather.wind_strength = 2
	Weather.wind_direction = 0
	var to := SeaChart.wind_to()
	_check(is_equal_approx(SeaChart.angle_multiplier(-to), 0.0), "straight into the wind the sail stalls")
	_check(is_equal_approx(SeaChart.angle_multiplier(to.rotated(PI - deg_to_rad(55))), 0.6), "close-hauled ×0.6")
	_check(is_equal_approx(SeaChart.angle_multiplier(to.rotated(PI / 2)), 1.0), "a beam reach ×1.0")
	_check(is_equal_approx(SeaChart.angle_multiplier(to.rotated(deg_to_rad(50))), 1.2), "a broad reach ×1.2 is the fastest")
	_check(is_equal_approx(SeaChart.angle_multiplier(to), 1.0), "running before the wind ×1.0")
	_check(is_equal_approx(SeaChart.sail_speed(to.rotated(PI / 2)), 0.0), "the dinghy has no sail")
	Weather.calm = true
	_check(is_equal_approx(SeaChart.strength_multiplier(), 0.0), "in a calm there is no wind to sail")
	Weather.calm = false

	var dock := SeaChart.place_pos("rest_place") - Vector2(0, 60 * 16)
	_check(SeaChart.is_land(dock) and Fishing.spot_tags("sea", dock).is_empty(), "the coast rows are land")
	_check(Fishing.spot_tags("sea", SeaChart.place_pos("seal_rock")).has("seal_rock"), "the seal rock is a fishing spot")
	_check(Fishing.spot_tags("sea", SeaChart.place_pos("rest_place")).has("sea_z1"), "the Resting Place lies in zone 1")
	_check(Fishing.spot_tags("sea", SeaChart.place_pos("teeth")).has("sea_teeth") \
		and SeaChart.zone_of(SeaChart.place_pos("teeth")) == 2, "the Teeth are a zone-2 spot")

	var xp := int(Skills.xp["seafaring"])
	_check(Sea.visit("rest_place") and not Sea.visit("rest_place"), "a place is discovered once")
	_check(int(Skills.xp["seafaring"]) == xp + 30 and Sea.visited.has("rest_place"), "discovery: +30 seafaring XP")
	SeaChart.reveal(SeaChart.place_pos("rest_place"))
	_check(Sea.revealed.has(SeaChart.chunk_key(SeaChart.place_pos("rest_place"))), "sailing reveals the chart")

	Inventory.add("fish_cod", 1)
	Crafting.store({"slots": Sea.hold}, Inventory.slots.find_custom(func(s: Dictionary) -> bool: return s["id"] == "fish_cod"))
	_check(str(Sea.hold[0]["id"]) == "fish_cod", "fish goes into the hold")
	Economy.money = 700
	_check(not Sea.damage_hull(60.0) and Sea.damage_hull(60.0), "the hull breaks at zero")
	Sea.tow_home()
	_check(Economy.money == 200 and Sea.hull == 100.0 and str(Sea.hold[0]["id"]) == "", "towing: 500 kr, and the hold is lost")
	Sea.damage_hull(35.0)
	Inventory.add("boards", 2)
	Inventory.add("resin", 2)
	_check(Sea.repair_at_boathouse() == 20 and is_equal_approx(Sea.hull, 85.0), "boards and resin mend 10% each at the boathouse")
	Inventory.add("repair_kit", 1)
	_check(Sea.use_repair_kit() and is_equal_approx(Sea.hull, 100.0) and not Sea.use_repair_kit(), "a repair kit patches 30% at sea")

	Clock.set_time(12, 0)
	var entry: Dictionary = {}
	for e in Economy.shop_stock("shop_ilm"):
		if str(e.get("upgrade", "")) == "boathouse":
			entry = e
	_check(not entry.is_empty(), "Ilm offers the sloop once there is a dinghy")
	Economy.money = 3000
	_check(Economy.buy("shop_ilm", entry) == "materials", "the sloop needs 200 boards")
	Inventory.reset()
	Inventory.add("boards", 200)
	_check(Economy.buy("shop_ilm", entry) == "ok" and Sea.boat == "sloop" and Sea.hold.size() == 24, "the sloop: 24-slot hold")
	_check(Sea.can_sail(2) == "" and SeaChart.sail_speed(to.rotated(PI / 2)) > 1.0, "the sloop sails into zone 2")
	var saved := JSON.stringify(Sea.serialize())
	Sea.reset()
	Sea.deserialize(JSON.parse_string(saved))
	_check(Sea.boat == "sloop" and Sea.hold.size() == 24 and Sea.visited.has("rest_place"), "the boat survives a save")


func _run() -> void:
	_check_every_fish()
	_check_minigame_rules()
	await _check_q1_3()
	_check_gear()
	_check_boat()
	print("M5 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
