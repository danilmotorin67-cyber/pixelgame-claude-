extends Node

const DAWN := 6 * 60

var lens: String = "old_mirror"
var lamp: String = "wick"
var mechanism: String = "weights"
var signal_kind: String = "hand_bell"
var reservoir_level: int = 0
var fuel_type: String = ""
var fuel_nights: float = 0.0
var barrel: Dictionary = {}
var cleanliness: float = 4.0
var tower: Dictionary = {}
var salt_shroud: bool = false
var lamp_on: bool = false
var lit_at_minutes: int = -1
var wound_until: int = -1
var bell_hours: Array = []
var fire_power: float = 0.0 # Light: average of the last seven nights.
var nightly_powers: Array[float] = []
var last_report: Dictionary = {}
# Weekly ledger for Monday's salary: nightly powers, bad-weather bonus, darkness and wrecks.
var week_powers: Array = []
var week_bonus: int = 0
var week_dark: bool = false
var week_wrecked: bool = false
var wrecks: Array = []
var pending_shore: Array = []


func cfg(key: String) -> Variant:
	return Game.balance("lighthouse", {}).get(key)


func reset() -> void:
	lens = "old_mirror"
	lamp = "wick"
	mechanism = "weights"
	signal_kind = "hand_bell"
	reservoir_level = 0
	fuel_type = ""
	fuel_nights = 0.0
	barrel.clear()
	tower = {}
	for part in cfg("tower_parts"):
		tower[part] = int(cfg("tower_start").get(part, 0))
	cleanliness = float(cfg("broken_glass_cap"))
	salt_shroud = false
	lamp_on = false
	lit_at_minutes = -1
	wound_until = -1
	bell_hours.clear()
	fire_power = 0.0
	nightly_powers.clear()
	last_report.clear()
	week_powers.clear()
	week_bonus = 0
	week_dark = false
	week_wrecked = false
	wrecks.clear()
	pending_shore.clear()


func _ready() -> void:
	reset()


func glass_cap() -> float:
	return 10.0 if Game.flag("lantern_glass_repaired") else float(cfg("broken_glass_cap"))


func reservoir_units() -> int:
	return int(cfg("reservoir_levels")[reservoir_level])


func fuel_info(id: String) -> Dictionary:
	return cfg("fuels").get(id, {})


func is_fuel(id: String) -> bool:
	return not fuel_info(id).is_empty()


func free_units() -> int:
	var nights_per_unit := float(fuel_info(fuel_type).get("nights", 1)) if fuel_type != "" else 1.0
	return reservoir_units() - ceili(fuel_nights / nights_per_unit - 0.001)


# Ritual step 1: pour fuel from the backpack; another fuel drains the old one into the barrel.
func refill(id: String = "") -> int:
	if lamp_on:
		return 0
	if id == "":
		for fuel in cfg("fuels"):
			if Inventory.count_of(fuel) > 0:
				id = fuel
				break
	if not is_fuel(id) or Inventory.count_of(id) <= 0:
		return 0
	if fuel_type != "" and fuel_type != id and fuel_nights > 0.0:
		barrel[fuel_type] = float(barrel.get(fuel_type, 0.0)) + fuel_nights
		fuel_nights = 0.0
	fuel_type = id
	var poured := 0
	while free_units() > 0 and Inventory.take(id, 1):
		fuel_nights += float(fuel_info(id)["nights"])
		poured += 1
	return poured


func nights_of_fuel() -> float:
	return fuel_nights


func tower_points() -> int:
	var total := 0
	for part in tower:
		total += int(tower[part])
	return total


func wound() -> bool:
	var every := int(cfg("mechanisms")[mechanism]["wind_every"])
	return every == 0 or wound_until >= Clock.day_index


# Ritual step 3: the weights need winding every night, the precise clock every other night.
func wind() -> bool:
	var every := int(cfg("mechanisms")[mechanism]["wind_every"])
	if every == 0 or wound():
		return false
	wound_until = Clock.day_index + every - 1
	return true


# Ritual step 4: 5 energy and a rag bring the glass back to 10 (4 while the panes are broken).
func clean_glass() -> bool:
	if cleanliness >= glass_cap() or not Inventory.take("rag", 1):
		return false
	cleanliness = glass_cap()
	return true


func ring_bell() -> bool:
	if bell_hours.has(Clock.hour):
		return false
	bell_hours.append(Clock.hour)
	return true


func signal_level() -> int:
	return int(cfg("signals")[signal_kind])


func foggy() -> bool:
	return Weather.current == "fog" or Weather.hmar_night


# Manual bell must be rung every game hour from lighting until bed in fog; others ring by themselves.
func signal_share(bedtime: int) -> float:
	if signal_level() >= 2 or not foggy():
		return 1.0
	if lit_at_minutes < 0:
		return 0.0
	var start := lit_at_minutes / 60
	var end := (bedtime if bedtime >= DAWN else bedtime + 1440) / 60
	var needed := 0
	var rung := 0
	for h in range(start, maxi(end, start + 1)):
		needed += 1
		if bell_hours.has(h % 24):
			rung += 1
	return float(rung) / float(maxi(needed, 1))


func components(bedtime: int = -1) -> Dictionary:
	if bedtime < 0:
		bedtime = Clock.minutes
	var mech_info: Dictionary = cfg("mechanisms")[mechanism]
	return {
		"lens": int(cfg("lenses")[lens]),
		"lamp": int(cfg("lamps")[lamp]),
		"fuel": int(fuel_info(fuel_type).get("points", 0)),
		"mechanism": int(mech_info["points"]) if wound() else 0,
		"clean": int(floor(cleanliness)),
		"tower": tower_points(),
		"signal": int(round(float(signal_level()) * signal_share(bedtime))),
	}


func base_power(bedtime: int = -1) -> float:
	var total := 0
	var parts := components(bedtime)
	for key in parts:
		total += int(parts[key])
	return float(total)


func sunset_minutes() -> int:
	var d := float(Clock.day - 1) / 27.0
	match Clock.season:
		"spring":
			return int(round(lerpf(1170.0, 1260.0, d)))
		"summer":
			return int(round(lerpf(1290.0, 1350.0, d)))
		"autumn":
			return int(round(lerpf(1200.0, 1020.0, d)))
		"winter":
			if Clock.day >= 10 and Clock.day <= 20:
				return 870
			return int(round(lerpf(960.0, 900.0, d)))
	return 1200


func white_nights() -> bool:
	return Clock.season == "summer" and Clock.day >= 8 and Clock.day <= 14


func fire_needed() -> bool:
	return not bool(Clock.festival_on().get("no_fire", false))


func on_time_until() -> int:
	return 23 * 60 if white_nights() else sunset_minutes() + 60


func lit_on_time() -> bool:
	return lit_at_minutes >= 0 and lit_at_minutes >= DAWN and lit_at_minutes <= on_time_until()


# Ritual step 2 (the hold is timed by the lamp object).
func light_lamp() -> bool:
	if lamp_on or fuel_nights <= 0.0:
		return false
	lamp_on = true
	lit_at_minutes = Clock.minutes
	Events.lamp_lit.emit(lit_on_time())
	return true


func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 2654435 + Clock.day_index * 40503 + salt, 2147483647)
	return rng


func effective_power(bedtime: int, watch_sleep: bool, parts: Dictionary) -> float:
	var power := 0.0
	for key in parts:
		power += float(parts[key])
	var sunset := sunset_minutes()
	var deadline := on_time_until()
	if lit_at_minutes > deadline or lit_at_minutes < DAWN:
		power *= 0.8
	if lit_at_minutes > deadline + 60 or lit_at_minutes < DAWN:
		var lit_minute := lit_at_minutes if lit_at_minutes >= DAWN else lit_at_minutes + 1440
		power *= clampf(float(1560 - lit_minute) / float(1560 - sunset), 0.0, 1.0)
	if watch_sleep:
		power += float(cfg("watch_sleep_bonus"))
	if foggy():
		power *= 0.6 + 0.08 * float(parts["signal"])
	return clampf(power, 0.0, 100.0)


# Night step 1: score the night, burn fuel, wear the tower and the glass.
func resolve_night(bedtime: int = 23 * 60, watch_sleep: bool = false) -> Dictionary:
	var storm := Weather.current in ["storm", "blizzard"]
	var protect := 0.5 if watch_sleep else 1.0
	var events: Array = []
	var burning := lamp_on and fuel_nights > 0.0
	var parts := components(bedtime)
	if burning and parts["mechanism"] > 0 and _rng(3).randf() < float(cfg("mechanism_stop")) * protect:
		parts["mechanism"] = 0
		events.append("mechanism_stopped")
	var power := effective_power(bedtime, watch_sleep, parts) if burning else 0.0
	if burning:
		fuel_nights = maxf(0.0, fuel_nights - 1.0)
		if fuel_nights <= 0.0:
			fuel_type = ""
	var on_time := burning and lit_on_time()
	var dirt := float(cfg("dirt_per_night"))
	if storm:
		dirt = float(cfg("dirt_storm"))
	elif Weather.hmar_night:
		dirt = float(cfg("dirt_hmar"))
	if salt_shroud:
		dirt *= 0.5
	cleanliness = maxf(0.0, cleanliness - dirt)
	if storm and _rng(5).randf() < float(cfg("storm_crack")) * protect:
		cleanliness = maxf(0.0, cleanliness - float(cfg("storm_crack_dirt")))
		events.append("glass_cracked")
	if storm and int(tower.get("rod", 0)) == 0 and _rng(7).randf() < float(cfg("lightning")):
		var damaged: Array = []
		for part in tower:
			if int(tower[part]) > 0:
				damaged.append(part)
		if not damaged.is_empty():
			var hit: String = damaged[_rng(11).randi_range(0, damaged.size() - 1)]
			tower[hit] = int(tower[hit]) - 1
			events.append("lightning_" + hit)
	var needed := fire_needed()
	var ships := _resolve_ships(needed, burning, power)
	if needed:
		week_powers.append(power)
		week_dark = week_dark or not burning
		nightly_powers.append(power)
		if nightly_powers.size() > 7:
			nightly_powers.pop_front()
		var total := 0.0
		for score in nightly_powers:
			total += score
		fire_power = total / float(nightly_powers.size())
		if not burning:
			Sea.add_mercy(float(cfg("no_fire_mercy")))
		if on_time:
			Knowledge.add_points("sea", 1)
			Skills.add_xp("keeping", 10)
	last_report = {"power": power, "light": fire_power, "lit": burning, "on_time": on_time,
		"no_fire": not needed, "parts": parts, "events": events, "ships": ships}
	lamp_on = false
	lit_at_minutes = -1
	bell_hours.clear()
	return last_report.duplicate(true)


func _resolve_ships(needed: bool, burning: bool, power: float) -> Array:
	var passed: Array = []
	var rng := _rng(13)
	var new_moon := Clock.day <= 3 or Clock.day >= 26
	var bad := Weather.hmar_night or Weather.current in ShipTraffic.BAD_WEATHER
	for ship in ShipTraffic.ships_for_night(Clock.day_index):
		var entry: Dictionary = ship.duplicate()
		entry["wrecked"] = false
		var info := Data.by_id("ships", str(ship["type"]))
		if needed:
			var chance := ShipTraffic.wreck_chance(Weather.current, Weather.hmar_night, burning, power, new_moon)
			var wrecked := rng.randf() < chance
			if wrecked and bool(info.get("double_check", false)):
				wrecked = rng.randf() < chance
			if wrecked:
				_wreck(entry, info, rng)
			elif bad:
				Knowledge.add_points("sea", 1)
				week_bonus += 20
				entry["safe_bad_weather"] = true
				if rng.randf() < 0.05:
					pending_shore.append({"item": roll_loot("gift_from_board", rng)[0][0], "beach": "cape"})
		passed.append(entry)
	return passed


func _wreck(entry: Dictionary, info: Dictionary, rng: RandomNumberGenerator) -> void:
	entry["wrecked"] = true
	var body_range: Array = info.get("bodies", [1, 1])
	var crate_range: Array = info.get("crates", [0, 0])
	var bodies := rng.randi_range(int(body_range[0]), int(body_range[1]))
	var crates := rng.randi_range(int(crate_range[0]), int(crate_range[1]))
	entry["bodies"] = bodies
	entry["crates"] = crates
	Sea.add_mercy(-3.0)
	week_wrecked = true
	wrecks.append({"day": Clock.day_index, "ship": entry["name"], "type": entry["type"], "bodies": bodies})
	for n in bodies:
		Graveyard.incoming.append({"ship": str(entry["name"]), "arrive": Clock.day_index + rng.randi_range(1, 3),
			"beach": ShipTraffic.pick_beach(rng)})
	for n in crates:
		var beach := ShipTraffic.pick_beach(rng)
		pending_shore.append({"item": str(info["crate"]), "beach": "cape" if beach == "lagoon" else beach})
	Game.counters["crates_allowed"] = int(Game.counters.get("crates_allowed", 0)) + ceili(float(crates) / 3.0)


func roll_loot(table_id: String, rng: RandomNumberGenerator) -> Array:
	var table: Dictionary = Data.tables.get("loot_tables", {}).get(table_id, {})
	var entries: Array = table.get("table", [])
	var out: Array = []
	for roll in int(table.get("rolls", 1)):
		var total := 0
		for entry in entries:
			total += int(entry[3])
		var pick := rng.randi_range(0, maxi(total - 1, 0))
		for entry in entries:
			pick -= int(entry[3])
			if pick < 0:
				out.append([str(entry[0]), rng.randi_range(int(entry[1]), int(entry[2]))])
				break
	return out


# Shore right (8.7): a third of every wreck's crates is the keeper's; opening more costs honour and mercy.
func open_crate(index: int) -> Array:
	var id := str(Inventory.slots[index]["id"])
	var table := str(Data.by_id("items", id).get("open", ""))
	if table == "" or not Inventory.take_slot(index, 1):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 7 + Clock.day_index * 131 + Clock.minutes + int(Game.counters.get("crates_opened", 0)) * 977,
		2147483647)
	var loot := roll_loot(table, rng)
	for entry in loot:
		Inventory.add(str(entry[0]), int(entry[1]))
	var opened := int(Game.counters.get("crates_opened", 0)) + 1
	Game.counters["crates_opened"] = opened
	if opened > int(Game.counters.get("crates_allowed", 0)):
		Game.add_honor(-2)
		Sea.add_mercy(-1.0)
	return loot


func hand_in_crates() -> int:
	var handed := 0
	for index in Inventory.capacity:
		var id := str(Inventory.slots[index]["id"])
		if Data.by_id("items", id).has("open") and id.begins_with("cargo_"):
			var count := int(Inventory.slots[index]["count"])
			Inventory.take_slot(index, count)
			handed += count
	Game.add_honor(3 * handed)
	return handed


func serialize() -> Dictionary:
	return {"lens": lens, "lamp": lamp, "mechanism": mechanism, "signal": signal_kind,
		"reservoir_level": reservoir_level, "fuel_type": fuel_type, "fuel_nights": fuel_nights,
		"barrel": barrel, "cleanliness": cleanliness, "tower": tower, "salt_shroud": salt_shroud,
		"lamp_on": lamp_on, "lit_at_minutes": lit_at_minutes, "wound_until": wound_until,
		"bell_hours": bell_hours, "fire_power": fire_power, "nightly_powers": nightly_powers,
		"last_report": last_report, "week_powers": week_powers, "week_bonus": week_bonus,
		"week_dark": week_dark, "week_wrecked": week_wrecked, "wrecks": wrecks, "pending_shore": pending_shore}


func deserialize(d: Dictionary) -> void:
	reset()
	if cfg("lenses").has(str(d.get("lens", ""))):
		lens = str(d["lens"])
	if cfg("lamps").has(str(d.get("lamp", ""))):
		lamp = str(d["lamp"])
	if cfg("mechanisms").has(str(d.get("mechanism", ""))):
		mechanism = str(d["mechanism"])
	if cfg("signals").has(str(d.get("signal", ""))):
		signal_kind = str(d["signal"])
	reservoir_level = clampi(int(d.get("reservoir_level", 0)), 0, cfg("reservoir_levels").size() - 1)
	fuel_type = str(d.get("fuel_type", "")) if is_fuel(str(d.get("fuel_type", ""))) else ""
	fuel_nights = maxf(float(d.get("fuel_nights", 0.0)), 0.0) if fuel_type != "" else 0.0
	var saved_barrel: Dictionary = d.get("barrel", {})
	for id in saved_barrel:
		if is_fuel(str(id)):
			barrel[str(id)] = float(saved_barrel[id])
	cleanliness = clampf(float(d.get("cleanliness", cleanliness)), 0.0, 10.0)
	var saved_tower: Dictionary = d.get("tower", {})
	for part in tower:
		tower[part] = clampi(int(saved_tower.get(part, tower[part])), 0, 2)
	salt_shroud = bool(d.get("salt_shroud", false))
	lamp_on = bool(d.get("lamp_on", false)) and fuel_nights > 0.0
	lit_at_minutes = int(d.get("lit_at_minutes", -1)) if lamp_on else -1
	wound_until = int(d.get("wound_until", -1))
	for hour in d.get("bell_hours", []):
		bell_hours.append(int(hour))
	fire_power = clampf(float(d.get("fire_power", 0.0)), 0.0, 100.0)
	var loaded: Variant = d.get("nightly_powers", [])
	if loaded is Array:
		for value in loaded.slice(maxi(0, loaded.size() - 7)):
			nightly_powers.append(clampf(float(value), 0.0, 100.0))
	last_report = d.get("last_report", {}) if d.get("last_report", {}) is Dictionary else {}
	for value in d.get("week_powers", []):
		week_powers.append(float(value))
	week_bonus = int(d.get("week_bonus", 0))
	week_dark = bool(d.get("week_dark", false))
	week_wrecked = bool(d.get("week_wrecked", false))
	for wreck in d.get("wrecks", []):
		wrecks.append({"day": int(wreck["day"]), "ship": str(wreck["ship"]), "type": str(wreck["type"]),
			"bodies": int(wreck["bodies"])})
	for entry in d.get("pending_shore", []):
		pending_shore.append({"item": str(entry["item"]), "beach": str(entry["beach"])})
