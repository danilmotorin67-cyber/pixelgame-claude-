class_name Ghosts

# The named ghosts of 11.8 beyond the graveyard talk: what they ask for away from their graves (the noon sight,
# Martin's fire, Jacques's cache, the salute, the sketches), the remains brought up from the Deep, and the
# ghost-hunters' club outings. Laying a ghost to rest stays in Graveyard.

static var last_sea_tile: Vector2i = Vector2i(-1, -1)


static func info(id: String) -> Dictionary:
	return Data.by_id("ghosts", id)


static func by_quest(quest_id: String) -> Dictionary:
	for g in Data.all("ghosts"):
		if str(g.get("quest", "")) == quest_id:
			return g
	return {}


# A finished ghost quest: ghosts that are not met by a grave rest at once.
static func on_quest_completed(quest_id: String) -> void:
	var g := by_quest(quest_id)
	if not g.is_empty() and bool(g.get("auto_lay", false)):
		Graveyard.lay_ghost(str(g["id"]))


# Buttons a ghost offers besides talk: hand-ins for its quest, Martin's fire.
static func actions(ghost_id: String) -> Array:
	var out: Array = []
	for pair in Quests.deliveries(ghost_id):
		out.append(["deliver:%s:%s" % [pair[0], pair[1]["id"]], Loc.t("ghost.opt.give")])
	if ghost_id == "ghost_martin" and Quests.state("g5_cold") == "active":
		out.append(["martin_fire", Loc.t("ghost.opt.fire")])
	return out


static func act(ghost_id: String, action: String) -> String:
	if action.begins_with("deliver:"):
		var parts := action.split(":")
		if not Quests.deliver(parts[1], parts[2]):
			return Loc.t("story.deliver.missing")
		return Graveyard.talk_ghost(ghost_id)
	if action == "martin_fire":
		return martin_fire()
	return ""


# 11.8 №5: a winter night, a fire of five driftwood by his grave, and the keeper still on the cape at midnight.
static func martin_fire() -> String:
	if Clock.season != "winter" or Clock.hour < 18 or Inventory.count_of("driftwood") < 5:
		return Loc.t("ghost.martin.no_fire")
	Inventory.take("driftwood", 5)
	Game.counters["martin_fire_day"] = Clock.day_index
	return Loc.t("ghost.martin.fire")


static func hourly(hour: int) -> void:
	if hour == 0 and int(Game.counters.get("martin_fire_day", -1)) == Clock.day_index and Router.current_map == "cape":
		Events.quest_event.emit("martin_fire", "")
	if hour == 23 and Router.current_map == "cape" and Quests.state("club_2_watch") == "active":
		Events.quest_event.emit("night_watch", "")


static func on_map(map_id: String) -> void:
	if map_id == "seal_shore" and Quests.state("club_5_seal") == "active" and Clock.tide_height() <= -0.4:
		Events.quest_event.emit("seal_expedition", "")


# 11.8 №4: a noon sight in zone 2 of the sea with any sextant.
static func sextant_fix() -> String:
	if Inventory.count_of("sextant") > 0 and Game.flag("treasure_15") and not Game.flag("treasure_15_dug"):
		Game.set_flag("nameless_isle_open")
		return Loc.t("ghost.sextant.treasure")
	var zone2 := Router.current_map == "sea" and last_sea_tile.y >= int(SeaChart.cfg("zone2_row")) \
		and last_sea_tile.y < int(SeaChart.cfg("zone3_row"))
	if not zone2 or Clock.minutes < 11 * 60 + 30 or Clock.minutes > 12 * 60 + 30:
		return Loc.t("ghost.sextant.no")
	Events.quest_event.emit("sextant_fix", "")
	return Loc.t("ghost.sextant.fix")


static func fire_flare() -> String:
	if not Inventory.take("signal_flare", 1):
		return ""
	Game.counters["flare_day"] = Clock.day_index
	return Loc.t("ghost.flare.fired")


# 11.8 №7: Jacques's remains in the fifth hall; taking the rum is one way to settle him.
static func jacques_remains() -> String:
	match Quests.state("g7_rum"):
		"none":
			Quests.start("g7_rum")
			return Loc.t(str(info("ghost_jacques")["lines"]["greet"]))
		"active":
			Inventory.add("rum", 10)
			Game.add_honor(-3)
			Events.quest_event.emit("jacques_cache", "rum")
			return Loc.t("ghost.jacques.rum")
	return Loc.t("ghost.jacques.remains")


# Remains brought up from the Deep (Gudmund, Tobias, Brigi) lie down in the morgue under their own names.
static func spawn_remains(body_id: String) -> Dictionary:
	if not Graveyard.body(body_id).is_empty():
		return {}
	var story := Data.by_id("bodies", body_id)
	var reg := Graveyard.registry_entry(str(story.get("registry", ""))).duplicate(true)
	for key in ["clues_visible", "clues_hidden", "items", "ghost"]:
		if story.has(key):
			reg[key] = story[key]
	var b := Graveyard._new_body(body_id, reg, true, Graveyard._rng(83))
	b["where"] = "morgue"
	b["preservation"] = 60.0
	b["washed"] = true
	if bool(story.get("known", false)):
		b["identified_as"] = str(reg.get("id", ""))
	Graveyard.bodies.append(b)
	Events.body_spawned.emit(body_id)
	return b


# A sketch for Emmerich at one of his three points of the sea.
static func sketch(place: String) -> String:
	Events.quest_event.emit("sketch", place)
	return Loc.t("story.sketch") % Loc.t("sea." + place)
