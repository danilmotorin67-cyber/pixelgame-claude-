extends Node

# Run with: godot --headless --path . res://tests/integration/test_m2.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh_bed(cell: Vector2i, salt: int = 0, fertility: int = 1) -> Dictionary:
	Farm.till(cell)
	var tile := Farm.get_tile(cell)
	tile["salt"] = salt
	tile["fertility"] = fertility
	return tile


func _grow(cell: Vector2i, nights: int) -> void:
	for night in nights:
		Farm.water(cell)
		Farm.advance_day()


func _check_crop_table() -> void:
	var expected_days := {"crop_turnip": 4, "crop_rhubarb": 13, "crop_sea_kale": 9, "crop_pumpkin": 13,
		"crop_winter_cabbage": 14, "crop_dill": 4}
	_check(Data.all("crops").size() == 24, "every seasonal crop of 13.4 must exist")
	for crop in Data.all("crops"):
		_check(Data.exists("items", str(crop["seed"])) and Data.exists("items", str(crop["produce"])),
			"crop %s has no seed or produce item" % crop["id"])
		_check(str(Data.by_id("items", str(crop["produce"])).get("name", "")).begins_with("item.")
			and Loc.t(str(Data.by_id("items", str(crop["produce"]))["name"])) != str(Data.by_id("items", str(crop["produce"]))["name"]),
			"crop %s has no localized name" % crop["id"])
		if expected_days.has(crop["id"]):
			_check(Farm.total_days(crop) == int(expected_days[crop["id"]]), "wrong days for " + str(crop["id"]))
	_check(int(Data.by_id("items", "turnip")["price"]) == 35, "turnip sells for 35 (13.4)")


func _check_planting_rules() -> void:
	Farm.reset()
	Inventory.reset()
	Clock.day_index = 0
	for seed_id in ["seed_pea", "seed_turnip", "seed_sea_kale", "seed_carrot"]:
		Inventory.add(seed_id, 5)
	_fresh_bed(Vector2i(0, 0), 1)
	_check(not Farm.plant(Vector2i(0, 0), "seed_pea"), "S0 peas refuse salt 1")
	_check(Farm.plant(Vector2i(0, 0), "seed_turnip"), "S1 turnip grows on salt 1")
	_fresh_bed(Vector2i(1, 0), 2)
	_check(Farm.plant(Vector2i(1, 0), "seed_sea_kale"), "S2 sea kale grows on salt 2")
	_fresh_bed(Vector2i(2, 0))
	_check(not Farm.plant(Vector2i(2, 0), "seed_carrot"), "summer carrots cannot be sown in spring")
	_check(Inventory.count_of("seed_carrot") == 5 and Inventory.count_of("seed_pea") == 5,
		"refused seeds stay in the backpack")


func _check_soil() -> void:
	Farm.reset()
	Inventory.reset()
	Clock.day_index = 0
	var cell := Vector2i(3, 3)
	var tile := _fresh_bed(cell, 2, 0)
	Inventory.add("compost", 2)
	Inventory.add("guano_fertilizer", 1)
	_check(Farm.amend(cell, "compost") == "ok" and int(tile["salt"]) == 1 and int(tile["fertility"]) == 1,
		"compost: salt -1, fertility +1")
	_check(Farm.amend(cell, "compost") == "season" and Inventory.count_of("compost") == 1,
		"compost at most once per season on a bed")
	_check(Farm.amend(cell, "guano_fertilizer") == "ok" and Farm.fertility(tile) == 3,
		"guano adds +2 fertility")
	Clock.day_index = 28
	_check(Farm.fertility(tile) == 1, "guano lasts only until the season ends")
	_check(Farm.amend(cell, "compost") == "ok" and int(tile["salt"]) == 0, "compost works again next season")
	_check(Farm.amend(cell, "tool_hoe") == "invalid", "only soil items amend a bed")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(Farm.serialize()))
	var before := Farm.serialize().duplicate(true)
	Farm.deserialize(restored)
	_check(Farm.serialize() == before, "amended beds survive a save round trip")
	Clock.day_index = 0


func _check_growth() -> void:
	Farm.reset()
	Inventory.reset()
	Weather.set_weather("clear")
	Clock.day_index = 0
	Inventory.add("seed_rhubarb", 2)
	Inventory.add("seed_pea", 1)
	var rich := Vector2i(0, 1)
	_fresh_bed(rich, 0, 3)
	Farm.plant(rich, "seed_rhubarb")
	var plain := Vector2i(1, 1)
	_fresh_bed(plain, 0, 1)
	Farm.plant(plain, "seed_rhubarb")
	for night in 11:
		Farm.water(rich)
		Farm.water(plain)
		Farm.advance_day()
	_check(not bool(Farm.get_tile(rich)["ready"]), "fertility 3 rhubarb is not ripe after 11 nights")
	Farm.water(rich)
	Farm.water(plain)
	Farm.advance_day()
	_check(bool(Farm.get_tile(rich)["ready"]) and not bool(Farm.get_tile(plain)["ready"]),
		"fertility 3 grows 10% faster: rhubarb in 12 nights instead of 13")
	_grow(plain, 1)
	_check(bool(Farm.get_tile(plain)["ready"]), "fertility 1 rhubarb ripens in 13 nights")
	var pea := Vector2i(2, 1)
	_fresh_bed(pea, 0, 0)
	Farm.plant(pea, "seed_pea")
	_grow(pea, 8)
	_check(Farm.harvest(pea) and str(Farm.get_tile(pea)["crop"]) == "crop_pea", "peas stay after picking")
	_grow(pea, 2)
	_check(not bool(Farm.get_tile(pea)["ready"]), "peas regrow in 3 days, not 2")
	_grow(pea, 1)
	_check(bool(Farm.get_tile(pea)["ready"]), "peas regrow every 3 days")

	Farm.reset()
	Inventory.add("seed_barley", 1)
	Inventory.add("seed_turnip", 1)
	_fresh_bed(Vector2i(0, 0))
	_fresh_bed(Vector2i(1, 0))
	Farm.plant(Vector2i(0, 0), "seed_barley")
	Farm.plant(Vector2i(1, 0), "seed_turnip")
	Clock.day_index = 28
	Farm.advance_day()
	_check(str(Farm.get_tile(Vector2i(0, 0))["crop"]) == "crop_barley", "barley lives into summer")
	_check(str(Farm.get_tile(Vector2i(1, 0))["crop"]) == "", "turnips die when spring ends")
	Clock.day_index = 0


func _check_storm() -> void:
	Farm.reset()
	Inventory.reset()
	Clock.day_index = 3
	Weather.set_weather("clear")
	Inventory.add("seed_potato", 60)
	for y in Farm.HEIGHT:
		for x in Farm.WIDTH:
			_fresh_bed(Vector2i(x, y))
			Farm.plant(Vector2i(x, y), "seed_potato")
	Farm.advance_day(true)
	var dead := 0
	for key in Farm.tiles:
		if str(Farm.tiles[key]["crop"]) == "":
			dead += 1
	_check(dead >= 2 and dead <= 20, "storms kill about 15%% of sprouts (killed %d of 60)" % dead)
	Farm.reset()
	Inventory.add("seed_potato", 60)
	for y in Farm.HEIGHT:
		for x in Farm.WIDTH:
			_fresh_bed(Vector2i(x, y))
			Farm.plant(Vector2i(x, y), "seed_potato")
			Farm.get_tile(Vector2i(x, y))["growth"] = 4.5
	Farm.advance_day(true)
	var set_back := 0
	for key in Farm.tiles:
		var tile: Dictionary = Farm.tiles[key]
		_check(str(tile["crop"]) == "crop_potato", "grown crops survive a storm")
		if float(tile["growth"]) < 4.5:
			set_back += 1
			_check(is_equal_approx(float(tile["growth"]), 2.0), "a storm sets a crop back one stage")
	_check(set_back >= 2 and set_back <= 20, "storms set back about 15%% of crops (%d of 60)" % set_back)
	Clock.day_index = 0


func _check_quality() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var crop := Data.by_id("crops", "crop_turnip")
	var poor := {"salt": 0, "fertility": 0, "guano_season": -1, "flawless_bonus": 0.0}
	var counts := [0, 0, 0, 0]
	Skills.reset()
	for roll in 4000:
		counts[Farm.roll_quality(poor, crop, rng)] += 1
	_check(counts[3] == 0, "no flawless harvests without fertility 3 and farming 8")
	var good_share := float(counts[1] + counts[2]) / 4000.0
	_check(good_share > 0.17 and good_share < 0.25, "fertility 0: ~21%% good or better (got %.2f)" % good_share)
	var average := {"salt": 0, "fertility": 1, "guano_season": -1, "flawless_bonus": 0.0}
	counts = [0, 0, 0, 0]
	for roll in 4000:
		counts[Farm.roll_quality(average, crop, rng)] += 1
	good_share = float(counts[1] + counts[2]) / 4000.0
	_check(good_share > 0.30 and good_share < 0.38, "fertility 1: ~34%% good or better (got %.2f)" % good_share)
	var rich := {"salt": 0, "fertility": 3, "guano_season": -1, "flawless_bonus": 0.05}
	Skills.levels["farming"] = 10
	counts = [0, 0, 0, 0]
	for roll in 4000:
		counts[Farm.roll_quality(rich, crop, rng)] += 1
	var flawless := float(counts[3]) / 4000.0
	_check(flawless > 0.08 and flawless < 0.12, "fertility 3 + farming 10 + Helga: ~10%% flawless (got %.3f)" % flawless)
	_check(counts[0] < 800, "a master farmer rarely harvests regular crops")
	Skills.reset()
	Inventory.reset()
	Farm.reset()
	Inventory.add("seed_turnip", 1)
	_fresh_bed(Vector2i(4, 4))
	Farm.plant(Vector2i(4, 4), "seed_turnip")
	_grow(Vector2i(4, 4), 4)
	_check(Farm.harvest(Vector2i(4, 4)), "turnip harvest")
	var got := Farm.last_harvest
	_check(str(got["id"]) == "turnip" and Inventory.count_of("turnip") == int(got["amount"]),
		"harvest reports what it added")
	var stored_quality := -1
	for slot in Inventory.slots:
		if slot["id"] == "turnip":
			stored_quality = int(slot["quality"])
	_check(stored_quality == int(got["quality"]), "harvest keeps its quality in the backpack")


func _run() -> void:
	Game.reset()
	Game.world_seed = 42
	Clock.reset()
	Clock.day_index = 0
	_check_crop_table()
	_check_planting_rules()
	_check_soil()
	_check_growth()
	_check_storm()
	_check_quality()
	Farm.reset()
	Inventory.reset()
	print("M2 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
