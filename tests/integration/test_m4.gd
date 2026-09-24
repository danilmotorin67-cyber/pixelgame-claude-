extends Node

# Run with: godot --headless --path . res://tests/integration/test_m4.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _new_game() -> void:
	Game.reset()
	Game.world_seed = 11
	Clock.reset()
	Weather.reset()
	Weather.start_day(0)
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Graveyard, Mail, Knowledge, Quests]:
		system.reset()
	Farm.scatter_rocks()
	Crafting.add_prefilled("cape", "chest", 664, 380, [["canvas", 1], ["thread", 2], ["rag", 3]])
	for tool in ["tool_hoe", "tool_shovel", "tool_scythe", "tool_pick"]:
		Inventory.add(tool, 1)
	Save.save_root = "user://saltlight_m4_test_saves"
	Save.current_slot = 2


func _scene() -> Node:
	Router.current_map = "cape"
	Router.spawn = Vector2(600, 360)
	Game.player_state = {}
	var old := get_tree().current_scene
	var cape: Node = load("res://scenes/world/cape.tscn").instantiate()
	get_tree().root.add_child(cape)
	get_tree().current_scene = cape
	if old and old != self:
		old.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return cape


func _sleep() -> void:
	Clock.paused = false
	Clock.set_time(23, 0)
	Weather.set_weather("clear")
	Night.end_day(false)
	await get_tree().process_frame
	await get_tree().process_frame


func _select(id: String) -> void:
	for index in Inventory.HOTBAR:
		if Inventory.slots[index]["id"] == id:
			Inventory.select_hotbar(index)


func _check_peace_formula() -> void:
	_new_game()
	_check(Graveyard.graves.size() == 12 and Graveyard.recalc_peace() == 0.0, "8 broken old graves keep Peace at 0")
	_check(Graveyard.penalties["neglect"] == 16, "each broken old grave counts as neglected (-2)")
	Inventory.add("stone", 40)
	for plot in 8:
		_check(Graveyard.repair_old(plot), "an old grave is repaired with 5 stone and a scythe")
	_check(is_equal_approx(Graveyard.peace, 12.0), "8 repaired graves of quality 20: Peace 0.6 x 20 = 12")
	var b := Graveyard.spawn_body(Graveyard.registry_entry("reg_nils_berg"), "cape")
	Clock.day_index = 2
	Graveyard.recalc_peace()
	_check(is_equal_approx(Graveyard.peace, 12.0 - 10.0), "a body on the shore for over a day: -10")
	Clock.day_index = 3
	b["where"] = "morgue"
	Graveyard.recalc_peace()
	_check(is_equal_approx(Graveyard.peace, 12.0 - 3.0), "an unburied body older than 2 days: -3")
	b["restless"] = true
	Graveyard.recalc_peace()
	_check(is_equal_approx(Graveyard.peace, 12.0 - 8.0), "a restless dead: -5 more")
	b["restless"] = false
	Graveyard.graves[3]["weeds"] = true
	Graveyard.recalc_peace()
	_check(is_equal_approx(Graveyard.peace, 12.0 - 3.0 - 2.0), "weeds make a grave neglected: -2")
	_check(Graveyard.tend(3, "tool_scythe") and is_equal_approx(Graveyard.peace, 9.0), "the scythe clears the weeds")
	Graveyard.laid_ghosts.append("ghost_x")
	Graveyard.recalc_peace()
	_check(is_equal_approx(Graveyard.peace, 10.0), "every laid ghost adds 1")
	Game.set_flag("twenty_buried")
	Graveyard.recalc_peace()
	_check(is_equal_approx(Graveyard.peace, 30.0), "all Twenty buried: +20")


func _check_decay() -> void:
	_new_game()
	var b := Graveyard.spawn_body(Graveyard.registry_entry("reg_nils_berg"), "cape")
	for night in 2:
		Clock.day_index += 1
		Graveyard.advance_night(false)
	_check(float(b["preservation"]) == 80.0, "10 a day on the shore")
	b["where"] = "morgue"
	Clock.day_index += 1
	Graveyard.advance_night(false)
	_check(float(b["preservation"]) == 74.0, "6 a day in the morgue")
	for night in 2:
		Clock.day_index += 1
		Graveyard.advance_night(false)
	_check(bool(b["restless"]), "after 5 days unburied the dead grow restless")
	Graveyard.incoming.append({"ship": "ship.hope.name", "arrive": Clock.day_index + 1, "beach": "wreck_bay",
		"registry": str(Graveyard._person(RandomNumberGenerator.new(), "merchant_brig", "ship.hope.name")["id"])})
	Clock.day_index += 1
	var arrived := Graveyard.advance_night(false)
	_check(arrived.size() == 1 and str(Graveyard.body(arrived[0])["map"]) == "wreck_bay", "a drowned sailor from the wreck washes up")
	_check(Graveyard.clue_text("initials:Я.Х.") == Loc.t("clue.initials") % "Я.Х.", "clues read as text")
	var storm_bodies := 0
	for seed_value in 100:
		Game.world_seed = seed_value
		Graveyard.next_id = seed_value * 3
		if not Graveyard.advance_night(true).is_empty():
			storm_bodies += 1
	_check(storm_bodies >= 8 and storm_bodies <= 35, "a storm brings a body about 20%% of the time (%d/100)" % storm_bodies)


func _check_q1_1_and_q1_5() -> void:
	_new_game()
	var cape: Node = await _scene()
	await _sleep()
	_check(Clock.day_index == 1 and Quests.state("q1_1_sea_returns") == "active", "Q1.1 starts on Spring 2")
	var lars := Graveyard.body("body_lars_ek")
	cape = get_tree().current_scene
	_check(not lars.is_empty() and str(lars["where"]) == "shore" and str(lars["map"]) == "cape", "Lars Ek lies on the cape beach")
	var layer: BodiesLayer = cape.get_node("BodiesLayer")
	var body_node: BodyObject = null
	for child in layer.get_children():
		if child is BodyObject and child.body_id == "body_lars_ek":
			body_node = child
	var player: Player = cape.get_node("Player")
	Clock.paused = false
	Clock.set_time(7, 0)
	body_node.interact(player)
	_check(Graveyard.carried == "body_lars_ek", "the keeper lifts the body")
	var morgue: MorgueDoor = cape.get_node("GraveyardWorld/MorgueDoor")
	morgue.interact(player)
	_check(str(lars["where"]) == "morgue" and Quests.step_done("q1_1_sea_returns", "carry"), "into the morgue")
	var chest: Dictionary = {}
	for obj in Crafting.placed["cape"]:
		if obj["id"] == "chest":
			chest = obj
	_check(Crafting.retrieve(chest, 0) and Crafting.retrieve(chest, 1) and Inventory.count_of("canvas") == 1,
		"Agatha's chest holds the canvas offcut")
	cape.get_node("GraveyardWorld/WaterPump").interact(player)
	var panel: InfoPanel = MorguePanel.open(cape.get_node("HUD"))
	panel.select(0)
	var energy := player.energy
	panel.press("Осмотреть")
	_check(bool(lars["examined"]) and lars["revealed"].has("tattoo:anchor_le") and player.energy == energy - 5.0,
		"examining shows the anchor tattoo for 5 energy")
	_check(Clock.hour == 8, "an examination takes an hour")
	panel.press("Обмыть")
	panel.press("Зашить")
	_check(bool(lars["washed"]) and bool(lars["sewn"]) and bool(lars["stitch"]) and Graveyard.preparation(lars) == 20,
		"washed, sewn with the last stitch: preparation 8 + 10 + 2")
	panel.press("Обыскать")
	_check(bool(lars["searched"]) and lars["items"].has("knife_initials_le"), "his knife goes to the family box")
	panel.press("Нести")
	_check(Graveyard.carried == "body_lars_ek", "carried out again")
	var plot_node: GravePlot = null
	for child in cape.get_node("GraveyardWorld").get_children():
		if child is GravePlot and child.plot == 8:
			plot_node = child
	_select("tool_shovel")
	for hit in Graveyard.dig_hits_needed():
		plot_node.use_tool(player, "tool_shovel")
	_check(bool(Graveyard.graves[8]["open"]), "six shovel hits open a grave")
	plot_node.interact(player)
	plot_node.use_tool(player, "tool_shovel")
	_check(bool(Graveyard.graves[8]["filled"]) and str(lars["where"]) == "grave", "laid and filled")
	var stones := 0
	for rock in Farm.rocks["cape"].duplicate():
		for hit in 2:
			var got := Farm.hit_rock("cape", rock)
			if got > 0:
				stones += got
		if Inventory.count_of("stone") >= 10:
			break
	_check(Inventory.count_of("stone") >= 10, "the pickaxe breaks the cape's stones into stone")
	_select("stone")
	plot_node.interact(player)
	_check(str(Graveyard.graves[8]["marker"]) == "mound" and int(Graveyard.graves[8]["quality"]) == 25,
		"the stone mound: preparation 20 + 5")
	_check(Quests.state("q1_1_sea_returns") == "done", "Q1.1 is complete")

	await _sleep()
	await _sleep()
	await _sleep()
	_check(Clock.day_index == 4 and Quests.state("q1_5_registry") == "active" and Game.flag("registry_copy"),
		"Q1.5 starts on Spring 5 with the registry copy")
	var candidates := Graveyard.candidates(lars, true)
	_check(candidates.size() == 1 and str(candidates[0]["id"]) == "reg_lars_ek", "the clue filter leaves only Lars Ek")
	_check(Graveyard.identify(lars, "reg_lars_ek") and int(Graveyard.graves[8]["quality"]) == 35
		and str(Graveyard.graves[8]["name"]) == "Ларс Эк", "the name on the grave adds 10 quality")
	Clock.set_time(10, 0)
	var money := Economy.money
	_check(Graveyard.send_family_letter(lars) and Economy.money == money - 20, "the family letter costs 20 kr")
	var honor := Game.honor
	for n in 4:
		await _sleep()
	_check(Clock.day_index == 8, "Spring 9")
	var reply: Dictionary = {}
	for letter in Mail.letters:
		if str(letter["text"]) == "mail.lars_family":
			reply = letter
	_check(not reply.is_empty() and int(reply["money"]) == 200, "Lars's mother answers on Spring 9 with 200 kr")
	Mail.read(reply)
	_check(Inventory.count_of("mothers_socks") == 1 and Game.honor == honor + 5, "her knitted socks and +5 honour")
	_check(Quests.state("q1_5_registry") == "done", "Q1.5 is complete")
	var burial_pay := false
	for letter in Mail.letters:
		burial_pay = burial_pay or (str(letter["text"]) == "mail.burial_pay" and int(letter["money"]) == 50)
	_check(burial_pay, "the directorate pays 50 kr for the burial")


func _check_whisper_and_mistakes() -> void:
	_new_game()
	Clock.day_index = 1
	var lars := Graveyard.spawn_body(Graveyard.registry_entry("reg_lars_ek").merged({"whisper": {"text": "body.lars.whisper",
		"clue": "initials:Л.Э."}}), "cape", true, "body_lars_ek")
	lars["where"] = "morgue"
	Clock.set_time(23, 0)
	_check(Graveyard.whisper(lars) == "", "no whisper before midnight")
	Clock.set_time(0, 30)
	_check(Graveyard.whisper(lars) == Loc.t("body.lars.whisper") and lars["revealed"].has("initials:Л.Э."),
		"the first night's whisper gives one more clue")
	_check(Graveyard.whisper(lars) == "", "only once")
	var other := Graveyard.spawn_body(Graveyard.registry_entry("reg_ulf_skog"), "cape")
	other["where"] = "morgue"
	_check(Graveyard.identify(other, "reg_jan_holm"), "a wrong name can be chosen")
	Clock.set_time(10, 0)
	Graveyard.send_family_letter(other)
	Graveyard.deliver_replies(Clock.day_index + 10)
	_check(Game.honor == -5 and bool(other["wrong_revealed"]) and str(Mail.letters[-1]["text"]) == "mail.family_wrong",
		"the family writes back that he is alive: -5 honour")
	_check(Graveyard.identify(other, "reg_ulf_skog"), "the mistake can be corrected")


func _check_pim_and_ulrika() -> void:
	_new_game()
	Clock.day_index = 8
	var cape: Node = await _scene()
	await _sleep()
	var pim := Graveyard.body("body_pim")
	_check(Clock.day_index == 9 and not pim.is_empty() and not Graveyard.body("body_bartholomew").is_empty(),
		"the cook and the cabin boy wash up on Spring 10")
	Graveyard.pick_up(pim)
	Graveyard.graves[9]["dug"] = 5
	Graveyard.graves[9]["open"] = true
	Graveyard.lay(9)
	Graveyard.fill(9)
	Clock.set_time(22, 0)
	_check(Graveyard.present_ghosts().size() == 1, "Pim's ghost rises by his grave at night")
	cape = get_tree().current_scene
	var layer: BodiesLayer = cape.get_node("BodiesLayer")
	layer.rebuild()
	var ghost_node: GhostObject = null
	for child in layer.get_children():
		if child is GhostObject:
			ghost_node = child
	_check(ghost_node != null, "the ghost shows on the cape at night")
	ghost_node.interact(cape.get_node("Player"))
	var panel: InfoPanel = cape.get_node_or_null("HUD/InfoPanel")
	_check(panel != null and panel._body.text == Loc.t("ghost.pim.greet") and Quests.state("g2_letter_home") == "active",
		"Pim asks for his bottle")
	panel.close()
	var found := false
	for n in 3:
		await _sleep()
		for gift in Sea.gifts.get("wreck_bay", []):
			if gift["item"] == "bottle_13":
				found = true
				Clock.set_time(12, 0)
				var low := 6 * 60
				for m in range(6 * 60, 20 * 60, 10):
					if Clock.tide_height_at(Clock.day_index, m) < Clock.tide_height_at(Clock.day_index, low):
						low = m
				Clock.set_time(low / 60, low % 60)
				Sea.collect_gift("wreck_bay", gift)
				break
		if found:
			break
	_check(found and Inventory.count_of("bottle_13") == 1 and Quests.step_done("g2_letter_home", "find"),
		"bottle No. 13 washes into Wreck Bay within three days")
	Inventory.take("bottle_13", 1)
	Events.quest_event.emit("bottle_sent", "bottle_13")
	_check(Quests.state("g2_letter_home") == "done", "Olaf posts the letter")
	var peace := Graveyard.recalc_peace()
	Clock.set_time(23, 0)
	_check(Graveyard.talk_ghost("ghost_pim") == Loc.t("ghost.pim.done") and Inventory.count_of("pim_harmonica") == 1
		and Graveyard.laid_ghosts.has("ghost_pim") and Graveyard.peace >= peace and Knowledge.rest_pts >= 5,
		"Pim is laid to rest: the harmonica and +5 rest notes")
	_check(Graveyard.present_ghosts().is_empty(), "a laid ghost does not return")

	Inventory.add("stone", 5)
	Graveyard.repair_old(0)
	_check(Graveyard.present_ghosts().size() == 1 and Graveyard.talk_ghost("ghost_ulrika") == Loc.t("ghost.ulrika.greet"),
		"keeper Ulrika wakes when her old grave is tended")
	Lighthouse.lens = "great_eye"
	Lighthouse.lamp = "rann_torch"
	Lighthouse.mechanism = "auto"
	Game.set_flag("lantern_glass_repaired")
	Weather.set_weather("clear")
	Weather.hmar_night = false
	for night in 7:
		Inventory.add("kerosene", 1)
		Lighthouse.refill()
		Lighthouse.cleanliness = 10.0
		Clock.set_time(19, 30)
		Lighthouse.light_lamp()
		Lighthouse.resolve_night()
	_check(Quests.state("g13_check_fire") == "done", "seven strong nights in a row satisfy Ulrika")
	Graveyard.talk_ghost("ghost_ulrika")
	_check(Game.flag("keeper_word") and Graveyard.laid_ghosts.has("ghost_ulrika"), "she hands over the Keeper's Word")

	Clock.set_time(23, 30)
	var honor := Game.honor
	_check(Graveyard.exhume(9) and Game.honor == honor - 10 and Graveyard.carried == "body_pim"
		and float(pim["preservation"]) == 0.0, "exhuming without a reason: -10 honour, remains")
	Graveyard.store_in_morgue()
	_check(Graveyard.preparation(pim) <= 20, "remains cannot be prepared past 20 (plus coffin and funeral)")
	Clock.day_index = 13
	Clock.set_time(10, 30)
	Economy.money = 100
	Inventory.add("wax_candle", 2)
	_check(Graveyard.chapel_funeral() == "ok" and bool(pim["funeral"]) and Economy.money == 50
		and Inventory.count_of("wax_candle") == 0, "Benedict's Sunday service: 50 kr and 2 candles")
	Clock.day_index = 14
	_check(Graveyard.chapel_funeral() == "hours", "services only on Sundays 10-12")
	var saved := JSON.stringify(Graveyard.serialize())
	Graveyard.deserialize(JSON.parse_string(saved))
	_check(JSON.stringify(Graveyard.serialize()) == saved, "the graveyard survives a save")
	var quests := JSON.stringify(Quests.serialize())
	Quests.deserialize(JSON.parse_string(quests))
	_check(JSON.stringify(Quests.serialize()) == quests, "quest progress survives a save")


func _run() -> void:
	_check_peace_formula()
	_check_decay()
	await _check_q1_1_and_q1_5()
	_check_whisper_and_mistakes()
	await _check_pim_and_ulrika()
	for file_path in Save._candidate_paths(2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	Save.save_root = "user://saves"
	Save.current_slot = 0
	print("M4 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
