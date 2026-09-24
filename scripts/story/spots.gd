class_name Spots

# What the story's places in the world do (data/story_spots.json): a view (title, text, action buttons) and the
# actions themselves. A few actions are games of skill: minigame() gives the Minigame, after_minigame() settles it.


static func view(s: Dictionary, v: Dictionary) -> Dictionary:
	var actions: Array = []
	match str(s.get("kind", "")):
		"glow_water":
			actions = [[Loc.t("spot.act.sample"), "sample"]]
		"berta_wreck", "lantern_dive":
			actions = [[Loc.t("spot.act.dive"), "dive"]]
		"crypt", "cairn":
			actions = [[Loc.t("spot.act.take"), "take"]]
		"treska":
			v["text"] = str(v["text"]) + "\n" + Loc.t("spot.tide") % Clock.tide_height()
			actions = [[Loc.t("spot.act.refloat"), "refloat"]]
		"archive":
			actions = [[Loc.t("spot.act.copy"), "copy"]]
		"telegraph":
			actions = [[Loc.t("spot.act.listen"), "listen"]]
		"safe":
			if Inventory.count_of("safe_key") > 0:
				actions.append([Loc.t("spot.act.open_key"), "open"])
			if Clock.hour >= 23 or Clock.hour < 3:
				actions.append([Loc.t("spot.act.break"), "break"])
		"ambush":
			v["text"] = str(v["text"]) + "\n" + ambush_text()
			for npc in ambush_candidates():
				var label := Loc.t("spot.act.drop") if ambush_crew.has(npc) else Loc.t("spot.act.take_ally")
				actions.append([label % Loc.t(str(NPCs.info(npc).get("name", npc))), "ally:" + npc])
			actions.append([Loc.t("spot.act.approach"), "approach"])
		"raven_mark", "dig":
			actions = [[Loc.t("spot.act.dig"), "dig"]]
		"ritual":
			actions = [[Loc.t("spot.act.rite"), "rite"]]
		"cat":
			actions = [[Loc.t("spot.act.read"), "read"]]
		"owl":
			actions = [[Loc.t("spot.act.look"), "look"]]
		"sketch":
			actions = [[Loc.t("spot.act.sketch"), "sketch"]]
		"cannery":
			actions = [[Loc.t("neptune.cannery"), "sell"]]
		"chapel_crypt":
			actions = [[Loc.t("spot.act.fresco"), "fresco"]]
		"circle":
			v["text"] = str(v["text"]) + "\n" + Loc.t("story.circle") % (Daughters.count() + (1 if Daughters.has("hmar") else 0))
		"daughter":
			actions = _daughter_actions(str(s.get("daughter", "")))
		"kronvald":
			actions = [[Loc.t("kronvald.go"), "go"]]
		"cabinet":
			v["text"] = str(v["text"]) + "\n" + Loc.t("cabinet.head") % Cabinet.count()
			actions = [[Loc.t("cabinet.give"), "give"]]
		"agatha":
			actions = [[Loc.t("spot.act.talk"), "talk"]]
		"cat_key":
			actions = [[Loc.t("spot.act.lift_cat"), "lift"]]
	v["actions"] = actions
	return v


static func act(s: Dictionary, action: String, arg: String = "") -> String:
	match action:
		"sample":
			if Inventory.count_of("hand_net") <= 0:
				return Loc.t("daughter.need_net")
			Inventory.add("glow_plankton", 1)
			Events.quest_event.emit("plankton_sampled", "")
			return Loc.t("spot.sampled")
		"dive":
			return _dive(s)
		"take":
			if str(s["kind"]) == "crypt":
				Story.add_fragment(1)
				return Loc.t("spot.fragment_1")
			Story.add_page(3)
			return Loc.t("spot.page_3")
		"refloat":
			if Clock.tide_height() > -0.4:
				return Loc.t("spot.tide_high")
			if not Inventory.take("boards", 5):
				return Loc.t("story.deliver.missing") + " " + Crafting.item_name("boards") + " ×5"
			Game.set_flag("treska_refloated")
			Events.quest_event.emit("treska_refloated", "")
			return Loc.t("spot.refloated")
		"copy":
			Inventory.add("death_certificates", 1)
			Game.set_flag("certificates_taken")
			Events.quest_event.emit("certificates_taken", "")
			return Loc.t("spot.copied")
		"listen":
			if Quests.state("sq_intercept") == "active" and (Clock.hour >= 22 or Clock.hour < 2):
				Story.add_evidence("telegram")
				Events.quest_event.emit("telegram_caught", "")
				return Loc.t("spot.telegram")
			return Loc.t("spot.telegraph_quiet") % Loc.t("weather." + Weather.barometer(1))
		"open":
			if not Inventory.take("safe_key", 1):
				return ""
			return open_safe()
		"approach":
			return ""
		"dig":
			return _dig(s)
		"rite":
			return rite()
		"read":
			var n := int(s.get("index", 0))
			Cats.find(n)
			return Cats.text(n)
		"look":
			Events.quest_event.emit("owl_seen", "")
			return Loc.t("story.owl")
		"sketch":
			return Ghosts.sketch(str(s["id"]).substr(7))
		"sell":
			return Community.sell_to_cannery(Inventory.selected_hotbar)
		"fresco":
			Story.add_page(11)
			return Loc.t("story.crypt.fresco")
		"give":
			if str(s["kind"]) == "cabinet":
				return Cabinet.donate(Inventory.selected_hotbar)
			return _daughter_give(str(s.get("daughter", "")))
		"listen_d", "dance":
			return _daughter_give(str(s.get("daughter", "")))
		"go":
			return Kronvald.travel()
		"talk":
			return Loc.t("agatha.line.%d" % (1 + posmod(Clock.day_index, 4)))
		"lift":
			Game.set_flag("house_key")
			return Loc.t("spot.cat_key")
	if action.begins_with("ally:"):
		return toggle_ally(action.substr(5))
	return ""


# ---- the games of skill ----

static func minigame(s: Dictionary, action: String) -> Minigame:
	var preset := ""
	match action:
		"break":
			preset = "break_in"
		"approach":
			preset = "teeth_stealth"
		"trial":
			preset = "zyb_rhythm" if str(s.get("daughter", "")) == "zyb" else "burun_race"
	if preset == "":
		return null
	var p: Dictionary = (Story.cfg("minigames", {}).get(preset, {}) as Dictionary).duplicate()
	p["seed"] = Game.world_seed + Clock.day_index * 13 + preset.hash()
	if preset == "teeth_stealth":
		# Allies watch for the beam: Hedda and Kai know these rocks best.
		for npc in ambush_crew:
			p["allowed"] = int(p.get("allowed", 1)) + (2 if npc in ["npc_hedda", "npc_kai"] else 1)
	return Minigame.make(str(p.get("type", "lanes")), p)


static func after_minigame(s: Dictionary, action: String, game: Minigame) -> String:
	match action:
		"break":
			if game.won:
				Game.add_honor(-15)
				return open_safe()
			Game.add_honor(-5)
			return Loc.t("spot.caught")
		"approach":
			return ambush_result(game.won)
		"trial":
			var d := str(s.get("daughter", ""))
			if game.won and Daughters.grant(d):
				return Loc.t("daughter.granted") % Loc.t("daughter." + d)
			return Loc.t("daughter.failed")
	return ""


# ---- the safe (Q3.8) ----

static func open_safe() -> String:
	Game.set_flag("safe_opened")
	for id in ["fragment_f3", "tuve_skin", "black_book"]:
		if Inventory.add(id, 1) != 1:
			Mail.send("mail.quest_parcel", [], 0, [[id, 1]])
	Game.set_flag("tuve_skin_found")
	Events.quest_event.emit("safe_opened", "")
	return Loc.t("spot.safe_open")


# ---- the ambush at the Teeth (Q3.9): up to two allies from those at 6+ hearts ----

static var ambush_crew: Array = []


static func ambush_candidates() -> Array:
	var out: Array = []
	for npc in Data.all("npcs"):
		var id := str(npc["id"])
		if not bool(npc.get("visitor", false)) and id not in ["npc_fortuna", "npc_halvdan", "npc_nut"] and Relationships.hearts_of(id) >= 6:
			out.append(id)
	return out


static func toggle_ally(npc: String) -> String:
	if ambush_crew.has(npc):
		ambush_crew.erase(npc)
	elif ambush_crew.size() < 2 and ambush_candidates().has(npc):
		ambush_crew.append(npc)
	return ambush_text()


static func ambush_text() -> String:
	var names: Array = []
	for npc in ambush_crew:
		names.append(Loc.t(str(NPCs.info(npc).get("name", npc))))
	return Loc.t("spot.crew") % (", ".join(names) if not names.is_empty() else "—")


static func ambush_result(won: bool) -> String:
	Game.set_flag("ambush_done")
	ambush_crew.clear()
	if won:
		Inventory.add("skau_lantern", 1)
		Game.set_flag("nut_caught")
		if Relationships.hearts_of("npc_rud") >= 4:
			Game.set_flag("rud_testimony")
			Story.add_card("rud_testimony")
			return Loc.t("spot.ambush_won_rud")
		return Loc.t("spot.ambush_won")
	Game.set_flag("lantern_in_water")
	return Loc.t("spot.ambush_lost")


static func _dive(s: Dictionary) -> String:
	if not Game.flag("diving_bell") and Inventory.count_of("diving_suit") <= 0:
		return Loc.t("spot.need_bell")
	if str(s["kind"]) == "berta_wreck":
		Game.set_flag("evidence_berta_hold")
		Story.add_evidence("berta_hold")
		return Loc.t("spot.berta_hold")
	Inventory.add("skau_lantern", 1)
	return Loc.t("spot.lantern_found")


static func _dig(s: Dictionary) -> String:
	if Inventory.count_of("tool_shovel") <= 0:
		return Loc.t("story.dig.no_shovel")
	match str(s["id"]):
		"raven_mark":
			Story.add_page(12)
			return Loc.t("spot.page_12")
		"treasure_7":
			Game.set_flag("treasure_7_dug")
			Inventory.add("bone_hook", 1)
			Economy.add(500)
			return Loc.t("story.dig.found") % Crafting.item_name("bone_hook")
		"treasure_15":
			Game.set_flag("treasure_15_dug")
			Inventory.add("ship_in_bottle", 1)
			Economy.add(500)
			return Loc.t("story.dig.found") % Crafting.item_name("ship_in_bottle")
	return ""


# The rite at Rann's Stone at midnight (Q2.12, Q4.4): a liked gift, a lantern and the words of the Pact.
static func rite() -> String:
	var year := "1" if Quests.state("q2_12_drowned_night") == "active" else "2"
	if not (Game.flag("page_8") or Game.flag("tale_6") or Game.flag("pact_words")):
		return Loc.t("spot.rite_words")
	if Inventory.count_of("lantern_tin") + Inventory.count_of("lantern_agatha") <= 0:
		return Loc.t("spot.rite_lantern")
	var index := Inventory.selected_hotbar
	var id := str(Inventory.slots[index]["id"])
	if id == "" or RannStone.taste(id, int(Inventory.slots[index]["quality"])) not in ["love", "like"]:
		return Loc.t("spot.rite_gift")
	Inventory.take_slot(index, 1)
	Game.counters["drowned_rites"] = int(Game.counters.get("drowned_rites", 0)) + 1
	Graveyard.recalc_peace()
	Cutscenes.queue("ev_story_ritual_" + year)
	Events.quest_event.emit("ritual", year)
	return Loc.t("spot.rite_done")


# ---- the daughters of Rann (12.4) ----

static func _daughter_actions(d: String) -> Array:
	match d:
		"zyb", "burun":
			return [[Loc.t("daughter.try"), "trial"]]
		"pena", "stuzha":
			return [[Loc.t("daughter.give"), "give"]]
		"tish":
			return [[Loc.t("daughter.listen"), "listen_d"]]
		"svetla":
			return [[Loc.t("daughter.dance"), "dance"]]
	return []


static func _daughter_give(d: String) -> String:
	match d:
		"pena":
			if not Inventory.take("sea_glass", 7):
				return Loc.t("daughter.need_glass")
		"stuzha":
			if not (Inventory.take("grog", 1) or Inventory.take("erland_grog", 1)):
				return Loc.t("daughter.need_grog")
		"svetla":
			if Daughters.has("svetla"):
				return Loc.t("daughter.spark") if Daughters.svetla_spark() else ""
			if Inventory.count_of("hand_net") <= 0 and Relationships.hearts_of("npc_liv") < 4:
				return Loc.t("daughter.need_net")
	if Daughters.grant(d):
		return Loc.t("daughter.granted") % Loc.t("daughter." + d)
	return ""
