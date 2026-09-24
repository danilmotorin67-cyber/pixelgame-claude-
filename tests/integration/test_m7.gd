extends Node

# Run with: godot --headless --path . res://tests/integration/test_m7.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh() -> void:
	Game.reset()
	Game.world_seed = 7
	Clock.reset()
	Weather.reset()
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Graveyard, Mail, Knowledge, Quests,
			Collections, Relationships, Cutscenes, NPCs, Buildings, Animals]:
		system.reset()
	Inventory.upgrade_capacity(36)


func _first_with_tag(tag: String) -> String:
	for item in Data.all("items"):
		if tag in item.get("tags", []):
			return str(item["id"])
	return ""


func _give(need: String, count: int) -> void:
	var id := _first_with_tag(need.substr(4)) if need.begins_with("tag:") else need
	Inventory.add(id, count)


func _empty_inventory() -> void:
	for index in Inventory.slots.size():
		Inventory.slots[index] = {"id": "", "count": 0, "quality": 0, "meta": {}}


# 36 (M7): every recipe of the game can be made at its station once it is known.
func _check_every_recipe() -> void:
	_fresh()
	var made := 0
	for recipe in Crafting.all_recipes():
		var id := str(recipe["id"])
		_empty_inventory()
		Crafting.learn(id)
		for need in recipe["in"]:
			_give(str(need[0]), int(need[1]))
		var station_id := str(recipe["station"])
		var info := Crafting.station(station_id)
		for fuel in info.get("fuel", []):
			Inventory.add(str(fuel[0]) if fuel is Array else str(fuel), 3)
		var out: Array = recipe["out"]
		var before := Inventory.count_of(str(out[0]))
		var result := ""
		match str(info.get("kind", "")):
			"instant", "cook":
				result = Crafting.make(id, 1, station_id)
			"process":
				var obj := Crafting._add("cape", station_id, 16, 16)
				result = Crafting.start(obj, id)
				Clock.day_index += 10
				if result == "ok" and Crafting.collect(obj) != 1:
					result = "not collected"
				Crafting.placed["cape"].erase(obj)
			_:
				result = "station kind " + str(info.get("kind", ""))
		var least := int(recipe.get("out_range", [out[1]])[0])
		var got := Inventory.count_of(str(out[0])) - before
		_check(result == "ok" and got >= least, "%s at %s: %s, got %d of %s" % [id, station_id, result, got, str(out[0])])
		if result == "ok":
			made += 1
	_check(made == Crafting.all_recipes().size(), "every recipe is made: %d of %d" % [made, Crafting.all_recipes().size()])
	_check(Crafting.all_recipes().size() >= 300, "the full recipe list of 19-20 is in the data")


# Unlocks: start, skill levels, knowledge nodes, professions, letters at N hearts, the gazette, flags.
func _check_unlocks() -> void:
	_fresh()
	var r := func(id: String) -> Dictionary: return Crafting._recipe(id)
	_check(Crafting.knows(r.call("craft_chest")) and not Crafting.knows(r.call("craft_trap")), "a trap needs Fishing 1")
	Skills.levels["fishing"] = 1
	_check(Crafting.knows(r.call("craft_trap")), "Fishing 1 opens the trap")
	_check(not Crafting.knows(r.call("grind_prism")), "prisms need node M7")
	Knowledge.unlock("M7")
	_check(Crafting.knows(r.call("grind_prism")), "M7 opens the prism")
	_check(Crafting.knows(r.call("craft_kelp_line")) == false, "the kelp line needs Z9 or Seafaring 6")
	Skills.levels["seafaring"] = 6
	_check(Crafting.knows(r.call("craft_kelp_line")), "Seafaring 6 also opens the kelp line")
	_check(not Crafting.knows(r.call("melt_stained_glass")), "stained glass is for the Glassblower")
	Skills.professions["crafting"] = ["optician", "glassblower"]
	_check(Crafting.knows(r.call("melt_stained_glass")), "the Glassblower learns stained glass")
	Game.effect("skill_fishing")
	Game.add_buff({"skill_fishing": 2, "hours": 5})
	_check(Skills.level("fishing") == 3 and Skills.base_level("fishing") == 1, "a dish lifts the skill level, not the unlocks")
	_check(not Crafting.knows(r.call("cook_kalitki")), "Solveig's recipe is not known before her letter")
	Relationships.set_hearts("npc_solveig", 3)
	var letters := Mail.letters.size()
	_check(Crafting.recipe_letters() >= 1 and Crafting.knows(r.call("cook_kalitki")) and Mail.letters.size() > letters,
		"Solveig writes the kalitki recipe at 3 hearts")
	_check(Crafting.recipe_letters() == 0, "a recipe letter comes once")
	Clock.day_index = 6
	var column := Crafting.gazette_recipe()
	_check(column != "" and str(r.call(column).get("unlock", "")) == "gazette" and Crafting.learned.has(column), "the gazette teaches a dish a week")
	_check(Crafting.gazette_recipe() == column, "the same week prints the same column")
	Clock.day_index = 13
	_check(Crafting.gazette_recipe() != column, "the next week another column")
	_check(not Crafting.knows(r.call("craft_drag_sled")), "the drag sled waits for Q2.10")
	Game.set_flag("q2_10_done")
	_check(Crafting.knows(r.call("craft_drag_sled")), "Q2.10 opens the drag sled")


# Fuel, quality from the main ingredient, station speed, double forge batches, the seed box, queues.
func _check_engine() -> void:
	_fresh()
	Knowledge.unlock("R2")
	var forge := Crafting._add("cape", "forge", 32, 32)
	Inventory.add("iron_scrap", 4)
	_check(Crafting.start(forge, "smelt_iron") == "fuel", "the forge needs peat or coal")
	Inventory.add("coal", 1)
	_check(Crafting.start(forge, "smelt_iron") == "ok" and Inventory.count_of("coal") == 0, "one coal per smelt")
	_check(int(forge["queue"][0]["ready_at"]) - Crafting.now() == 120, "a smelt takes 2 hours")
	Skills.levels["crafting"] = 10
	Inventory.add("peat", 1)
	Crafting.start(forge, "smelt_iron")
	_check(int(forge["queue"][1]["ready_at"]) - int(forge["queue"][0]["ready_at"]) == 96, "Crafting 10: stations 20% faster")
	Skills.professions["crafting"] = ["craftsman"]
	_check(Crafting.job_minutes(Crafting._recipe("smelt_iron")) == 77, "the Craftsman works 25% faster again")
	Skills.professions.clear()
	Clock.day_index += 1
	_check(Crafting.collect(forge) == 2 and Inventory.count_of("iron_ingot") == 2, "two ingots from four scrap")
	Inventory.add("iron_scrap", 4)
	Inventory.add("coal", 1)
	Inventory.add("forge_tongs", 1)
	_check(Crafting.start(forge, "smelt_iron") == "ok" and Inventory.count_of("iron_scrap") == 0, "the forge tongs smelt a double batch")
	Clock.day_index += 1
	Crafting.collect(forge)
	_check(Inventory.count_of("iron_ingot") == 4, "the double batch gives two ingots")
	# quality follows the main ingredient
	Knowledge.unlock("Z5")
	Knowledge.unlock("Z8")
	var press := Crafting._add("cape", "cheese_press", 48, 48)
	Inventory.add("milk", 1, 2)
	Inventory.add("milk", 1, 0)
	Crafting.start(press, "press_cheese")
	Clock.day_index += 1
	Crafting.collect(press)
	_check(Inventory.count_of("cheese") == 1 and _quality_of("cheese") == 2, "excellent milk makes excellent cheese")
	# the seed box gives one to three seeds
	Knowledge.unlock("Z2")
	Knowledge.unlock("Z7")
	var box := Crafting._add("cape", "seed_box", 64, 64)
	Inventory.add("potato", 3)
	for n in 3:
		Crafting.start(box, "seeds_potato")
	Clock.day_index += 1
	Crafting.collect(box)
	var seeds := Inventory.count_of("seed_potato")
	_check(seeds >= 3 and seeds <= 9, "three potatoes give 3-9 seeds (%d)" % seeds)
	# the sawhorse costs energy
	Knowledge.unlock("R6")
	Inventory.add("driftwood", 3)
	_check(Crafting.make("saw_driftwood", 1, "sawhorse") == "ok" and is_equal_approx(Crafting.last_energy, 3.0)
		and Inventory.count_of("boards") == 2, "3 driftwood -> 2 boards for 3 energy")
	# the stove cooks the pot dishes too; the hearth needs fuel, the stove does not
	Inventory.add("rye_flour", 1)
	Inventory.add("salt", 1)
	_check(Crafting.make("cook_bread_rye", 1, "kitchen_stove") == "ok" and Inventory.count_of("bread_rye") == 1,
		"the kitchen stove bakes rye bread without fuel")
	_check(Crafting.recipes_for("kitchen_stove").size() > Crafting.recipes_for("hearth").size(), "the stove knows more than the pot")
	_check(Crafting.make("cook_fried_smelt", 1, "hearth") == "unknown", "the pot cannot fry smelt")


# Receiver chest, cellar barrels, hives, trees, the drying racks in the rain, gathering, parts and buffs.
func _check_world_stations() -> void:
	_fresh()
	Knowledge.unlock("M2")
	var renderer := Crafting._add("cape", "renderer", 400, 400)
	var chest := Crafting._add("cape", "receiver_chest", 432, 400)
	var far := Crafting._add("cape", "renderer", 600, 400)
	Inventory.add("fish_guts", 10)
	Inventory.add("peat", 2)
	Crafting.start(renderer, "render_oil")
	Crafting.start(far, "render_oil")
	Clock.day_index += 1
	_check(Crafting.sweep_receivers() == 1 and str(chest["slots"][0]["id"]) == "fish_oil" and far["queue"].size() == 1,
		"the receiver chest gathers from stations within 3 tiles only")
	# cellar: a step every 19 days, flawless by day 56
	var cask := Crafting._add("cape", "cellar_barrel", 400, 460)
	Inventory.add("aquavit", 2, 0)
	var index := -1
	for i in Inventory.capacity:
		if str(Inventory.slots[i]["id"]) == "aquavit":
			index = i
	_check(Crafting.store(cask, index) and str(cask["slots"][0]["id"]) == "aquavit", "aquavit goes into the cellar barrel")
	Inventory.add("fish_cod", 1)
	for i in Inventory.capacity:
		if str(Inventory.slots[i]["id"]) == "fish_cod":
			index = i
	_check(not Crafting.store(cask, index), "the cellar takes only aquavit, wine and cheese")
	Clock.day_index += 19
	Crafting.night("clear")
	_check(int(cask["slots"][0]["quality"]) == 1, "19 days: good aquavit")
	Clock.day_index += 37
	Crafting.night("clear")
	_check(int(cask["slots"][0]["quality"]) == 3, "56 days: flawless")
	# hive: honey every 4 days, not in winter; sea buckthorn nearby makes buckthorn honey
	Clock.day_index = 0
	var hive := Crafting._add("cape", "beehive", 700, 700)
	Clock.day_index = 4
	Crafting.night("clear")
	_check(hive["stock"].size() == 1 and str(hive["stock"][0][0]) == "honey", "the hive gives honey after 4 days")
	var bush := Crafting._add("cape", "tree", 720, 700)
	bush["tree"] = "tree_buckthorn"
	bush["age"] = 0
	bush["grown"] = false
	bush["fruit"] = 0
	for day in range(5, 30):
		Clock.day_index = day
		Crafting.night("clear")
	_check(bool(bush["grown"]), "a sea buckthorn grows in 20 days")
	_check(str(hive["stock"][-1][0]) == "buckthorn_honey", "buckthorn within 5 tiles flavours the honey")
	_check(hive["stock"].any(func(e: Array) -> bool: return str(e[0]) == "beeswax"), "wax with every third honey")
	Clock.day_index = 28 * 3 + 2
	var before: int = hive["stock"].size()
	for n in 6:
		Clock.day_index += 1
		Crafting.night("clear")
	_check(hive["stock"].size() == before, "bees sleep in winter")
	Clock.day_index = 28 + 5
	bush["fruit"] = 0
	bush["last_fruit"] = -10
	Crafting.night("clear")
	_check(int(bush["fruit"]) == 1 and Crafting.pick_fruit(bush) >= 1 and Inventory.count_of("sea_buckthorn") >= 1,
		"summer sea buckthorn gives berries")
	_check(Crafting.sheltered("cape", Vector2(720, 760)) and not Crafting.sheltered("cape", Vector2(720, 900)),
		"a grown sea buckthorn shelters radius 5")
	# drying racks wait for dry weather
	Knowledge.unlock("Z2")
	var rack := Crafting._add("cape", "drying_rack", 300, 300)
	Inventory.add("kelp", 1)
	Crafting.start(rack, "dry_kelp")
	var due := int(rack["queue"][0]["ready_at"])
	Crafting.night("rain")
	_check(int(rack["queue"][0]["ready_at"]) == due + 720, "rain slows the drying racks by half a day")
	# gathering
	_empty_inventory()
	var row0 := Sea.first_row("seal_shore")
	_check(Crafting.dig_sand("seal_shore", Vector2(20 * 16 + 8, (row0 - 1) * 16 + 8)) > 0, "a shovel digs sand on the beach")
	_check(Crafting.dig_sand("moor", Vector2(100, 100)) == 0, "no sand on the moor")
	_check(Crafting.scoop_seawater("seal_shore", Vector2(20 * 16 + 8, (row0 + 8) * 16 + 8), 5) == 5, "the belt keg scoops 5 buckets")
	var felled := 0
	for n in 8:
		if Crafting.fell_birch("birch", Vector2(30 * 16, 14 * 16)).has("log"):
			felled += 1
	_check(felled == 6 and Inventory.count_of("birch_log") == 6, "six birches a day in the grove")
	# lighthouse parts
	Inventory.add("parabolic_reflector", 1)
	_check(Lighthouse.install_part("parabolic_reflector") == "ok" and Lighthouse.lens == "parabolic", "the reflector goes in")
	Inventory.add("lens_fresnel_4", 1)
	_check(Lighthouse.install_part("lens_fresnel_4") == "ok" and Lighthouse.lens == "fresnel_4"
		and Inventory.count_of("parabolic_reflector") == 1, "the Fresnel lens replaces it; the reflector comes back")
	Inventory.add("reservoir_3", 1)
	_check(Lighthouse.install_part("reservoir_3") == "ok" and Lighthouse.reservoir_units() == 3, "the reservoir holds 3")
	Inventory.add("lightning_rod", 1)
	_check(Lighthouse.install_part("lightning_rod") == "ok" and int(Lighthouse.tower["rod"]) == 2, "the lightning rod: +2 tower")
	Inventory.add("lamp_argand", 1)
	var power_before: int = Lighthouse.components()["lamp"]
	Lighthouse.install_part("lamp_argand")
	_check(Lighthouse.components()["lamp"] > power_before, "the Argand lamp brightens the light")
	# food buffs and clothes
	Inventory.add("berg_herring", 1)
	var luck_before := Game.luck_total()
	Game.add_buff(Data.by_id("items", "berg_herring")["buff"])
	_check(is_equal_approx(Game.luck_total(), luck_before + 0.02), "herring à la Berg: luck +0.02")
	Clock.day_index += 2
	_check(is_equal_approx(Game.luck_total(), luck_before), "the buff wears off")
	Inventory.add("amber_pendant", 1)
	_check(Game.equip("amber_pendant") == "on" and is_equal_approx(Game.effect("luck"), 0.02), "the amber pendant: luck +0.02")
	_check(Game.equip("amber_pendant") == "off" and Inventory.count_of("amber_pendant") == 1, "taken off again")


func _quality_of(id: String) -> int:
	for slot in Inventory.slots:
		if str(slot["id"]) == id:
			return int(slot["quality"])
	return -1


func _run() -> void:
	_check_every_recipe()
	_check_unlocks()
	_check_engine()
	_check_world_stations()
	print("M7 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
