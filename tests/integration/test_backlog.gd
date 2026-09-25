extends Node

# Run with: godot --headless --path . res://tests/integration/test_backlog.tscn
# The leftovers of M2-M9 finished before M10: the cape field, charged tools, the job board, rescues at wrecks,
# the Peace effects and the morgue upgrades, the whole cold, the missing professions, the bot's cabin, gull
# marauders, the spyglass collections and the family.
var failures: Array[String] = []
# Night.end_day wakes the keeper on this "map" instead of changing the scene.
var map_id: String = "cape"


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh() -> void:
	NewGame.start({"name": "Тест", "gender": "m", "stern_phrase": "Я увольняюсь."})
	Game.world_seed = 9
	Inventory.upgrade_capacity(36)
	Economy.money = 100000


func _goto(index: int, hour: int = 8) -> void:
	Clock.day_index = index
	Clock.set_time(hour, 0)
	Weather.start_day(index)
	Story.update_act()


func _run() -> void:
	for section in ["_check_field", "_check_tools"]:
		print("- ", section)
		call(section)
	print("Backlog integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


# 13.1/13.3: the overgrown field, its salty soil and the salt a storm brings.
func _check_field() -> void:
	_fresh()
	var total := 0
	for plot in Farm.FIELDS:
		var size: Vector2i = Farm.PLOTS[plot]["size"]
		total += size.x * size.y
	_check(total + 60 >= 900 and total + 60 <= 1000, "the field and the old beds give ≈900 tiles (%d)" % (total + 60))
	_check(Farm.clutter.size() > total / 2 and Farm.field_clear_count() == total - Farm.clutter.size(), "most of the field starts overgrown")
	var kinds := {}
	var salts := {1: 0, 2: 0}
	for plot in Farm.FIELDS:
		var size: Vector2i = Farm.PLOTS[plot]["size"]
		for y in size.y:
			for x in size.x:
				kinds[Farm.clutter_at(Vector2i(x, y), plot)] = true
				salts[Farm.base_salt(Vector2i(x, y), plot)] += 1
	_check(kinds.has("weed") and kinds.has("rock") and kinds.has("snag") and kinds.has(""), "weeds, stones, snags and bare tiles")
	var share := float(salts[2]) / float(total)
	_check(share > 0.52 and share < 0.68 and salts[1] > 0, "about 60%% of the field is Salt 2 (%.2f)" % share)
	# Clearing: each thing answers only its tool.
	var cells := {}
	for key in Farm.clutter:
		var parsed := Farm.parse_key(key)
		cells[str(Farm.clutter[key]["k"])] = parsed
	var weed: Array = cells["weed"]
	var rock: Array = cells["rock"]
	var snag: Array = cells["snag"]
	_check(not Farm.till(weed[1], weed[0]), "an overgrown tile cannot be tilled")
	_check(Farm.clear_clutter(weed[1], weed[0], "tool_pick") == "wrong", "the pickaxe does not mow weeds")
	_check(Farm.clear_clutter(weed[1], weed[0], "tool_scythe") == "weed", "the scythe clears weeds")
	var stone := Inventory.count_of("stone")
	_check(Farm.clear_clutter(rock[1], rock[0], "tool_pick") == "" and Farm.clear_clutter(rock[1], rock[0], "tool_pick") == "stone"
		and Inventory.count_of("stone") == stone + 1, "a stone takes two blows and gives stone")
	var wood := Inventory.count_of("driftwood")
	Farm.clear_clutter(snag[1], snag[0], "tool_axe")
	_check(Farm.clear_clutter(snag[1], snag[0], "tool_axe") == "driftwood" and Inventory.count_of("driftwood") == wood + 1, "a snag gives driftwood to the axe")
	_check(Farm.till(weed[1], weed[0]) and int(Farm.get_tile(weed[1], weed[0])["salt"]) == Farm.base_salt(weed[1], weed[0]),
		"a cleared tile is tilled with the field's own salt")
	# S0 peas will not grow on Salt 1-2.
	var bed: Array = weed
	Inventory.add("seed_pea", 1)
	_check(not Farm.plant(bed[1], "seed_pea", bed[0]), "peas refuse salty field soil")
	# Storm spray: only the southern field lies within 12 tiles of the shore; stone walls shelter it.
	_check(Farm.near_shore(Vector2i(0, 0), "field_s") and not Farm.near_shore(Vector2i(0, 0), "field_nw")
		and not Farm.near_shore(Vector2i(0, 0), "beds"), "only the shore field takes storm salt")
	var tilled: Array = []
	for x in 30:
		var cell := Vector2i(x, 5)
		Farm.clutter.erase(Farm._key(cell, "field_s"))
		Farm.till(cell, "field_s")
		Farm.get_tile(cell, "field_s")["salt"] = 0
		tilled.append(cell)
	var north := Vector2i(0, 0)
	Farm.clutter.erase(Farm._key(north, "field_nw"))
	Farm.till(north, "field_nw")
	Farm.get_tile(north, "field_nw")["salt"] = 0
	var salted := 0
	for night in 4:
		Clock.day_index += 1
		Farm.advance_day(true)
	for cell in tilled:
		salted += int(Farm.get_tile(cell, "field_s")["salt"])
	_check(salted >= 12 and salted <= 50, "storm nights salt ~25%% of the shore tiles a night (%d grains over 4 nights)" % salted)
	_check(int(Farm.get_tile(north, "field_nw")["salt"]) == 0, "the northern field keeps its salt")
	Farm.advance_day(false)
	var calm := 0
	for cell in tilled:
		calm += int(Farm.get_tile(cell, "field_s")["salt"])
	_check(calm == salted, "a quiet night brings no salt")
	Crafting.placed["cape"] = [{"id": "stone_wall", "x": 400 + 8 * 16 + 8, "y": 672 + 5 * 16 + 8}]
	var sheltered := Vector2i(8, 5)
	Farm.get_tile(sheltered, "field_s")["salt"] = 0
	for night in 8:
		Clock.day_index += 1
		Farm.advance_day(true)
	_check(int(Farm.get_tile(sheltered, "field_s")["salt"]) == 0, "a stone wall shelters the tiles around it")
	# Saved and loaded.
	var left := Farm.clutter.size()
	var back: Dictionary = JSON.parse_string(JSON.stringify(Farm.serialize()))
	Farm.deserialize(back)
	_check(Farm.clutter.size() == left and Farm.field_ready and not Farm.get_tile(weed[1], weed[0]).is_empty(), "the field is saved")
	back.erase("clutter")
	back.erase("field_ready")
	Farm.deserialize(back)
	_check(Farm.clutter.size() > 0 and Farm.field_ready, "an old save gets an overgrown field")


# 9: the can's volume and fresh water, charged blows of the hoe and the can, the big hulls of Wreck Bay.
func _check_tools() -> void:
	_fresh()
	_check(Farm.can_water == 40 and Farm.can_capacity() == 40, "a rusty can holds 40")
	Game.counters["can_level"] = 4
	_check(Farm.can_capacity() == 100 and Farm.fill_can() == 60 and Farm.can_water == 100, "a moon-silver can holds 100")
	Game.counters["can_level"] = 0
	Farm.can_water = 2
	for x in 3:
		Farm.till(Vector2i(x, 0))
	_check(Farm.water_with_can(Vector2i(0, 0)) == "ok" and Farm.water_with_can(Vector2i(1, 0)) == "ok"
		and Farm.water_with_can(Vector2i(2, 0)) == "empty" and Farm.can_water == 0, "each tile takes one measure of water")
	_check(Farm.fresh_water_at("cape", Farm.RAIN_BUTT) and not Farm.fresh_water_at("cape", Vector2(700, 1000))
		and not Farm.fresh_water_at("wreck_bay", Vector2(100, 500)), "only fresh water fills the can")
	Crafting.placed["cape"].append({"id": "cistern", "x": 300, "y": 300})
	_check(Farm.fresh_water_at("cape", Vector2(305, 300)), "a cistern fills the can")
	# Charge shapes: 1 / 3 / 5 / 3×3 / 6×3.
	var sizes: Array = []
	for step in 5:
		sizes.append(Farm.charge_cells(Vector2i(4, 4), Vector2i(1, 0), step).size())
	_check(sizes == [1, 3, 5, 9, 18], "charged blows cover 1/3/5/9/18 tiles (%s)" % str(sizes))
	_check(Farm.charge_cells(Vector2i(0, 0), Vector2i(0, 1), 2) == [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)],
		"a line runs the way the keeper faces")
	_check(Farm.max_charge("tool_hoe") == 0, "a rusty hoe does not charge")
	Game.counters["hoe_level"] = 3
	_check(Farm.max_charge("tool_hoe") == 3, "a silver hoe charges to 3×3")
	Farm.tiles.clear()
	_check(Farm.till_area(Vector2i(1, 1), "beds", Vector2i(1, 0), 3) == 9, "a charged hoe tills a 3×3 block")
	_check(Farm.till_area(Vector2i(8, 0), "beds", Vector2i(1, 0), 2) == 2, "tiles beyond the plot are left alone")
	Farm.can_water = 5
	_check(Farm.water_area(Vector2i(1, 1), "beds", Vector2i(1, 0), 3) == 5 and Farm.can_water == 0, "a charged can waters until it runs dry")
	# The big hulls.
	_check(Crafting.hull_standing(0) and Crafting.chop_hull(0) == "weak", "an iron axe cannot break a big hull")
	Game.counters["axe_level"] = 3
	var boards := Inventory.count_of("boards")
	var result := ""
	for n in 6:
		result = Crafting.chop_hull(0)
	_check(result == "done" and Inventory.count_of("boards") >= boards + 4 and Inventory.count_of("iron_scrap") >= 2, "a silver axe breaks a hull into boards and scrap")
	_check(not Crafting.hull_standing(0) and Crafting.chop_hull(0) == "gone", "a broken hull is gone for the season")
	Clock.day_index += Clock.DAYS_PER_SEASON
	_check(Crafting.hull_standing(0), "the next season's storms bring another hull")
	var back: Dictionary = JSON.parse_string(JSON.stringify({"f": Farm.serialize(), "c": Crafting.serialize()}))
	Farm.can_water = 1
	Farm.deserialize(back["f"])
	Crafting.deserialize(back["c"])
	_check(Farm.can_water == 0 and Crafting.hulls.has("0"), "the can and the hulls are saved")
