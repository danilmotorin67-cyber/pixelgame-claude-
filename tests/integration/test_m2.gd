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
	_check(Data.all("crops").filter(func(c: Dictionary) -> bool: return str(c["id"]) != "crop_lightflower").size() == 24,
		"every seasonal crop of 13.4 must exist")
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


func _entry(shop_id: String, item_id: String) -> Dictionary:
	for entry in Economy.shop_stock(shop_id):
		if str(entry.get("item", "")) == item_id:
			return entry
	return {}


func _check_shops() -> void:
	Inventory.reset()
	Economy.reset()
	Clock.day_index = 0
	Clock.set_time(10, 0)
	_check(Economy.shop_closed_reason("shop_berg") == "", "the Bergs open at 10:00 on Monday")
	_check(not _entry("shop_berg", "seed_turnip").is_empty() and _entry("shop_berg", "seed_carrot").is_empty(),
		"the Bergs sell seeds of the current season only")
	_check(_entry("shop_berg", "seed_rhubarb").is_empty(), "rhubarb seeds appear only from Spring 8")
	Clock.day_index = 7
	_check(not _entry("shop_berg", "seed_rhubarb").is_empty(), "rhubarb seeds on sale from Spring 8")
	_check(Economy.buy("shop_berg", _entry("shop_berg", "seed_turnip"), 3) == "ok"
		and Inventory.count_of("seed_turnip") == 3 and Economy.money == 440, "seeds cost 20 each")
	_check(Economy.buy("shop_berg", _entry("shop_berg", "seed_rhubarb"), 5) == "money",
		"a purchase needs enough crowns")
	Clock.set_time(17, 0)
	_check(Economy.shop_closed_reason("shop_berg") == "hours", "the Bergs close at 17:00")
	Clock.set_time(10, 0)
	Clock.day_index = 2
	_check(Economy.shop_closed_reason("shop_berg") == "day", "the Bergs close on Wednesdays")
	Clock.day_index = 0

	Economy.money = 20000
	Inventory.reset()
	for index in Inventory.HOTBAR:
		Inventory.add("tool_hoe", 1)
	_check(not Inventory.can_fit("seed_turnip", 1) and Inventory.add("seed_turnip", 1) == 0,
		"the starter backpack holds 12 stacks")
	var backpack: Dictionary = {}
	for entry in Economy.shop_stock("shop_berg"):
		if str(entry.get("upgrade", "")) == "backpack":
			backpack = entry
	_check(int(backpack.get("slots", 0)) == 24 and int(backpack["price"]) == 2000, "first backpack: 24 slots, 2000")
	_check(Economy.buy("shop_berg", backpack) == "ok" and Inventory.capacity == 24, "backpack upgrade to 24")
	backpack = {}
	for entry in Economy.shop_stock("shop_berg"):
		if str(entry.get("upgrade", "")) == "backpack":
			backpack = entry
	_check(int(backpack.get("slots", 0)) == 36 and int(backpack["price"]) == 10000, "second backpack: 36, 10000")
	Economy.buy("shop_berg", backpack)
	var last_offer := true
	for entry in Economy.shop_stock("shop_berg"):
		if str(entry.get("upgrade", "")) == "backpack":
			last_offer = false
	_check(Inventory.capacity == 36 and last_offer and Economy.money == 8000, "no backpack beyond 36 slots")
	var saved := Inventory.serialize().duplicate(true)
	Inventory.deserialize(JSON.parse_string(JSON.stringify(saved)))
	_check(Inventory.capacity == 36, "backpack size survives a save")

	Inventory.reset()
	Economy.reset()
	Inventory.add("turnip", 2, 1)
	Inventory.add("fish_cod", 1)
	_check(Economy.sell_to_shop("shop_berg", 1) == 0 and Inventory.count_of("fish_cod") == 1,
		"the Bergs do not buy fish")
	_check(Economy.sell_to_shop("shop_erland", 1) == 90 and Economy.money == 590, "Erland buys fish")
	_check(Economy.sell_to_shop("shop_berg", 0) == 88 and Inventory.count_of("turnip") == 0,
		"the Bergs pay the base price with the quality bonus")
	Inventory.reset()
	Economy.reset()


func _check_forage() -> void:
	Sea.reset()
	Inventory.reset()
	Skills.reset()
	_check(Sea.mercy == 30.0, "Rann's mercy starts at 30 (12.1)")
	Sea.generate_gifts(10, false)
	var calm_total := 0
	for map_id in ["cape", "seal_shore", "wreck_bay", "village"]:
		var count: int = Sea.gifts.get(map_id, []).size()
		_check(count >= 6 and count <= 15, "%s must get 6-15 gifts (got %d)" % [map_id, count])
		calm_total += count
		for gift in Sea.gifts[map_id]:
			_check(Data.exists("items", str(gift["item"])), "unknown gift " + str(gift["item"]))
			if int(gift["row"]) >= Sea.FAR_ROW:
				_check(str(gift["item"]) not in ["trash", "cork_float"], "far strips hold the better finds")
	var again := JSON.stringify(Sea.gifts)
	Sea.generate_gifts(10, false)
	_check(JSON.stringify(Sea.gifts) == again, "gifts are deterministic for a world and day")
	Sea.generate_gifts(10, true)
	var storm_total := 0
	var storm_only := 0
	for map_id in Sea.gifts:
		storm_total += Sea.gifts[map_id].size()
		for gift in Sea.gifts[map_id]:
			if str(gift["item"]) in ["amber", "pumice"]:
				storm_only += 1
	_check(storm_total >= calm_total * 2 and storm_only > 0, "storms triple the gifts and bring amber and pumice")
	Sea.mercy = 10.0
	Sea.generate_gifts(10, false)
	var hostile := 0
	for map_id in Sea.gifts:
		hostile += Sea.gifts[map_id].size()
	_check(hostile * 2 <= calm_total + 4, "a hostile sea gives half the gifts")
	Sea.mercy = 45.0
	Sea.generate_gifts(10, false)
	for map_id in Sea.gifts:
		var rare := false
		for gift in Sea.gifts[map_id]:
			if str(gift["item"]) in ["sea_glass", "amber"]:
				rare = true
		_check(rare, "mercy 40+ guarantees a rare gift on " + map_id)
	Sea.mercy = 30.0

	Sea.gifts = {"cape": [{"item": "kelp", "x": 10, "row": 5}, {"item": "trash", "x": 11, "row": 0},
		{"item": "trash", "x": 12, "row": 0}]}
	var far: Dictionary = Sea.gifts["cape"][0]
	Clock.day_index = 0
	Clock.set_time(0, 0)
	var low_minute := 0
	var high_minute := 0
	for minute in range(0, 1440, 10):
		if Clock.tide_height_at(0, minute) < Clock.tide_height_at(0, low_minute):
			low_minute = minute
		if Clock.tide_height_at(0, minute) > Clock.tide_height_at(0, high_minute):
			high_minute = minute
	Clock.set_time(high_minute / 60, high_minute % 60)
	_check(not Sea.is_dry(far) and not Sea.collect_gift("cape", far), "the far strip is under water at high tide")
	Clock.set_time(low_minute / 60, low_minute % 60)
	_check(Sea.collect_gift("cape", far) and Inventory.count_of("kelp") >= 1, "low tide opens the far strip")
	_check(int(Skills.xp["foraging"]) == 3, "a sea gift gives 3 foraging XP")
	Sea.collect_gift("cape", Sea.gifts["cape"][0])
	_check(is_equal_approx(Sea.mercy, 30.2), "rubbish lifts mercy by 0.2")
	Sea.trash_mercy_today = 1.9
	Sea.collect_gift("cape", Sea.gifts["cape"][0])
	_check(is_equal_approx(Sea.mercy, 30.3), "rubbish lifts mercy by at most 2 a day")

	Farm.spawn_wild(3)
	var spring_items := ["morel", "wild_garlic", "sorrel", "cottongrass", "armeria", "scurvygrass"]
	var zones: Dictionary = Data.tables["forage"]["zones"]
	for map_id in Farm.wild:
		for spot in Farm.wild[map_id]:
			_check(str(spot["item"]) in spring_items, "spring forage only in spring: " + str(spot["item"]))
			var inside := false
			for zone in zones[map_id]:
				inside = inside or (int(spot["x"]) >= int(zone[0]) and int(spot["x"]) < int(zone[0]) + int(zone[2])
					and int(spot["y"]) >= int(zone[1]) and int(spot["y"]) < int(zone[1]) + int(zone[3]))
			_check(inside, "forage must spawn inside its open zone")
	Farm.spawn_wild(3 * 28 + 3)
	_check(str(Farm.wild["birch"][0]["item"]) == "oyster_mushroom", "winter birches give oyster mushrooms")
	var spot: Dictionary = Farm.wild["birch"][0]
	var xp_before := int(Skills.xp["foraging"])
	_check(Farm.collect_wild("birch", spot) and int(Skills.xp["foraging"]) == xp_before + 7
		and not Farm.wild["birch"].has(spot), "a seasonal find gives 7 foraging XP and disappears")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(Sea.serialize()))
	var sea_before := JSON.stringify(Sea.serialize())
	Sea.deserialize(restored)
	_check(JSON.stringify(Sea.serialize()) == sea_before, "sea gifts survive a save")
	Clock.day_index = 0
	Farm.reset()
	Sea.reset()
	Inventory.reset()
	Skills.reset()


func _check_eating(player: Player) -> void:
	Inventory.reset()
	Inventory.add("bread_rye", 2)
	Inventory.add("fly_agaric", 1)
	Inventory.select_hotbar(0)
	player.energy = 100.0
	player.health = 50.0
	_check(player.eat_selected() == "bread_rye" and player.energy == 150.0 and player.health == 70.0,
		"rye bread restores 50 energy and 20 health (20)")
	player.energy = Game.max_energy() - 5.0
	player.eat_selected()
	_check(player.energy == Game.max_energy(), "food never overfills energy")
	Inventory.select_hotbar(1)
	_check(player.eat_selected() == "" and Inventory.count_of("fly_agaric") == 1, "fly agaric is not food")
	Inventory.reset()


func _station(id: String) -> Dictionary:
	for obj in Crafting.placed.get("cape", []):
		if str(obj["id"]) == id:
			return obj
	return {}


func _check_crafting() -> void:
	Crafting.reset()
	Inventory.reset()
	Economy.reset()
	Skills.reset()
	Clock.day_index = 0
	Clock.set_time(10, 0)
	for id in ["workbench", "hearth", "compost_pit", "cutting_table"]:
		_check(not _station(id).is_empty(), "the cape starts with a " + id)
	var boards := {}
	for entry in Economy.shop_stock("shop_ilm"):
		if str(entry.get("item", "")) == "boards":
			boards = entry
	Economy.money = 3000
	_check(Economy.buy("shop_ilm", boards, 50) == "ok" and Inventory.count_of("boards") == 50,
		"Ilm sells boards at 50")
	Clock.day_index = 1
	_check(Economy.shop_closed_reason("shop_ilm") == "day", "Ilm's shop is closed on Tuesdays")
	Clock.day_index = 0
	_check(Crafting.make("craft_chest") == "ok" and Inventory.count_of("chest") == 1
		and Inventory.count_of("boards") == 0 and int(Skills.xp["crafting"]) == 3,
		"a chest takes 50 boards and gives 2 + 1 crafting XP")
	_check(Crafting.make("craft_chest") == "ingredients", "no boards, no chest")

	for index in Inventory.HOTBAR:
		if Inventory.slots[index]["id"] == "chest":
			Inventory.select_hotbar(index)
	_check(not Crafting.place_selected("cape", Vector2(560, 372)), "a chest cannot stand on the workbench")
	_check(Crafting.place_selected("cape", Vector2(700, 460)) and Inventory.count_of("chest") == 0,
		"a chest can be placed on open ground")
	var chest := _station("chest")
	_check(chest.get("slots", []).size() == 24, "a chest holds 24 stacks")
	_check(int(chest["x"]) == 696 and int(chest["y"]) == 456, "placed objects snap to the 16 px grid")
	Inventory.add("kelp", 30)
	var kelp_slot := -1
	for index in Inventory.capacity:
		if Inventory.slots[index]["id"] == "kelp":
			kelp_slot = index
	_check(Crafting.store(chest, kelp_slot) and Inventory.count_of("kelp") == 0, "storing moves the stack")
	_check(not Crafting.pick_up("cape", chest), "a full chest cannot be picked up")
	_check(Crafting.retrieve(chest, 0) and Inventory.count_of("kelp") == 30, "retrieving returns the stack")
	_check(Crafting.pick_up("cape", chest) and Inventory.count_of("chest") == 1 and _station("chest").is_empty(),
		"an empty chest goes back into the backpack")

	var hearth := Crafting.recipes_for("hearth")
	var ids: Array = []
	for recipe in hearth:
		ids.append(recipe["id"])
	_check(ids.size() == 5 and not ids.has("cook_keeper_soup"), "five pot dishes are known from the start")
	Inventory.add("fish_cod", 1)
	_check(Crafting.make("cook_drowned_stew") == "fuel", "the hearth needs driftwood")
	Inventory.add("driftwood", 1)
	_check(Crafting.make("cook_drowned_stew") == "ok" and Inventory.count_of("drowned_stew") == 1
		and Inventory.count_of("fish_cod") == 0 and Inventory.count_of("driftwood") == 0,
		"any fish + kelp + firewood make the drowned man's stew")
	Crafting.learn("cook_keeper_soup")
	_check(Crafting.recipes_for("hearth").size() == 6, "learned recipes join the pot list")

	var pit := _station("compost_pit")
	Inventory.add("kelp", 1)
	_check(Crafting.start(pit, "process_compost") == "ok" and Inventory.count_of("kelp") == 20,
		"the compost pit takes 10 kelp")
	Crafting.start(pit, "process_compost")
	Crafting.start(pit, "process_compost")
	Inventory.add("kelp", 10)
	_check(Crafting.start(pit, "process_compost") == "full", "a station queues at most three jobs")
	Clock.day_index = 2
	_check(Crafting.ready_jobs(pit) == 0 and Crafting.collect(pit) == 0, "compost takes three days")
	Clock.day_index = 3
	_check(Crafting.finished_overnight() == 1, "the night report counts finished jobs")
	_check(Crafting.collect(pit) == 1 and Inventory.count_of("compost") == 5, "10 kelp make 5 compost")
	Clock.day_index = 6
	_check(Crafting.ready_jobs(pit) == 1, "queued jobs run one after another")
	var saved := JSON.stringify(Crafting.serialize())
	Crafting.deserialize(JSON.parse_string(saved))
	_check(JSON.stringify(Crafting.serialize()) == saved, "stations survive a save")
	Clock.day_index = 0
	Crafting.reset()
	Inventory.reset()
	Economy.reset()
	Skills.reset()


func _low_tide_minute(index: int) -> int:
	var best := 6 * 60
	for minute in range(6 * 60, 20 * 60, 10):
		if Clock.tide_height_at(index, minute) < Clock.tide_height_at(index, best):
			best = minute
	return best


# Spec 36, M2 done-criterion: a week of spring without the lighthouse or the graveyard.
func _check_spring_week() -> void:
	Save.save_root = "user://saltlight_m2_test_saves"
	Save.current_slot = 2
	Game.reset()
	Game.world_seed = 7
	Clock.reset()
	Weather.reset()
	Clock.day_index = 0
	Weather.start_day(0)
	Economy.reset()
	Inventory.reset()
	Farm.reset()
	Sea.reset()
	Skills.reset()
	Crafting.reset()
	Farm.spawn_wild(0)
	Sea.generate_gifts(0, false)
	Inventory.add("seed_turnip", 15)
	Inventory.add("bread_rye", 3)
	Inventory.add("tool_hoe")
	Inventory.add("tool_can")
	Game.player_state = {"energy": Game.max_energy()}
	var beds: Array[Vector2i] = []
	for x in 10:
		beds.append(Vector2i(x, 0))
	var nights := 0
	var gathered := 0
	var sold_turnips := 0
	var money_start := Economy.money
	var reports: Array = []
	var catcher := func(report: Dictionary) -> void: reports.append(report)
	Events.night_resolved.connect(catcher)
	for day in 7:
		var energy := float(Game.player_state.get("energy", Game.max_energy()))
		Clock.set_time(7, 0)
		for cell in beds:
			if Farm.get_tile(cell).is_empty() and energy >= 2.0:
				Farm.till(cell)
				energy -= Game.action_cost("hoe")
			var tile := Farm.get_tile(cell)
			if bool(tile.get("ready", false)):
				Farm.harvest(cell)
			if str(tile.get("crop", "x")) == "" and Inventory.count_of("seed_turnip") > 0:
				Farm.plant(cell, "seed_turnip")
			if not tile.is_empty() and Farm.water(cell):
				energy -= Game.action_cost("can")
		if energy < Game.max_energy() * 0.3:
			for index in Inventory.capacity:
				if str(Inventory.slots[index]["id"]) == "bread_rye":
					Inventory.select_hotbar(index)
			if Inventory.count_of("bread_rye") > 0:
				Inventory.take("bread_rye", 1)
				energy = minf(energy + 50.0, Game.max_energy())
		var low := _low_tide_minute(Clock.day_index)
		Clock.set_time(low / 60, low % 60)
		for gift in Sea.gifts.get("cape", []).duplicate():
			if Sea.collect_gift("cape", gift):
				gathered += 1
		Clock.set_time(10, 0)
		if Economy.shop_closed_reason("shop_berg") == "" and Inventory.count_of("seed_turnip") < 10:
			for entry in Economy.shop_stock("shop_berg"):
				if str(entry.get("item", "")) == "seed_turnip" and Economy.can_pay(200):
					Economy.buy("shop_berg", entry, 10)
		for index in Inventory.capacity:
			var id := str(Inventory.slots[index]["id"])
			if id == "turnip":
				sold_turnips += int(Inventory.slots[index]["count"])
			if id in ["turnip", "driftwood", "scallop_shell", "sea_glass", "red_kelp"]:
				Economy.ship_slot(index)
		Game.player_state["energy"] = energy
		_check(energy >= 0.0, "the keeper never works below zero energy (day %d)" % day)
		Clock.set_time(22, 0)
		Night.end_day(false)
		nights += 1
	Events.night_resolved.disconnect(catcher)
	_check(nights == 7 and Clock.day_index == 7 and reports.size() == 7, "seven spring nights resolved")
	_check(Clock.season == "spring" and Clock.day == 8, "the week ends on Spring 8")
	_check(gathered >= 20, "the shore feeds a keeper all week (%d finds)" % gathered)
	_check(sold_turnips > 0 and Economy.money > money_start, "turnips and gifts turn into crowns")
	_check(bool(reports[-1].get("saved", false)) and Save.has_save(2), "every night saves the game")
	_check(float(Game.player_state.get("energy", 0.0)) == Game.max_energy(), "sleeping before midnight restores energy")
	for file_path in Save._candidate_paths(2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	Save.save_root = "user://saves"
	Save.current_slot = 0


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
	_check_shops()
	_check_forage()
	_check_crafting()
	Router.current_map = "cape"
	Router.spawn = Vector2(600, 360)
	Game.player_state = {}
	Sea.generate_gifts(0, false)
	var cape: Node2D = load("res://scenes/world/cape.tscn").instantiate()
	get_tree().root.add_child(cape)
	get_tree().current_scene = cape
	await get_tree().process_frame
	var pickups: Pickups = cape.get_node_or_null("Pickups")
	var gift_nodes := pickups.get_children().filter(func(n: Node) -> bool: return n is PickupSpot) if pickups else []
	_check(pickups != null and gift_nodes.size() == Sea.gifts["cape"].size(),
		"the cape shows every gift of the morning")
	_check_eating(cape.get_node("Player"))
	var stations: Stations = cape.get_node_or_null("Stations")
	_check(stations != null and stations.get_child_count() == 4, "the cape shows its four stations")
	var hearth_node: StationObject = null
	for child in stations.get_children():
		if child.station_id == "hearth":
			hearth_node = child
	Inventory.add("rye_flour", 1)
	Inventory.add("salt", 1)
	Inventory.add("driftwood", 1)
	hearth_node.interact(cape.get_node("Player"))
	var panel: StationPanel = cape.get_node_or_null("HUD/StationPanel")
	_check(panel != null and Clock.paused, "the hearth opens its recipe panel")
	if panel:
		panel._list.select(1)
		_check(panel.act() == "ok" and Inventory.count_of("bread_rye") == 1, "baking rye bread from the panel")
		panel.close()
	Inventory.reset()
	cape.queue_free()
	_check_spring_week()
	Farm.reset()
	Inventory.reset()
	print("M2 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
