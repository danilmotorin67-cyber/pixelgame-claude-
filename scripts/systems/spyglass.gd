class_name Spyglass

# 27.4: point the spyglass and hold it two seconds — the bird or the ship goes into the collection.
# Birds (15) keep to their shores and seasons; ships (20) pass by day on their own days, or at dusk on the
# night's pilot calendar ("traffic"). Missed rare ones (the Saint Berta, the Caprice) come from Olaf's
# archive at 10 hearts, so the collection can always be finished.

static func cfg(key: String, default: Variant = null) -> Variant:
	return Game.balance("spyglass", {}).get(key, default)


static func has_glass() -> bool:
	return Inventory.count_of("spyglass") > 0 or Game.flag("spyglass_installed")


static func _rng(salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 3301 + Clock.day_index * 97 + salt.hash(), 2147483647)
	return rng


static func _hour_in(hours: Array) -> bool:
	if hours.is_empty():
		return true
	var from := int(hours[0])
	var to := int(hours[1])
	return Clock.hour >= from and Clock.hour < to if from < to else (Clock.hour >= from or Clock.hour < to)


# What is in sight from here now: [{kind: "birds"|"ships", id, name}].
static func targets(map_id: String = Router.current_map) -> Array:
	var out: Array = []
	for row in cfg("birds", []):
		var seasons: Array = row[3]
		if map_id not in row[2] or (not seasons.is_empty() and Clock.season not in seasons):
			continue
		if Clock.hour < 5 or Clock.hour >= 21:
			continue
		if _rng(map_id + str(row[0])).randf() < float(row[4]):
			out.append({"kind": "birds", "id": str(row[0]), "name": str(row[1])})
	if map_id in cfg("ship_maps", []):
		var tonight: Array = []
		for ship in ShipTraffic.ships_for_night(Clock.day_index):
			tonight.append(str(ship["name"]))
		for row in cfg("ships", []):
			var visible := false
			if str(row[2]) == "traffic":
				visible = (Clock.hour >= 18 and Clock.hour < 23) and tonight.has(str(row[1]))
			else:
				visible = _hour_in(row[3]) and ConditionContext.check(str(row[2])) and _rng("ship" + str(row[0])).randf() < float(row[4])
			if visible:
				out.append({"kind": "ships", "id": str(row[0]), "name": Loc.t(str(row[1]))})
	return out


# The keeper held the glass on a target for `held` seconds.
static func observe(target: Dictionary, held: float) -> bool:
	if not has_glass() or held < float(cfg("hold", 2.0)):
		return false
	var kind := str(target.get("kind", ""))
	var id := str(target.get("id", ""))
	if Collections.has(kind, id):
		return false
	var in_sight := false
	for t in targets():
		in_sight = in_sight or (str(t["kind"]) == kind and str(t["id"]) == id)
	if not in_sight:
		return false
	Collections.mark(kind, id)
	Knowledge.add_points("sea", 1)
	Events.quest_event.emit("sighted", id)
	return true


static func count(kind: String) -> int:
	return Collections.found.get(kind, {}).size()


static func total(kind: String) -> int:
	return (cfg(kind, []) as Array).size()


# Olaf's archive (10 hearts): the rare ships that can no longer be seen.
static func night() -> bool:
	if Game.flag("olaf_archive") or Relationships.hearts_of("npc_olaf") < 10:
		return false
	var names: Array = []
	for id in cfg("archive", []):
		if Collections.has("ships", str(id)):
			continue
		var gone := false
		match str(id):
			"berta":
				gone = Clock.year > 1 or Clock.day_index > 27
			"kapriz":
				gone = Clock.year > 1 or Clock.day_index >= 28 + 15
		if gone:
			Collections.mark("ships", str(id))
			for row in cfg("ships", []):
				if str(row[0]) == str(id):
					names.append(Loc.t(str(row[1])))
	if names.is_empty():
		return false
	Game.set_flag("olaf_archive")
	Mail.send("mail.olaf_archive", [", ".join(names)])
	return true
