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


func _run() -> void:
	var tree := get_tree()
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
	_check(not Lighthouse.refill() and not Lighthouse.light_lamp(),
		"empty reservoir must not light without fish oil")
	Inventory.add("fish_oil", 1)
	_check(Lighthouse.refill() and Inventory.count_of("fish_oil") == 0,
		"refilling must consume exactly one portion of fish oil")
	_check(not Lighthouse.refill(), "full reservoir must reject a second portion")
	Clock.set_time(19, 30)
	_check(Lighthouse.light_lamp() and Lighthouse.lamp_on and Lighthouse.current_power > 0.0,
		"lighthouse must light after refilling")
	_check(not Lighthouse.light_lamp(), "already lit lamp must not light twice")
	var first_light := Lighthouse.resolve_night()
	_check(int(first_light["power"]) == 35 and Lighthouse.fuel == 0.0 and not Lighthouse.lamp_on,
		"lit night must score and consume one reservoir")
	var dark_night := Lighthouse.resolve_night()
	_check(int(dark_night["power"]) == 0 and is_equal_approx(Lighthouse.fire_power, 17.5),
		"unlit night must count as zero in the seven-night Light average")
	Weather.set_weather("storm")
	_check(is_equal_approx(float(station.call("hold_seconds")), 4.0), "storm must double the ignition hold")
	Weather.set_weather("clear")
	Lighthouse.reset()

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
	_check(Lighthouse.refill() and Lighthouse.light_lamp(), "cannot prepare lit save")
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
	var fuel_shop: Area2D = tree.current_scene.get_node("Terrain/FuelShop")
	_check(fuel_shop.collision_layer == 8, "the village oil counter cannot be reached")
	var oil_before := Inventory.count_of("fish_oil")
	var money_before := Economy.money
	fuel_shop.call("interact", tree.current_scene.get_node("Player"))
	_check(Inventory.count_of("fish_oil") == oil_before + 1 and Economy.money == money_before - 40,
		"buying oil must add one nightly portion and charge 40 crowns")
	Clock.day_index = 2
	fuel_shop.call("interact", tree.current_scene.get_node("Player"))
	_check(Inventory.count_of("fish_oil") == oil_before + 1 and Economy.money == money_before - 40,
		"the Bergs' shop must be closed on Wednesdays")
	Clock.day_index = 0
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
	_check(int(Lighthouse.last_report.get("power", 0)) == 35 and Lighthouse.fuel == 0.0,
		"night resolution must record the lamp score and burn its fuel")
	_check(morning_scene.get_node("HUD/MorningPanel/MorningText").text.contains("Маяк: 35"),
		"morning report must show the lighthouse score")
	_check(int(Farm.get_tile(garden_cell)["days"]) == 1, "watered crop did not grow overnight")
	for day_offset in 3:
		Farm.water(garden_cell)
		Clock.start_next_day()
		Farm.advance_day()
	_check(bool(Farm.get_tile(garden_cell)["ready"]), "turnip did not ripen after four watered nights")
	_check(Farm.harvest(garden_cell) and Inventory.count_of("turnip") == 1,
		"ripe turnip was not added to inventory")

	for file_path in Save._candidate_paths(2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save._slot_path(2) + ".tmp"))
	Save.save_root = "user://saves"
	Save.current_slot = 0
	print("M1 integration: %d failure(s)" % failures.size())
	tree.quit(1 if not failures.is_empty() else 0)
