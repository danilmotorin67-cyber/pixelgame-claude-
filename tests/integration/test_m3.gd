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
	_check(desk != null and Game.honor == 6 and Inventory.count_of("cargo_fishing") == 0,
		"the directorate takes wreck crates for honour")
	village.queue_free()
	await get_tree().process_frame


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
	_fresh()
	print("M3 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
