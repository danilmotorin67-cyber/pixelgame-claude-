extends Node

const START_MERCY := 30.0
const SHORE_ROWS := 6
const FAR_ROW := 3

var mercy: float = START_MERCY
var blessings: Array = []
var boat: String = ""
var revealed: Dictionary = {}
# Beach gifts per map: [{item, x, row}], `row` counts from the high-water line (0) seaward (5).
var gifts: Dictionary = {}
var trash_mercy_today: float = 0.0
# Gifts promised by the story: {item, beach, day}.
var scheduled: Array = []
# Set traps and nets: {kind, map, x, y, baited, catch: [[id, n]], set_day, set_minute}.
var gear: Array = []
var hull: float = 100.0
var hold: Array = []
var visited: Dictionary = {}
var boat_ready_day: int = -1
# Rock pools (fixed per world) and today's clam bubbles; "fished" marks today's visits.
var pools: Dictionary = {}
var clams: Array = []
var pools_fished: Dictionary = {}
# The sea garden of 13.10 by the cape pier: [{kind, x, y, planted, next, ready, broken}] in sea-map tiles.
var sea_garden: Array = []
# 16.6: the events met on this outing, rolled when the boat leaves the pier: [{id, x, y, done}] in pixels.
var outing: Array = []
var towing: bool = false


func reset() -> void:
	mercy = START_MERCY
	blessings.clear()
	boat = ""
	revealed.clear()
	gifts.clear()
	trash_mercy_today = 0.0
	scheduled.clear()
	gear.clear()
	hull = 100.0
	hold.clear()
	visited.clear()
	boat_ready_day = -1
	pools.clear()
	clams.clear()
	pools_fished.clear()
	sea_garden.clear()
	outing.clear()
	towing = false


func schedule_gift(item: String, beach: String, day: int) -> void:
	scheduled.append({"item": item, "beach": beach, "day": day})


func add_mercy(n: float) -> void:
	mercy = clampf(mercy + n, 0.0, 100.0)


func first_row(map_id: String) -> int:
	var beach: Dictionary = Data.tables.get("forage", {}).get("beaches", {}).get(map_id, {})
	if beach.has("first_row"):
		return int(beach["first_row"])
	return int(Data.tables.get("regions", {}).get(map_id, {}).get("coast_row", -1))


# Same shoreline elevation as the tide cells of the cape and the regions.
func row_elevation(x: int, row: int) -> float:
	return 1.25 - float(row) * 0.5 + sin(float(x) * 0.37) * 0.06


func is_dry(gift: Dictionary) -> bool:
	return Clock.tide_height() < row_elevation(int(gift["x"]), int(gift["row"]))


func _pick(rng: RandomNumberGenerator, table: Array) -> String:
	var total := 0
	for entry in table:
		total += int(entry[1])
	var roll := rng.randi_range(0, maxi(total - 1, 0))
	for entry in table:
		roll -= int(entry[1])
		if roll < 0:
			return str(entry[0])
	return str(table[0][0])


# Night step 8: yesterday's gifts wash away and the tide brings new ones (18.2).
# Night step 8 (first half): the day's fishing and the drowned left on the shore weigh on Rann (12.1).
func night_mercy() -> void:
	if int(Game.counters.get("fish_today", 0)) > 60:
		add_mercy(-1.0)
	Game.counters["fish_today"] = 0
	Game.counters["released_today"] = 0
	for b in Graveyard.bodies:
		if str(b["where"]) == "shore":
			add_mercy(-1.0)


func generate_gifts(index: int, storm: bool) -> void:
	var config: Dictionary = Data.tables.get("forage", {})
	gifts.clear()
	trash_mercy_today = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 30011 + index * 7187 + 5, 2147483647)
	var bounds: Array = config.get("gifts_per_beach", [6, 15])
	for map_id in config.get("beaches", {}):
		var beach: Dictionary = config["beaches"][map_id]
		var columns: Array = beach.get("columns", [2, 60])
		var count := int(round(float(rng.randi_range(int(bounds[0]), int(bounds[1]))) * Daughters.gift_mult()))
		if storm:
			count *= int(config.get("storm_mult", 3))
		if mercy < 20.0:
			count = maxi(1, count / 2)
		var placed: Array = []
		var used := {}
		for n in count:
			var row := rng.randi_range(0, SHORE_ROWS - 1)
			var table: Array = config.get("far" if row >= FAR_ROW else "near", [])
			if storm and rng.randf() < 0.15:
				table = config.get("storm", table)
			_place(placed, used, rng, columns, row, _pick(rng, table))
		# 12.2: a friendly sea leaves one sure gift a day, a generous one another rare one.
		var rare: Array = config.get("rare", ["sea_glass"])
		for _n in (2 if mercy >= 60.0 else 1) if mercy >= 40.0 else 0:
			_place(placed, used, rng, columns, rng.randi_range(FAR_ROW, SHORE_ROWS - 1),
				str(rare[rng.randi_range(0, rare.size() - 1)]))
		# 18.6: bottles wash up — a tenth of days in Wreck Bay, three in a hundred elsewhere.
		if rng.randf() < Bottles.beach_chance(str(map_id)):
			_place(placed, used, rng, columns, rng.randi_range(0, SHORE_ROWS - 1), "message_bottle")
		# Pena: a pearl in the foam now and then.
		if Sea.blessings.has("pena") and rng.randf() < 0.1:
			_place(placed, used, rng, columns, rng.randi_range(0, SHORE_ROWS - 1), "pearl")
		gifts[map_id] = placed
	for entry in Lighthouse.pending_shore:
		var beach_id := str(entry["beach"])
		var columns: Array = config.get("beaches", {}).get(beach_id, {}).get("columns", [2, 60])
		if not gifts.has(beach_id):
			gifts[beach_id] = []
		_place(gifts[beach_id], {}, rng, columns, rng.randi_range(0, FAR_ROW - 1), str(entry["item"]))
	Lighthouse.pending_shore.clear()
	var waiting: Array = []
	for entry in scheduled:
		if int(entry["day"]) <= index:
			var beach_id := str(entry["beach"])
			var columns: Array = config.get("beaches", {}).get(beach_id, {}).get("columns", [2, 60])
			if not gifts.has(beach_id):
				gifts[beach_id] = []
			_place(gifts[beach_id], {}, rng, columns, 0, str(entry["item"]))
		else:
			waiting.append(entry)
	scheduled = waiting


func _place(placed: Array, used: Dictionary, rng: RandomNumberGenerator, columns: Array,
		row: int, item: String) -> void:
	for attempt in 8:
		var x := rng.randi_range(int(columns[0]), int(columns[1]))
		var key := "%d,%d" % [x, row]
		if not used.has(key):
			used[key] = true
			placed.append({"item": item, "x": x, "row": row})
			return


func collect_gift(map_id: String, gift: Dictionary) -> bool:
	var list: Array = gifts.get(map_id, [])
	var index := list.find(gift)
	if index < 0 or not is_dry(gift):
		return false
	if not Inventory.forage(str(gift["item"]), 3):
		return false
	if Skills.has_profession("beachcomber") and randf() < 0.2:
		Inventory.add(str(gift["item"]), 1)
	list.remove_at(index)
	if str(gift["item"]) == "trash":
		var config: Dictionary = Data.tables.get("forage", {})
		var bonus := minf(float(config.get("trash_mercy", 0.2)),
			float(config.get("trash_mercy_day", 2.0)) - trash_mercy_today)
		if bonus > 0.0:
			trash_mercy_today += bonus
			add_mercy(bonus)
	return true


# Rock pools are fixed per world; they open at low tide (18.3).
func ensure_pools() -> void:
	if not pools.is_empty():
		return
	var config: Dictionary = Data.tables.get("forage", {}).get("tidepools", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 3571 + 7, 2147483647)
	for map_id in ["cape", "seal_shore"]:
		var bounds: Array = config.get(map_id, [6, 10])
		var columns: Array = Data.tables["forage"]["beaches"].get(map_id, {}).get("columns", [4, 60])
		var rows: Array = config.get("rows", [2, 3])
		var list: Array = []
		for n in rng.randi_range(int(bounds[0]), int(bounds[1])):
			list.append({"id": "%s_%d" % [map_id, n], "x": rng.randi_range(int(columns[0]), int(columns[1])),
				"row": rng.randi_range(int(rows[0]), int(rows[1]))})
		pools[map_id] = list


func pool_open() -> bool:
	return Clock.tide_height() <= float(Data.tables["forage"]["tidepools"].get("tide", -0.4))


func net_pool(pool: Dictionary) -> Array:
	var config: Dictionary = Data.tables["forage"]["tidepools"]
	if pools_fished.has(str(pool["id"])) or not pool_open() or Inventory.count_of("hand_net") <= 0:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 29 + Clock.day_index * 131 + str(pool["id"]).hash(), 2147483647)
	var table: Array = []
	for entry in config["table"]:
		var fish := Data.by_id("fish", str(entry[0]))
		if fish.is_empty() or Clock.season in fish.get("seasons", []):
			table.append(entry)
	var got: Array = []
	var bounds: Array = config.get("catch", [1, 3])
	for n in rng.randi_range(int(bounds[0]), int(bounds[1])):
		var id := _pick(rng, table)
		if Inventory.add(id, 1) == 1:
			got.append(id)
			Skills.add_xp("foraging", 5)
			if id.begins_with("fish_"):
				Collections.mark("fish", id)
	pools_fished[str(pool["id"])] = true
	return got


func _spawn_clams(index: int) -> void:
	var config: Dictionary = Data.tables.get("forage", {}).get("clams", {})
	clams.clear()
	if config.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 811 + index * 67, 2147483647)
	var columns: Array = Data.tables["forage"]["beaches"].get(str(config["map"]), {}).get("columns", [4, 60])
	var bounds: Array = config.get("spots", [3, 6])
	var rows: Array = config.get("rows", [1, 3])
	for n in rng.randi_range(int(bounds[0]), int(bounds[1])):
		clams.append({"map": str(config["map"]), "x": rng.randi_range(int(columns[0]), int(columns[1])),
			"row": rng.randi_range(int(rows[0]), int(rows[1]))})


func clams_visible() -> bool:
	return Clock.tide_height() <= float(Data.tables["forage"].get("clams", {}).get("tide", -0.2))


func dig_clam(spot: Dictionary) -> bool:
	if not clams.has(spot) or not clams_visible() or not Inventory.can_fit("mya_clam", 1):
		return false
	clams.erase(spot)
	Inventory.add("mya_clam", 1)
	Skills.add_xp("foraging", 5)
	return true


# Traps go into water by a shore, pier or at sea; nets onto the tidal strip at low tide (15.1).
func place_gear(kind: String, map_id: String, at: Vector2) -> bool:
	var cell := Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
	var row0 := first_row(map_id)
	if kind == "net":
		if row0 < 0 or cell.y < row0 or cell.y >= row0 + SHORE_ROWS or Clock.tide_height() > -0.3:
			return false
	elif not Fishing.is_water(map_id, at) or map_id in ["moor", "birch"]:
		return false
	for g in gear:
		if str(g["map"]) == map_id and Vector2(float(g["x"]), float(g["y"])).distance_to(at) < 16.0:
			return false
	var item := {"trap": "trap", "net": "set_net", "longline": "longline"}.get(kind, "set_net") as String
	if not Inventory.take(item, 1):
		return false
	gear.append({"kind": kind, "map": map_id, "x": floorf(at.x / 16.0) * 16.0 + 8.0, "y": floorf(at.y / 16.0) * 16.0 + 8.0,
		"baited": false, "catch": [], "set_day": Clock.day_index, "set_minute": Clock.minutes})
	return true


func bait_trap(g: Dictionary) -> bool:
	if str(g["kind"]) != "trap" or bool(g["baited"]) or not g["catch"].is_empty():
		return false
	for id in ["bait", "worms", "fish_capelin"]:
		if Inventory.take(id, 1):
			g["baited"] = true
			return true
	return false


func trap_table(g: Dictionary) -> String:
	if str(g["map"]) == "sea":
		return "sea"
	var tags := Fishing.spot_tags(str(g["map"]), Vector2(float(g["x"]), float(g["y"])))
	return "rocks" if tags.has("rocky") else "shore"


# A net comes up at the next low tide after at least one high water (six hours after setting it).
func net_ready(g: Dictionary) -> bool:
	var elapsed := (Clock.day_index - int(g["set_day"])) * 1440 + Clock.minutes - int(g["set_minute"])
	return elapsed >= 360 and Clock.tide_height() <= -0.3


func lift_gear(g: Dictionary) -> Array:
	if not gear.has(g):
		return []
	if str(g["kind"]) == "net":
		if not net_ready(g):
			return []
		g["catch"] = _net_catch(g)
	var got: Array = []
	for entry in g["catch"]:
		if Inventory.add(str(entry[0]), int(entry[1])) > 0:
			got.append(entry)
			Skills.add_xp("fishing", 5)
			if str(entry[0]).begins_with("fish_"):
				Collections.mark("fish", str(entry[0]))
	g["catch"] = []
	if str(g["kind"]) == "net":
		gear.erase(g)
		Inventory.add("set_net", 1)
	return got


# A longline comes back to the backpack when lifted empty (its catch is taken first).
func take_up_gear(g: Dictionary) -> bool:
	if not gear.has(g) or not g["catch"].is_empty() or str(g["kind"]) == "net":
		return false
	var item := {"trap": "trap", "longline": "longline"}.get(str(g["kind"]), "") as String
	if item == "" or not Inventory.can_fit(item, 1):
		return false
	gear.erase(g)
	Inventory.add(item, 1)
	return true


func _net_catch(g: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 97 + Clock.day_index * 7 + int(g["x"]), 2147483647)
	var tags := Fishing.spot_tags(str(g["map"]), Vector2(float(g["x"]), float(g["y"])))
	if tags.is_empty():
		tags = ["coast"]
	var pool: Array = []
	for fish in Data.all("fish"):
		if bool(fish.get("legendary", false)) or Clock.season not in fish.get("seasons", []):
			continue
		for tag in ["coast", "sand", "rocky", "pier"]:
			if fish["where"].has(tag) and (tags.has(tag) or tag == "coast"):
				pool.append(fish)
				break
	var out: Array = []
	var catches := rng.randi_range(3, 6) if str(g["kind"]) == "net" else rng.randi_range(2, 4)
	for n in catches * (2 if Skills.has_profession("netter") else 1):
		if not pool.is_empty():
			out.append([str(pool[rng.randi_range(0, pool.size() - 1)]["id"]), 1])
	out.append(["kelp", rng.randi_range(1, 3)])
	if rng.randf() < 0.5:
		out.append(["trash", 1])
	return out


# Night step 8: baited traps fill; a hostile sea tears nets and loses traps.
func night_gear() -> void:
	var keep: Array = []
	for g in gear:
		var rng := RandomNumberGenerator.new()
		rng.seed = posmod(Game.world_seed * 41 + Clock.day_index * 17 + int(g["x"]) * 3 + int(g["y"]), 2147483647)
		if mercy < 20.0 and rng.randf() < 0.1:
			continue
		if str(g["kind"]) == "trap" and (bool(g["baited"]) or Skills.has_profession("trapper")) and g["catch"].is_empty():
			var table: Array = Data.tables["forage"]["traps"][trap_table(g)]
			g["catch"] = [[_pick(rng, table), 1]]
			if Skills.has_profession("trapper") and rng.randf() < 0.25:
				g["catch"].append([_pick(rng, table), 1])
			g["baited"] = false
		elif str(g["kind"]) == "longline" and g["catch"].is_empty():
			var hooked := _net_catch(g)
			hooked.pop_back()
			g["catch"] = hooked
		keep.append(g)
	gear = keep
	pools_fished.clear()
	_spawn_clams(Clock.day_index)


# ---- the events of an outing (16.6) ----

func _random_water(rng: RandomNumberGenerator, zones: Array) -> Vector2:
	var size: Array = SeaChart.cfg("size")
	for n in 200:
		var at := Vector2(rng.randi_range(4, int(size[0]) - 5) * 16 + 8, rng.randi_range(int(SeaChart.cfg("coast_rows")) + 3, int(size[1]) - 3) * 16 + 8)
		if SeaChart.zone_of(at) in zones and not SeaChart.is_land(at):
			return at
	return SeaChart.place_pos("sea_garden")


func roll_outing(seed_value: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value >= 0 else posmod(Game.world_seed * 71 + Clock.day_index * 13 + Clock.minutes, 2147483647)
	outing.clear()
	var reach: Array = range(1, int(SeaChart.boat_info().get("zones", 1)) + 1)
	for ev in SeaChart.cfg("events"):
		var id := str(ev["id"])
		var zones: Array = ev.get("zones", reach).filter(func(z: Variant) -> bool: return int(z) in reach)
		if zones.is_empty():
			continue
		if ev.has("season") and Clock.season != str(ev["season"]):
			continue
		if ev.has("days") and (Clock.day < int(ev["days"][0]) or Clock.day > int(ev["days"][1])):
			continue
		if bool(ev.get("hmar", false)) and not Weather.hmar_night:
			continue
		if bool(ev.get("bad_weather", false)) and Weather.current not in ["rain", "storm", "fog", "snow", "blizzard"]:
			continue
		if rng.randf() >= float(ev["chance"]):
			continue
		var at := _random_water(rng, zones)
		if ev.has("near"):
			at = SeaChart.place_pos(str(ev["near"])) + Vector2(rng.randf_range(-40, 40), rng.randf_range(24, 48))
		outing.append({"id": id, "x": at.x, "y": at.y, "done": false})
		if id == "squall":
			damage_hull(5.0)
			Weather.wind_direction = (Weather.wind_direction + 4) % 8
	return outing


# Meeting an event: returns the line to show.
func meet(ev: Dictionary) -> String:
	if bool(ev["done"]):
		return ""
	var id := str(ev["id"])
	match id:
		"cargo", "bottle":
			if Inventory.count_of("gaff_wood") + Inventory.count_of("gaff_iron") <= 0:
				return "Не дотянуться — нужен багор."
			var item: String = "sealed_bottle_letter" if id == "bottle" else str(["cargo_fishing", "cargo_merchant"][int(ev["x"]) % 2])
			if Inventory.add(item, 1) != 1:
				return "Трюм и рюкзак полны."
			Skills.add_xp("foraging", 10 if id == "bottle" else 3)
		"bird_frenzy":
			Game.add_buff({"bite": -0.5, "hours": 1})
		"seals":
			var key := "seal_fed_%d" % Clock.day_index
			if Game.flag(key):
				return "Тюлени сыты и довольны."
			if not Inventory.take("fish_herring", 1):
				return "Тюлени смотрят выжидательно. У вас нет сельди."
			Game.set_flag(key)
			Game.add_stat("seal_feed_days")
		"whales", "orcas":
			Game.add_stat(id + "_seen")
			Game.set_flag(id + "_seen")
		"ghost_ship":
			if int(Game.counters.get("eleonora_year", 0)) == Clock.year:
				return "«Элеонора» растворяется в тумане."
			var isle := SeaChart.place_pos("nameless_isle") + Vector2(0, 40)
			outing.append({"id": "eleonora_chest", "x": isle.x, "y": isle.y, "done": false})
		"eleonora_chest":
			Game.counters["eleonora_year"] = Clock.year
			Inventory.add("chest_deep", 1)
		"fisher_in_trouble":
			towing = true
	ev["done"] = true
	return Loc.t("sea_event." + id) if Loc.has("sea_event." + id) else "Сундук у Острова Без Имени."


# Towing a fisherman back to the pier (16.6): a present and honour (doubled for the Rescuer).
func finish_tow() -> int:
	if not towing:
		return 0
	towing = false
	var honour := 6 if Skills.has_profession("rescuer") else 3
	Game.add_honor(honour)
	Economy.add(300)
	Inventory.add("fish_cod", 3)
	return honour


# ---- boats (16) ----

func set_boat(id: String) -> void:
	boat = id
	var size := int(SeaChart.boat_info(id).get("hold", 12)) + (12 if Skills.has_profession("skipper") else 0)
	while hold.size() < size:
		hold.append({"id": "", "count": 0, "quality": 0})


func can_sail(zone: int = 1) -> String:
	if boat == "":
		return "no_boat"
	if zone > int(SeaChart.boat_info().get("zones", 1)):
		return "zone"
	if Weather.current in ["storm", "blizzard"] and not Game.flag("storm_sails") \
			and not (Inventory.count_of("storm_sails") > 0 and bool(SeaChart.boat_info().get("storm_ok_with_sails", false) or boat == "sloop")):
		return "storm"
	return ""


func damage_hull(amount: float) -> bool:
	if int(Game.counters.get("boat_blessed_until", -1)) >= Clock.day_index:
		amount *= 0.9
	amount *= maxf(0.0, 1.0 - 0.05 * float(Skills.base_level("seafaring"))) * (0.5 if Skills.has_profession("skipper") else 1.0)
	hull = maxf(0.0, hull - amount)
	return hull <= 0.0


# At 0 the boat is towed home for 500 kr and the hold is lost (16.3).
func tow_home() -> void:
	for slot in hold:
		slot["id"] = ""
		slot["count"] = 0
		slot["quality"] = 0
	var price := int(SeaChart.cfg("tow_price"))
	Economy.add(-mini(price, Economy.money))
	hull = 100.0
	Mail.send("mail.towed")


func repair_at_boathouse() -> int:
	var fixed := 0
	while hull < 100.0 and Inventory.count_of("boards") >= 1 and Inventory.count_of("resin") >= 1:
		Inventory.take("boards", 1)
		Inventory.take("resin", 1)
		hull = minf(100.0, hull + 10.0)
		fixed += 10
	return fixed


func use_repair_kit() -> bool:
	if hull >= 100.0 or not Inventory.take("repair_kit", 1):
		return false
	hull = minf(100.0, hull + 30.0)
	return true


# First visits to named places: +30 seafaring XP and +3 sea notes (25.2, 26.1).
func visit(place: String) -> bool:
	if place == "" or visited.has(place):
		return false
	visited[place] = true
	Skills.add_xp("seafaring", 30)
	Knowledge.add_points("sea", 3)
	return true


# Q1.6: Ilm needs 20 driftwood, 5 resin and 300 kr; the dinghy is ready two days later.
func order_boat() -> bool:
	if boat != "" or boat_ready_day >= 0:
		return false
	if Inventory.count_of("driftwood") < 20 or Inventory.count_of("resin") < 5 or not Economy.can_pay(300):
		return false
	Inventory.take("driftwood", 20)
	Inventory.take("resin", 5)
	Economy.pay(300)
	boat_ready_day = Clock.day_index + 2
	Events.quest_event.emit("boat_ordered", "")
	return true


func night_boats() -> void:
	if boat == "" and boat_ready_day >= 0 and Clock.day_index >= boat_ready_day:
		set_boat("yalik")
		Mail.send("mail.boat_ready")
		Events.quest_event.emit("boat_launched", "")


func serialize() -> Dictionary:
	return {"mercy": mercy, "blessings": blessings, "boat": boat, "revealed": revealed,
		"gifts": gifts, "trash_mercy_today": trash_mercy_today, "scheduled": scheduled,
		"gear": gear, "hull": hull, "hold": hold, "visited": visited, "boat_ready_day": boat_ready_day,
		"pools": pools, "clams": clams, "pools_fished": pools_fished, "sea_garden": sea_garden}


func deserialize(d: Dictionary) -> void:
	mercy = clampf(float(d.get("mercy", START_MERCY)), 0.0, 100.0)
	blessings = d.get("blessings", [])
	boat = str(d.get("boat", ""))
	revealed = d.get("revealed", {})
	trash_mercy_today = float(d.get("trash_mercy_today", 0.0))
	hull = clampf(float(d.get("hull", 100.0)), 0.0, 100.0)
	hold = d.get("hold", []).duplicate(true)
	for slot in hold:
		slot["count"] = int(slot.get("count", 0))
		slot["quality"] = int(slot.get("quality", 0))
	visited = d.get("visited", {}).duplicate()
	boat_ready_day = int(d.get("boat_ready_day", -1))
	if boat != "":
		set_boat(boat)
	gear = d.get("gear", []).duplicate(true)
	for g in gear:
		g["set_day"] = int(g["set_day"])
		g["set_minute"] = int(g["set_minute"])
		for entry in g["catch"]:
			entry[1] = int(entry[1])
	pools = d.get("pools", {}).duplicate(true)
	for map_id in pools:
		for pool in pools[map_id]:
			pool["x"] = int(pool["x"])
			pool["row"] = int(pool["row"])
	clams = d.get("clams", []).duplicate(true)
	for spot in clams:
		spot["x"] = int(spot["x"])
		spot["row"] = int(spot["row"])
	pools_fished = d.get("pools_fished", {}).duplicate()
	sea_garden.clear()
	for g in d.get("sea_garden", []):
		sea_garden.append({"kind": str(g["kind"]), "x": int(g["x"]), "y": int(g["y"]), "planted": int(g["planted"]),
			"next": int(g["next"]), "ready": bool(g.get("ready", false)), "broken": bool(g.get("broken", false))})
	scheduled.clear()
	for entry in d.get("scheduled", []):
		scheduled.append({"item": str(entry["item"]), "beach": str(entry["beach"]), "day": int(entry["day"])})
	gifts.clear()
	var saved: Dictionary = d.get("gifts", {})
	for map_id in saved:
		var list: Array = []
		for gift in saved[map_id]:
			list.append({"item": str(gift["item"]), "x": int(gift["x"]), "row": int(gift["row"])})
		gifts[map_id] = list
