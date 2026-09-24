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
	Knowledge.sea_pts = 0


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


func _run() -> void:
	_check_components()
	_check_fuel()
	_check_modifiers()
	_check_breakdowns()
	_fresh()
	print("M3 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
