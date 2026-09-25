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
	for section in ["_check_field", "_check_tools", "_check_boards", "_check_rescue", "_check_graveyard"]:
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


# 21.2: the tavern's errands, the week's demand and the week's big order.
func _check_boards() -> void:
	_fresh()
	var counts := {}
	for day in 28:
		var list := Boards.posted(day)
		counts[list.size()] = true
		for notice in list:
			_check(int(notice["due"]) == day + 1 and int(notice["reward"]) >= 80, "an errand lasts 2 days and pays")
	_check(counts.has(1) and counts.has(2) and not counts.has(0) and not counts.has(3), "1-2 errands a day")
	_check(JSON.stringify(Boards.posted(3)) == JSON.stringify(Boards.posted(3)), "the board is the same all day")
	_goto(5)
	var notice: Dictionary = Boards.posted()[0]
	var npc := str(notice["npc"])
	_check(Boards.take(notice) and not Boards.take(notice) and Boards.taken(notice), "an errand is taken once")
	_check(Boards.npc_options(npc).size() == 1 and Story.npc_options(npc).has(Boards.npc_options(npc)[0]), "the asker offers to take it")
	var before := int(Relationships.points.get(npc, 0))
	var money := Economy.money
	_check(Story.npc_action(npc, "errand:0").contains("не хватает"), "empty hands are refused")
	Inventory.add(str(notice["item"]), int(notice["count"]))
	Story.npc_action(npc, "errand:0")
	_check(Economy.money == money + int(notice["reward"]) and str(Boards.errands[0]["state"]) == "done", "the errand pays")
	_check(int(Relationships.points.get(npc, 0)) == before + 150 and Game.stat("errands_done") == 1, "and +150 friendship")
	# A late one lapses overnight.
	var second: Dictionary = Boards.posted(6)[0]
	_goto(6)
	Boards.take(second)
	_goto(8)
	Boards.night()
	_check(str(Boards.errands[1]["state"]) == "late" and Boards.npc_options(str(second["npc"])).is_empty(), "a late errand lapses")
	# The week's demand: +25% on one category.
	_goto(14)
	var cat := Boards.demand()
	var probe := ""
	for item in Data.all("items"):
		if str(item.get("category", "")) == cat and int(item.get("price", 0)) >= 100:
			probe = str(item["id"])
			break
	var base := int(Data.by_id("items", probe).get("price", 0))
	_check(probe != "" and Economy.sell_price(probe) >= int(round(base * 1.25)) - 1, "the week's demand pays 25%% more (%s)" % cat)
	_check(Boards.demand(14) == Boards.demand(20) and Boards.week_of(20) == 14, "the demand lasts the week")
	# The big order.
	var order := Boards.order()
	var price := int(Data.by_id("items", str(order["item"])).get("price", 0))
	_check(int(order["reward"]) >= int(price * int(order["count"]) * 1.3), "the big order pays about 1.5x")
	Inventory.add(str(order["item"]), int(order["count"]) - 1)
	_check(Boards.hand_in_order().begins_with("Принято") and Boards.order_given == int(order["count"]) - 1, "part of an order is handed in")
	money = Economy.money
	Inventory.add(str(order["item"]), 1)
	_check(Boards.hand_in_order().begins_with("Заказ выполнен") and Economy.money == money + int(order["reward"]), "the order pays once complete")
	_check(Boards.hand_in_order().contains("закрыт"), "only once a week")
	_goto(21)
	_check(not Boards.order_text().contains("Оплачен"), "a new week, a new order")
	var back: Dictionary = JSON.parse_string(JSON.stringify(Boards.serialize()))
	Boards.deserialize(back)
	_check(Boards.errands.size() == 2 and str(Boards.errands[0]["state"]) == "done", "the boards are saved")


# A wreck of `bodies` sailors tonight (the ship loop's own path).
func _wreck(bodies: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var entry := {"name": "ship.test", "type": "schooner"}
	Lighthouse._wreck(entry, {"bodies": [bodies, bodies], "crates": [0, 0], "crate": "cargo_merchant"}, rng)
	return Lighthouse.wrecks[Lighthouse.wrecks.size() - 1]


# 10.12: the rescue station's bell, the boat and the ring, the crew, the guests at the tavern, the Rescuer.
func _check_rescue() -> void:
	_fresh()
	_goto(10)
	_wreck(3)
	_check(Rescue.night(10, true) == 0 and Lighthouse.rescue_pending.is_empty(), "no station, no bell")
	Game.set_flag("rescue_station")
	Graveyard.incoming.clear()
	Lighthouse.wrecks.clear()
	_wreck(3)
	_check(Rescue.survivors("ship.test") == 3, "three in the water")
	Rescue.night(10, true)
	var wreck := Rescue.pending()
	_check(not wreck.is_empty() and str(wreck["ship"]) == "ship.test", "asleep in the watch room, the bell wakes the keeper")
	var game := Rescue.game_for(wreck)
	_check(game is TimingGame and (game as TimingGame).rounds == 3, "one throw of the ring per sailor")
	var honor := Game.honor
	var mercy := Sea.mercy
	_check(Rescue.resolve(wreck, 2) == 2 and Rescue.survivors("ship.test") == 1, "each hit saves one: one body fewer")
	_check(Game.honor == honor + 20 and is_equal_approx(Sea.mercy, minf(mercy + 6.0, 100.0)), "+10 honour and +3 mercy each")
	_check(Lighthouse.rescue_guests.size() == 2 and Rescue.pending().is_empty(), "the saved stay at the tavern")
	# The guests send thanks once, then leave after 3 days.
	var letters := Mail.letters.size()
	Rescue.guests_night()
	_check(Mail.letters.size() == letters + 2 and not (Mail.letters[letters]["items"] as Array).is_empty(), "each guest sends a gift")
	Rescue.guests_night()
	_check(Mail.letters.size() == letters + 2, "only once")
	_goto(14)
	Rescue.guests_night()
	_check(Lighthouse.rescue_guests.is_empty(), "after 3 days they sail home")
	# Asleep at home: the crew, 30% + 5% per Seafaring level.
	Graveyard.incoming.clear()
	Lighthouse.wrecks.clear()
	_goto(20)
	Skills.levels["seafaring"] = 6
	var saved := 0
	var total := 0
	for n in 30:
		Graveyard.incoming.clear()
		Lighthouse.wrecks.clear()
		Clock.day_index = 20 + n
		_wreck(4)
		total += 4
		saved += Rescue.night(Clock.day_index, false)
	var share := float(saved) / float(total)
	var expect := Rescue.crew_chance()
	_check(absf(share - expect) < 0.15, "the crew saves about %.0f%% (%.2f)" % [expect * 100.0, share])
	_check(Lighthouse.rescue_pending.is_empty(), "no bell for a keeper asleep at home")
	# The Rescuer: two more saved, double rewards.
	Graveyard.incoming.clear()
	Lighthouse.wrecks.clear()
	Lighthouse.rescue_guests.clear()
	Skills.professions["seafaring"] = ["skipper", "rescuer"]
	_goto(60)
	_wreck(1)
	Rescue.night(60, true)
	honor = Game.honor
	Rescue.resolve(Rescue.pending(), 1)
	_check(Lighthouse.rescue_guests.size() == 3 and Game.honor == mini(honor + 20, 100), "the Rescuer brings two more and doubles honour")
	var back: Dictionary = JSON.parse_string(JSON.stringify(Lighthouse.serialize()))
	Lighthouse.deserialize(back)
	_check(Lighthouse.rescue_guests.size() == 3, "the guests are saved")


func _bury(b: Dictionary) -> int:
	for plot in Graveyard.graves.size():
		var g: Dictionary = Graveyard.graves[plot]
		if bool(g["old"]) or str(g["body"]) != "" or bool(g["filled"]):
			continue
		g["open"] = true
		Graveyard.carried = str(b["id"])
		b["where"] = "carried"
		if Graveyard.lay(plot) and Graveyard.fill(plot):
			return plot
	return -1


# 11.5/11.6/11.11: beauty of flowers and rowans, the morgue's upgrades, the bell, the Peace effects, epitaphs.
func _check_graveyard() -> void:
	_fresh()
	var inside := Graveyard.block_origin(0) + Vector2(40, 40)
	var before := Graveyard.beauty()
	Crafting.placed["cape"].append({"uid": 900, "id": "decor", "item": "armeria", "x": inside.x, "y": inside.y, "queue": []})
	Crafting.placed["cape"].append({"uid": 901, "id": "decor", "item": "heather", "x": inside.x + 16, "y": inside.y, "queue": []})
	_check(is_equal_approx(Graveyard.beauty(), before + 1.0), "armeria and heather add 0.5 each")
	Crafting.placed["cape"].append({"uid": 902, "id": "tree", "tree": "tree_rowan", "grown": true, "x": inside.x + 32, "y": inside.y, "queue": []})
	_check(is_equal_approx(Graveyard.beauty(), before + 3.0), "a grown rowan adds 2")
	_check(str(Data.by_id("items", "armeria").get("place", "")) == "decor", "flowers can be planted")
	# The morgue's upgrades.
	var reg := Graveyard._person(Graveyard._rng(3), "schooner", "ship.test")
	var b := Graveyard.spawn_body(reg, "cape")
	b["where"] = "morgue"
	b["items"] = ["sea_glass"]
	_check(not Graveyard.wash(b), "no bucket, no washroom: no washing")
	_check(Graveyard.search(b, false).is_empty() and not bool(b["searched"]), "no cabinet: the things stay on the body")
	_check(not Graveyard.build_upgrade("morgue_washroom"), "the washroom needs stone and iron")
	Inventory.add("stone", 10)
	Inventory.add("iron_ingot", 2)
	_check(Graveyard.build_upgrade("morgue_washroom") and Inventory.count_of("stone") == 0 and Graveyard.wash(b), "the washroom washes without a bucket")
	Inventory.add("boards", 15)
	_check(Graveyard.build_upgrade("morgue_cabinet") and Graveyard.search(b, false) == ["sea_glass"], "the cabinet keeps the things")
	Inventory.add("brass", 1)
	Inventory.add("glass", 1)
	Inventory.add("boards", 5)
	_check(Graveyard.build_upgrade("morgue_lamp_table") and Game.flag("morgue_lamp_table"), "the lamp table is built")
	Inventory.add("bronze", 5)
	_check(Graveyard.build_upgrade("graveyard_bell") and not Graveyard.build_upgrade("graveyard_bell"), "the bell is cast once")
	var letters := Mail.letters.size()
	_check(Graveyard.ring_bell([b["id"]]) and Mail.letters.size() == letters + 1 and not Graveyard.ring_bell([]), "the bell rings when the sea brings someone")
	# Peace below 20: crops by the graveyard wither now and then; 40-59: quiet sleep; 60+: fewer Hmar creatures.
	Graveyard.peace = 5.0
	_check(Graveyard.near_graveyard(Farm.tile_center(Vector2i(0, 0), "field_s"), 160.0) and not Graveyard.near_graveyard(Farm.tile_center(Vector2i(0, 0)), 160.0),
		"10 tiles around the graveyard: the shore field, not Agatha's beds")
	for x in 10:
		for y in 4:
			var cell := Vector2i(x, y)
			Farm.clutter.erase(Farm._key(cell, "field_s"))
			Farm.till(cell, "field_s")
			Farm.tiles[Farm._key(cell, "field_s")]["crop"] = "crop_turnip"
			Farm.tiles[Farm._key(cell, "field_s")]["growth"] = 5.0
	var hits := 0
	for night in 10:
		Clock.day_index += 1
		hits += Graveyard.unrest_night()
	_check(hits > 0, "unrest withers crops by the graveyard (%d)" % hits)
	Graveyard.peace = 30.0
	_check(Graveyard.unrest_night() == 0, "no unrest at 20+")
	Graveyard.peace = 50.0
	var quiet := 0
	for n in 200:
		if Graveyard.quiet_sleep(n):
			quiet += 1
	_check(quiet > 20 and quiet < 60, "quiet sleep about 20%% of mornings (%d/200)" % quiet)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var full := LandFoes.spawns("cape", rng).size()
	Graveyard.peace = 65.0
	rng.seed = 3
	var half := LandFoes.spawns("cape", rng).size()
	Graveyard.peace = 85.0
	rng.seed = 3
	_check(half < full and half >= 3 and LandFoes.spawns("cape", rng).is_empty(), "Peace 60+ halves the cape's Hmar, 80+ keeps it away (%d → %d)" % [full, half])
	Graveyard.laid_ghosts.append("ghost_pim")
	_goto(7)
	letters = Mail.letters.size()
	_check(Graveyard.weekly_ghost_gift() and Mail.letters.size() == letters + 1, "80+: a ghost's gift on Monday")
	_goto(8)
	_check(not Graveyard.weekly_ghost_gift(), "once a week")
	# Epitaphs on a headstone for a named body.
	b["identified_as"] = str(reg["id"])
	var plot := _bury(b)
	Inventory.add("headstone", 1)
	_check(plot >= 0 and Graveyard.place_marker(plot, "headstone"), "a headstone for a named grave")
	var options := Graveyard.epitaph_options(plot)
	_check(options.size() == 3 and str(options[0]["text"]).contains(str(reg["name"])), "three epitaphs from the person's story")
	Inventory.add("epitaph_book", 1)
	options = Graveyard.epitaph_options(plot)
	_check(options.size() == 5 and str(options[4]["style"]) == "masterpiece", "the Book of Epitaphs adds two, one a masterpiece")
	Game.set_flag("twenty_buried")
	Game.set_flag("elmo_bell")
	var peace_before := Graveyard.recalc_peace()
	_check(Graveyard.set_epitaph(plot, 4) and not Graveyard.set_epitaph(plot, 0), "the words are cut once")
	_check(peace_before > 0.0 and is_equal_approx(Graveyard.peace, minf(peace_before + 5.0, 100.0)), "a masterpiece: +5 Peace (%.1f → %.1f)" % [peace_before, Graveyard.peace])
	var back: Dictionary = JSON.parse_string(JSON.stringify(Graveyard.serialize()))
	Graveyard.deserialize(back)
	_check(str(Graveyard.graves[plot].get("epitaph", "")) != "" and bool(Graveyard.graves[plot].get("masterpiece", false)), "the epitaph is saved")
	Graveyard.extend_plots(24)
	back = JSON.parse_string(JSON.stringify(Graveyard.serialize()))
	Graveyard.deserialize(back)
	_check(Graveyard.graves.size() == 24, "an extended graveyard survives a load")
