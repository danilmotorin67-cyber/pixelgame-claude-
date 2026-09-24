extends Node

# Run with: godot --headless --path . res://tests/integration/test_m9.tscn
# M9 "The Story": the acts and their quests, the Twenty, the ghosts and collections, the daughters, the Guild House
# and Neptune, the festivals, the finale — and the story run that reaches every ending (with debug skips).
var failures: Array[String] = []
# Night.end_day wakes the keeper on this "map" instead of changing the scene.
var map_id: String = "cape"


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh(phrase: String = "Я увольняюсь.") -> void:
	NewGame.start({"name": "Тест", "gender": "m", "stern_phrase": phrase})
	Game.world_seed = 9
	Inventory.upgrade_capacity(36)
	Economy.money = 100000


# Jump to a date at the given hour (the story reads the day index and the clock).
func _goto(index: int, hour: int = 8) -> void:
	Clock.day_index = index
	Clock.set_time(hour, 0)
	Weather.start_day(index)
	Story.update_act()


func _sleep() -> void:
	Night.end_day()


func _hotbar(id: String) -> void:
	for i in Inventory.capacity:
		if str(Inventory.slots[i]["id"]) == id:
			if i < Inventory.HOTBAR:
				Inventory.select_hotbar(i)
			else:
				_swap(i)
			return


func _swap(i: int) -> void:
	var tmp: Dictionary = Inventory.slots[0]
	Inventory.slots[0] = Inventory.slots[i]
	Inventory.slots[i] = tmp
	Inventory.select_hotbar(0)


func _run() -> void:
	for section in ["_check_quest_engine", "_check_prologue_and_act_one", "_check_act_two", "_check_twenty"]:
		print("- ", section)
		call(section)
	print("M9 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


# Steps by events, conditions, hand-ins and order (5.0 and the quests' format).
func _check_quest_engine() -> void:
	_fresh()
	Quests.start("q2_4_bell")
	_check(Quests.state("q2_4_bell") == "active" and Game.flag("q2_4_started"), "the bell quest starts with its flag")
	_check(Quests.deliveries("npc_tora").is_empty(), "Tora's hand-in waits for the porthole glass")
	_check(Story.npc_options("npc_liv").size() >= 1, "Liv offers the porthole glass")
	Story.npc_action("npc_liv", "opt:liv_glass")
	_check(Quests.step_done("q2_4_bell", "glass"), "the glass step is done by picking it up")
	var tora := Quests.deliveries("npc_tora")
	_check(tora.size() == 1, "now Tora takes the materials")
	var answer := Story.npc_action("npc_tora", "deliver:q2_4_bell:tora")
	_check(answer.begins_with(Loc.t("story.deliver.missing")), "missing materials are listed")
	Inventory.add("copper_ingot", 10)
	Inventory.add("boards", 30)
	Inventory.add("resin", 5)
	Inventory.add("iron_ingot", 2)
	Story.npc_action("npc_tora", "deliver:q2_4_bell:tora")
	_check(Quests.step_done("q2_4_bell", "tora") and Inventory.count_of("copper_ingot") == 0, "Tora takes the materials")
	var money := Economy.money
	Story.npc_action("npc_ilm", "deliver:q2_4_bell:winch")
	_check(Economy.money == money - 500 and int(Game.counters.get("bell_ready", 0)) == Clock.day_index + 2, "Ilm's winch: 500 kr, ready in two days")
	Quests.poll()
	_check(not Game.flag("diving_bell"), "the bell is not ready at once")
	Clock.day_index += 2
	Quests.poll()
	_check(Game.flag("diving_bell") and Quests.state("q2_4_bell") == "done", "two days later the bell hangs on the dinghy")
	# counts by amount and the kelp of Q1.2
	Quests.start("q1_2_salt_land")
	Inventory.add("kelp", 6)
	Inventory.add("kelp", 4)
	_check(Quests.step_done("q1_2_salt_land", "kelp"), "kelp counts by the amount picked up")
	_check(Quests.journal_lines().any(func(l: String) -> bool: return l.contains("⚑")), "story quests carry the lighthouse mark")


func _check_prologue_and_act_one() -> void:
	_fresh("Беру бессрочный отпуск.")
	_check(Story.stern_phrase == "Беру бессрочный отпуск." and Game.flag("prologue_done"), "the prologue's phrase is remembered")
	_check(Loc.format("{phrase}") == "Беру бессрочный отпуск.", "Stern can quote it in Act III")
	_check(Clock.minutes == 17 * 60 and Clock.day_index == 0, "Spring 1, 17:00")
	_goto(0, 18)
	_check(Game.act == 1 and Story.act_for(28) == 2 and Story.act_for(84) == 3 and Story.act_for(168) == 4, "acts begin by date")
	# Q1.7: the code lock
	Quests.start("q1_7_logbook")
	_check(Story.try_code("весна 1") == Loc.t("story.lock.wrong"), "a wrong code")
	Story.try_code("лето 3")
	_check(Story.try_code("зима 9") == Loc.t("story.lock.hint"), "after three tries Fortuna hints")
	_check(Story.try_code("осень 14") == Loc.t("story.lock.click") and Story.pages.has(1), "Autumn 14 opens the log: page 1")
	_check(Quests.state("q1_7_logbook") == "done" and Collections.has("pages", "page_1"), "the watch log quest and the pages collection")
	# Q1.4: neighbours
	Quests.start("q1_4_neighbours")
	var met := 0
	for npc in Festivals.residents():
		if met >= 16:
			break
		Relationships.talk(str(npc))
		met += 1
	_check(Quests.state("q1_4_neighbours") == "done", "sixteen neighbours met")
	# Q1.10: the grotto stone at the great ebb
	Quests.start("q1_10_ebb")
	_goto(14, 12)
	var found := false
	for m in range(0, 720, 10):
		Clock.set_time(6 + m / 60, m % 60)
		if Grotto.band_open(1):
			found = true
			break
	_check(found and Grotto.break_entrance("tool_pick") and Quests.step_done("q1_10_ebb", "open"), "the pickaxe breaks the grotto stone at the ebb")
	Game.counters["grotto_deepest"] = 3
	Grotto.hall = 2
	Grotto.interact(Vector2i(14, 3))
	Quests.poll()
	_check(Story.pages.has(2) and Quests.state("q1_10_ebb") == "done", "page 2 behind the 'F'")
	# Q1.11: Neptune's offer
	Quests.start("q1_11_neptune")
	Cutscenes.simulate("ev_story_stern_offer", [1])
	_check(Community.neptune == "offer" and Quests.state("q1_11_neptune") == "done", "'I'll think about it' keeps the offer open")
	# Q1.13: the false fire — the night of Spring 28 wrecks the Saint Berta whatever the rating
	_goto(27, 22)
	Quests.check_starts()
	_check(Quests.state("q1_13_false_fire") == "active", "the false fire quest waits for Spring 28")
	Lighthouse.lamp_on = true
	_sleep()
	_check(Game.flag("berta_wrecked") and Quests.state("q1_13_false_fire") == "done" and Game.act == 2, "the Saint Berta goes down; Act II begins")
	var arrived := 0
	for id in ["body_pennington", "body_martin", "body_vera"]:
		if not Graveyard.body(id).is_empty():
			arrived += 1
	_check(arrived == 3 and str(Graveyard.body("body_pennington")["identified_as"]) == "reg_pennington", "three dead come ashore on Summer 1, two of them known")
	_check(Quests.state("q2_1_morning_after") == "active", "'The Morning After' begins")


func _check_act_two() -> void:
	_fresh()
	_goto(29, 20)
	Game.act = 2
	Quests.start("q2_2_white_hmar")
	_sleep()
	_check(Clock.day_index == 30 and Weather.hmar_night, "Summer 3 is the first White Hmar")
	Router.current_map = "cape"
	_sleep()
	_check(Quests.state("q2_2_white_hmar") == "done" and Game.flag("hmar_open") and Game.flag("q2_2_done"), "surviving the night on the cape opens the random Hmar Nights")
	# Q2.3 and the plankton
	Quests.start("q2_3_guest")
	Story.npc_action("npc_liv", "deliver:q2_3_guest:gallery")
	_check(Inventory.count_of("seed_lightflower") == 10, "Liv gives ten lightflower seeds")
	_goto(28 + 26, 22)
	_check(Story.spots_on("cape").any(func(s: Dictionary) -> bool: return str(s["id"]) == "glow_water"), "the glowing water shows on the new-moon nights")
	Inventory.add("hand_net", 1)
	Story.spot_action("glow_water", "sample")
	_check(Quests.state("q2_3_guest") == "done" and Game.flag("q2_3_done"), "a net of plankton finishes the guest's quest")
	# Q2.5: Agatha's chest on level 10
	Game.set_flag("diving_bell")
	_check(Story.deep_chests(10) == ["agatha_chest"], "Agatha's chest waits on level 10")
	Quests.start("q2_5_kelp")
	Game.counters["deep_max"] = 10
	Inventory.add("agatha_chest", 1)
	_check(Story.pages.has(5) and Story.pages.has(6) and Inventory.count_of("lantern_agatha") == 1 and Inventory.count_of("agatha_chest") == 0,
		"the chest gives pages 5-6 and Agatha's lantern")
	_check(Quests.state("q2_5_kelp") == "done" and CombatWorld.lantern_tiles() >= 4.0, "the kelp forest quest; the lantern reaches further")
	# Q2.6-Q2.7: the sail and the hermit
	Quests.start("q2_6_sail")
	Inventory.add("boards", 40)
	Inventory.add("canvas", 3)
	Story.npc_action("npc_erland", "deliver:q2_6_sail:order")
	_check(Sea.boat == "sloop", "Erland's sloop")
	Quests.check_starts()
	_check(Quests.state("q2_7_hermit") == "active", "the hermit's quest follows the sail")
	Inventory.add("kerosene", 3)
	for i in 3:
		_check(Story.visit_kai() != "", "Kai visit %d" % (i + 1))
		_check(Story.visit_kai() == "", "one visit a day")
		Clock.day_index += 1
	_check(Story.pages.has(7) and Quests.state("q2_7_hermit") == "done", "the third visit gives page 7")
	# Q2.8: Helga's tales after a liked gift
	Quests.start("q2_8_tales")
	_check(Tales.next_tale() == 0, "no tale without a gift")
	Game.counters["helga_liked_day"] = Clock.day_index
	_check(Tales.next_tale() == 1 and Tales.tell().contains(Loc.t("tale.1.title")), "the first tale")
	_check(Tales.next_tale() == 0, "one tale a visit")
	Clock.day_index += 1
	Game.counters["helga_liked_day"] = Clock.day_index
	Relationships.set_hearts("npc_helga", 2)
	Tales.tell()
	Clock.day_index += 1
	Game.counters["helga_liked_day"] = Clock.day_index
	Tales.tell()
	Quests.poll()
	_check(Quests.state("q2_8_tales") == "done", "three tales told")
	# Q2.13: the Great Hmar — six bonfires before 00:30, fire 50+, Peace 35+
	_fresh()
	_goto(83, 21)
	Game.act = 2
	Quests.start("q2_13_great_hmar")
	_check(Story.siege_night() and Story.spots_on("village").filter(func(s: Dictionary) -> bool: return str(s["kind"]) == "bonfire").size() == 6,
		"six bonfires round the village on the siege night")
	_check(Story.light_bonfire(1) == "fuel", "a bonfire needs peat or driftwood")
	Inventory.add("peat", 6)
	for i in 6:
		Story.light_bonfire(i + 1)
	Graveyard.peace = 40.0
	Lighthouse.last_report = {"lit": true, "power": 60.0}
	_check(Story.judge_great_hmar(83) == "won" and Quests.state("q2_13_great_hmar") == "done", "the Great Hmar is held")
	_fresh()
	_goto(83, 21)
	Game.act = 2
	Farm.get_tile(Vector2i(2, 2))
	Lighthouse.last_report = {"lit": true, "power": 30.0}
	_check(Story.judge_great_hmar(83) == "failed" and Story.great_hmar == "pending" and Game.flag("village_pier_broken"),
		"a weak fire loses the siege: the pier breaks and it will come again")


# The Twenty (5.9): carried out at low tide, named from the crew list, buried; Eleonora last.
func _check_twenty() -> void:
	_fresh()
	_goto(56, 10)
	Game.act = 2
	Quests.check_starts()
	_check(Quests.state("q2_10_twenty") == "active", "Autumn 1: the Twenty")
	Game.set_flag("grotto_open")
	Game.set_flag("grotto_rubble")
	_check(Twenty.take_from_hall() == Loc.t("twenty.hall.found") and Game.flag("twenty_found"), "the hall and the crew list are found")
	Twenty.take_from_hall()
	_check(Twenty.take_from_hall() == Loc.t("twenty.hall.full"), "one on the shoulders")
	Twenty.on_flood()
	_check(Twenty.carrying == 0 and Twenty.in_hall == 19, "the flood leaves the bones in the hall")
	Inventory.add("drag_sledge", 1)
	Twenty.take_from_hall()
	Twenty.take_from_hall()
	Grotto.active = true
	_check(Grotto.leave().contains("2") and Twenty.carried_out == 2, "two on the sledge reach the morgue")
	Relationships.set_hearts("npc_knud", 4)
	Relationships.set_hearts("npc_einar", 6)
	_check(Story.npc_options("npc_knud").any(func(o: Array) -> bool: return str(o[0]) == "opt:knud_twenty"), "Knud offers to help")
	Story.npc_action("npc_knud", "opt:knud_twenty")
	Story.npc_action("npc_einar", "opt:einar_twenty")
	_check(Twenty.carried_out == 12 and not Twenty.can_help("npc_knud"), "Knud and Einar carry five each, once")
	while Twenty.in_hall > 0:
		Twenty.take_from_hall()
		Twenty.take_from_hall()
		Grotto.active = true
		Grotto.leave()
	_check(Twenty.carried_out == 19, "all nineteen carried out")
	var skeletons: Array = Graveyard.bodies.filter(func(b: Dictionary) -> bool: return b.has("twenty"))
	_check(skeletons.size() == 19 and bool(skeletons[0]["sewn"]), "nineteen skeletons in canvas in the morgue")
	var b: Dictionary = skeletons[0]
	var roll := Graveyard.candidates(b, true)
	_check(roll.size() == 19 and bool(roll[0].get("fortuna", false)), "the crew list offers every unnamed sailor")
	# name the first right, the second wrong
	_check(Graveyard.identify(b, str(b["registry"])), "a skeleton named from the crew list")
	var b2: Dictionary = skeletons[1]
	var wrong := ""
	for reg in Graveyard.candidates(b2, true):
		if str(reg["id"]) != str(b2["registry"]):
			wrong = str(reg["id"])
			break
	Graveyard.identify(b2, wrong)
	_check(not Graveyard.send_family_letter(b), "no family letters for the Fortuna's crew")
	# bury them (Ilm's graveyard extension makes room)
	Graveyard.extend_plots(40)
	var rest_before := Knowledge.rest_pts
	var buried := 0
	for sk in skeletons:
		if _bury(sk):
			buried += 1
	_check(buried == 19 and Twenty.buried_count() == 19, "nineteen buried")
	_check(Knowledge.rest_pts >= rest_before + 2, "a right name is worth two candles more")
	_check(Cutscenes.find("ev_story_fortuna_voice").size() > 0 and Story.fortuna_scene() == "ev_story_fortuna_voice", "after ten, Fortuna speaks")
	Cutscenes.simulate("ev_story_fortuna_voice")
	_check(Twenty.niche_open() and Twenty.take_eleonora() == Loc.t("twenty.niche.open"), "with nineteen buried the niche opens")
	Grotto.active = true
	Grotto.leave()
	var eleonora := Graveyard.body("body_fortuna_eleonora")
	_check(not eleonora.is_empty() and str(eleonora["identified_as"]) == "reg_t20_20", "Eleonora comes out named")
	_bury(eleonora)
	_check(Game.flag("twenty_buried") and Game.flag("eleonora_buried") and Story.pages.has(22), "all twenty: the flag, Eleonora, page 22")
	Graveyard.recalc_peace()
	Quests.check_starts()
	_check(Quests.state("q2_10_twenty") == "done" and Quests.state("q2_11_fortuna_voice") == "done", "Q2.10 and Q2.11 done")
	Game.act = 3
	Weather.last_hmar_day = -100
	var with_twenty := Weather.hmar_chance(90)
	Game.set_flag("twenty_buried", false)
	_check(with_twenty < Weather.hmar_chance(90), "the Twenty at rest: fewer Hmar Nights")
	Game.set_flag("twenty_buried")


func _bury(b: Dictionary) -> bool:
	for plot in Graveyard.graves.size():
		var g: Dictionary = Graveyard.graves[plot]
		if bool(g["old"]) or str(g["body"]) != "" or bool(g["filled"]):
			continue
		g["open"] = true
		Graveyard.carried = str(b["id"])
		b["where"] = "carried"
		if Graveyard.lay(plot) and Graveyard.fill(plot):
			return true
	return false
