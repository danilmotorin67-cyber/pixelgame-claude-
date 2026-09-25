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
var season_powers: Array = []
var year_powers: Array = []
var inspections: int = 0
var retake_day: int = -1
var inspected_day: int = -1
var log_day: int = -1
var blueprints_given: int = 0
var strong_streak: int = 0
# 10.12: wrecks waiting for the keeper's morning choice, and the saved staying at the tavern.
var rescue_pending: Array = []
var rescue_guests: Array = []


func cfg(key: String) -> Variant:
	return Game.balance("lighthouse", {}).get(key)


func reset() -> void:
	rescue_pending.clear()
	rescue_guests.clear()
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
	season_powers.clear()
	year_powers.clear()
	inspections = 0
	retake_day = -1
	inspected_day = -1
	log_day = -1
	blueprints_given = 0
	strong_streak = 0


func _ready() -> void:
	reset()
	Events.hour_changed.connect(_on_hour_changed)


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


const REPAIRS := {
	"stairs": {"items": [["boards", 10]], "points": 2},
	"masonry": {"items": [["stone", 20]], "points": 2},
	"paint": {"items": [["shell_lime", 5], ["whale_oil", 1]], "alt": [["tower_paint", 1]], "points": 2},
	"glass": {"items": [["glass", 3]], "flag": "lantern_glass_repaired"},
}


# Q1.8 repairs, available once node M5 is open: each part is paid for with materials.
func repair(part: String) -> String:
	if not Knowledge.has_unlock("tower_repair"):
		return "locked"
	var info: Dictionary = REPAIRS.get(part, {})
	if info.is_empty():
		return "unknown"
	if (info.has("flag") and Game.flag(str(info["flag"]))) or (info.has("points") and int(tower.get(part, 0)) >= 2):
		return "done"
	var items: Array = info["items"]
	for option in [info["items"], info.get("alt", [])]:
		var enough: bool = not (option as Array).is_empty()
		for need in option:
			enough = enough and Data.exists("items", str(need[0])) and Inventory.count_of(str(need[0])) >= int(need[1])
		if enough:
			items = option
			break
	for need in items:
		if not Data.exists("items", str(need[0])) or Inventory.count_of(str(need[0])) < int(need[1]):
			return "materials"
	for need in items:
		Inventory.take(str(need[0]), int(need[1]))
	if info.has("flag"):
		Game.set_flag(str(info["flag"]))
	else:
		tower[part] = int(info["points"])
	Events.quest_event.emit("tower_part_repaired", part)
	return "ok"


# Parts from the stations (10.4-10.10, 19.4) go in by hand; a better part replaces the old one, which goes
# back to the backpack if it was made. Returns "ok", "worse", "space" or "unknown".
func install_part(item_id: String) -> String:
	var spec: Array = Data.by_id("items", item_id).get("install", [])
	if spec.size() < 2 or Inventory.count_of(item_id) <= 0:
		return "unknown"
	var slot := str(spec[0])
	var value: Variant = spec[1]
	var tables := {"lens": "lenses", "lamp": "lamps", "mechanism": "mechanisms", "signal": "signals"}
	var old := ""
	match slot:
		"lens", "lamp", "mechanism", "signal":
			var table: Dictionary = cfg(tables[slot])
			var current := str(get(slot if slot != "signal" else "signal_kind"))
			var rank := func(id: String) -> float:
				var entry: Variant = table.get(id, 0)
				return float(entry["points"]) if entry is Dictionary else float(entry)
			if float(rank.call(str(value))) <= float(rank.call(current)):
				return "worse"
			old = _part_item(slot, current)
			if old != "" and not Inventory.can_fit(old, 1):
				return "space"
			set(slot if slot != "signal" else "signal_kind", str(value))
		"reservoir":
			if int(value) <= reservoir_level:
				return "worse"
			reservoir_level = int(value)
		"shroud":
			if salt_shroud:
				return "worse"
			salt_shroud = true
		"tower":
			if int(tower.get(str(value), 0)) >= 2:
				return "worse"
			tower[str(value)] = 2
		"red_sector":
			if Game.flag("red_sector"):
				return "worse"
			Game.set_flag("red_sector")
	Inventory.take(item_id, 1)
	if old != "":
		Inventory.add(old, 1)
	Events.quest_event.emit("lighthouse_part", item_id)
	# 5.8 №10: behind the old lens, once the fourth-order Fresnel goes in, a page of Agatha's notes.
	if item_id == "lens_fresnel_4":
		Story.add_page(10)
	return "ok"


func _part_item(slot: String, value: String) -> String:
	for item in Data.all("items"):
		var spec: Array = item.get("install", [])
		if spec.size() == 2 and str(spec[0]) == slot and str(spec[1]) == value:
			return str(item["id"])
	return ""


# Fuel drained into the storeroom barrel goes back into an empty (or same-fuel) reservoir.
func refill_from_barrel(id: String) -> float:
	var stored := float(barrel.get(id, 0.0))
	if lamp_on or stored <= 0.0 or (fuel_type != "" and fuel_type != id and fuel_nights > 0.0):
		return 0.0
	var room := float(reservoir_units()) * float(fuel_info(id)["nights"]) - (fuel_nights if fuel_type == id else 0.0)
	var poured := minf(room, stored)
	if poured <= 0.0:
		return 0.0
	fuel_type = id
	fuel_nights += poured
	barrel[id] = stored - poured
	if float(barrel[id]) <= 0.0:
		barrel.erase(id)
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
	return minf(100.0, float(total + keeper_bonus()))


# 25.2: +1 per Keeping level (up to 10), Fire keeper +5, Lighthouse eye +10, Fresnel's pupil +5 to any lens.
func keeper_bonus() -> int:
	var bonus := mini(10, Skills.base_level("keeping"))
	bonus += 5 if Skills.has_profession("fire_keeper") else 0
	bonus += 10 if Skills.has_profession("lighthouse_eye") else 0
	bonus += 5 if Skills.has_profession("fresnel_pupil") and lens != "old_mirror" else 0
	return bonus


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
		fuel_nights = maxf(0.0, fuel_nights - (0.75 if Skills.has_profession("fire_keeper") else 1.0))
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
	if power >= 100.0:
		Game.set_flag("fire_100")
	if needed:
		week_powers.append(power)
		season_powers.append(power)
		strong_streak = strong_streak + 1 if power >= 50.0 else 0
		if strong_streak >= 7:
			Events.quest_event.emit("fire_streak_7", "")
		year_powers.append(power)
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
		var sailor: Dictionary = Graveyard._person(rng, str(entry["type"]), str(entry["name"]))
		Graveyard.incoming.append({"ship": str(entry["name"]), "arrive": Clock.day_index + rng.randi_range(1, 3),
			"beach": ShipTraffic.pick_beach(rng), "registry": str(sailor["id"]), "type": str(entry["type"])})
	for n in crates:
		var beach := ShipTraffic.pick_beach(rng)
		pending_shore.append({"item": str(info["crate"]), "beach": "cape" if beach == "lagoon" else beach})
	Game.counters["crates_allowed"] = int(Game.counters.get("crates_allowed", 0)) + ceili(float(crates) / 3.0)


const INSPECTION := [[80, "exemplary", 5000, 15, 150], [60, "excellent", 3000, 10, 100],
	[40, "good", 1500, 5, 50], [20, "satisfactory", 500, 0, 0]]
const BLUEPRINTS := ["lightning_rod", "reservoir_3", "steam_horn", "auto_mechanism"]


func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


# Night step 9 (Monday): 150 kr + 5 kr × the week's average + bad-weather bonuses unless a ship was lost.
func weekly_salary() -> int:
	if week_powers.is_empty():
		return 0
	var average := _average(week_powers)
	var bonus := 0 if week_wrecked else week_bonus
	var salary := 150 + int(round(5.0 * average)) + bonus + (100 if Game.flag("two_fires") else 0)
	if Skills.has_profession("night_pilot"):
		salary = int(round(float(salary) * 1.5))
	Mail.send("mail.salary_wreck" if week_wrecked else "mail.salary", [salary, int(round(average)), bonus], salary)
	if week_powers.size() >= 7 and not week_dark:
		Sea.add_mercy(float(cfg("full_week_mercy")))
	week_powers.clear()
	week_bonus = 0
	week_dark = false
	week_wrecked = false
	return salary


func night_mail(night_index: int) -> void:
	for wreck in wrecks:
		if int(wreck["day"]) == night_index:
			Mail.send("mail.wreck", [Loc.t(str(wreck["ship"]))])
	if Clock.weekday == "mon":
		weekly_salary()


func _on_hour_changed(hour: int) -> void:
	# On the Great Tide Palm sails on the Queen; his grade comes the morning after the finale (Q4.5).
	if hour == 10 and (Clock.day == 28 or Clock.day_index == retake_day) and inspected_day != Clock.day_index \
			and not (Clock.day_index == Story.finale_day and Story.ending in ["", "D"]):
		inspect()


# Inspection on the 28th at 10:00 by the season's average; the very first one by the last seven nights.
func inspect() -> Dictionary:
	inspected_day = Clock.day_index
	var first := inspections == 0
	var average := fire_power if first else _average(season_powers)
	var threshold := 25.0 if first and Clock.year == 1 and Clock.season == "spring" else 20.0
	var result := {"grade": "unsatisfactory", "average": average, "money": 0, "notes": 0}
	if average >= threshold:
		for row in INSPECTION:
			if average >= float(row[0]) or row[1] == "satisfactory":
				result = {"grade": row[1], "average": average, "money": row[2], "notes": row[3]}
				Skills.add_xp("keeping", int(row[4]))
				break
		inspections += 1
		retake_day = -1
		Events.quest_event.emit("inspection_passed", str(result["grade"]))
		Knowledge.add_points("sea", int(result["notes"]))
		var items: Array = []
		if result["grade"] == "excellent" and blueprints_given < BLUEPRINTS.size():
			Game.set_flag("blueprint_" + BLUEPRINTS[blueprints_given])
			result["blueprint"] = BLUEPRINTS[blueprints_given]
			blueprints_given += 1
		if result["grade"] == "exemplary":
			items.append(["medal_directorate", 1])
		Mail.send("mail.inspection_" + str(result["grade"]), [int(round(average))], int(result["money"]), items)
	else:
		retake_day = Clock.DAYS_PER_YEAR * (Clock.year - 1) + Clock.DAYS_PER_SEASON + 6 if threshold == 25.0 \
			else Clock.day_index + 7
		result["retake_day"] = retake_day
		Mail.send("mail.inspection_unsatisfactory", [int(round(average))])
	if Clock.season == "winter" and Clock.day == 28:
		if _average(year_powers) >= 70.0:
			Game.set_flag("keeper_of_the_year_%d" % Clock.year)
			Mail.send("mail.keeper_of_the_year", [Clock.year])
		year_powers.clear()
	if Clock.day == 28:
		season_powers.clear()
	Game.add_stat("inspections")
	return result


# Ritual step 6: once a day, +5 keeping XP and a sea note; the Sunday summary adds two more.
func write_log() -> bool:
	if log_day == Clock.day_index:
		return false
	log_day = Clock.day_index
	Skills.add_xp("keeping", 5)
	Knowledge.add_points("sea", 3 if Clock.weekday == "sun" else 1)
	return true


func roll_loot(table_id: String, rng: RandomNumberGenerator) -> Array:
	var table: Dictionary = Data.tables.get("loot_tables", {}).get(table_id, {})
	var entries: Array = table.get("table", [])
	var out: Array = []
	if bool(table.get("fixed", false)):
		for entry in entries:
			out.append([str(entry[0]), rng.randi_range(int(entry[1]), int(entry[2]))])
		return out
	var rolls_value: Variant = table.get("rolls", 1)
	var rolls := rng.randi_range(int(rolls_value[0]), int(rolls_value[1])) if rolls_value is Array else int(rolls_value)
	for roll in rolls:
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
	var money := int(Data.tables.get("loot_tables", {}).get(table, {}).get("money", 0))
	if money > 0:
		Economy.add(money)
	if not id.begins_with("cargo_"):
		return loot
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
		"week_dark": week_dark, "week_wrecked": week_wrecked, "wrecks": wrecks, "pending_shore": pending_shore,
		"season_powers": season_powers, "year_powers": year_powers, "inspections": inspections,
		"retake_day": retake_day, "inspected_day": inspected_day, "log_day": log_day,
		"blueprints_given": blueprints_given, "strong_streak": strong_streak, "rescue_pending": rescue_pending,
		"rescue_guests": rescue_guests}


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
	for value in d.get("season_powers", []):
		season_powers.append(float(value))
	for value in d.get("year_powers", []):
		year_powers.append(float(value))
	inspections = int(d.get("inspections", 0))
	retake_day = int(d.get("retake_day", -1))
	inspected_day = int(d.get("inspected_day", -1))
	log_day = int(d.get("log_day", -1))
	blueprints_given = int(d.get("blueprints_given", 0))
	for w in d.get("rescue_pending", []):
		rescue_pending.append({"ship": str(w["ship"]), "type": str(w.get("type", "")), "day": int(w["day"])})
	for g in d.get("rescue_guests", []):
		rescue_guests.append({"name": str(g["name"]), "ship": str(g["ship"]), "until": int(g["until"]), "gift": bool(g.get("gift", false))})
	strong_streak = int(d.get("strong_streak", 0))
	for entry in d.get("pending_shore", []):
		pending_shore.append({"item": str(entry["item"]), "beach": str(entry["beach"])})
