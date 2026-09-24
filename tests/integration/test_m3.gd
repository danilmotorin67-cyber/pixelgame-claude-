extends Node

# Run with: godot --headless --path . res://tests/integration/test_m3.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh(day: int = 0) -> void:
	Game.reset()
	Game.world_seed = 42
	Clock.reset()
	Clock.day_index = day
	Weather.reset()
	Weather.set_weather("clear")
	Inventory.reset()
	Lighthouse.reset()
	Sea.reset()
	Skills.reset()
	Knowledge.reset()
	Mail.reset()
	Economy.reset()
	Graveyard.reset()
	Quests.reset()


func _light(at_hour: int, at_minute: int = 0) -> void:
	Clock.set_time(at_hour, at_minute)
	Lighthouse.light_lamp()


func _check_components() -> void:
	_fresh()
	Inventory.add("fish_oil", 2)
	_check(Lighthouse.refill() == 1 and Inventory.count_of("fish_oil") == 1, "the starting reservoir holds one unit")
	var parts := Lighthouse.components()
	_check(parts == {"lens": 5, "lamp": 5, "fuel": 3, "mechanism": 0, "clean": 4, "tower": 1, "signal": 1},
		"starting lighthouse: mirror 5, wick 5, raw oil 3, unwound weights, dirty broken glass 4, gallery 1, bell 1")
	_check(Lighthouse.wind() and Lighthouse.components()["mechanism"] == 5 and not Lighthouse.wind(),
		"the weights are wound once a night")
	_check(Lighthouse.base_power() == 24.0, "24 is the best a new keeper can do")
	_check(not Lighthouse.clean_glass(), "no rag, no cleaning")
	Lighthouse.cleanliness = 1.0
	Inventory.add("rag", 2)
	_check(Lighthouse.clean_glass() and Lighthouse.cleanliness == 4.0, "broken panes keep the glass at 4 or less")
	Game.set_flag("lantern_glass_repaired")
	_check(Lighthouse.clean_glass() and Lighthouse.cleanliness == 10.0 and Inventory.count_of("rag") == 0,
		"repaired panes clean up to 10 with one rag")
	_light(19, 30)
	var night := Lighthouse.resolve_night(22 * 60)
	_check(int(night["power"]) == 30 and bool(night["on_time"]), "a clean, wound, on-time night scores 30")
	_check(Lighthouse.cleanliness == 9.0 and Knowledge.sea_pts == 1 and int(Skills.xp["keeping"]) == 10,
		"each night dirties the glass by 1; an on-time fire gives 1 sea note and 10 keeping XP")
	Clock.day_index = 1
	_check(Lighthouse.components()["mechanism"] == 0, "tomorrow the weights need winding again")

	_fresh()
	Lighthouse.mechanism = "precise_clock"
	Lighthouse.wind()
	Clock.day_index = 1
	_check(Lighthouse.wound() and not Lighthouse.wind(), "the precise clock runs two nights")
	Clock.day_index = 2
	_check(not Lighthouse.wound(), "and then stops")
	Lighthouse.mechanism = "auto"
	_check(Lighthouse.wound() and Lighthouse.components()["mechanism"] == 10, "the automatic mechanism never needs winding")


func _check_fuel() -> void:
	_fresh()
	Lighthouse.reservoir_level = 1
	Inventory.add("kerosene", 5)
	_check(Lighthouse.refill("kerosene") == 3 and Lighthouse.fuel_nights == 6.0, "3 cans of kerosene fill a 3-unit tank for 6 nights")
	_check(Lighthouse.components()["fuel"] == 10, "kerosene is worth 10 points")
	Inventory.add("whale_oil", 1)
	_check(Lighthouse.refill("whale_oil") == 1 and Lighthouse.fuel_type == "whale_oil"
		and is_equal_approx(float(Lighthouse.barrel.get("kerosene", 0.0)), 6.0),
		"another fuel drains the old one into the barrel without loss")
	_check(Lighthouse.components()["fuel"] == 6, "whale oil is worth 6")
	_light(19, 30)
	Lighthouse.resolve_night()
	_check(Lighthouse.fuel_nights == 0.0 and Lighthouse.fuel_type == "", "one unit of whale oil burns one night")
	_check(not Lighthouse.light_lamp(), "no fuel, no fire")


func _check_modifiers() -> void:
	_fresh()
	Inventory.add("fish_oil", 3)
	Lighthouse.refill()
	var sunset := Lighthouse.sunset_minutes()
	_light((sunset + 90) / 60, (sunset + 90) % 60)
	var late := Lighthouse.resolve_night(23 * 60)
	_check(is_equal_approx(float(late["power"]), 19.0 * 0.8), "lighting 60-120 minutes after sunset: x0.8")
	Lighthouse.refill()
	_light(19, 30)
	var watched := Lighthouse.resolve_night(23 * 60, true)
	_check(int(watched["power"]) == 19 - 1 + 5, "sleeping in the watch room adds 5")
	Lighthouse.refill()
	Weather.set_weather("fog")
	_light(19, 30)
	var silent := Lighthouse.resolve_night(22 * 60)
	_check(is_equal_approx(float(silent["power"]), (5 + 5 + 3 + 0 + 2 + 1 + 0) * 0.6),
		"fog without the bell: x0.6 and no signal points")
	_fresh()
	Inventory.add("fish_oil", 1)
	Lighthouse.refill()
	Weather.set_weather("fog")
	_light(19, 30)
	for hour in [19, 20, 21]:
		Clock.set_time(hour, 40)
		Lighthouse.ring_bell()
	var rung := Lighthouse.resolve_night(22 * 60)
	_check(is_equal_approx(float(rung["power"]), 19.0 * 0.68), "a bell rung every hour until bed: +1 and x(0.6 + 0.08)")

	_fresh()
	Weather.set_weather("storm")
	Lighthouse.cleanliness = 4.0
	Lighthouse.resolve_night()
	_check(Lighthouse.cleanliness == 0.0, "a storm dirties the glass by 4")
	_fresh()
	Weather.hmar_night = true
	Lighthouse.salt_shroud = true
	Lighthouse.resolve_night()
	_check(Lighthouse.cleanliness == 3.0, "a Hmar night dirties by 2, halved by the salt shroud")
	_fresh()
	var mercy := Sea.mercy
	Lighthouse.resolve_night()
	_check(Sea.mercy == mercy - 2.0, "a night without fire costs 2 mercy")


func _check_breakdowns() -> void:
	var stops := 0
	var watch_stops := 0
	var cracks := 0
	var strikes := 0
	for seed_value in 400:
		for watch in [false, true]:
			_fresh(seed_value)
			Game.world_seed = seed_value
			Inventory.add("fish_oil", 1)
			Lighthouse.refill()
			Lighthouse.wind()
			_light(19, 30)
			var night := Lighthouse.resolve_night(23 * 60, watch)
			if "mechanism_stopped" in night["events"]:
				if watch:
					watch_stops += 1
				else:
					stops += 1
					_check(int(night["parts"]["mechanism"]) == 0, "a stopped mechanism scores nothing")
		_fresh(seed_value)
		Game.world_seed = seed_value
		Weather.set_weather("storm")
		var night := Lighthouse.resolve_night()
		if "glass_cracked" in night["events"]:
			cracks += 1
		for event in night["events"]:
			if str(event).begins_with("lightning"):
				strikes += 1
	_check(stops > 16 and stops < 50, "the weights stop in about 8%% of nights (%d/400)" % stops)
	_check(watch_stops < stops, "sleeping in the watch room prevents half the stops (%d vs %d)" % [watch_stops, stops])
	_check(cracks > 6 and cracks < 40, "storms crack the glass about 5%% of the time (%d/400)" % cracks)
	_check(strikes > 20 and strikes < 70, "lightning strikes about 10%% of storm nights without a rod (%d/400)" % strikes)


func _count_type(ships: Array, type: String) -> int:
	var n := 0
	for ship in ships:
		if ship["type"] == type:
			n += 1
	return n


func _check_ship_schedule() -> void:
	_fresh()
	var boats := 0
	for index in 28:
		var ships := ShipTraffic.ships_for_night(index)
		_check(JSON.stringify(ships) == JSON.stringify(ShipTraffic.ships_for_night(index)), "the schedule is deterministic")
		boats += _count_type(ships, "fishing_boat")
		_check(_count_type(ships, "whaler") == 0, "no whalers in spring")
		_check(_count_type(ships, "queen") == (1 if index == 12 else 0), "the Queen passes only on the night to the 14th")
	_check(boats >= 18 and boats <= 28, "fishing boats almost every night (%d/28)" % boats)
	for week in 8:
		var brigs := 0
		var colliers := 0
		var whalers := 0
		for night in 7:
			var ships := ShipTraffic.ships_for_night(28 + week * 7 + night)
			brigs += _count_type(ships, "merchant_brig")
			colliers += _count_type(ships, "collier")
			whalers += _count_type(ships, "whaler")
		_check(brigs >= 2 and brigs <= 3, "2-3 merchant brigs a week (%d)" % brigs)
		_check(colliers == 1 and whalers == 1, "one collier and one summer whaler a week")
	var calendar := ShipTraffic.calendar(5)
	_check(calendar.size() == 7 and int(calendar[0]["day_index"]) == 5, "the pilot calendar covers seven nights")
	_check(is_equal_approx(ShipTraffic.wreck_chance("clear", false, true, 50.0, false), 0.01), "P = 1% x 0.5 x 2")
	_check(is_equal_approx(ShipTraffic.wreck_chance("fog", false, true, 0.0, true), 0.10 * 2.0 * 1.2), "new moon x1.2")
	_check(is_equal_approx(ShipTraffic.wreck_chance("storm", false, false, 80.0, false), 0.55), "dark night: base x3 + 10%")
	_check(is_equal_approx(ShipTraffic.base_chance("clear", true), 0.25), "a Hmar night starts at 25%")


func _check_wrecks() -> void:
	var found := false
	for seed_value in 60:
		_fresh(seed_value * 7 % 28)
		Game.world_seed = seed_value
		Weather.set_weather("storm")
		var mercy := Sea.mercy
		var night := Lighthouse.resolve_night()
		var wrecked: Array = []
		for ship in night["ships"]:
			if ship["wrecked"]:
				wrecked.append(ship)
		if wrecked.is_empty():
			continue
		found = true
		var bodies := 0
		var crates := 0
		var allowed := 0
		for ship in wrecked:
			bodies += int(ship["bodies"])
			crates += int(ship["crates"])
			allowed += ceili(float(ship["crates"]) / 3.0)
		_check(is_equal_approx(Sea.mercy, mercy - 2.0 - 3.0 * wrecked.size()), "each wreck costs 3 mercy")
		_check(Graveyard.incoming.size() == bodies and Lighthouse.wrecks.size() == wrecked.size(),
			"the drowned wait to wash ashore")
		for body in Graveyard.incoming:
			_check(int(body["arrive"]) >= Clock.day_index + 1 and int(body["arrive"]) <= Clock.day_index + 3,
				"bodies arrive within 1-3 days")
		_check(Lighthouse.pending_shore.size() == crates and int(Game.counters["crates_allowed"]) == allowed,
			"crates wash up and a third belongs to the keeper")
		_check(Lighthouse.week_wrecked, "a wreck burns the weekly bonus")
		Sea.generate_gifts(Clock.day_index + 1, true)
		var on_shore := 0
		for beach in Sea.gifts:
			for gift in Sea.gifts[beach]:
				if str(gift["item"]).begins_with("cargo_"):
					on_shore += 1
		_check(on_shore == crates and Lighthouse.pending_shore.is_empty(), "crates lie on the beaches next morning")
		Inventory.reset()
		var crate_id := str(Data.by_id("ships", str(wrecked[0]["type"]))["crate"])
		Inventory.add(crate_id, allowed + 1)
		Inventory.select_hotbar(0)
		for n in allowed:
			_check(not Lighthouse.open_crate(0).is_empty(), "a crate holds goods")
		_check(Game.honor == 0, "opening your third is honest")
		var mercy_before := Sea.mercy
		Lighthouse.open_crate(0)
		_check(Game.honor == -2 and is_equal_approx(Sea.mercy, mercy_before - 1.0), "keeping more than a third: -2 honour, -1 mercy")
		Inventory.add(crate_id, 2)
		_check(Lighthouse.hand_in_crates() == 2 and Game.honor == 4, "handing crates to the directorate: +3 honour each")
		break
	_check(found, "a dark stormy night must wreck something within 60 worlds")

	var queen_wrecks := 0
	var other_wrecks := 0
	for seed_value in 300:
		_fresh(12)
		Game.world_seed = seed_value
		Weather.set_weather("storm")
		for ship in Lighthouse.resolve_night()["ships"]:
			if ship["type"] == "queen" and ship["wrecked"]:
				queen_wrecks += 1
			elif ship["type"] == "fishing_boat" and ship["wrecked"]:
				other_wrecks += 1
	_check(queen_wrecks < other_wrecks, "the Queen sinks only on two failed checks (%d vs %d)" % [queen_wrecks, other_wrecks])

	_fresh(3)
	Weather.set_weather("fog")
	Inventory.add("kerosene", 1)
	Lighthouse.refill()
	Lighthouse.wind()
	_light(19, 30)
	for hour in [19, 20, 21]:
		Clock.set_time(hour, 30)
		Lighthouse.ring_bell()
	var foggy := Lighthouse.resolve_night(22 * 60)
	var safe := 0
	for ship in foggy["ships"]:
		if bool(ship.get("safe_bad_weather", false)):
			safe += 1
	_check(Lighthouse.week_bonus == 20 * safe and Knowledge.sea_pts >= safe, "safe passage in fog: +20 kr and +1 sea note per ship")


func _check_salary_and_mail() -> void:
	_fresh(7)
	for n in 7:
		Lighthouse.week_powers.append(30.0)
	Lighthouse.week_bonus = 40
	var mercy := Sea.mercy
	Lighthouse.night_mail(6)
	_check(Mail.letters.size() == 1 and int(Mail.letters[0]["money"]) == 340,
		"Monday salary: 150 + 5 x 30 + 40 bad-weather bonus")
	_check(Sea.mercy == mercy + 1.0, "a week with fire every night: +1 mercy")
	_check(Lighthouse.week_powers.is_empty() and Lighthouse.week_bonus == 0, "the weekly ledger starts over")
	var money := Economy.money
	_check(Mail.read(Mail.letters[0]) and Economy.money == money + 340 and Mail.unread() == 0,
		"reading the letter pays the salary once")
	_check(Mail.text_of(Mail.letters[0]).contains("340"), "the letter names the sum")
	Mail.read(Mail.letters[0])
	_check(Economy.money == money + 340, "a letter pays only once")
	Lighthouse.week_powers = [50.0, 0.0]
	Lighthouse.week_bonus = 60
	Lighthouse.week_wrecked = true
	Lighthouse.wrecks.append({"day": 13, "ship": "ship.hope.name", "type": "merchant_brig", "bodies": 4})
	Clock.day_index = 14
	Lighthouse.night_mail(13)
	_check(Mail.letters.size() == 3 and str(Mail.letters[1]["text"]) == "mail.wreck"
		and int(Mail.letters[2]["money"]) == 150 + 125, "a wreck: the directorate writes and the bonus burns")
	_check(Mail.text_of(Mail.letters[1]).contains(Loc.t("ship.hope.name")), "the wreck letter names the ship")
	var saved := JSON.stringify(Mail.serialize())
	Mail.deserialize(JSON.parse_string(saved))
	_check(JSON.stringify(Mail.serialize()) == saved, "mail survives a save")


func _check_inspections() -> void:
	_fresh(27)
	Lighthouse.nightly_powers.assign([30.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0])
	Lighthouse.fire_power = 30.0
	var first := Lighthouse.inspect()
	_check(first["grade"] == "satisfactory" and int(Mail.letters[-1]["money"]) == 500,
		"first inspection: 25+ over the last seven nights is satisfactory, 500 kr")
	_fresh(27)
	Lighthouse.fire_power = 22.0
	var failed := Lighthouse.inspect()
	_check(failed["grade"] == "unsatisfactory" and int(failed["retake_day"]) == 28 + 6,
		"failing the first inspection sets a retake on Summer 7")
	Lighthouse.fire_power = 26.0
	Clock.day_index = 34
	Events.hour_changed.emit(10)
	_check(Lighthouse.inspections == 1 and Lighthouse.retake_day == -1, "the retake happens at 10:00 on its day")
	Lighthouse.season_powers.assign([65.0, 65.0])
	Clock.day_index = 55
	var excellent := Lighthouse.inspect()
	_check(excellent["grade"] == "excellent" and int(excellent["money"]) == 3000 and Knowledge.sea_pts == 10
		and Game.flag("blueprint_lightning_rod"), "excellent: 3000 kr, 10 notes and the lightning rod blueprint first")
	_check(Lighthouse.season_powers.is_empty(), "each season is judged on its own nights")
	Lighthouse.season_powers.assign([85.0])
	Clock.day_index = 83
	var exemplary := Lighthouse.inspect()
	Mail.read(Mail.letters[-1])
	_check(exemplary["grade"] == "exemplary" and Inventory.count_of("medal_directorate") == 1,
		"exemplary: the directorate medal")
	Lighthouse.season_powers.assign([45.0])
	Lighthouse.year_powers.assign([72.0, 71.0])
	Clock.day_index = 111
	_check(Lighthouse.inspect()["grade"] == "good" and Game.flag("keeper_of_the_year_1"),
		"Winter 28: a year averaging 70+ makes the keeper of the year")

	_fresh(5)
	_check(Lighthouse.write_log() and not Lighthouse.write_log() and Knowledge.sea_pts == 1
		and int(Skills.xp["keeping"]) == 5, "one log entry a day: +1 sea note, +5 keeping XP")
	Clock.day_index = 6
	Lighthouse.write_log()
	_check(Knowledge.sea_pts == 4, "the Sunday summary adds two more notes")


func _check_knowledge() -> void:
	_fresh()
	_check(Knowledge.blocked_reason("M2") == "points", "the renderer node costs 3 sea notes")
	_check(Knowledge.blocked_reason("M3") == "requires", "the settling tank needs the renderer first")
	Knowledge.add_points("sea", 4)
	_check(Knowledge.unlock_node("M2") and Knowledge.sea_pts == 1 and Knowledge.has_unlock("station:renderer"),
		"opening M2 spends 3 notes and unlocks the renderer")
	_check(Knowledge.blocked_reason("M5") == "story", "tower repairs wait for Q1.8")
	Game.set_flag("q1_8")
	_check(Knowledge.unlock_node("M5"), "M5 is free after Q1.8")
	Inventory.add("fish_cod", 2)
	Inventory.add("turnip", 1)
	_check(Knowledge.study("fish_cod") == 1 and Knowledge.study("fish_cod") == 0 and Knowledge.sea_pts == 2,
		"studying the first cod teaches a sea note, once")
	_check(Knowledge.study("turnip") == 1 and Knowledge.land_pts == 1, "a crop teaches a land note")
	_check(Knowledge.study("tool_hoe") == 0, "tools teach nothing")


func _check_world_objects() -> void:
	_fresh()
	Mail.send("mail.salary", [200, 10, 0], 200)
	Router.current_map = "cape"
	Router.spawn = Vector2(600, 360)
	Game.player_state = {}
	var cape: Node2D = load("res://scenes/world/cape.tscn").instantiate()
	get_tree().root.add_child(cape)
	get_tree().current_scene = cape
	await get_tree().process_frame
	var mailbox: Mailbox = cape.get_node_or_null("Mailbox")
	_check(mailbox != null and mailbox.collision_layer == 8, "the cape house has a mailbox")
	var money := Economy.money
	mailbox.interact(cape.get_node("Player"))
	var panel: MailPanel = cape.get_node_or_null("HUD/MailPanel")
	_check(panel != null and Clock.paused and Economy.money == money + 200, "opening the mailbox reads the newest letter")
	if panel:
		panel.close()
	cape.queue_free()
	await get_tree().process_frame
	Router.current_map = "village"
	var village: Node2D = load("res://scenes/world/island_region.tscn").instantiate()
	get_tree().root.add_child(village)
	get_tree().current_scene = village
	await get_tree().process_frame
	var desk: DirectorateDesk = village.get_node_or_null("Terrain/Directorate")
	Clock.set_time(10, 0)
	Inventory.add("cargo_fishing", 2)
	if desk:
		desk.interact(village.get_node("Player"))
		var desk_panel: InfoPanel = village.get_node_or_null("HUD/InfoPanel")
		if desk_panel:
			desk_panel.press("Сдать ящики")
			desk_panel.close()
	_check(desk != null and Game.honor == 6 and Inventory.count_of("cargo_fishing") == 0,
		"the directorate takes wreck crates for honour")
	village.queue_free()
	await get_tree().process_frame


func _find_station(id: String) -> Dictionary:
	for obj in Crafting.placed.get("cape", []):
		if str(obj["id"]) == id:
			return obj
	return {}


func _select(id: String) -> void:
	for index in Inventory.capacity:
		if Inventory.slots[index]["id"] == id:
			Inventory.select_hotbar(index)


func _check_fuel_chain() -> void:
	_fresh()
	Crafting.reset()
	Inventory.add("fish_cod", 27)
	_check(Crafting.make("cut_fillet", 30) == "ok" and Inventory.count_of("fillet") == 20
		and Inventory.count_of("fish_guts") == 20 and Inventory.count_of("fish_cod") == 7,
		"the cutting table works in batches of up to 20: fish -> fillet + guts")
	_check(Crafting.make("cut_bait") == "ok" and Inventory.count_of("bait") == 5, "one fish -> 5 bait")

	_check(Knowledge.blocked_reason("M2") == "points", "the renderer needs sea notes")
	Knowledge.add_points("sea", 8)
	_check(Knowledge.unlock_node("M2") and Inventory.count_of("renderer") == 1, "M2 hands over a renderer")
	_check(Knowledge.unlock_node("M3") and Inventory.count_of("settling_tank") == 1, "M3 hands over a settling tank")
	_select("renderer")
	_check(Crafting.place_selected("cape", Vector2(760, 470)), "the renderer is placed on the cape")
	_select("settling_tank")
	_check(Crafting.place_selected("cape", Vector2(800, 470)), "the settling tank is placed on the cape")
	var renderer := _find_station("renderer")
	var tank := _find_station("settling_tank")
	Clock.set_time(8, 0)
	_check(Crafting.start(renderer, "render_oil") == "fuel", "the renderer burns peat")
	Inventory.add("peat", 2)
	_check(Crafting.start(renderer, "render_oil") == "ok" and Inventory.count_of("peat") == 1
		and Inventory.count_of("fish_guts") == 15, "5 guts and 1 peat go in")
	Clock.set_time(11, 50)
	_check(Crafting.collect(renderer) == 0, "rendering takes 4 hours")
	Clock.set_time(12, 0)
	_check(Crafting.collect(renderer) == 1 and Inventory.count_of("fish_oil") == 1, "5 guts make 1 fish oil")
	Inventory.add("fish_oil", 1)
	_check(Crafting.start(tank, "settle_whale_oil") == "ok" and Inventory.count_of("fish_oil") == 0, "2 fish oil settle")
	Clock.day_index = 1
	_check(Crafting.collect(tank) == 1 and Inventory.count_of("whale_oil") == 1, "a day later: 1 whale oil")
	_check(Lighthouse.refill() == 1 and Lighthouse.components()["fuel"] == 6, "whale oil in the reservoir: 6 points")

	Clock.day_index = 0
	var bog := Vector2i(15, 45)
	var got := Farm.dig_peat("moor", bog)
	_check(got >= 1 and got <= 2 and Farm.dig_peat("moor", bog) == 0, "a bog tile gives 1-2 peat once a season")
	_check(Farm.dig_peat("moor", Vector2i(40, 10)) == 0 and Farm.dig_peat("cape", bog) == 0, "peat only in the moor bog")
	Clock.day_index = 28
	_check(Farm.dig_peat("moor", bog) >= 1, "the bog recovers next season")
	Clock.day_index = 0
	Clock.set_time(10, 0)
	var kerosene := {}
	for entry in Economy.shop_stock("shop_grim"):
		if entry["item"] == "kerosene":
			kerosene = entry
	Economy.money = 500
	_check(Economy.buy("shop_grim", kerosene) == "ok" and Economy.money == 380, "Grim sells kerosene at 120")
	Clock.day_index = 6
	_check(Economy.shop_closed_reason("shop_grim") == "day", "the trading house is closed on Sundays")
	Crafting.reset()
	Farm.reset()


func _object(scene: Node, kind: String) -> TowerObject:
	for child in scene.get_node("Terrain").get_children():
		if child is TowerObject and child.kind == kind:
			return child
	return null


func _go(map_id: String, at: Vector2 = Vector2.ZERO) -> Node:
	Router.goto_map(map_id, at)
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene


func _check_tower() -> void:
	_fresh(5)
	Save.save_root = "user://saltlight_m3_test_saves"
	Save.current_slot = 2
	Crafting.reset()
	Router.current_map = "cape"
	Router.spawn = Vector2(724, 290)
	Game.player_state = {}
	get_tree().change_scene_to_file("res://scenes/world/cape.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var cape := get_tree().current_scene
	Clock.paused = false
	Clock.set_time(18, 0)
	cape.get_node("LighthouseStation").interact(cape.get_node("Player"))
	await get_tree().process_frame
	await get_tree().process_frame
	var hall := get_tree().current_scene
	_check(Router.current_map == "lh_1" and _object(hall, "fortuna") != null, "the tower door leads to Fortuna's hall")
	Clock.paused = false
	_object(hall, "fortuna").interact(hall.get_node("Player"))
	var panel: InfoPanel = hall.get_node_or_null("HUD/InfoPanel")
	_check(panel != null and panel._body.text == Loc.t("fortuna.first"), "Fortuna's first words")
	panel.close()
	_check(Dialogue.fortuna_talk() == Loc.t("fortuna.again"), "Fortuna talks once a day")
	Clock.day_index = 6
	_check(Dialogue.fortuna_talk().length() > 10 and Dialogue.hint_of_the_day(6) != Dialogue.hint_of_the_day(7),
		"then a hint of the day")
	Clock.day_index = 5
	var floors := [hall]
	for n in 3:
		_object(get_tree().current_scene, "stairs_up").interact(get_tree().current_scene.get_node("Player"))
		await get_tree().process_frame
		await get_tree().process_frame
		floors.append(get_tree().current_scene)
	_check(Router.current_map == "lh_4", "the spiral stairs climb to the lantern room")
	var lantern := get_tree().current_scene
	var player: Player = lantern.get_node("Player")
	_check(lantern.get_node_or_null("HUD/RitualChecklist") != null, "the ritual checklist shows in the lantern room")
	_check(RitualChecklist.lines()[0].begins_with("□"), "nothing is done yet")
	Inventory.add("fish_oil", 1)
	Inventory.add("rag", 1)
	Clock.paused = false
	Clock.set_time(19, 30)
	var lamp := _object(lantern, "lamp")
	player.global_position = lamp.global_position + Vector2(0, 12)
	lamp.interact(player)
	_check(Lighthouse.fuel_nights == 1.0, "the lamp takes fuel from the backpack")
	Input.action_press("interact")
	lamp.interact(player)
	for frame in 2000:
		await get_tree().process_frame
		if Lighthouse.lamp_on:
			break
	Input.action_release("interact")
	_check(Lighthouse.lamp_on, "holding E lights the lamp")
	var mechanism := _object(lantern, "mechanism")
	player.global_position = mechanism.global_position + Vector2(0, 12)
	var energy := player.energy
	mechanism.interact(player)
	for step in 40:
		mechanism.add_rotation(TAU / 12.0)
	_check(Lighthouse.wound() and is_equal_approx(player.energy, energy - 3.0), "three circles wind the weights for 3 energy")
	var glass := _object(lantern, "glass")
	Lighthouse.cleanliness = 1.0
	player.global_position = glass.global_position + Vector2(0, 12)
	glass.interact(player)
	_check(Lighthouse.cleanliness == 4.0 and is_equal_approx(player.energy, energy - 8.0), "wiping the glass costs 5 energy and a rag")
	_check(TowerObject.spyglass_text().begins_with("Море"), "no spyglass, no view")
	Inventory.add("spyglass", 1)
	_check(TowerObject.spyglass_text().contains("Завтра"), "at sunset the spyglass shows tomorrow's weather")
	_check(TowerObject.calendar_text().split("\n").size() == 7, "the pilot calendar lists seven nights")
	_check(TowerObject.barometer_text().split("\n").size() == 8, "the barometer reads a week ahead")

	_object(lantern, "stairs_down").interact(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var watch := get_tree().current_scene
	_check(Router.current_map == "lh_3", "down to the watch room")
	var reports: Array = []
	var catcher := func(report: Dictionary) -> void: reports.append(report)
	Events.night_resolved.connect(catcher)
	Clock.set_time(22, 0)
	_object(watch, "bunk").interact(watch.get_node("Player"))
	await get_tree().process_frame
	Events.night_resolved.disconnect(catcher)
	_check(not reports.is_empty() and Router.current_map == "lh_3" and Clock.day_index == 6,
		"sleeping in the bunk wakes the keeper in the watch room")
	if not reports.is_empty():
		var parts: Dictionary = reports[0]["lighthouse"]["parts"]
		var total := 0
		for key in parts:
			total += int(parts[key])
		_check(is_equal_approx(float(reports[0]["lighthouse"]["power"]), float(total) + 5.0),
			"the watch-room bunk adds 5 to the night")
		_check("q1_8_tower" in reports[0]["quests_started"] and Game.flag("q1_8"), "Q1.8 starts on Spring 6")
	_check(is_equal_approx(float(Game.player_state.get("energy", 0.0)), Game.max_energy() * 0.9)
		or is_equal_approx(watch.get_node("Player").energy, Game.max_energy() * 0.9),
		"without the comfy bunk the watch room restores 90%")
	_check(Lighthouse.repair("stairs") == "locked", "repairs need node M5")
	_check(Knowledge.unlock_node("M5"), "M5 opens for free once Q1.8 has begun")
	Inventory.add("boards", 10)
	Inventory.add("glass", 3)
	_check(Lighthouse.repair("stairs") == "ok" and Lighthouse.tower_points() == 3, "10 boards mend the stairs: +2 tower")
	_check(Lighthouse.repair("glass") == "ok" and Lighthouse.glass_cap() == 10.0, "3 panes lift the glass limit to 10")
	_check(Lighthouse.repair("masonry") == "materials", "masonry needs 20 stone")
	for file_path in Save._candidate_paths(2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	Save.save_root = "user://saves"
	Save.current_slot = 0
	Clock.paused = true


func _simulate_week(diligent: bool) -> Array:
	_fresh(0)
	Weather.start_day(0)
	Crafting.reset()
	Farm.reset()
	Save.save_root = "user://saltlight_m3_test_saves"
	Save.current_slot = 2
	Router.current_map = "cape"
	Router.spawn = Vector2(600, 360)
	Game.player_state = {}
	get_tree().change_scene_to_file("res://scenes/world/cape.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var reports: Array = []
	var catcher := func(report: Dictionary) -> void: reports.append(report)
	Events.night_resolved.connect(catcher)
	for night in 7:
		Clock.paused = false
		if diligent:
			Inventory.add("fish_oil", 1)
			Inventory.add("rag", 1)
			Lighthouse.refill()
			Lighthouse.wind()
			if Lighthouse.cleanliness < 6.0:
				Lighthouse.clean_glass()
			Lighthouse.write_log()
			var sunset := Lighthouse.sunset_minutes()
			Clock.set_time(sunset / 60, sunset % 60)
			Lighthouse.light_lamp()
			for hour in range(sunset / 60, 23):
				Clock.set_time(hour, 30)
				Lighthouse.ring_bell()
		Clock.set_time(23, 0)
		Night.end_day(false, diligent and night % 2 == 1)
		await get_tree().process_frame
		if Router.current_map != "cape":
			Router.goto_map("cape", Vector2(600, 360))
			await get_tree().process_frame
			await get_tree().process_frame
	Events.night_resolved.disconnect(catcher)
	for file_path in Save._candidate_paths(2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	Save.save_root = "user://saves"
	Save.current_slot = 0
	return reports


func _check_week_of_nights() -> void:
	var reports: Array = await _simulate_week(true)
	_check(reports.size() == 7 and Clock.day_index == 7 and Clock.weekday == "mon", "a week of nights ends on Monday")
	var total := 0.0
	var all_lit := true
	for report in reports:
		total += float(report["lighthouse"]["power"])
		all_lit = all_lit and bool(report["lighthouse"]["lit"]) and bool(report["lighthouse"]["on_time"])
		_check(NightReport.text(report).begins_with("Ночной отчёт смотрителя"), "every morning shows the report")
	_check(all_lit, "the diligent keeper lights on time every night")
	_check(is_equal_approx(Lighthouse.fire_power, total / 7.0) and Lighthouse.fire_power >= 20.0,
		"Light is the week's average (%.1f)" % Lighthouse.fire_power)
	var salary: Dictionary = {}
	for letter in Mail.letters:
		if str(letter["text"]).begins_with("mail.salary"):
			salary = letter
	_check(not salary.is_empty() and int(salary["money"]) >= 150 + 5 * int(floor(Lighthouse.fire_power)),
		"Monday brings the week's salary")
	_check(Knowledge.sea_pts >= 7 + 7, "on-time fires and log entries teach sea notes (%d)" % Knowledge.sea_pts)
	var last_text := NightReport.text(reports[-1])
	_check(last_text.contains("Фортуна:") and last_text.contains("Компас:"), "the report carries the compass and Fortuna")
	var mercy_kept := Sea.mercy

	var dark: Array = await _simulate_week(false)
	_check(dark.size() == 7 and Lighthouse.fire_power == 0.0, "a forgotten lighthouse drops Light to zero")
	var wrecks := 0
	for report in dark:
		_check(not bool(report["lighthouse"]["lit"]), "nobody lit the lamp")
		for ship in report["lighthouse"]["ships"]:
			if ship["wrecked"]:
				wrecks += 1
	_check(Sea.mercy <= 30.0 - 14.0 - 3.0 * wrecks + 0.001, "every dark night costs mercy, every wreck more")
	_check(Sea.mercy < mercy_kept, "darkness angers the sea more than a kept watch")
	print("M3 week: light %.1f, dark wrecks %d" % [total / 7.0, wrecks])


func _run() -> void:
	await _check_world_objects()
	_check_components()
	_check_fuel()
	_check_modifiers()
	_check_breakdowns()
	_check_ship_schedule()
	_check_wrecks()
	_check_salary_and_mail()
	_check_inspections()
	_check_knowledge()
	_check_fuel_chain()
	await _check_tower()
	await _check_week_of_nights()
	_fresh()
	print("M3 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
