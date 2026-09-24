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


# 25: professions at 5 and 10, their effects; 26.1: where notes come from; the tree opens node by node.
func _check_skills() -> void:
	_fresh()
	Skills.add_xp("fishing", 2150)
	var gained := Skills.apply_levels()
	_check(Skills.base_level("fishing") == 5 and gained.size() == 5, "2150 XP: Fishing 5 after sleep")
	_check(Skills.pending.size() == 1 and Skills.options("fishing", 5) == ["angler", "trapper"], "level 5 offers Angler or Trapper")
	var cod_before := Economy.sell_price("fish_cod")
	_check(Skills.choose("fishing", "angler") and Skills.has_profession("angler"), "the keeper becomes an Angler")
	_check(Economy.sell_price("fish_cod") == int(round(cod_before * 1.25)), "Angler: fish +25%")
	_check(not Skills.choose("fishing", "trapper"), "only one profession per level")
	Skills.add_xp("fishing", 15000)
	Skills.apply_levels()
	_check(Skills.options("fishing", 10) == ["pier_legend", "quiet_hand"], "level 10 offers the Angler's branches")
	Skills.choose("fishing", "pier_legend")
	_check(Economy.sell_price("fish_cod") == int(round(cod_before * 1.5)), "Pier legend: fish +50% instead of +25%")
	var saved := JSON.stringify(Skills.serialize())
	Skills.reset()
	Skills.deserialize(JSON.parse_string(saved))
	_check(Skills.has_profession("pier_legend") and Skills.base_level("fishing") == 10, "professions survive a save")
	# prices
	Skills.professions = {"crafting": ["craftsman", "cooper"], "farming": ["herder", "down_keeper"]}
	_check(Economy.sell_price("cheese") == int(round(230 * 1.4)), "Cooper: artisan goods +40%")
	_check(Economy.sell_price("egg") == int(round(50 * 1.6)), "Herder and Down-keeper: eggs +60%")
	Inventory.add("sea_glass_ring", 1)
	Game.equip("sea_glass_ring")
	_check(Economy.sell_price("amber") == int(round(150 * 1.1)), "the sea-glass ring: finds +10%")
	# the light
	Skills.levels["keeping"] = 7
	Skills.professions = {"keeping": ["fire_keeper", "lighthouse_eye"]}
	_check(Lighthouse.keeper_bonus() == 22, "Keeping 7 + Fire keeper 5 + Lighthouse eye 10")
	# notes of 26.1
	_fresh()
	Farm.till(Vector2i(0, 0))
	Inventory.add("seed_turnip", 1)
	Farm.plant(Vector2i(0, 0), "seed_turnip")
	var tile := Farm.get_tile(Vector2i(0, 0))
	tile["ready"] = true
	var land := Knowledge.land_pts
	Farm.harvest(Vector2i(0, 0))
	_check(Knowledge.land_pts == land + 2, "a new crop is two land notes")
	land = Knowledge.land_pts
	Inventory.forage("heather", 7)
	Inventory.forage("heather", 7)
	_check(Knowledge.land_pts == land + 1, "a new kind of find is one land note, once")
	land = Knowledge.land_pts
	Inventory.add("milk", 1)
	Knowledge.unlock("Z5")
	Knowledge.unlock("Z8")
	var churn := Crafting._add("cape", "butter_churn", 20, 20)
	Crafting.start(churn, "churn_butter")
	Clock.day_index += 1
	Crafting.collect(churn)
	_check(Knowledge.land_pts == land + 2, "a new artisan good is two land notes")
	Clock.day_index = 12
	land = Knowledge.land_pts
	Knowledge._on_map_entered("village")
	Knowledge._on_map_entered("village")
	_check(Knowledge.land_pts == land + 2, "the Boat Launch visited: two land notes, once")
	# the tree
	Knowledge.sea_pts = 100
	Knowledge.land_pts = 100
	Knowledge.rest_pts = 100
	for id in ["R2", "R17", "Z2", "R10", "T4", "T5"]:
		_check(Knowledge.unlock_node(id), "node %s opens with enough notes" % id)
	_check(Knowledge.blocked_reason("S2") == "story", "S2 waits for the story")
	_check(Knowledge.blocked_reason("Z9") == "story", "the sea garden needs a boat")
	Sea.set_boat("yalik")
	_check(Knowledge.blocked_reason("Z9") == "", "with the skiff the sea garden can open")
	_check(Inventory.count_of("forge") == 1 and Inventory.count_of("glass_furnace") == 1, "station nodes hand over the station")
	_check(Data.all("knowledge_tree").size() >= 90, "the whole tree of 26.2 is in the data")


# 21.5: Ilm builds one thing at a time, from the day after payment; each building does its job.
func _check_buildings() -> void:
	_fresh()
	var offer := Economy.shop_stock("shop_ilm").filter(func(e: Dictionary) -> bool: return e.has("building"))
	var ids: Array = offer.map(func(e: Dictionary) -> String: return str(e["building"]))
	_check("house" in ids and "well" in ids and not "coop" in ids, "Ilm offers the house and the well; the coop needs Z3")
	Economy.money = 200000
	_check(Buildings.place_order("house") == "materials", "the house needs 450 boards")
	Inventory.add("boards", 999)
	Inventory.add("stone", 999)
	_check(Buildings.place_order("house") == "ok" and Economy.money == 190000 and Inventory.count_of("boards") == 549,
		"house level 1: 10 000 crowns and 450 boards")
	_check(Buildings.place_order("well") == "busy", "one building at a time")
	for night in 3:
		Clock.day_index += 1
		_check(Buildings.night() == "", "not finished on night %d" % (night + 1))
	Clock.day_index += 1
	var mail_before := Mail.letters.size()
	_check(Buildings.night() == "house" and Buildings.level("house") == 1, "the house is ready on the 4th morning (3 days from the next day)")
	_check(Mail.letters.size() == mail_before + 1 and str(Mail.letters[-1]["items"][0][0]) == "kitchen_stove", "the kitchen stove arrives with it")
	Inventory.add("amber_ring", 1)
	var ring := -1
	for i in Inventory.capacity:
		if str(Inventory.slots[i]["id"]) == "amber_ring":
			ring = i
	_check(str(Relationships.give("npc_hedda", ring).get("reason", "")) != "house", "with a house the ring is no longer refused for want of one")
	# graveyard extension, ice house, greenhouse
	_check(Buildings.place_order("graveyard_ext") == "ok", "the graveyard extension")
	Clock.day_index += 3
	Buildings.night()
	_check(Graveyard.graves.size() == 24 and Graveyard.block_count() == 2, "24 plots in two blocks")
	_check(Graveyard.plot_position(12).x > Graveyard.plot_position(3).x, "the new block lies east of the old one")
	Knowledge.unlock("P7")
	Knowledge.unlock("P10")
	Inventory.add("iron_ingot", 20)
	_check(Buildings.place_order("ice_house") == "ok", "the ice house after P10")
	Clock.day_index += 4
	Buildings.night()
	var b := {"id": "t", "where": "morgue", "preservation": 100.0, "arrived": Clock.day_index, "restless": false}
	Graveyard.bodies.append(b)
	Graveyard.advance_night(false)
	_check(is_equal_approx(float(b["preservation"]), 98.0), "in the ice house bodies lose 2 a day")
	Graveyard.bodies.erase(b)
	Knowledge.unlock("Z2")
	Knowledge.unlock("Z7")
	Knowledge.unlock("Z13")
	Inventory.add("glass", 30)
	_check(Buildings.place_order("greenhouse_small") == "ok", "the small greenhouse after Z13")
	Clock.day_index += 4
	Buildings.night()
	_check(Farm.opened.has("greenhouse_small"), "the greenhouse plot opens")
	Clock.day_index = 84 + 3
	_check(Clock.season == "winter", "winter")
	_check(Farm.till(Vector2i(1, 1), "greenhouse_small"), "the greenhouse soil can be tilled")
	Inventory.add("seed_rhubarb", 1)
	_check(Farm.plant(Vector2i(1, 1), "seed_rhubarb", "greenhouse_small"), "spring rhubarb grows in a winter greenhouse")
	_check(not Farm.plant(Vector2i(0, 0), "seed_rhubarb"), "but not outdoors")
	for day in 14:
		Farm.water(Vector2i(1, 1), "greenhouse_small")
		Farm.advance_day(day == 3)
	_check(bool(Farm.get_tile(Vector2i(1, 1), "greenhouse_small")["ready"]), "storms do not reach inside the greenhouse")
	# the hayloft and the Ilm discount
	Knowledge.unlock("Z4")
	Buildings.place_order("hayloft")
	Clock.day_index += 3
	Buildings.night()
	_check(Buildings.hay_capacity() == 240 and Buildings.mow(0.1) == 1 and Buildings.mow(0.9) == 0, "the scythe fills the hayloft half the time")
	Inventory.add("hay", 10)
	_check(Buildings.store_feed("hay", 10) == 10 and Buildings.hay == 11, "hay goes into the hayloft")
	var price := int(Buildings.next_level_info("well")["price"])
	Relationships.set_hearts("npc_ilm", 6)
	_check(int(Buildings.next_level_info("well")["price"]) == int(round(price * 0.9)), "Ilm at 6 hearts: 10% off")
	# the workshop and its interior
	Knowledge.unlock("R6")
	Knowledge.unlock("R16")
	Inventory.add("boards", 300)
	var workshop_reason := Buildings.place_order("workshop")
	_check(workshop_reason == "ok", "the workshop after R16: " + workshop_reason)
	Clock.day_index += 4
	Buildings.night()
	_check(MapInfo.is_interior("cape_workshop") and Mail.letters[-1]["items"][0][0] == "mill", "the workshop brings the mill")
	Inventory.add("mill", 1)
	Inventory.select_hotbar(0)
	for i in Inventory.HOTBAR:
		if str(Inventory.slots[i]["id"]) == "mill":
			Inventory.select_hotbar(i)
	_check(Crafting.place_selected("cape_workshop", Vector2(40, 40)) and Crafting.objects("cape_workshop", "mill").size() == 1,
		"stations stand in the workshop")
	# saves
	var saved := JSON.stringify(Buildings.serialize())
	Buildings.reset()
	Buildings.deserialize(JSON.parse_string(saved))
	_check(Buildings.level("house") == 1 and Buildings.level("workshop") == 1 and Buildings.hay == 11, "buildings survive a save")


# 14: animals from Margit, fed from the hayloft, petted, their products in the box; 13.9 trees; 13.10 sea garden.
func _check_farm_life() -> void:
	_fresh()
	Economy.money = 100000
	_check(Animals.buy("chicken") == "home", "no chickens without a coop")
	Buildings.levels["coop"] = 1
	Buildings.levels["hayloft"] = 1
	_check(Animals.buy("duck") == "home", "ducks need coop level 2")
	for n in 4:
		_check(Animals.buy("chicken") == "ok", "chicken %d" % (n + 1))
	_check(Animals.buy("chicken") == "home", "coop level 1 holds 4")
	var land := Knowledge.land_pts
	_check(land == 3, "a new kind of animal is 3 land notes (once)")
	Buildings.hay = 3
	Clock.day_index = 1
	var night := Animals.night("clear")
	_check(int(night["products"]) == 3 and int(night["hungry"]) == 1 and Buildings.hay == 0, "three fed hens lay, the fourth goes hungry")
	_check(Animals.box_count("coop") == 3, "eggs wait in the coop box")
	var eggs := Animals.collect("coop")
	_check(eggs == 3 and Inventory.count_matching("tag:egg") == 3, "collecting the eggs")
	var hen: Dictionary = Animals.herd[0]
	_check(Animals.pet(int(hen["id"])) and not Animals.pet(int(hen["id"])) and int(hen["friendship"]) == 15, "petting: +15 once a day")
	hen["friendship"] = 900
	Buildings.hay = 10
	var big := 0
	for day in range(2, 30):
		Clock.day_index = day
		Animals.night("clear")
	for entry in Animals.boxes.get("coop", []):
		if str(entry[0]) == "egg_large":
			big += int(entry[1])
	_check(big > 0, "a hen with 200+ friendship lays large eggs")
	# the barn, the pasture and manure
	Buildings.levels["barn"] = 1
	_check(Animals.buy("cow") == "ok" and Animals.buy("sheep") == "ok", "a cow and a sheep in the barn")
	Buildings.hay = 0
	Buildings.levels["pasture"] = 1
	Clock.day_index = 30
	Animals.night("clear")
	var sheep: Dictionary = Animals.herd.filter(func(a: Dictionary) -> bool: return str(a["kind"]) == "sheep")[0]
	_check(int(sheep["fed"]) == 30, "the sheep grazes seaweed on the pasture without hay")
	Buildings.hay = 5
	for day in range(31, 36):
		Clock.day_index = day
		Animals.night("clear")
	_check(Animals.boxes.get("barn", []).any(func(e: Array) -> bool: return str(e[0]) == "manure"), "the barn gathers manure")
	_check(Animals.boxes.get("barn", []).any(func(e: Array) -> bool: return str(e[0]) == "wool"), "wool every 3 days")
	# eider and nest box, pony
	Clock.day_index = 25
	Crafting._add("cape", "eider_nest", 900, 800)
	_check(Animals.buy("eider") == "ok", "an eider settles into the nest box after Bird Day")
	Clock.day_index = 26
	Animals.night("clear")
	var nest: Dictionary = Crafting.objects("cape", "eider_nest")[0]
	_check(Animals.collect_nest(nest) == 1 and Inventory.count_of("eider_down") == 1, "eider down once a spring")
	Buildings.levels["stable"] = 1
	Clock.day_index = 29
	_check(Animals.buy("pony") == "ok" and Animals.has_pony(), "a pony from Summer 1")
	var saved := JSON.stringify(Animals.serialize())
	Animals.reset()
	Animals.deserialize(JSON.parse_string(saved))
	_check(Animals.herd.size() == 8 and Animals.has_pony(), "animals survive a save")
	# trees on the cape; cloudberries only on the bog
	_empty_inventory()
	Inventory.add("cloudberry_bush", 1)
	Inventory.add("sapling_apple", 1)
	Inventory.select_hotbar(0)
	_check(not Crafting.place_selected("cape", Vector2(1200, 900)), "cloudberries need the bog")
	var bog := Crafting._add("cape", "tree", 1200, 880)
	bog["tree"] = "bog_cranberry"
	_check(Crafting.place_selected("cape", Vector2(1210, 900)), "a cloudberry bush on the cranberry bog")
	Inventory.select_hotbar(1)
	_check(Crafting.place_selected("cape", Vector2(300, 300)) and Crafting.objects("cape", "tree").size() == 3, "an apple tree planted")
	# the sea garden
	_empty_inventory()
	var patch := SeaGarden.area()
	var spot := Vector2(patch.position.x * 16 + 24, (patch.position.y + 2) * 16 + 8)
	Inventory.add("kelp_line", 1)
	Inventory.add("oyster_cage", 1)
	_check(SeaGarden.place("kelp_line", Vector2(5, 60) * 16) == "area", "only inside the patch by the pier")
	_check(SeaGarden.place("kelp_line", spot) == "ok" and SeaGarden.place("oyster_cage", spot) == "taken", "one object per tile")
	var line: Dictionary = Sea.sea_garden[0]
	Clock.day_index = 28 + 11
	SeaGarden.night(false)
	_check(not bool(line["ready"]) and SeaGarden.work(line).begins_with("Растёт"), "kelp takes 12 days")
	Clock.day_index = 28 + 13
	SeaGarden.night(false)
	var kelp_before := Inventory.count_of("kelp")
	_check(SeaGarden.work(line).begins_with("Собрано") and Inventory.count_of("kelp") - kelp_before >= 5, "5-8 kelp from a line")
	_check(int(line["next"]) == Clock.day_index + 6, "then every 6 days")
	var torn := 0
	for day in 60:
		Clock.day_index += 1
		line["broken"] = false
		SeaGarden.night(true)
		torn += 1 if bool(line["broken"]) else 0
	_check(torn > 0 and torn < 20, "storms tear objects loose about one time in ten (%d of 60)" % torn)
	line["broken"] = true
	_check(SeaGarden.work(line).begins_with("Сорвано"), "a torn line needs a thread")
	Inventory.add("thread", 1)
	_check(SeaGarden.work(line) == "Починено." and not bool(line["broken"]), "a thread mends it")
	Clock.day_index = 84 + 1
	Inventory.add("kelp_line", 1)
	SeaGarden.place("kelp_line", spot + Vector2(16, 0))
	_check(int(Sea.sea_garden[-1]["next"]) - Clock.day_index == 24, "in winter kelp grows half as fast")


# Runs a process recipe `times` times on a station (placed if needed), lets the time pass and collects.
func _work(station_id: String, recipe_id: String, times: int = 1) -> int:
	var list := Crafting.objects("cape", station_id)
	var obj: Dictionary = list[0] if not list.is_empty() else Crafting._add("cape", station_id, 64 + Crafting.placed["cape"].size() * 24, 1000)
	var done := 0
	for n in times:
		var info := Crafting.station(station_id)
		for fuel in info.get("fuel", []):
			Inventory.add(str(fuel[0]) if fuel is Array else str(fuel), int(fuel[1]) if fuel is Array else 1)
			break
		if Crafting.start(obj, recipe_id) != "ok":
			break
		Clock.day_index += 6
		done += Crafting.collect(obj)
	return done


# 19.3: the twelve production chains, from what the island gives to what the keeper uses.
func _check_chains() -> void:
	_fresh()
	Inventory.upgrade_capacity(36)
	Knowledge.sea_pts = 999
	Knowledge.land_pts = 999
	Knowledge.rest_pts = 999
	for id in ["M2", "M3", "M4", "M7", "M8", "R2", "R17", "Z2", "R10", "R3", "R4", "R5", "R6", "R8", "R9", "P3", "P4", "P6", "P11",
			"R11", "R12", "R13", "R14", "Z3", "Z5", "Z8", "Z6", "P5", "T4", "T5", "S7", "Z7"]:
		Knowledge.unlock(id)
	Skills.levels["fishing"] = 1
	# 1. Light: fish -> guts -> fish oil -> whale oil -> the reservoir
	Inventory.add("fish_cod", 10)
	Crafting.make("cut_fillet", 10, "cutting_table")
	_check(_work("renderer", "render_oil", 2) == 2 and _work("settling_tank", "settle_whale_oil") == 1, "chain 1: guts -> oil -> whale oil")
	_check(Lighthouse.refill("whale_oil") == 1 and Lighthouse.fuel_type == "whale_oil", "chain 1: whale oil in the reservoir")
	# 2. Lenses: kelp ash + sand -> glass; pumice -> abrasive; prisms; copper + zinc -> brass -> frame; the lens goes in
	Inventory.add("kelp", 20)
	_check(_work("drying_rack", "dry_kelp", 20) == 20 and _work("ash_kiln", "burn_kelp_ash", 4) == 4 and Inventory.count_of("kelp_ash") == 8,
		"chain 2: 20 kelp -> dried -> 8 ash")
	var row0 := Sea.first_row("seal_shore")
	while Inventory.count_of("sand") < 16:
		Crafting.dig_sand("seal_shore", Vector2(20 * 16 + 8, (row0 - 1) * 16 + 8))
	_check(_work("glass_furnace", "melt_glass", 8) == 8 and Inventory.count_of("glass") == 8, "chain 2: sand + ash -> 8 glass")
	Inventory.add("pumice", 8)
	Crafting.make("craft_abrasive_pumice", 8, "workbench")
	for n in 8:
		Crafting.make("craft_abrasive_pumice")
	_check(_work("optical_bench", "grind_prism", 8) == 8 and Inventory.count_of("prism") == 8, "chain 2: 8 prisms")
	Inventory.add("copper_ingot", 6)
	Inventory.add("zinc", 3)
	_work("forge", "alloy_brass", 3)
	_check(Inventory.count_of("brass") == 6 and _work("forge", "forge_frame_small") == 1, "chain 2: brass -> the small frame")
	_check(_work("optical_bench", "assemble_fresnel_4") == 1 and Lighthouse.install_part("lens_fresnel_4") == "ok"
		and Lighthouse.components()["lens"] == 15, "chain 2: the 4th-order Fresnel lens shines with 15")
	# 3. Metal: wreck scrap -> ingots -> nails
	Inventory.add("iron_scrap", 4)
	_check(_work("forge", "smelt_iron", 2) == 2 and _work("forge", "forge_nails") == 1 and Inventory.count_of("nails") >= 20,
		"chain 3: scrap -> ingots -> 20 nails")
	# 4. Canvas: flax -> fibre -> thread -> canvas -> oiled canvas -> oilskin
	Inventory.add("flax", 6)
	_work("scutcher", "scutch_flax", 6)
	_work("spinning_wheel", "spin_thread", 6)
	_check(Inventory.count_of("thread") >= 6 and _work("loom", "weave_canvas", 2) == 2, "chain 4: flax -> thread -> canvas")
	Inventory.add("whale_oil", 2)
	Crafting.make("craft_oiled_canvas")
	Crafting.make("craft_oiled_canvas")
	_check(Crafting.make("craft_storm_coat") == "ok" and Inventory.count_of("storm_coat") == 1, "chain 4: oiled canvas -> oilskin")
	# 5. Wood: driftwood -> boards -> a simple coffin
	Inventory.add("driftwood", 12)
	Crafting.make("saw_driftwood", 4, "sawhorse")
	_check(Inventory.count_of("boards") >= 8 and _work("carpentry_table", "carpentry_coffin_simple") == 1
		and Inventory.count_of("coffin_simple") == 1, "chain 5: driftwood -> boards -> coffin")
	# 6. Stone: stones -> blocks -> slab and headstone
	Inventory.add("stone", 50)
	Inventory.add("fish_squid", 1)
	Crafting.make("cut_squid", 1, "cutting_table")
	_work("stonecutter_table", "cut_stone_block", 5)
	_check(_work("stonecutter_table", "cut_stone_slab") == 1 and _work("stonecutter_table", "cut_headstone") == 1,
		"chain 6: stone -> blocks -> slab and headstone (squid ink)")
	# 7. Salt: seawater -> salt -> brined herring
	Crafting.scoop_seawater("seal_shore", Vector2(20 * 16 + 8, (row0 + 8) * 16 + 8), 5)
	_check(_work("salt_pan", "boil_salt") == 1 and Inventory.count_of("salt") >= 3, "chain 7: 5 buckets of sea -> 3 salt")
	Inventory.add("fish_herring", 5)
	_check(_work("brine_barrel", "brine_herring") == 1 and Inventory.count_of("salted_herring") == 5, "chain 7: salted herring")
	# 8. Fish goods: fillet -> smoked fish; cod on the racks -> stockfish -> lutefisk
	Inventory.add("salt", 2)
	Inventory.add("fish_cod", 1)
	_check(_work("smokehouse", "smoke_fillet") == 1 and _work("drying_rack", "dry_cod") == 1, "chain 8: smoked fish and stockfish")
	Inventory.add("kelp_ash", 1)
	Crafting.learn("cook_lutefisk")
	_check(Crafting.make("cook_lutefisk", 1, "kitchen_stove") == "ok", "chain 8: Helga's lutefisk")
	# 9. Milk and wool
	Inventory.add("milk", 2)
	Inventory.add("wool", 5)
	_check(_work("butter_churn", "churn_butter") == 1 and _work("cheese_press", "press_cheese") == 1, "chain 9: butter and cheese")
	_work("spinning_wheel", "spin_yarn", 5)
	Crafting.learn("craft_keeper_sweater")
	_check(Crafting.make("craft_keeper_sweater") == "ok", "chain 9: wool -> yarn -> the keeper's sweater")
	# 10. Drinks: ale, wine, aquavit aged in the cellar
	Inventory.add("barley", 3)
	Inventory.add("hops", 1)
	Inventory.add("cloudberry", 5)
	Inventory.add("potato", 5)
	Inventory.add("dill", 1)
	_check(_work("brewery", "brew_ale") == 1 and _work("wine_vat", "vat_wine_cloudberry") == 1 and _work("still", "distill_aquavit") == 1,
		"chain 10: ale, cloudberry wine, aquavit")
	var cask := Crafting._add("cape", "cellar_barrel", 64, 64)
	for i in Inventory.capacity:
		if str(Inventory.slots[i]["id"]) == "aquavit":
			Crafting.store(cask, i)
	Clock.day_index += 56
	Crafting.night("clear")
	Crafting.retrieve(cask, 0)
	_check(_quality_of("aquavit") == 3, "chain 10: 56 days in the cellar make flawless aquavit")
	# 11. Candles: wax from the hive, tallow from fish oil
	Inventory.add("beeswax", 1)
	Inventory.add("fish_oil", 1)
	Inventory.add("thread", 2)
	_check(_work("candle_mold", "mold_wax_candles") == 1 and _work("candle_mold", "mold_tallow_candles") == 1
		and Inventory.count_of("wax_candle") >= 2 and Inventory.count_of("tallow_candle") == 2, "chain 11: wax and tallow candles")
	# 12. Light water: lightflower + glowing plankton + glass -> the herbalist's table -> lighthouse fuel
	Knowledge.unlock("T6")
	Knowledge.unlocked["T6"] = true
	Inventory.add("lightflower", 2)
	Inventory.add("glow_plankton", 1)
	Inventory.add("glass", 1)
	_check(_work("herbal_table", "brew_light_water") == 1, "chain 12: light water brewed")
	Lighthouse.fuel_nights = 0.0
	Lighthouse.fuel_type = ""
	_check(Lighthouse.refill("light_water") == 1 and is_equal_approx(Lighthouse.fuel_nights, 4.0), "chain 12: light water burns 4 nights")


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
	_check_skills()
	_check_buildings()
	_check_farm_life()
	_check_chains()
	print("M7 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
