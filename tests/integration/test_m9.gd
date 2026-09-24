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
	for section in ["_check_quest_engine", "_check_prologue_and_act_one", "_check_act_two", "_check_twenty",
			"_check_ghosts", "_check_collections", "_check_daughters", "_check_community", "_check_festivals"]:
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


# Arrive a story body, bury it named; returns the body.
func _arrive_and_bury(body_id: String) -> Dictionary:
	var story := Data.by_id("bodies", body_id)
	var reg := Graveyard.registry_entry(str(story["registry"])).duplicate(true)
	for key in ["clues_visible", "clues_hidden", "items", "ghost"]:
		if story.has(key):
			reg[key] = story[key]
	var b := Graveyard.spawn_body(reg, "cape", true, body_id)
	Graveyard.identify(b, str(story["registry"]))
	_bury(b)
	return b


# The named ghosts (11.8): their wishes away from the graves, the gifts, laying them to rest.
func _check_ghosts() -> void:
	_fresh()
	Graveyard.extend_plots(40)
	_check(Data.all("ghosts").size() == 20, "twenty named ghosts")
	# Bartholomew: an excellent labskaus
	_arrive_and_bury("body_bartholomew")
	_check(Graveyard.present_ghosts().any(func(g: Dictionary) -> bool: return str(g["id"]) == "ghost_bartholomew"), "the cook rises by his grave")
	Graveyard.talk_ghost("ghost_bartholomew")
	_check(Quests.state("g1_labskaus") == "active" and Crafting.learned.has("cook_labskaus"), "he whispers the recipe")
	Inventory.add("labskaus", 1, 1)
	_check(Ghosts.actions("ghost_bartholomew").size() == 1 and not Quests.deliver("g1_labskaus", "cook"), "a good labskaus is not enough")
	Inventory.add("labskaus", 1, 2)
	var line := Ghosts.act("ghost_bartholomew", "deliver:g1_labskaus:cook")
	_check(Graveyard.laid_ghosts.has("ghost_bartholomew") and Inventory.count_of("bartholomew_ladle") == 1 and Crafting.learned.has("cook_labskaus_cook"),
		"the excellent one lays him to rest: the ladle and the cook's recipe (%s)" % line.left(20))
	# Horn: exhumed without sin, buried at sea with a flare
	var horn := _arrive_and_bury("body_horn")
	Graveyard.talk_ghost("ghost_horn")
	var honor := Game.honor
	Clock.set_time(23, 0)
	_check(Graveyard.exhume(_plot_of("body_horn")), "the captain is dug up at night")
	_check(Game.honor == honor and Quests.step_done("g10_wrong_burial", "exhume"), "no honour lost for his wish")
	horn["sewn"] = true
	Inventory.add("stone", 3)
	_check(SeaBurial.perform().contains("ракета"), "without a flare the captain refuses the sea")
	Inventory.add("signal_flare", 1)
	_check(SeaBurial.perform().contains("салют"), "a salute and the sea")
	_check(Graveyard.laid_ghosts.has("ghost_horn") and Inventory.count_of("captain_cap") == 1, "Horn rests; his cap is ours")
	# Jacques: rum or customs
	_check(Ghosts.jacques_remains() == Loc.t("ghost.jacques.greet") and Quests.state("g7_rum") == "active", "Jacques in the fifth hall")
	_check(Story.npc_options("npc_olaf").any(func(o: Array) -> bool: return str(o[0]) == "opt:jacques_customs"), "Olaf will take the cache for customs")
	honor = Game.honor
	Story.npc_action("npc_olaf", "opt:jacques_customs")
	_check(Game.honor == honor + 5 and Graveyard.laid_ghosts.has("ghost_jacques") and Game.flag("shadow_fair"), "customs: honour, the reward, the Shadow Fair")
	# Martin: a winter fire kept till midnight
	_arrive_and_bury("body_martin")
	Graveyard.talk_ghost("ghost_martin")
	_goto(84 + 3, 22)
	Inventory.add("driftwood", 5)
	_check(Ghosts.martin_fire() == Loc.t("ghost.martin.fire"), "a fire by his grave")
	Router.current_map = "cape"
	Ghosts.hourly(0)
	_check(Quests.state("g5_cold") == "done", "midnight on the cape keeps Martin warm")
	Graveyard.talk_ghost("ghost_martin")
	_check(Inventory.count_of("martin_ember") == 1 and Daughters.cold_mult() == 1.0, "Martin's ember (it warms once worn)")
	# Grunwald: a noon sight in zone 2
	_arrive_and_bury("body_grunwald")
	Graveyard.talk_ghost("ghost_grunwald")
	Inventory.add("sextant_cracked", 1)
	Router.current_map = "sea"
	Clock.set_time(12, 0)
	var zone2 := int(SeaChart.cfg("zone2_row")) + 2
	_check(Story.use_item("sextant_cracked", Vector2(40 * 16, zone2 * 16)) == Loc.t("ghost.sextant.fix"), "the noon sight in zone 2")
	Graveyard.talk_ghost("ghost_grunwald")
	_check(Inventory.count_of("sextant") == 1, "Grunwald's sextant")
	Router.current_map = "cape"
	# Pennington: the portfolio from level 17 is evidence No. 1
	_arrive_and_bury("body_pennington")
	Graveyard.talk_ghost("ghost_pennington")
	_check(Story.deep_chests(17) == ["pennington_portfolio"], "the portfolio waits on level 17 while he asks")
	Inventory.add("pennington_portfolio", 1)
	Ghosts.act("ghost_pennington", "deliver:g11_portfolio:portfolio")
	_check(Story.evidence.has("portfolio") and Graveyard.laid_ghosts.has("ghost_pennington"), "the portfolio pinned on the board")
	# Gudmund's bones from level 8 become a named body
	Inventory.add("gudmund_bones", 1)
	_check(not Graveyard.body("body_gudmund").is_empty() and Game.flag("gudmund_found"), "Gudmund's bones lie in the morgue")
	# the dog: the sailor with the dog tattoo
	_check(not ConditionContext.new().dog_master_buried(), "no dog's master yet")
	_arrive_and_bury("body_dog_sailor")
	Quests.start("g14_where_master")
	_check(Graveyard.laid_ghosts.has("ghost_dog") and Game.flag("ghost_dog"), "Brown finds his master and walks with the keeper")
	# Nilsen: the bell for the Memorial room
	Game.set_flag("ghost_nilsen")
	Quests.start("g17_bell")
	_check(Story.deep_chests(25).has("solvik_bell"), "the bell of Old Solvik on level 25")
	# Emmerich's sketches
	Quests.start("g16_map")
	for place in ["teeth", "eider_isle", "dead_fire"]:
		Ghosts.sketch(place)
	_check(Quests.state("g16_map") == "done" and Game.flag("nameless_isle_open"), "three sketches open the Nameless Isle")
	# the ghost hunters' club
	Relationships.set_hearts("npc_nils", 2)
	Quests.check_starts()
	_check(Quests.state("club_1_owl") == "active", "the club's first case")
	_goto(60, 22)
	Story.spot_action("mill_owl", "look")
	_check(Quests.state("club_1_owl") == "done", "the ghost of the mill is an owl")
	Quests.check_starts()
	Router.current_map = "cape"
	Ghosts.hourly(23)
	_check(Quests.state("club_2_watch") == "done", "an hour of night watch")
	Quests.check_starts()
	for n in [1, 2, 3]:
		Cats.find(n)
	Quests.poll()
	Quests.check_starts()
	Graveyard.talk_ghost("ghost_bartholomew")
	_arrive_and_bury("body_vera")
	Graveyard.talk_ghost("ghost_vera")
	_check(Quests.state("club_4_real") == "done", "cat graves, then a real ghost")
	Quests.check_starts()
	var low := -1
	for m in range(0, 1440, 10):
		if Clock.tide_height_at(Clock.day_index, m) <= -0.4:
			low = m
			break
	Clock.set_time(low / 60, low % 60)
	Ghosts.on_map("seal_shore")
	Story._on_map_entered("village")
	_check(Quests.state("club_5_seal") == "done", "the Seal Rock expedition, back before the tide")
	Quests.check_starts()
	_check(Crafting.knows(Data.by_id("recipes_craft", "forge_brass_badge")), "the badge recipe")
	Inventory.add("brass_badge", 2)
	Story.npc_action("npc_nils", "deliver:club_6_badges:badges")
	_check(Game.flag("club_official") and Inventory.count_of("ghost_club_badge") >= 1, "the club is official")
	# Vera's notebooks for Ingrid
	var ingrid: int = int(Relationships.points.get("npc_ingrid", 0))
	Inventory.add("vera_notebooks", 1)
	Story.npc_action("npc_ingrid", "deliver:g19_pupils:notebooks")
	Graveyard.talk_ghost("ghost_vera")
	_check(int(Relationships.points.get("npc_ingrid", 0)) >= int(ingrid) + 250 and Graveyard.laid_ghosts.has("ghost_vera"), "Vera's pupils")


func _plot_of(body_id: String) -> int:
	for plot in Graveyard.graves.size():
		if str(Graveyard.graves[plot]["body"]) == body_id:
			return plot
	return -1


# Bottles (18.6), cat graves (18.7), Helga's tales (27.3).
func _check_collections() -> void:
	_fresh()
	var got := {}
	Inventory.add("bottle_13", 1)
	_check(Collections.has("bottles", "bottle_13"), "Pim's bottle counts for the collection")
	for i in 38:
		Inventory.add("message_bottle", 1)
		_hotbar("message_bottle")
		var text := Story.use_item("message_bottle")
		got[text.get_slice(":", 0)] = true
	_check(Bottles.read_count() == 40 and Collections.has("bottles", "bottle_39"), "39 bottles read, Agatha's last; Olaf mails the fortieth")
	_check(Inventory.count_of("star_amber") >= 1 or Mail.letters.any(func(l: Dictionary) -> bool: return str(l.get("key", l.get("text", ""))) == "mail.bottle_40"),
		"the fortieth comes with a Star Amber")
	_check(Game.flag("treasure_7") and Story.cards.has("mercy_hold") and Inventory.count_of("letter_hedda") == 1, "bottles lead to treasure, a card, letters")
	Inventory.add("message_bottle", 1)
	_hotbar("message_bottle")
	_check(Story.use_item("message_bottle") == Loc.t("bottle.all") and Inventory.count_of("unopened_letter") == 1, "then they stay sealed for Olaf")
	_check(Inventory.count_of("empty_bottle") == 38, "an empty bottle from each")
	Relationships.set_hearts("npc_hedda", 0)
	Story.npc_action("npc_hedda", "opt:hedda_letter")
	_check(Relationships.hearts_of("npc_hedda") >= 1, "Hedda's letter: +250")
	# the treasure of bottle 7
	Story.spot_action("treasure_7", "dig")
	_check(Game.flag("treasure_7_dug") and Inventory.count_of("bone_hook") == 1, "twelve steps from the stone with three gulls")
	# cats
	for n in range(1, 9):
		if n != 7:
			Story.spot_action("cat_%d" % n, "read")
	Grotto.hall = 3
	Grotto.interact(Vector2i(0, 0))
	for y in 12:
		for x in 30:
			if Grotto.tile(Vector2i(x, y)) == "G":
				Grotto.interact(Vector2i(x, y))
	_check(Cats.count() == 8 and Collections.found.get("cats", {}).size() == 8, "eight cat graves")
	# tales: the order by conditions
	Relationships.set_hearts("npc_helga", 10)
	Quests.states["q2_2_white_hmar"] = {"steps": ["survive"], "done": true, "counts": {}}
	Quests.states["q3_1_truth"] = {"steps": ["listen"], "done": true, "counts": {}}
	Game.counters["deep_max"] = 30
	Game.set_flag("hmar_open")
	Game.stats["seal_feed_days"] = 3
	for i in 12:
		Clock.day_index += 1
		Game.counters["helga_liked_day"] = Clock.day_index
		Tales.tell()
	_check(Tales.count() == 12 and Story.pages.has(8) and Game.flag("pact_words"), "twelve tales; the sixth gives the words of the Pact")


# Rann's daughters (12.4): each meeting, its trial and its blessing; five of them bring the Gills (Q3.11).
func _check_daughters() -> void:
	_fresh()
	Game.act = 2
	# Zyb: a calm day at sea, a rhythm to row
	var calm := -1
	for d in range(28, 56):
		if Weather.calm_on(d):
			calm = d
			break
	_goto(calm, 10)
	_check(Story.spots_on("sea").any(func(s: Dictionary) -> bool: return str(s["id"]) == "daughter_zyb"), "Zyb waits on a calm day")
	var game := Spots.minigame(Story.spot("daughter_zyb"), "trial")
	game.autoplay(1.0)
	_check(game.won and Spots.after_minigame(Story.spot("daughter_zyb"), "trial", game).contains(Loc.t("daughter.zyb")), "rowing in her rhythm")
	_check(Daughters.boat_speed_mult() > 1.0, "the boat is faster")
	var weak := Spots.minigame(Story.spot("daughter_burun"), "trial")
	weak.autoplay(0.0)
	_check(not weak.won, "a clumsy keeper loses the breaker race")
	var strong := Spots.minigame(Story.spot("daughter_burun"), "trial")
	strong.autoplay(1.0)
	Spots.after_minigame(Story.spot("daughter_burun"), "trial", strong)
	_check(Daughters.has("burun") and Daughters.storm_hull_safe(), "Burun: storms spare the boat")
	# Pena: seven sea glass the morning after a storm
	Game.counters["last_storm_day"] = Clock.day_index - 1
	Clock.set_time(6, 0)
	_check(Story.spots_on("seal_shore").any(func(s: Dictionary) -> bool: return str(s["id"]) == "daughter_pena"), "Pena on the morning after a storm")
	_check(Story.spot_action("daughter_pena", "give") == Loc.t("daughter.need_glass"), "she wants seven bubbles")
	Inventory.add("sea_glass", 7)
	Story.spot_action("daughter_pena", "give")
	_check(Daughters.has("pena") and Daughters.gift_mult() > 1.0, "Pena: more gifts of the surf")
	# Stuzha: grog on the ice field
	Inventory.add("grog", 1)
	Story.spot_action("daughter_stuzha", "give")
	_check(Daughters.has("stuzha") and Daughters.cold_mult() == 0.5, "Stuzha: the cold builds half as fast")
	# Tish after ten sea burials
	Game.counters["sea_burials"] = 10
	_check(Story.spots_on("sea").any(func(s: Dictionary) -> bool: return str(s["id"]) == "daughter_tish"), "Tish after ten sea burials")
	Story.spot_action("daughter_tish", "listen_d")
	_check(Daughters.has("tish"), "Tish's blessing")
	_check(Quests.state("q3_11_gills") == "none", "four is not enough")
	# Svetla on a summer new moon, with a net
	_goto(28 + 26, 22)
	Inventory.add("hand_net", 1)
	Story.spot_action("daughter_svetla", "dance")
	_check(Daughters.has("svetla") and Inventory.count_of("svetla_spark") == 1 and Game.flag("blessing_svetla"), "Svetla dances; a spark")
	_goto(112 + 28 + 27, 23)
	_check(Daughters.svetla_spark() and Inventory.count_of("svetla_spark") == 2, "the next summer's new moon: a second spark")
	# Priliva: a flawless fish at the peak of a spring tide
	_goto(112 + 14, 6)
	var peak := Clock.next_high_tide()
	Clock.set_time(peak / 60, peak % 60)
	_check(not Daughters.priliva_offering("fish_cod", 2), "an excellent fish is not flawless")
	_check(Daughters.priliva_offering("fish_cod", 3), "Priliva rises for a flawless one")
	# Otliva: staying in the tenth hall when the water comes back
	Grotto.active = true
	Grotto.hall = 9
	_check(Grotto.flood() == "otliva" and Daughters.has("otliva") and Grotto.blessed(), "Otliva holds the water in the tenth hall")
	_check(Daughters.count() == 8, "all eight blessings")
	Quests.check_starts()
	_check(Quests.state("q3_11_gills") == "active", "five and more: Rann's Gills")
	Cutscenes.simulate("ev_story_rann_gills")
	_check(Inventory.count_of("rann_gills") == 1 and Game.flag("gills_of_rann") and Quests.state("q3_11_gills") == "done", "the Gills")
	_check(ConditionContext.check("blessings() >= 8"), "the Nine Maidens glow")


# The Guild House (23): offerings, rooms mended, the Hmar Nights fewer; the Neptune path and clause 47.3.
func _check_community() -> void:
	_fresh()
	Game.act = 2
	Game.set_flag("hmar_open")
	Weather.last_hmar_day = -100
	var before := Weather.hmar_chance(40)
	Inventory.add("driftwood", 99)
	Inventory.add("stone", 99)
	_hotbar("driftwood")
	_check(Community.offer("workshop", Inventory.selected_hotbar).begins_with(Loc.t("community.offered") % Crafting.item_name("driftwood")), "99 driftwood into the Workshop")
	_hotbar("stone")
	Community.offer("workshop", Inventory.selected_hotbar)
	_check(Community.slot_done("workshop", "wood_stone"), "driftwood and stone slot done")
	Inventory.add("tool_hoe", 1)
	_hotbar("tool_hoe")
	_check(Community.offer("workshop", Inventory.selected_hotbar) == Loc.t("community.nothing"), "the Mistfolk refuse what they don't need")
	for pair in [["iron_ingot", 10], ["copper_ingot", 10], ["brass", 5], ["glass", 10], ["resin", 10], ["kelp_ash", 20], ["canvas", 10],
			["yarn", 10], ["flax_fiber", 5], ["peat", 50], ["salt", 30]]:
		Inventory.add(str(pair[0]), int(pair[1]))
		_hotbar(str(pair[0]))
		Community.offer("workshop", Inventory.selected_hotbar)
	_check(Community.room_done("workshop") and Game.flag("mill_open") and Game.flag("bridge_north"), "the Workshop: the mill and the bridge")
	_check(Weather.hmar_chance(40) < before, "a mended room: fewer Hmar Nights")
	# the ghosts' gifts are only remembered
	Inventory.add("pim_harmonica", 1)
	Inventory.add("bartholomew_ladle", 1)
	Inventory.add("vera_pointer", 1)
	_hotbar("pim_harmonica")
	var answer := Community.offer("memorial", Inventory.selected_hotbar)
	_check(answer.contains(Loc.t("community.returned")) and Inventory.count_of("pim_harmonica") == 1, "ghost gifts come back")
	# the chest: money
	for s in ["c2500", "c5000", "c10000", "c25000"]:
		Community.offer_money("chest", s)
	_check(Community.room_done("chest") and Game.flag("school_open") and Game.flag("ferry_saturdays"), "the Mistfolk's Chest: ferry, school, catalogue")
	# the rest, as a debug skip, then the Homecoming
	for room in ["fishers", "pantry", "memorial", "navigator"]:
		for slot in Community.room(room)["slots"]:
			for entry in slot["items"]:
				Community._record(room, str(slot["id"]), str(entry[0]))
		Community._check_room(room)
	_check(Community.rooms_done() == 6 and Game.flag("guild_house_restored") and Community.hmar_mult() == 0.5, "all six rooms: the Homecoming")
	_check(Game.flag("elmo_bell") and Game.flag("chapel_crypt") and Farm.opened.has("greenhouse"), "the bell, the crypt, the greenhouse")
	Story.spot_action("chapel_crypt", "fresco")
	_check(Story.pages.has(11), "page 11 behind the fresco")
	# Neptune
	_fresh()
	_goto(19, 10)
	Quests.start("q1_11_neptune")
	var mercy := Sea.mercy
	var money := Economy.money
	Cutscenes.simulate("ev_story_stern_offer", [0])
	_check(Community.neptune == "signed" and Economy.money == money + 5000 and Sea.mercy <= mercy - 19.0, "signing: 5 000 kr and the sea darkens")
	_check(Community.pay_room("memorial") == Loc.t("community.refused"), "'We do not invest in the dead'")
	Community.pay_room("fishers")
	_check(Community.paid.has("fishers") and Community.room_done("fishers") and Community.mist_rooms() == 0, "a paid room keeps no Mistfolk")
	Inventory.add("fish_cod", 5)
	_hotbar("fish_cod")
	money = Economy.money
	var sold := Community.sell_to_cannery(Inventory.selected_hotbar)
	_check(Economy.money > money and Inventory.count_of("fish_cod") == 0, "the cannery buys at 95% with Neptune's pier: " + sold)
	_check(Community.bay_fish_mult() < 1.0, "the bay's fish bite less")
	Relationships.set_hearts("npc_ilm", 0)
	Finale.phase = "choice"
	_check(Finale.missing("A").has("neptune"), "the contract closes the New Pact")
	Finale.phase = ""
	# clause 47.3
	Story.add_evidence("portfolio")
	Quests.check_starts()
	_check(Quests.state("sq_clause_47") == "active", "clause 47.3 after Pennington's portfolio")
	Inventory.add("boards", 10)
	for pair in [["npc_knud", "coffin"], ["npc_magnus", "certificate"], ["npc_benedict", "service"], ["npc_sigrid", "epitaph"]]:
		Story.npc_action(str(pair[0]), "deliver:sq_clause_47:" + str(pair[1]))
	_check(Quests.step_done("sq_clause_47", "epitaph"), "the funeral is arranged")
	mercy = Sea.mercy
	Cutscenes.simulate("ev_story_own_funeral", [0])
	_check(Community.neptune == "annulled" and Sea.mercy >= mercy + 9.0 and Quests.state("sq_clause_47") == "done", "the keeper rises: the contract is void")
	_check(not Finale.missing("A").has("neptune"), "the New Pact is open again")


# The festivals (24): a day at the festival place stops the clock; the activities and their minigames.
func _check_festivals() -> void:
	_fresh()
	Economy.money = 100000
	var days := {"boat_blessing": 12, "bird_day": 23, "white_sun": 28 + 10, "regatta": 28 + 24, "herring_fair": 56 + 15,
		"drowned_night": 56 + 26, "ice_festival": 84 + 7, "long_night": 84 + 24}
	for id in days:
		var f := Festivals.info(str(id))
		_goto(int(days[id]), int(f["start"]))
		_check(str(Festivals.today().get("id", "")) == str(id), "%s is on its day" % id)
		Festivals.on_map_entered(str(f["map"]))
		_check(Festivals.active == str(id), "%s starts when the keeper walks in" % id)
		var minute := Clock.minutes
		Clock._process(30.0)
		_check(Clock.minutes == minute, "%s: the clock stands still" % id)
		for a in f["activities"]:
			var act := str(a["id"])
			if str(a["kind"]) == "shop":
				continue
			var result: Variant = Festivals.run(act)
			if result is Minigame:
				(result as Minigame).autoplay(1.0)
				result = Festivals.finish(act, result)
			_check(str(result) != "", "%s/%s answers" % [id, act])
		Festivals.on_map_entered("cape")
		_check(not Festivals.running() and Clock.hour == (int(f["end"]) if int(f["end"]) < 24 else 23), "%s ends and moves the clock" % id)
	_check(Game.counters.get("boat_blessed_until", -1) >= 12, "Benedict's blessing on the boat")
	_check(Collections.found.get("birds", {}).size() == 5, "Liv's five birds")
	_check(Inventory.count_of("fair_token") > 0, "fair tokens")
	var dance := Festivals.dance_partner()
	_check(dance == "", "no partner below 4 hearts")
	Relationships.set_hearts("npc_liv", 4)
	_check(Festivals.dance_partner() == "npc_liv", "Liv dances with a keeper at 4 hearts")
	# the regatta needs a sloop; a strong keeper wins it
	_fresh()
	Sea.set_boat("sloop")
	_goto(28 + 24, 9)
	Festivals.begin("regatta")
	var race: Minigame = Festivals.run("race")
	race.autoplay(1.0)
	_check(race.won and Festivals.finish("race", race).begins_with(Loc.t("fest.win").left(6)) and Inventory.count_of("storm_sails") == 1, "the regatta: cup and storm sails")
	# NPCs go to the festival place for its hours
	_goto(56 + 15, 10)
	var entry := Festivals.schedule_entry("npc_olaf")
	_check(not entry.is_empty() and str(entry["path"][1][1]) == "village", "Olaf goes to the Herring Fair")
	_check(NPCs.entry_for("npc_olaf") == entry or int(NPCs.entry_for("npc_olaf").get("priority", 0)) == 1000, "the festival outranks the day's routine")
	# the Long Night's secret giver writes a week before
	_goto(84 + 17, 20)
	Festivals.night()
	_check(Mail.letters.any(func(l: Dictionary) -> bool: return str(l["text"]) == "mail.secret_giver"), "the Secret Giver's letter")
