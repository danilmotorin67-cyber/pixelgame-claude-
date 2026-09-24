extends Node

# Run with: godot --headless --path . res://tests/integration/test_m1.tscn
const TEST_SAVE_ROOT := "user://saltlight_m1_test_saves"
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _check_calendar_rules() -> void:
	var spring_13 := 12
	var autumn_16 := 2 * 28 + 15
	var autumn_27 := 2 * 28 + 26
	var winter_8 := 3 * 28 + 7
	var winter_25 := 3 * 28 + 24
	_check(Clock.festival_on(spring_13).get("id", "") == "boat_blessing", "Spring 13 must be the boat blessing")
	_check(Clock.festival_on(spring_13 + 1).is_empty(), "Spring 14 is not a festival")
	var storm_week_storms := 0
	for seed_value in range(1, 301):
		Game.world_seed = seed_value
		for index in [spring_13, autumn_16, winter_8, winter_25 + 112]:
			_check(Weather.weather_for_day(index) not in ["storm", "blizzard"],
				"festival day %d rolled a storm with seed %d" % [index, seed_value])
		if Weather.weather_for_day(2 * 28 + 9) == "storm":
			storm_week_storms += 1
		_check(Weather.aurora_on(winter_25), "the Long Night must always have an aurora")
		_check(not Weather.aurora_on(28 + 5) and not Weather.calm_on(5),
			"aurora is winter-only and calm is summer-only")
		if Weather.calm_on(28 + 5):
			_check(Weather.weather_for_day(28 + 5) == "clear", "calm must be a clear day")
	_check(storm_week_storms > 75, "the autumn storm week must double storms")
	Game.world_seed = 42

	Graveyard.peace = 0.0
	Weather.last_hmar_day = -100
	_check(Weather.hmar_chance(28 + 1) == 0.0, "no Hmar nights before Act II")
	Game.act = 2
	_check(Weather.hmar_chance(28 + 1) == 0.0, "random Hmar nights wait for the first White Hmar (Q2.2)")
	Game.set_flag("hmar_open")
	_check(is_equal_approx(Weather.hmar_chance(28 + 1), 0.2), "Hmar: 5% + (100-Peace)/10% + 5% new moon")
	_check(is_equal_approx(Weather.hmar_chance(28 + 9), 0.15), "Hmar chance without new moon")
	_check(Weather.hmar_chance(spring_13) == 0.0, "no Hmar on festival nights")
	_check(Weather.hmar_chance(autumn_27) > 0.0, "story festival nights may bring Hmar")
	Game.set_flag("twenty_buried")
	Game.set_flag("guild_house_restored")
	_check(is_equal_approx(Weather.hmar_chance(28 + 9), 0.15 * 0.7 * 0.5), "Hmar multipliers")
	Weather.last_hmar_day = 28 + 7
	_check(Weather.hmar_chance(28 + 9) == 0.0 and Weather.hmar_chance(28 + 11) > 0.0,
		"Hmar nights at most once in four days")
	Game.act = 0
	Game.flags.erase("twenty_buried")
	Game.flags.erase("guild_house_restored")
	Game.flags.erase("hmar_open")
	Weather.last_hmar_day = -100

	var right := 0
	var samples := 0
	for index in range(3, 603):
		Clock.day_index = index - 1
		samples += 1
		if Weather.barometer(1) == Weather.weather_for_day(index):
			right += 1
	var accuracy := float(right) / float(samples)
	_check(accuracy > 0.8 and accuracy < 0.9, "barometer must be right about 85%% (got %.2f)" % accuracy)
	Game.set_flag("telegraph_working")
	right = 0
	for index in range(3, 603):
		Clock.day_index = index - 1
		if Weather.barometer(1) == Weather.weather_for_day(index):
			right += 1
	_check(float(right) / float(samples) > 0.92, "telegraph barometer must be right about 95%")
	Game.flags.erase("telegraph_working")

	Clock.day_index = 3 * 28 + 11
	_check(Lighthouse.sunset_minutes() == 870, "Winter 10-20 sunset is 14:30")
	Clock.day_index = 28 + 9
	_check(Lighthouse.on_time_until() == 23 * 60, "white nights: fire on time until 23:00")
	Clock.day_index = 28 + 10
	var powers_before := Lighthouse.nightly_powers.size()
	var white_sun := Lighthouse.resolve_night()
	_check(bool(white_sun["no_fire"]) and Lighthouse.nightly_powers.size() == powers_before,
		"the Night of the White Sun needs no fire and must not lower Light")
	Clock.day_index = 0
	Lighthouse.reset()

	var first_luck := Game.roll_luck(10, false)
	_check(first_luck >= -0.1 and first_luck <= 0.1, "luck of the day must stay within ±0.1")
	_check(is_equal_approx(Game.roll_luck(10, true), first_luck + 0.05), "aurora adds 0.05 luck")
	Game.luck = 0.0
	_check(Night.energy_fraction(23 * 60, false) == 1.0 and Night.energy_fraction(30, false) == 0.9
		and Night.energy_fraction(90, false) == 0.75 and Night.energy_fraction(120, true) == 0.5,
		"sleep energy table (8.4)")


func _check_shipping() -> void:
	Economy.reset()
	Inventory.reset()
	Clock.day_index = 5
	Clock.set_time(10, 0)
	Inventory.add("turnip", 3, 2)
	Inventory.add("tool_hoe", 1)
	_check(Economy.sell_price("turnip", 2) == 53 and Economy.sell_price("tool_hoe") == 0,
		"sell price must apply the quality multiplier and refuse tools")
	_check(not Economy.ship_slot(1) and Inventory.count_of("tool_hoe") == 1, "tools cannot be shipped")
	_check(Economy.ship_slot(0) and Inventory.count_of("turnip") == 0 and Economy.shipping_value() == 159,
		"shipping must move the whole stack into the box")
	_check(Economy.take_back_last() and Inventory.count_of("turnip") == 3, "the last stack can be taken back")
	Economy.ship_slot(0)
	Clock.set_time(18, 30)
	_check(not Economy.take_back_last(), "the «Чайка» already took today's box at 18:00")
	Inventory.add("fish_cod", 1)
	Economy.ship_slot(0)
	_check(int(Economy.shipping[-1]["due"]) == 6, "goods boxed after 18:00 wait for tomorrow")
	var stormy := Economy.collect_shipping(5, true)
	_check(int(stormy["income"]) == 0 and Economy.shipping.size() == 2 and Economy.money == 500,
		"no «Чайка» in a storm")
	var paid := Economy.collect_shipping(6, false)
	_check(int(paid["income"]) == 249 and Economy.money == 749 and Economy.shipping.is_empty(),
		"the storm-delayed box must be paid the next night")
	Economy.reset()
	Inventory.reset()
	Clock.day_index = 0


func _check_energy_and_skills(player: Player) -> void:
	Skills.reset()
	_check(Game.action_cost("hoe") == 2.0 and Game.action_cost("scythe") == 1.0
		and Game.action_cost("cast") == 6.0, "base action costs from 8.1")
	Skills.levels["farming"] = 5
	Skills.levels["fishing"] = 10
	_check(is_equal_approx(Game.action_cost("can"), 1.5) and is_equal_approx(Game.action_cost("cast"), 2.0),
		"skill levels reduce tool energy")
	Skills.levels["farming"] = 10
	_check(Game.action_cost("hoe") == 1.0, "tool energy never drops below 1")
	_check(is_equal_approx(Game.action_cost("hoe", 60.0), 1.25), "cold of 50+ costs 25% more energy")
	Skills.reset()
	Game.counters["star_amber"] = 9
	_check(Game.max_energy() == 480.0, "seven star ambers cap energy at 480")
	Game.counters.erase("star_amber")
	_check(Game.max_energy() == 270.0, "base energy is 270")
	var saved_energy := player.energy
	player.energy = 1.0
	_check(player.spend_energy("hoe") and player.energy == 0.0, "the last action may drain energy to zero")
	_check(not player.spend_energy("hoe"), "tools do not work at zero energy")
	player.energy = 270.0 * 0.15
	_check(player.is_tired(), "15% energy means fatigue")
	player.energy = 270.0 * 0.16
	_check(not player.is_tired(), "fatigue starts at 15%")
	player.energy = saved_energy
	_check(Skills.level_for_xp(99) == 0 and Skills.level_for_xp(100) == 1
		and Skills.level_for_xp(14999) == 9 and Skills.level_for_xp(15000) == 10, "skill XP table 25.1")
	Skills.add_xp("keeping", 400)
	_check(Skills.level("keeping") == 0, "levels are only counted in sleep")
	var gained := Skills.apply_levels()
	_check(Skills.level("keeping") == 2 and gained.size() == 2, "sleep grants every level reached")
	Skills.reset()


func _run() -> void:
	var tree := get_tree()
	var night_reports: Array[Dictionary] = []
	Events.night_resolved.connect(func(report: Dictionary) -> void: night_reports.append(report))
	Save.save_root = TEST_SAVE_ROOT
	Save.current_slot = 2
	Game.reset()
	Lighthouse.reset()
	Game.world_seed = 42
	Clock.reset()
	Weather.start_day(0)
	var cape: Node2D = load("res://scenes/world/cape.tscn").instantiate()
	tree.root.add_child(cape)
	tree.current_scene = cape
	await tree.process_frame
	TranslationServer.set_locale("ru")
	var player: Player = cape.get_node("Player")
	_check(player.sprite.hframes == 16, "keeper direction frames are missing")
	for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		player.facing = direction
		player._update_sprite(false)
		_check(player.sprite.frame == player._direction_index() * 4,
			"keeper does not face %s" % direction)
	player.play_tool("hoe", player.global_position + Vector2.LEFT * 16)
	_check(player.tool_time > 0.0 and player.tool_kind == "hoe" and player.sprite.frame == 4,
		"hoe use must face the worked plot")
	player.tool_time = 0.0
	player.facing = Vector2.DOWN
	player._update_sprite(false)
	var slot_click := InputEventMouseButton.new()
	slot_click.button_index = MOUSE_BUTTON_LEFT
	slot_click.pressed = true
	slot_click.position = Vector2(5 * 25 + 10, 12)
	cape.get_node("HUD/Hotbar").call("_gui_input", slot_click)
	_check(Inventory.selected_hotbar == 5, "clicking a hotbar slot must select it")
	_check(TranslationServer.translate("game.title") == "Солёный свет", "Russian CSV translation is unavailable")
	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("game.title") == "Saltlight", "English CSV translation is unavailable")
	TranslationServer.set_locale("ru")

	_check(is_equal_approx(Clock.tide_amplitude(0), 1.4), "spring tide amplitude")
	_check(is_equal_approx(Clock.tide_amplitude(7), 0.6), "neap tide amplitude")
	Clock.day_index = 14
	Clock.set_time(12, 40)
	_check(Clock.tide_height() < -1.39, "Spring 15 story low tide")
	Clock.day_index = 0
	var high_minute := 0
	var low_minute := 0
	var high := -10.0
	var low := 10.0
	for at_minute in range(0, 1440, 10):
		var level := Clock.tide_height_at(0, at_minute)
		if level > high:
			high = level
			high_minute = at_minute
		if level < low:
			low = level
			low_minute = at_minute
	Clock.set_time(int(high_minute / 60), high_minute % 60)
	await tree.process_frame
	var first_shore_tile: CollisionShape2D = cape.get_node("TideShore/TideCollision").get_child(0)
	_check(not first_shore_tile.disabled, "high tide must block shore tile")
	var shore_cells: Array = cape.get_node("TideShore").get("_cells")
	_check(bool(shore_cells[0]["flooded"]) and bool(shore_cells[5 * 90]["flooded"]),
		"high tide must render the coast as water")
	Clock.set_time(int(low_minute / 60), low_minute % 60)
	await tree.process_frame
	_check(first_shore_tile.disabled, "low tide must unblock shore tile")
	_check(not bool(shore_cells[0]["flooded"]) and not bool(shore_cells[5 * 90]["flooded"]),
		"low tide must expose the walkable coast")
	_check(Weather.weather_for_day(0) == "clear" and Weather.weather_for_day(2) == "clear",
		"first three days must be clear")
	var station: Area2D = cape.get_node("LighthouseStation")
	_check(station.collision_layer == 8 and station.has_method("interact"),
		"keeper cannot interact with lighthouse door")
	_check(Lighthouse.refill() == 0 and not Lighthouse.light_lamp(),
		"empty reservoir must not light without fish oil")
	Inventory.add("fish_oil", 1)
	_check(Lighthouse.refill() == 1 and Inventory.count_of("fish_oil") == 0,
		"refilling must consume exactly one portion of fish oil")
	Inventory.add("fish_oil", 1)
	_check(Lighthouse.refill() == 0 and Inventory.count_of("fish_oil") == 1, "full reservoir must reject a second portion")
	Inventory.take("fish_oil", 1)
	Clock.set_time(19, 30)
	_check(Lighthouse.light_lamp() and Lighthouse.lamp_on and Lighthouse.base_power() > 0.0,
		"lighthouse must light after refilling")
	_check(not Lighthouse.light_lamp(), "already lit lamp must not light twice")
	var first_light := Lighthouse.resolve_night()
	_check(int(first_light["power"]) == 19 and Lighthouse.fuel_nights == 0.0 and not Lighthouse.lamp_on,
		"lit night must score and consume one reservoir")
	var dark_night := Lighthouse.resolve_night()
	_check(int(dark_night["power"]) == 0 and is_equal_approx(Lighthouse.fire_power, 9.5),
		"unlit night must count as zero in the seven-night Light average")
	var lamp := TowerObject.new()
	lamp.kind = "lamp"
	Weather.set_weather("storm")
	_check(is_equal_approx(lamp.hold_seconds(), 4.0), "storm must double the ignition hold")
	Weather.set_weather("clear")
	_check(is_equal_approx(lamp.hold_seconds(), 2.0), "the lamp lights after a 2 s hold")
	lamp.free()
	Lighthouse.reset()
	_check_calendar_rules()
	_check_shipping()
	_check_energy_and_skills(player)

	Game.set_flag("m1_roundtrip", true)
	Game.add_stat("m1_test_items", 3)
	Inventory.add("bread_rye", 3, 2)
	var garden_cell := Vector2i(0, 0)
	Farm.reset()
	Inventory.add("seed_turnip", 2)
	_check(Farm.till(garden_cell), "cannot till the starter garden")
	_check(Farm.plant(garden_cell, "seed_turnip"), "cannot plant a turnip")
	_check(Farm.water(garden_cell), "cannot water the starter garden")
	Inventory.select_hotbar(4)
	Economy.money = 731
	player.global_position = Vector2(612, 401)
	Clock.set_time(19, 40)
	Inventory.add("fish_oil", 1)
	_check(Lighthouse.refill() == 1 and Lighthouse.light_lamp(), "cannot prepare lit save")
	_check(Save.save_game(2), "save failed")
	var expected_game := Game.serialize().duplicate(true)
	var expected_clock := JSON.stringify(Clock.serialize())
	var expected_weather := JSON.stringify(Weather.serialize())
	var expected_inventory := Inventory.serialize().duplicate(true)
	var expected_farm := Farm.serialize().duplicate(true)
	var expected_lighthouse := Lighthouse.serialize().duplicate(true)
	Game.set_flag("m1_roundtrip", false)
	Economy.money = 1
	Clock.set_time(8, 0)
	Weather.set_weather("storm")
	Lighthouse.reset()
	_check(Save.load_game(2), "load failed")
	if JSON.stringify(Game.serialize()) != JSON.stringify(expected_game):
		print("Game before load: ", JSON.stringify(expected_game))
		print("Game after load: ", JSON.stringify(Game.serialize()))
	if Inventory.serialize() != expected_inventory:
		print("Inventory before load: ", JSON.stringify(expected_inventory))
		print("Inventory after load: ", JSON.stringify(Inventory.serialize()))
	_check(JSON.stringify(Game.serialize()) == JSON.stringify(expected_game),
		"game/player state changed after load")
	_check(JSON.stringify(Clock.serialize()) == expected_clock, "clock changed after load")
	_check(JSON.stringify(Weather.serialize()) == expected_weather, "weather changed after load")
	_check(Inventory.serialize() == expected_inventory, "inventory changed after load")
	_check(Inventory.selected_hotbar == 4, "selected hotbar slot changed after load")
	_check(Farm.serialize() == expected_farm, "garden changed after load")
	_check(Lighthouse.serialize() == expected_lighthouse, "lit lamp and fuel changed after load")
	_check(Inventory.count_of("bread_rye") == 3, "saved items were lost")
	_check(Economy.money == 731, "money changed after load")

	Game.set_flag("backup", true)
	_check(Save.save_game(2), "second save failed")
	var broken := FileAccess.open(Save._slot_path(2), FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	_check(Save.load_game(2) and not Game.flag("backup"), "backup recovery failed")
	_check(Router.goto_map("village", Vector2(1224, 488)), "cape to village failed")
	await tree.process_frame
	_check(tree.current_scene.get("map_id") == "village", "village scene did not load")
	_check(tree.current_scene.get_node("Terrain/To_cape") is RegionExit,
		"village return portal is missing")
	_check(tree.current_scene.get_node("Player").global_position == Vector2(1224, 488),
		"player arrived at wrong village entrance")
	_check(tree.current_scene.get_node_or_null("Terrain/Door_village_berg") is RegionExit, "the Bergs' shop needs a door")
	_check(Router.goto_map("village_berg"), "the shop interior must load")
	await tree.process_frame
	var berg_shop: ShopCounter = tree.current_scene.get_node("Terrain/Shop_shop_berg")
	_check(berg_shop.collision_layer == 8, "the Bergs' counter cannot be reached")
	var saved_minutes := Clock.minutes
	var was_paused := Clock.paused
	Clock.set_time(10, 0)
	var oil_before := Inventory.count_of("fish_oil")
	var money_before := Economy.money
	berg_shop.interact(tree.current_scene.get_node("Player"))
	var panel: ShopPanel = tree.current_scene.get_node_or_null("HUD/ShopPanel")
	_check(panel != null and Clock.paused, "the shop opens a panel and stops time")
	if panel:
		var oil_index := -1
		for index in panel._entries.size():
			if str(panel._entries[index].get("item", "")) == "fish_oil":
				oil_index = index
		panel._list.select(oil_index)
		_check(panel.buy_selected(1) == "ok", "buying oil at the Bergs failed")
		panel.close()
		await tree.process_frame
	_check(Inventory.count_of("fish_oil") == oil_before + 1 and Economy.money == money_before - 40,
		"buying oil must add one nightly portion and charge 40 crowns")
	_check(Clock.paused == was_paused, "closing the shop restores the clock")
	Clock.day_index = 2
	berg_shop.interact(tree.current_scene.get_node("Player"))
	_check(tree.current_scene.get_node_or_null("HUD/ShopPanel") == null,
		"the Bergs' shop must be closed on Wednesdays")
	Clock.minutes = saved_minutes
	Clock.day_index = 0
	_check(Router.goto_map("village", Vector2(15 * 16 + 8, 28 * 16 + 8)), "back out of the shop")
	await tree.process_frame
	var village_box: ShippingBox = tree.current_scene.get_node_or_null("Terrain/ShippingBox")
	_check(village_box != null and village_box.collision_layer == 8, "the village harbor needs a shipping box")
	if village_box:
		var bread_slot := -1
		for index in Inventory.HOTBAR:
			if Inventory.slots[index]["id"] == "bread_rye":
				bread_slot = index
		Inventory.select_hotbar(bread_slot)
		var bread_before := Inventory.count_of("bread_rye")
		village_box.interact(tree.current_scene.get_node("Player"))
		_check(bread_slot >= 0 and Inventory.count_of("bread_rye") == 0 and Economy.shipping.size() == 1,
			"the village box must take the selected stack")
		Economy.take_back_last()
		_check(Inventory.count_of("bread_rye") == bread_before and Economy.shipping.is_empty(),
			"a boxed stack can be taken back until the «Чайка» takes it")
	_check(Router.goto_map("moor", Vector2(568, 904)), "village to moor failed")
	await tree.process_frame
	_check(tree.current_scene.get("map_id") == "moor", "moor scene did not load")
	tree.current_scene.get_node("Terrain/To_bird_cliffs").interact(tree.current_scene.get_node("Player"))
	_check(Router.current_map == "moor", "cliffs must be gated before the festival")
	for region_id in ["birch", "seal_shore", "wreck_bay", "bird_cliffs", "lagoon"]:
		_check(Router.goto_map(region_id), "cannot route to " + region_id)
		await tree.process_frame
		_check(tree.current_scene.get("map_id") == region_id, "wrong region: " + region_id)
		_check(tree.current_scene.get_node("Terrain").width > 0, "region failed to build: " + region_id)
		if region_id == "seal_shore":
			tree.current_scene.get_node("Terrain/To_wreck_bay").interact(tree.current_scene.get_node("Player"))
			_check(Router.current_map == "seal_shore", "bay must open on Spring 5")
	Clock.set_time(1, 50)
	Weather.set_weather("clear")
	Economy.shipping.append({"id": "turnip", "count": 2, "quality": 0, "due": Clock.day_index})
	var money_before_night := Economy.money
	Clock.paused = false
	var previous_day := Clock.day_index
	Clock.advance(10)
	await tree.process_frame
	var morning_scene := tree.current_scene
	_check(Clock.day_index == previous_day + 1 and Clock.minutes == 360,
		"fainting must start next day at 06:00")
	_check(morning_scene.get("map_id") == "cape", "morning must return to cape")
	_check(is_equal_approx(morning_scene.get_node("Player").energy, 135.0),
		"fainting must restore half energy")
	_check(Save.has_save(2), "night must create a save")
	_check(morning_scene.get_node("HUD/MorningPanel").visible, "night report must be shown")
	_check(not night_reports.is_empty() and night_reports[-1]["steps"] == [
		"lighthouse", "weather_tides", "farm", "animals", "stations", "bodies", "peace", "sea", "mail", "sales", "friendship", "quests", "luck", "skills", "autosave", "report"],
		"night resolution must follow the order of spec 6.4")
	_check(not night_reports.is_empty() and str(night_reports[-1].get("faint_message", "")) in Night.FAINT_MESSAGES
		and morning_scene.get_node("HUD/MorningPanel/MorningText").text.contains(
			str(night_reports[-1].get("faint_message", "-"))),
		"fainting must show one of the spec's faint messages")
	_check(int(Lighthouse.last_report.get("power", 0)) > 0 and Lighthouse.fuel_nights == 0.0,
		"night resolution must record the lamp score and burn its fuel")
	_check(morning_scene.get_node("HUD/MorningPanel/MorningText").text.contains("Маяк: %d" % int(round(float(Lighthouse.last_report.get("power", -1))))),
		"morning report must show the lighthouse score")
	_check(morning_scene.get_node("HUD/MorningPanel/MorningText").text.contains("Выручка «Чайки»: 70 кр"),
		"the morning report must show the shipping income")
	_check(Economy.money == money_before_night + 70 - mini(int(floor(float(money_before_night + 70) * 0.1)), 1000),
		"shipping income is paid before the faint penalty")
	_check(morning_scene.get_node_or_null("ShippingBox") is ShippingBox, "the cape pier needs a shipping box")
	_check(int(Farm.get_tile(garden_cell)["days"]) == 1, "watered crop did not grow overnight")
	for day_offset in 3:
		Farm.water(garden_cell)
		Clock.start_next_day()
		Farm.advance_day()
	_check(bool(Farm.get_tile(garden_cell)["ready"]), "turnip did not ripen after four watered nights")
	var farming_xp := int(Skills.xp["farming"])
	_check(Farm.harvest(garden_cell) and Inventory.count_of("turnip") == 1,
		"ripe turnip was not added to inventory")
	_check(int(Skills.xp["farming"]) == farming_xp + 4, "harvest gives 3 + price/20 farming XP")

	for file_path in Save._candidate_paths(2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save._slot_path(2) + ".tmp"))
	Save.save_root = "user://saves"
	Save.current_slot = 0
	print("M1 integration: %d failure(s)" % failures.size())
	tree.quit(1 if not failures.is_empty() else 0)
