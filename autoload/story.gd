extends Node

# Section 5: the acts by date, the dated story beats, Agatha's 24 pages, the evidence board, the fragments of
# the Pact Stone, the allies for the Great Tide and what the ending left behind. Quests (quests.json) carry the
# goals; this keeps the story's own state and wires the world's things to it (spots, story items, hand-ins).

# Acts I-IV begin on these days (5.0): Spring y1, Summer y1, Winter y1, Autumn y2.
const ACT_START := [0, 28, 84, 168]
const DAY_FALSE_FIRE := 27
const DAY_WHITE_HMAR := 30
const DAY_GREAT_HMAR := 83
const DAY_AMBUSH := 157
const DAY_GREAT_TIDE := 195
# The seven evidences of Q3.5, in board order; the Grims' black book stands in for any one missing.
const EVIDENCE := ["portfolio", "berta_hold", "tin_box", "hedda", "doctor", "telegram", "lantern"]
const BONFIRES := 6

var pages: Array = []
var evidence: Dictionary = {}
var cards: Array = []
var fragments: Array = []
var stone_whole: bool = false
var stern_phrase: String = ""
var allies: Array = []
# Q2.13: bonfire index -> the absolute minute it was lit; the siege is "", "pending", "failed" or "won".
var bonfires: Dictionary = {}
var great_hmar: String = ""
var finale_day: int = DAY_GREAT_TIDE
var ending: String = ""
var resolution: String = ""
var fortuna_fate: String = ""
var epilogue: Array = []
var tale_day: int = -1
var kai_days: Array = []
var left_cape_day: int = -1


func _ready() -> void:
	Events.gift_given.connect(func(npc: String, _item: String, reaction: String) -> void: Tales.on_gift(npc, reaction))
	Events.quest_completed.connect(func(id: String) -> void:
		Ghosts.on_quest_completed(id)
		if id == "q2_13_great_hmar":
			great_hmar = "won")
	Events.item_added.connect(_on_item_added)
	Events.npc_talked.connect(_on_npc_talked)
	Events.map_entered.connect(_on_map_entered)
	Events.heart_event_seen.connect(func(_id: String) -> void: sync())
	Events.hour_changed.connect(_on_hour)


func cfg(key: String, fallback: Variant = null) -> Variant:
	var table: Variant = Data.tables.get("story", {})
	return table.get(key, fallback) if table is Dictionary else fallback


func reset() -> void:
	pages.clear()
	evidence.clear()
	cards.clear()
	fragments.clear()
	stone_whole = false
	stern_phrase = ""
	allies.clear()
	bonfires.clear()
	great_hmar = ""
	finale_day = DAY_GREAT_TIDE
	ending = ""
	resolution = ""
	fortuna_fate = ""
	epilogue.clear()
	tale_day = -1
	kai_days.clear()
	left_cape_day = -1


# ---- acts and dated beats ----

func act_for(index: int) -> int:
	var act := 1
	for i in ACT_START.size():
		if index >= int(ACT_START[i]):
			act = i + 1
	return act


func update_act() -> void:
	var act := act_for(Clock.day_index)
	if ending != "" and ending != "D":
		act = 5
	Game.act = maxi(Game.act, act) if Game.act < 5 else 5


# Weather the story fixes: the ambush night is foggy, the Great Tide comes with a storm.
func weather_on(index: int) -> String:
	if index == DAY_AMBUSH:
		return "fog"
	if index == finale_day and ending in ["", "D"]:
		return "storm"
	return ""


# Story Hmar nights: the first White Hmar (Q2.2), the Great Hmar (Q2.13) and the Great Tide.
func hmar_on(index: int) -> bool:
	return index in [DAY_WHITE_HMAR, DAY_GREAT_HMAR] or (index == finale_day and ending in ["", "D"])


# Night step "quests": what the night decided for the story (called before new quests may start).
func night(night_index: int, hmar_tonight: bool) -> Array:
	var news: Array = []
	if night_index == DAY_FALSE_FIRE and not Game.flag("berta_wrecked"):
		_wreck_berta()
		news.append("berta")
	if hmar_tonight:
		if left_cape_day != night_index:
			Events.quest_event.emit("hmar_survived", "")
		if great_hmar == "pending" or (night_index == DAY_GREAT_HMAR and great_hmar == ""):
			news.append("great_hmar_" + judge_great_hmar(night_index))
	bonfires.clear()
	update_act()
	sync()
	# 27.3: the sixth tale is guaranteed by Autumn 20 of year 1 — Helga writes "Come, it is time".
	if Clock.day_index == 75 and not Game.flag("tale_6"):
		Mail.send("mail.helga_tale6")
	news.append_array(Community.night())
	news.append_array(Twenty.night())
	Festivals.night()
	Finale.night(night_index)
	return news


# Q1.13: the brig "Saint Berta" turns to the second fire on the Teeth. Its three dead come ashore on Summer 1
# (bodies.json), its crates too; one of them carries boulders.
func _wreck_berta() -> void:
	Game.set_flag("berta_wrecked")
	Game.set_flag("false_fire_seen")
	Lighthouse.wrecks.append({"day": DAY_FALSE_FIRE, "ship": "ship.saint_berta", "type": "merchant_brig", "bodies": 3})
	for i in 3:
		Lighthouse.pending_shore.append({"item": "cargo_merchant", "beach": "cape" if i < 2 else "wreck_bay"})
	Lighthouse.pending_shore.append({"item": "berta_crate_stones", "beach": "wreck_bay"})
	Game.counters["crates_allowed"] = int(Game.counters.get("crates_allowed", 0)) + 1
	Sea.add_mercy(-3.0)


# ---- the Great Hmar (Q2.13) ----

func bonfire_lit(index: int) -> bool:
	return bonfires.has(str(index))


func light_bonfire(index: int) -> String:
	if bonfire_lit(index):
		return "lit"
	var fuel := ""
	for id in ["peat", "driftwood"]:
		if Inventory.count_of(id) > 0:
			fuel = id
			break
	if fuel == "":
		return "fuel"
	Inventory.take(fuel, 1)
	bonfires[str(index)] = night_minute()
	Events.quest_event.emit("bonfire", str(index))
	return "ok"


# The clock keeps the day's number past midnight: small hours count as the next day here.
static func night_minute() -> int:
	return Game.minute_now() + (Clock.MINUTES_PER_DAY if Clock.minutes < Clock.WAKE_MINUTE else 0)


func siege_night() -> bool:
	return Clock.day_index == DAY_GREAT_HMAR or (great_hmar == "pending" and Weather.hmar_night)


# Success needs the fire at 50+, Peace 35+ and all six bonfires lit before 00:30 (5.3).
func judge_great_hmar(night_index: int) -> String:
	var night_start := Lighthouse.last_report
	var deadline := (night_index + 1) * Clock.MINUTES_PER_DAY + 30
	var lit_in_time := 0
	for key in bonfires:
		if int(bonfires[key]) <= deadline:
			lit_in_time += 1
	var won := bool(night_start.get("lit", false)) and float(night_start.get("power", 0.0)) >= 50.0 \
		and Graveyard.peace >= 35.0 and lit_in_time >= BONFIRES
	if won:
		great_hmar = "won"
		Events.quest_event.emit("great_hmar", "won")
		Game.set_flag("great_hmar_won")
		Game.set_flag("village_pier_broken", false)
		return "won"
	great_hmar = "pending"
	Game.set_flag("village_pier_broken")
	Farm.setback(1)
	return "failed"


# ---- Agatha's pages (5.8) ----

func add_page(n: int) -> bool:
	if n < 1 or n > 24 or pages.has(n):
		return false
	pages.append(n)
	pages.sort()
	Game.set_flag("page_%d" % n)
	Collections.mark("pages", "page_%d" % n)
	Knowledge.add_points("rest", 1)
	Events.quest_event.emit("page", str(n))
	if n >= 13 and n <= 16 and _has_pages(13, 16):
		add_evidence("tin_box")
	return true


func _has_pages(from: int, to: int) -> bool:
	for n in range(from, to + 1):
		if not pages.has(n):
			return false
	return true


func page_text(n: int) -> String:
	if n == 24:
		return Loc.t("page.24.%s" % (ending.to_lower() if ending != "" else "d"))
	return Loc.t("page.%d.text" % n)


# ---- the evidence board (Q3.5) ----

func add_evidence(id: String) -> bool:
	if evidence.has(id) or not (id in EVIDENCE or id == "black_book"):
		return false
	evidence[id] = Clock.day_index
	Events.quest_event.emit("evidence", id)
	Knowledge.add_points("rest", 2)
	return true


func add_card(id: String) -> bool:
	if cards.has(id):
		return false
	cards.append(id)
	return true


# Evidences for the court (5.6): the seven, and the black book in place of one that is missing.
func evidence_count() -> int:
	var n := 0
	for id in EVIDENCE:
		if evidence.has(id):
			n += 1
	if evidence.has("black_book") and n < EVIDENCE.size():
		n += 1
	return n


func board_open() -> bool:
	return Quests.state("q3_1_truth") == "done" or Game.act >= 3 and Game.flag("board_open")


# ---- the Pact Stone (Q3.4, Q4.3) ----

func add_fragment(n: int) -> bool:
	if fragments.has(n) or n < 1 or n > 3:
		return false
	fragments.append(n)
	Game.set_flag("fragment_%d_found" % n)
	if Inventory.count_of("fragment_f%d" % n) <= 0:
		Inventory.add("fragment_f%d" % n, 1)
	Events.quest_event.emit("fragment", str(n))
	return true


func can_join_stone() -> bool:
	for n in [1, 2, 3]:
		if Inventory.count_of("fragment_f%d" % n) <= 0:
			return false
	return not stone_whole and Game.act >= 4 and Clock.day_index < finale_day


func join_stone() -> bool:
	if not can_join_stone():
		return false
	for n in [1, 2, 3]:
		Inventory.take("fragment_f%d" % n, 1)
	stone_whole = true
	Game.set_flag("stone_whole")
	Events.quest_event.emit("stone_whole", "")
	return true


# Flags set by heart scenes and other systems carry story facts: fold them into the story's state.
func sync() -> void:
	for n in 24:
		if Game.flag("page_%d" % (n + 1)) and not pages.has(n + 1):
			add_page(n + 1)
	if Game.flag("fragment_1_found") and not fragments.has(1):
		add_fragment(1)
	if Game.flag("evidence_telegram"):
		add_evidence("telegram")
	for card in ["evidence_kai_witness", "evidence_false_fire_schedule", "olaf_old_false_fire_letter", "gudmund_truth"]:
		if Game.flag(card):
			add_card(card)
	for i in 12:
		if Game.flag("tale_%d" % (i + 1)):
			Collections.mark("tales", "tale_%d" % (i + 1))


# ---- the team for the Great Tide (Q4.2) ----

func ally_info(npc: String) -> Dictionary:
	return cfg("allies", {}).get(npc, {})


func can_ask(npc: String) -> bool:
	var info := ally_info(npc)
	return not info.is_empty() and Quests.state("q4_2_team") == "active" and not allies.has(npc) \
		and Relationships.hearts_of(npc) >= int(info.get("hearts", 6))


func ask_ally(npc: String) -> bool:
	if not can_ask(npc):
		return false
	allies.append(npc)
	Events.quest_event.emit("ally", npc)
	return true


func has_ally(npc: String) -> bool:
	return allies.has(npc)


# ---- NPC options: hand-ins, the team, Helga's tales and the story's small favours ----

# [id, label] pairs offered after the day's talk.
func npc_options(npc: String) -> Array:
	var out: Array = []
	for pair in Quests.deliveries(npc):
		var step: Dictionary = pair[1]
		out.append(["deliver:%s:%s" % [pair[0], step["id"]], Loc.t(str(step.get("label", "story.opt.deliver")))])
	if can_ask(npc):
		out.append(["ally", Loc.t("story.opt.ally")])
	if npc == "npc_helga" and Tales.next_tale() > 0:
		out.append(["tale", Loc.t("story.opt.tale")])
	for option in cfg("npc_options", []):
		if str(option["npc"]) == npc and ConditionContext.check(str(option.get("when", ""))):
			out.append(["opt:" + str(option["id"]), Loc.t(str(option["label"]))])
	return out


# Runs an option; returns the NPC's answer.
func npc_action(npc: String, id: String) -> String:
	if id.begins_with("deliver:"):
		var parts := id.split(":")
		var step := _step(parts[1], parts[2])
		if not Quests.can_deliver(step):
			return Loc.t(str(step.get("missing", "story.deliver.missing"))) + "\n" + _needs(step)
		Quests.deliver(parts[1], parts[2])
		return Loc.t(str(step.get("reply", "story.deliver.thanks")))
	if id == "ally":
		if ask_ally(npc):
			return Loc.t(str(ally_info(npc).get("line", "story.ally.yes")))
		return Loc.t("story.ally.no")
	if id == "tale":
		return Tales.tell()
	if id.begins_with("opt:"):
		for option in cfg("npc_options", []):
			if "opt:" + str(option["id"]) == id and str(option["npc"]) == npc:
				if option.has("call"):
					return call_named(str(option["call"]), npc)
				Effects.apply(option.get("effects", []))
				return Loc.t(str(option.get("reply", "")))
	return ""


# Named story actions for data (effects ["call", name], npc options with "call").
func call_named(what: String, npc: String = "") -> String:
	if what.begins_with("remains:"):
		Ghosts.spawn_remains(what.substr(8))
		return ""
	match what:
		"visit_kai":
			return visit_kai()
		"twenty_help":
			return Twenty.help(npc)
		"tuve_choice":
			# 4.3: given the choice, Tuve stays — or swims away if the keeper's honour is below zero.
			Game.set_flag("tuve_left" if Game.honor < 0 else "tuve_stays")
			return ""
		"annul_neptune":
			Community.annul()
			return ""
		"greenhouse":
			Farm.open_plot("greenhouse")
			return ""
		"bottles_check":
			Bottles.check_forty()
			return ""
	return ""


func _step(quest_id: String, step_id: String) -> Dictionary:
	for step in Quests.quest(quest_id).get("steps", []):
		if str(step["id"]) == step_id:
			return step
	return {}


func _needs(step: Dictionary) -> String:
	var parts: Array = []
	for need in step.get("items", []):
		parts.append("%s ×%d (%d)" % [Crafting.item_name(str(need[0])), int(need[1]), Inventory.count_matching(str(need[0]))])
	if int(step.get("money", 0)) > 0:
		parts.append("%d кр" % int(step["money"]))
	return ", ".join(parts)


# Q2.7: a keeper brings Kai kerosene or grog on three different days.
func visit_kai() -> String:
	if Quests.state("q2_7_hermit") != "active" or kai_days.has(Clock.day_index):
		return ""
	var gift := ""
	for id in ["kerosene", "grog"]:
		if Inventory.count_of(id) > 0:
			gift = id
			break
	if gift == "":
		return Loc.t("story.kai.nothing")
	Inventory.take(gift, 1)
	kai_days.append(Clock.day_index)
	Events.quest_event.emit("kai_visit", "")
	return Loc.t("story.kai.visit_%d" % mini(kai_days.size(), 3))


# ---- story items: pages, evidences and fragments found in chests, holds and bottles ----

func _on_item_added(id: String, _n: int) -> void:
	var entry: Dictionary = cfg("pickups", {}).get(id, {})
	if entry.is_empty():
		return
	Effects.apply(entry.get("effects", []))
	if bool(entry.get("consume", false)):
		Inventory.take(id, Inventory.count_of(id))


# Story chests waiting on a level of the Deep (story.json "deep_chests").
func deep_chests(level: int) -> Array:
	var out: Array = []
	for c in cfg("deep_chests", []):
		if int(c["level"]) != level:
			continue
		if c.has("unless") and ConditionContext.check(str(c["unless"])):
			continue
		if c.has("when") and not ConditionContext.check(str(c["when"])):
			continue
		out.append(str(c["item"]))
	return out


# Items the keeper uses in the world by hand (Q on a sextant, a letter to read, a map...).
func use_item(id: String, at: Vector2 = Vector2(-1, -1)) -> String:
	if at.x >= 0.0 and Router.current_map == "sea":
		Ghosts.last_sea_tile = Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
	match id:
		"message_bottle":
			return Bottles.open_one()
		"sextant_cracked", "sextant":
			return Ghosts.sextant_fix()
		"signal_flare":
			return Ghosts.fire_flare()
	return ""


# ---- the world: first meetings, leaving the cape on a Hmar night, dated hours ----

func _on_npc_talked(npc: String) -> void:
	if not Game.flag("met_" + npc):
		Game.set_flag("met_" + npc)
		if not bool(NPCs.info(npc).get("visitor", false)) and npc != "npc_fortuna":
			Events.quest_event.emit("npc_met", npc)


func _on_map_entered(map_id: String) -> void:
	if Weather.hmar_night and Clock.is_night() and not (map_id == "cape" or map_id.begins_with("lh_") or map_id.begins_with("cape_")):
		left_cape_day = Clock.day_index
	Events.quest_event.emit("map", map_id)
	Ghosts.on_map(map_id)


func _on_hour(hour: int) -> void:
	sync()
	Ghosts.hourly(hour)
	if hour == 10 and Clock.day_index == DAY_FALSE_FIRE + 1:
		Events.quest_event.emit("berta_ashore", "")


# ---- spots of the world (data/story_spots.json) ----

func spots_on(map_id: String) -> Array:
	var out: Array = []
	for spot in Data.all("story_spots"):
		if str(spot.get("map", "")) == map_id and ConditionContext.check(str(spot.get("when", ""))):
			out.append(spot)
	return out


func spot(id: String) -> Dictionary:
	return Data.by_id("story_spots", id)


# What a spot shows: {title, text, actions: [[label, action]]}.
func spot_view(id: String) -> Dictionary:
	var s := spot(id)
	var view := {"title": Loc.t(str(s.get("title", ""))), "text": Loc.t(str(s.get("text", ""))), "actions": []}
	match str(s.get("kind", "")):
		"bonfire":
			view["text"] = Loc.t("story.bonfire.lit") if bonfire_lit(int(s["index"])) else Loc.t("story.bonfire.dark")
			if not bonfire_lit(int(s["index"])):
				view["actions"] = [[Loc.t("story.bonfire.light"), "light"]]
		"board":
			view["text"] = board_text()
		"journal":
			view["text"] = journal_text()
		"code_lock":
			view["actions"] = [[Loc.t("story.lock.try"), "code"]]
		_:
			view = Spots.view(s, view)
	return view


func spot_action(id: String, action: String, arg: String = "") -> String:
	var s := spot(id)
	match action:
		"light":
			match light_bonfire(int(s["index"])):
				"ok":
					return Loc.t("story.bonfire.done") % bonfires.size()
				"fuel":
					return Loc.t("story.bonfire.fuel")
			return ""
		"code":
			return try_code(arg)
	return Spots.act(s, action, arg)


# Fortuna's story talks in the lighthouse hall: the truth (Q3.1) and her own voice (Q2.11).
func fortuna_scene() -> String:
	if Quests.state("q3_1_truth") == "active" and not Cutscenes.seen.has("ev_story_fortuna_truth"):
		return "ev_story_fortuna_truth"
	if Twenty.buried_count() >= 10 and not Game.flag("fortuna_voice"):
		return "ev_story_fortuna_voice"
	return ""


# ---- Q1.7: the watch-room desk, locked with "season + day" ----

var code_tries: int = 0


func try_code(code: String) -> String:
	if Game.flag("journal_open"):
		return Loc.t("story.lock.open")
	if code.strip_edges().to_lower() in ["осень 14", "autumn 14", "autumn:14", "осень:14"]:
		Game.set_flag("journal_open")
		add_page(1)
		Events.quest_event.emit("journal_opened", "")
		return Loc.t("story.lock.click")
	code_tries += 1
	if code_tries >= 3:
		return Loc.t("story.lock.hint")
	return Loc.t("story.lock.wrong")


func board_text() -> String:
	var lines: Array = [Loc.t("story.board.head") % [evidence_count(), EVIDENCE.size()]]
	for i in EVIDENCE.size():
		var id: String = EVIDENCE[i]
		lines.append("%d. %s" % [i + 1, Loc.t("evidence.%s.%s" % [id, "found" if evidence.has(id) else "hint"])])
	if evidence.has("black_book"):
		lines.append("★ " + Loc.t("evidence.black_book.found"))
	for card in cards:
		lines.append("· " + Loc.t("evidence.card.%s" % card))
	lines.append(Loc.t("story.board.threads.%d" % mini(3, evidence_count() / 2)))
	return "\n".join(lines)


func journal_text() -> String:
	if pages.is_empty():
		return Loc.t("story.journal.empty")
	var lines: Array = [Loc.t("story.journal.head") % pages.size()]
	for n in pages:
		lines.append("№%d. %s" % [n, page_text(int(n))])
	return "\n\n".join(lines)


# ---- the ending (5.6) ----

func serialize() -> Dictionary:
	return {"pages": pages, "evidence": evidence, "cards": cards, "fragments": fragments, "stone_whole": stone_whole,
		"stern_phrase": stern_phrase, "allies": allies, "bonfires": bonfires, "great_hmar": great_hmar,
		"finale_day": finale_day, "ending": ending, "resolution": resolution, "fortuna_fate": fortuna_fate,
		"epilogue": epilogue, "tale_day": tale_day, "kai_days": kai_days, "left_cape_day": left_cape_day,
		"code_tries": code_tries}


func deserialize(d: Dictionary) -> void:
	reset()
	for n in d.get("pages", []):
		pages.append(int(n))
	for id in d.get("evidence", {}):
		evidence[str(id)] = int(d["evidence"][id])
	cards = d.get("cards", []).duplicate()
	for n in d.get("fragments", []):
		fragments.append(int(n))
	stone_whole = bool(d.get("stone_whole", false))
	stern_phrase = str(d.get("stern_phrase", ""))
	allies = d.get("allies", []).duplicate()
	for key in d.get("bonfires", {}):
		bonfires[str(key)] = int(d["bonfires"][key])
	great_hmar = str(d.get("great_hmar", ""))
	finale_day = int(d.get("finale_day", DAY_GREAT_TIDE))
	ending = str(d.get("ending", ""))
	resolution = str(d.get("resolution", ""))
	fortuna_fate = str(d.get("fortuna_fate", ""))
	epilogue = d.get("epilogue", []).duplicate()
	tale_day = int(d.get("tale_day", -1))
	for n in d.get("kai_days", []):
		kai_days.append(int(n))
	left_cape_day = int(d.get("left_cape_day", -1))
	code_tries = int(d.get("code_tries", 0))
