extends Node

# Run with: godot --headless --path . res://tests/integration/test_m8.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh() -> void:
	Game.reset()
	Game.world_seed = 8
	Clock.reset()
	Weather.reset()
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Graveyard, Mail, Knowledge, Quests,
			Collections, Relationships, Cutscenes, NPCs, Buildings, Animals]:
		system.reset()
	Inventory.upgrade_capacity(36)


func _arena(seed_value: int) -> CombatWorld:
	return CombatWorld.new(seed_value, func(p: Vector2) -> bool: return Rect2(-400, -300, 800, 600).has_point(p))


# 17.4-17.5: hits, crits, invulnerability, dodges, behaviours and loot.
func _check_combat() -> void:
	_fresh()
	var w := _arena(3)
	var crab := w.spawn("crab", Vector2(20, 0))
	w.player["facing"] = Vector2.RIGHT
	var hit := w.attack("cutlass")
	_check(hit.size() == 1 and float(crab["hp"]) < 20.0, "a cutlass swing hits the crab in front")
	_check(w.attack("cutlass").is_empty(), "the next swing waits for the cooldown")
	var behind := w.spawn("jellyfish", Vector2(-20, 0))
	w.player["attack_cd"] = 0.0
	w.attack("cutlass")
	_check(float(behind["hp"]) == 10.0, "a swing does not reach behind")
	w.underwater = true
	_check(is_equal_approx(w.attack_cooldown("cutlass"), 0.55 * 1.2), "attacks are 20% slower underwater")
	w.player["invuln"] = 0.0
	_check(w.hurt_player(10, Vector2(10, 0)) and not w.hurt_player(10, Vector2(10, 0)), "0.5 s of invulnerability after a hit")
	w.player["invuln"] = 0.0
	w.player["dodge_cd"] = 0.0
	_check(w.dodge() and not w.hurt_player(10, Vector2(10, 0)) and not w.dodge(), "a dodge gives i-frames and has a cooldown")
	# hmar-things: weapons a quarter, the lantern four times
	var h := w.spawn("hmarnik", Vector2(20, 0))
	var hp0 := float(h["hp"])
	w.player["attack_cd"] = 0.0
	w.attack("oar")
	_check(hp0 - float(h["hp"]) <= 6.0 * 1.5 * 0.25 + 0.01, "weapons hurt a hmar-thing at a quarter")
	w.player["lantern"] = true
	for n in 20:
		w.step(0.1)
		w.player["pos"] = Vector2.ZERO
	_check(not w.enemies.has(h), "the lantern burns the hmar-thing away")
	w.player["lantern"] = false
	# armour: the helmeted crayfish only fears the back
	w = _arena(4)
	var cray := w.spawn("helmet_crayfish", Vector2(20, 0))
	cray["facing"] = Vector2.LEFT
	w.player["facing"] = Vector2.RIGHT
	w.attack("cutlass")
	var front := 80.0 - float(cray["hp"])
	cray["hp"] = 80.0
	cray["invuln"] = 0.0
	cray["pos"] = Vector2(20, 0)
	cray["facing"] = Vector2.RIGHT
	w.player["attack_cd"] = 0.0
	w.attack("cutlass")
	_check(front < 6.0 and 80.0 - float(cray["hp"]) > front * 2.5, "the crayfish's helmet takes the front blow (%.1f / %.1f)" % [front, 80.0 - float(cray["hp"])])
	# the silver cutlass and the drowned
	_check(w.weapon("silver_cutlass")["bonus"]["drowned"] == 0.5, "silver: +50% against the drowned")
	# loot
	w = _arena(5)
	var jelly := w.spawn("jellyfish", Vector2(16, 0))
	jelly["hp"] = 1.0
	w.attack("oar")
	_check(w.events.any(func(e: Dictionary) -> bool: return str(e["event"]) == "kill"), "the jellyfish dies")
	var got := w.collect_drops(40.0)
	_check(not w.enemies.has(jelly) and Skills.xp["diving"] > 0, "kills give diving XP")
	_check(got.size() <= 1, "loot is rolled per the enemy's table")
	# the bully seal steals and gives back
	w = _arena(6)
	Inventory.add("bread_rye", 2)
	var seal := w.spawn("seal_bully", Vector2(4, 0))
	w.step(0.1)
	_check(str(seal["carry"]) == "bread_rye" and Inventory.count_of("bread_rye") == 1, "the seal steals one item")
	seal["pos"] = Vector2(14, 0)
	w.player["attack_cd"] = 0.0
	w.attack("oar")
	_check(Inventory.count_of("bread_rye") == 2 and Inventory.count_of("sea_glass") >= 1, "catch it and it gives back, with a present")
	# a random pack of the kelp forest falls to a knife
	w = _arena(7)
	for i in 4:
		w.spawn(["crab", "jellyfish", "bullhead", "moray"][i], Vector2(80 + i * 30, (i - 2) * 30))
	Skills.levels["diving"] = 2
	w.player["max_hp"] = 110.0
	w.player["hp"] = 110.0
	_check(CombatBot.new(w, "fisher_knife").fight(120.0) == "won", "a kelp pack falls to the fisher's knife")


# "Bosses are passable": a scripted keeper with the gear of that depth wins each fight.
func _check_bosses() -> void:
	for spec in [["mother_moray", "cutlass", 5, 4], ["bell_ringer", "silver_cutlass", 7, 6], ["bone_whale", "silver_cutlass", 9, 8]]:
		_fresh()
		Skills.levels["diving"] = int(spec[2])
		Inventory.add("cod_solvik", int(spec[3]))
		var w := _arena(11)
		w.player["max_hp"] = 100.0 + 5.0 * float(spec[2])
		w.player["hp"] = w.player["max_hp"]
		w.player["pos"] = Vector2(0, 120)
		w.start_boss(str(spec[0]), Vector2.ZERO)
		var bot := CombatBot.new(w, str(spec[1]))
		var result := bot.fight(600.0)
		_check(result == "won", "%s with %s at Diving %d: %s (boss hp %d, keeper hp %d, t %.0f)" % [spec[0], spec[1], spec[2], result,
			int(w.boss["hp"]), int(w.player["hp"]), w.time])
		if result == "won":
			var money := Economy.money
			w.boss_reward()
			w.player["pos"] = w.boss["pos"]
			w.collect_drops(80.0)
			_check(Game.flag("boss_" + str(spec[0])), "%s: the victory is remembered" % spec[0])
			if str(spec[0]) == "mother_moray":
				_check(Inventory.count_of("moray_fang") == 1 and Economy.money == money + 2000, "Mother Moray: the fang and 2 000 crowns")
			if str(spec[0]) == "bone_whale":
				_check(Inventory.count_of("star_amber") == 1 and Inventory.count_of("whalebone") == 10, "the Bone Whale: star amber and whalebone")


# 17.2: every level of the Deep (and the bottomless ones) is whole: exit, finds, chests and foes reachable.
func _check_generation() -> void:
	_fresh()
	var locked := 0
	for lv in range(1, 81):
		for seed_value in [1, 2]:
			var d := DeepGen.generate(lv, seed_value)
			var problems := DeepGen.check(d)
			_check(problems.is_empty(), "level %d seed %d: %s" % [lv, seed_value, ", ".join(problems)])
			_check(d["rows"].size() == 30 and str(d["rows"][0]).length() == 40, "level %d is 40×30" % lv)
			if str(d["exit_kind"]) == "locked":
				locked += 1
		var d1 := DeepGen.generate(lv, 1)
		var expect := "kelp" if lv <= 20 else ("old_solvick" if lv <= 40 else "bone_abyss")
		_check(str(d1["biome"]) == expect, "level %d lies in %s" % [lv, expect])
		if lv in [10, 30, 50]:
			_check(d1["enemies"].is_empty() and not d1["chests"].is_empty() and str(d1["exit_kind"]) == "open", "level %d is a treasury" % lv)
		if lv in [20, 40, 60]:
			_check(str(d1["boss"]) != "" and str(d1["exit_kind"]) == "boss", "level %d has its boss" % lv)
		_check(bool(d1["station"]) == (lv % 5 == 0), "bell stations every 5 levels")
	_check(locked > 5 and locked < 40, "about 15%% of levels are locked until cleared (%d of 160)" % locked)
	_check(DeepGen.generate(7, 1)["rows"] == DeepGen.generate(7, 1)["rows"], "the same seed builds the same level")
	var w := CombatWorld.new(1)
	var weak := w.spawn("crab", Vector2.ZERO, 30)
	var strong := w.spawn("crab", Vector2.ZERO, 80)
	_check(is_equal_approx(float(strong["max_hp"]), float(weak["max_hp"]) * 2.0), "the bottomless Deep: +5% a level past 60")


# Air (17.1) and passing out (8.5).
func _check_air() -> void:
	_fresh()
	_check(Deep.begin(1) == "gear", "no dive without gear")
	Game.set_flag("diving_bell")
	_check(Deep.max_level() == 20 and Deep.begin(1) == "ok", "the bell: levels 1-20")
	var entry := Deep.cell_center(Deep.data["entry"])
	var away := entry + Vector2(80, 0)
	for n in 10:
		Deep.world.player["pos"] = away
		Deep.breathe(1.0)
	_check(is_equal_approx(Deep.air, 90.0), "outside the bell: −1 air a second")
	Deep.world.player["pos"] = entry
	Deep.breathe(1.0)
	_check(Deep.air > 90.0, "the bell refills the air")
	Inventory.add("air_bag", 1)
	_check(is_equal_approx(Deep.air_max(), 130.0), "the air bag: +30")
	Inventory.add("diving_suit", 1)
	_check(Deep.gear() == "suit" and Deep.max_level() == 40, "the suit: levels to 40")
	Knowledge.unlock("S11")
	_check(Deep.max_level() == 60, "the steam pump: to 60")
	Deep.world.player["pos"] = entry + Vector2(20 * 16, 0)
	Deep.breathe(1.0)
	_check(is_equal_approx(Deep.air, Deep.air_max()), "inside the hose radius the air is endless")
	Deep.world.player["pos"] = entry + Vector2(35 * 16, 0)
	Deep.breathe(30.0)
	_check(Deep.air < Deep.air_max() * 0.6, "off the hose the air lasts 60 seconds")
	Inventory.add("bread_rye", 5)
	Inventory.add("fish_cod", 5)
	Economy.money = 5000
	var result := Deep.pass_out()
	_check(result["lost"].size() >= 2 and int(result["money"]) == 500 and not Deep.active, "passing out: stacks and 10% of the money lost")
	_check(Inventory.count_of("diving_suit") == 1, "the suit (a tool) is never lost")


# The test mode of M8: straight down to 60 — breaking debris, clearing locked levels, beating the bosses.
func _check_descent() -> void:
	_fresh()
	Game.set_flag("test_deep")
	Skills.levels["diving"] = 9
	Inventory.add("cod_solvik", 20)
	_check(Deep.begin(1) == "ok", "the test dive starts")
	var stuck := ""
	while Deep.level < 60 and stuck == "":
		match str(Deep.data["exit_kind"]):
			"debris":
				_check(not Deep.exit_open() and Deep.break_debris("gaff_wood"), "level %d: the gaff breaks the debris" % Deep.level)
			"locked":
				_check(not Deep.exit_open() or Deep.world.hostile_count() == 0, "level %d stays locked while foes live" % Deep.level)
				for e in Deep.world.enemies.duplicate():
					if not bool(CombatWorld.enemy_info(str(e["kind"])).get("invulnerable", false)):
						Deep.world._kill(e)
			"boss":
				Deep.world.player["pos"] = Deep.world.boss["center"] + Vector2(0, 120)
				Deep.world.player["hp"] = Deep.world.player["max_hp"]
				var bot := CombatBot.new(Deep.world, "silver_cutlass" if Deep.level >= 40 else "cutlass")
				bot.bounds = Rect2(16, 16, 38 * 16, 28 * 16)
				var outcome := bot.fight(600.0)
				_check(outcome == "won", "level %d boss: %s" % [Deep.level, outcome])
		var before := Deep.level
		var result := Deep.descend()
		if result != "ok" or Deep.level != before + 1:
			stuck = "level %d: %s" % [before, result]
	_check(stuck == "" and Deep.level == 60, "the test descent reaches 60 " + stuck)
	var bot60 := CombatBot.new(Deep.world, "silver_cutlass")
	Deep.world.player["pos"] = Deep.world.boss["center"] + Vector2(0, 120)
	bot60.bounds = Rect2(16, 16, 38 * 16, 28 * 16)
	_check(bot60.fight(600.0) == "won", "the Bone Whale falls on level 60")
	_check(Deep.descend() == "ok" and Deep.level == 61, "past 60 the bottomless Deep goes on")
	_check(int(Game.counters.get("deep_max", 0)) == 61 and int(Game.counters.get("deep_station", 0)) == 60, "the deepest level and station are kept")
	_check(Game.flag("boss_mother_moray") and Game.flag("boss_bell_ringer") and Game.flag("boss_bone_whale"), "all three bosses paid out")


func _low_tide(threshold: float, from_day: int) -> Array:
	for day in range(from_day, from_day + 60):
		for m in range(0, 1440, 10):
			if Clock.tide_height_at(day, m) <= threshold - 0.05 and Clock.tide_height_at(day, m + 120) <= threshold:
				return [day, m]
	return []


func _hall_path(index: int) -> bool:
	var r := Grotto.rows(index)
	var start := Grotto.entry_cell(index)
	var target := Vector2i(-1, -1)
	for y in r.size():
		var x := str(r[y]).find(">")
		if x >= 0:
			target = Vector2i(x, y)
	if target.x < 0:
		return true
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == target:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and Grotto.tile(n, index) != "#":
				seen[n] = true
				queue.append(n)
	return false


# 17.6: ten halls, the tide window, the flood, the plates, the echo, the dive, the rubble and the treasures.
func _check_grotto() -> void:
	_fresh()
	_check(Data.tables["grotto"]["halls"].size() == 10, "ten halls")
	for i in 10:
		_check(_hall_path(i), "hall %d leads from its entry to the next hall" % (i + 1))
	var low := _low_tide(-0.4, 14)
	_check(not low.is_empty(), "a low tide after Spring 15")
	Clock.day_index = int(low[0])
	Clock.minutes = int(low[1])
	_check(Grotto.entrance_state() == "rock", "a stone closes the mouth")
	_check(not Grotto.break_entrance("tool_axe") and Grotto.break_entrance("tool_pick"), "a pickaxe breaks it at the ebb")
	_check(Grotto.enter() and Grotto.hall == 0, "the keeper walks into hall 1")
	_check(Grotto.minutes_left(1) > 0, "the hint counts the minutes to the water")
	# hall 2: three plates lift the grate
	Grotto.hall = 1
	var boulders: Array = []
	var plate_cells: Array = []
	var rows := Grotto.rows()
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] == "B":
				boulders.append(Vector2i(x, y))
			if str(rows[y])[x] == "p":
				plate_cells.append(Vector2i(x, y))
	_check(not Grotto.gate_open(), "the grate of hall 2 is down")
	for i in 3:
		Grotto.interact(boulders[i])
		Grotto.interact(plate_cells[i])
	_check(Grotto.gate_open(), "three stones on three plates lift the grate")
	# hall 6: the echo
	Grotto.hall = 5
	var stal: Array = []
	rows = Grotto.rows()
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] == "T":
				stal.append(Vector2i(x, y))
	_check(Grotto.strike(stal[3]).begins_with("Звук"), "a wrong stalactite starts the rhythm over")
	for i in Grotto.ECHO:
		Grotto.strike(stal[int(i)])
	_check(Grotto.gate_open() and Game.flag("grotto_echo"), "the echo answers the drops' rhythm")
	# hall 7: 30 seconds of breath
	Grotto.hall = 6
	var water := Vector2(8 * 16 + 8, 3 * 16 + 8)
	_check(Grotto.dive_tick(20.0, water) == "" and Grotto.dive_tick(11.0, water) == "gasp", "30 s of breath in the flooded passage")
	# hall 8: the rubble needs an iron pickaxe from Tora
	Grotto.hall = 7
	var rubble := Vector2i(11, 1)
	_check(Grotto.tile(rubble) == "R" and Grotto.interact(rubble, "tool_pick").begins_with("Завал"), "a rusty pick does not break the rubble")
	Inventory.add("tool_pick", 1)
	Inventory.add("copper_ingot", 5)
	Inventory.add("iron_ingot", 5)
	Economy.money = 20000
	_check(Buildings.order_tool("tool_pick") == "ok" and Inventory.count_of("tool_pick") == 0, "Tora takes the pickaxe for copper")
	_check(Buildings.order_tool("tool_axe") == "busy", "one tool at a time")
	Clock.day_index += 2
	_check(Buildings.tool_night() == "tool_pick" and Buildings.tool_level("tool_pick") == 1, "two days later the copper pick")
	_check(Mail.read(Mail.letters[-1]) and Inventory.count_of("tool_pick") == 1, "the pickaxe comes back by mail")
	_check(Buildings.order_tool("tool_pick") == "ok", "then iron")
	Clock.day_index += 2
	Buildings.tool_night()
	_check(Buildings.tool_level("tool_pick") == 2, "the iron pickaxe")
	_check(Grotto.interact(rubble, "tool_pick").begins_with("Завал рухнул") and not Grotto.blocked("R"), "the iron pick breaks into the Hall of the Twenty")
	# hall 9 and 10: treasure and the heart of the grotto
	Grotto.hall = 8
	_check(Grotto.interact(Vector2i(15, 2)).begins_with("Клад") and Inventory.count_of("old_crown") >= 3, "Crooked Lantern's hoard")
	_check(Grotto.interact(Vector2i(18, 3)).begins_with("Старый") and Inventory.count_of("false_lantern") == 1, "the old false lantern")
	Grotto.hall = 9
	_check(Grotto.interact(Vector2i(11, 3)).begins_with("Сундук") and Grotto.interact(Vector2i(11, 3)) == "Сундук пуст.", "the heart chest, once")
	var money := Economy.money
	var slot := -1
	for i in Inventory.capacity:
		if str(Inventory.slots[i]["id"]) == "heart_of_grotto":
			slot = i
	Lighthouse.open_crate(slot)
	_check(Inventory.count_of("deep_quartz") >= 1 and Inventory.count_of("black_pearl") == 1 and Economy.money == money + 1000,
		"'Heart of the Grotto': deep quartz, a black pearl and 1 000 crowns")
	# the halls' finds
	Grotto.hall = 0
	_check(Grotto.interact(Vector2i(7, 1)).begins_with("В луже") and Grotto.interact(Vector2i(7, 1)).begins_with("Лужа пуста"), "a tidepool once per ebb")
	Grotto.hall = 2
	_check(Grotto.interact(Vector2i(14, 3)).begins_with("Страница") and Knowledge.rest_pts >= 3, "page 2 in the 'F' niche")
	# the flood
	Grotto.hall = 5
	Inventory.add("bread_rye", 3)
	var closing := 0
	while Grotto.band_open(2) and closing < 720:
		Clock.minutes += 5
		closing += 5
		if Clock.minutes >= 1440:
			Clock.minutes -= 1440
			Clock.day_index += 1
	var result := Grotto.check_water()
	_check(result.begins_with("flood") and not Grotto.active and Grotto.flood_energy() == 20.0, "the water returns: thrown out, −20 energy, a stack lost")
	Sea.blessings.append("otliva")
	_check(Grotto.flood_energy() == 0.0, "Otliva keeps the water off the keeper")


# 16.1, 16.5, 16.6: the sloop and Raven's Eye, zone 3, and what the sea brings on an outing.
func _check_sea() -> void:
	_fresh()
	_check(SeaChart.zone_of(Vector2(100, 40 * 16)) == 1 and SeaChart.zone_of(Vector2(100, 60 * 16)) == 2
		and SeaChart.zone_of(Vector2(100, 110 * 16)) == 3, "three zones down the chart")
	Sea.set_boat("sloop")
	_check(Sea.can_sail(2) == "" and Sea.can_sail(3) == "zone", "the sloop reaches zone 2, not 3")
	Sea.set_boat("bot")
	_check(Sea.can_sail(3) == "" and Sea.hold.size() >= 48, "Raven's Eye: zone 3 and a 48-slot hold")
	Weather.current = "storm"
	_check(Sea.can_sail(1) == "storm", "no sailing into a storm without storm sails")
	Inventory.add("storm_sails", 1)
	_check(Sea.can_sail(1) == "", "the boat with storm sails goes out in a storm")
	Weather.current = "clear"
	_check(SeaChart.place_pos("ice_field").y > float(SeaChart.cfg("zone3_row")) * 16.0, "the ice field lies in zone 3")
	# event frequencies over many outings
	Clock.day_index = 28 + 16
	var counts := {}
	for n in 600:
		for ev in Sea.roll_outing(n):
			counts[str(ev["id"])] = int(counts.get(str(ev["id"]), 0)) + 1
	_check(int(counts.get("cargo", 0)) > 60 and int(counts.get("cargo", 0)) < 120, "floating cargo on ~15%% of outings (%d/600)" % int(counts.get("cargo", 0)))
	_check(int(counts.get("whales", 0)) > 130 and int(counts.get("whales", 0)) < 230, "whales on ~30%% of summer outings 15-21 (%d)" % int(counts.get("whales", 0)))
	_check(int(counts.get("orcas", 0)) > 10 and int(counts.get("orcas", 0)) < 60, "orcas ~5%% in zone 3 (%d)" % int(counts.get("orcas", 0)))
	_check(not counts.has("ghost_ship") and not counts.has("squall"), "no ghost ship without the Hmar, no squall in fair weather")
	Clock.day_index = 28 + 3
	var whales := 0
	for n in 200:
		for ev in Sea.roll_outing(n):
			whales += 1 if str(ev["id"]) == "whales" else 0
	_check(whales == 0, "whales only on Summer 15-21")
	# meeting them
	var cargo := {"id": "cargo", "x": 16.0, "y": 0.0, "done": false}
	_check(Sea.meet(cargo).begins_with("Не дотянуться"), "cargo needs a gaff")
	Inventory.add("gaff_wood", 1)
	Sea.meet(cargo)
	_check(bool(cargo["done"]) and (Inventory.count_of("cargo_fishing") + Inventory.count_of("cargo_merchant")) == 1,
		"the gaff hooks a crate")
	var seals := {"id": "seals", "x": 0.0, "y": 0.0, "done": false}
	_check(Sea.meet(seals).begins_with("Тюлени смотрят"), "seals want herring")
	Inventory.add("fish_herring", 2)
	Sea.meet(seals)
	_check(Game.stat("seal_feed_days") == 1, "feeding the seals counts a day (the way to Tuve)")
	var ghost := {"id": "ghost_ship", "x": 0.0, "y": 0.0, "done": false}
	Sea.meet(ghost)
	var chest: Dictionary = Sea.outing.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "eleonora_chest")[0]
	Sea.meet(chest)
	_check(Inventory.count_of("chest_deep") == 1 and int(Game.counters["eleonora_year"]) == Clock.year, "the Eleonora leads to a chest by the Nameless Isle")
	var again := {"id": "ghost_ship", "x": 0.0, "y": 0.0, "done": false}
	_check(Sea.meet(again).contains("растворяется"), "once a year")
	var fisher := {"id": "fisher_in_trouble", "x": 0.0, "y": 0.0, "done": false}
	Sea.meet(fisher)
	var money := Economy.money
	_check(Sea.towing and Sea.finish_tow() == 3 and Economy.money == money + 300 and Game.honor == 3, "towing a fisherman home: a present and honour")
	var frenzy := {"id": "bird_frenzy", "x": 0.0, "y": 0.0, "done": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var slow := Fishing.wait_seconds("rod_agatha", "", rng)
	Sea.meet(frenzy)
	rng.seed = 5
	_check(is_equal_approx(Fishing.wait_seconds("rod_agatha", "", rng), slow * 0.5), "under the bird frenzy fish bite twice as often")


func _run() -> void:
	_check_combat()
	_check_bosses()
	_check_generation()
	_check_air()
	_check_descent()
	_check_grotto()
	_check_sea()
	print("M8 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
