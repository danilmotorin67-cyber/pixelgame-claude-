extends Node

# The old beds beside the cape house: 10 columns by 6 rows of salt-free soil (13.1).
const WIDTH := 10
const HEIGHT := 6
const MAX_SALT := 2
const MAX_FERTILITY := 3
const STORM_STAGE_LOSS := 0.15
const HARVEST_FERTILITY_LOSS := 0.25
# The beds' top-left corner on the cape map (the Garden node), 16 px tiles.
const ORIGIN := Vector2(672, 304)
# Garden plots of the cape: Agatha's beds outdoors; the greenhouses (13.11) grow anything in any season,
# with no salt, and neither gulls, storms nor rain reach inside.
const PLOTS := {
	"beds": {"origin": Vector2(672, 304), "size": Vector2i(10, 6), "indoor": false},
	"greenhouse_small": {"origin": Vector2(1040, 304), "size": Vector2i(6, 6), "indoor": true},
	"greenhouse": {"origin": Vector2(1040, 440), "size": Vector2i(10, 12), "indoor": true},
}
var opened: Dictionary = {"beds": true}
var tiles: Dictionary = {}
var last_harvest: Dictionary = {}
# Seasonal wild finds per map: [{item, x, y}] in tiles.
var wild: Dictionary = {}
# Peat bog tiles dug this season: "x,y" -> season key; each tile recovers once a season (13.13).
var peat_dug: Dictionary = {}
# Loose stones to clear with the pickaxe: map -> [{x, y, hp}] in tiles.
var rocks: Dictionary = {}


func _key(cell: Vector2i, plot: String = "beds") -> String:
	return "%d,%d" % [cell.x, cell.y] if plot == "beds" else "%s|%d,%d" % [plot, cell.x, cell.y]


static func parse_key(key: String) -> Array:
	var plot := "beds"
	var rest := key
	if key.contains("|"):
		plot = key.get_slice("|", 0)
		rest = key.get_slice("|", 1)
	return [plot, Vector2i(int(rest.get_slice(",", 0)), int(rest.get_slice(",", 1)))]


func _valid(cell: Vector2i, plot: String = "beds") -> bool:
	if not PLOTS.has(plot) or not opened.has(plot):
		return false
	var size: Vector2i = PLOTS[plot]["size"]
	return cell.x >= 0 and cell.x < size.x and cell.y >= 0 and cell.y < size.y


func indoor(plot: String) -> bool:
	return bool(PLOTS.get(plot, {}).get("indoor", false))


func open_plot(plot: String) -> void:
	if PLOTS.has(plot):
		opened[plot] = true
		Events.farm_changed.emit()


func _season_key() -> int:
	return Clock.day_index / Clock.DAYS_PER_SEASON


func _rng(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 92821 + Clock.day_index * 7703 + cell.x * 131 + cell.y * 17 + salt,
		2147483647)
	return rng


func get_tile(cell: Vector2i, plot: String = "beds") -> Dictionary:
	return tiles.get(_key(cell, plot), {}) if _valid(cell, plot) else {}


func reset() -> void:
	tiles.clear()
	opened = {"beds": true}
	wild.clear()
	peat_dug.clear()
	rocks.clear()
	Events.farm_changed.emit()


func till(cell: Vector2i, plot: String = "beds") -> bool:
	if not _valid(cell, plot) or not get_tile(cell, plot).is_empty():
		return false
	tiles[_key(cell, plot)] = {"salt": 0, "fertility": 1, "watered": false, "crop": "", "days": 0,
		"growth": 0.0, "ready": false, "amended": {}, "guano_season": -1, "flawless_bonus": 0.0}
	Events.farm_changed.emit()
	return true


func water(cell: Vector2i, plot: String = "beds") -> bool:
	var tile := get_tile(cell, plot)
	if tile.is_empty() or bool(tile["watered"]):
		return false
	tile["watered"] = true
	Events.farm_changed.emit()
	return true


func fertility(tile: Dictionary) -> int:
	var value := int(tile.get("fertility", 0))
	if int(tile.get("guano_season", -1)) == _season_key():
		value += 2
	return mini(value, MAX_FERTILITY)


func total_days(crop: Dictionary) -> int:
	var total := 0
	for length in crop.get("stage_days", []):
		total += int(length)
	return total


# 0-based growth stage; the crop is ripe once growth reaches the last boundary.
func stage(tile: Dictionary) -> int:
	var crop := Data.by_id("crops", str(tile.get("crop", "")))
	var passed := 0.0
	var index := 0
	for length in crop.get("stage_days", []):
		passed += float(length)
		if float(tile.get("growth", 0.0)) < passed:
			return index
		index += 1
	return maxi(index - 1, 0)


func plant(cell: Vector2i, seed_id: String, plot: String = "beds") -> bool:
	var tile := get_tile(cell, plot)
	if tile.is_empty() or str(tile["crop"]) != "":
		return false
	for crop in Data.all("crops"):
		if str(crop.get("seed", "")) != seed_id:
			continue
		if (Clock.season not in crop.get("seasons", []) and not indoor(plot)) or int(tile["salt"]) > int(crop.get("salt", 0)):
			return false
		if not Inventory.take(seed_id):
			return false
		tile["crop"] = str(crop["id"])
		tile["days"] = 0
		tile["growth"] = 0.0
		tile["ready"] = false
		Events.farm_changed.emit()
		return true
	return false


# Soil treatments from 13.3, each at most once per season on a bed.
func amend(cell: Vector2i, item_id: String, plot: String = "beds") -> String:
	var tile := get_tile(cell, plot)
	var soil: Dictionary = Data.by_id("items", item_id).get("soil", {})
	if tile.is_empty() or soil.is_empty():
		return "invalid"
	var amended: Dictionary = tile["amended"]
	if int(amended.get(item_id, -1)) == _season_key():
		return "season"
	if not Inventory.take(item_id):
		return "invalid"
	amended[item_id] = _season_key()
	tile["salt"] = clampi(int(tile["salt"]) + int(soil.get("salt", 0)), 0, MAX_SALT)
	tile["fertility"] = clampi(int(tile["fertility"]) + int(soil.get("fertility", 0)), 0, MAX_FERTILITY)
	if soil.has("fertility_season"):
		tile["guano_season"] = _season_key()
	tile["flawless_bonus"] = float(tile["flawless_bonus"]) + float(soil.get("flawless", 0.0))
	Events.farm_changed.emit()
	return "ok"


func roll_quality(tile: Dictionary, crop: Dictionary, rng: RandomNumberGenerator) -> int:
	var fert := fertility(tile)
	var level := Skills.level("farming")
	var flawless := float(tile.get("flawless_bonus", 0.0))
	if fert >= 3 and level >= 8:
		flawless += 0.05
	var good := 0.15 + 0.03 * float(level) + 0.10 * float(fert)
	if int(crop.get("salt", 0)) == 2 and int(tile.get("salt", 0)) == 2:
		good += 0.10
	if rng.randf() < flawless:
		return 3
	if rng.randf() < good * 0.5:
		return 2
	if rng.randf() < good:
		return 1
	return 0


func harvest(cell: Vector2i, plot: String = "beds") -> bool:
	var tile := get_tile(cell, plot)
	if tile.is_empty() or not bool(tile["ready"]):
		return false
	var crop := Data.by_id("crops", str(tile["crop"]))
	if crop.is_empty():
		return false
	var rng := _rng(cell + (Vector2i(100, 0) if plot != "beds" else Vector2i.ZERO), 401)
	var quality := roll_quality(tile, crop, rng)
	var amount := 1 + (1 if rng.randf() < float(crop.get("extra_chance", 0.0)) else 0)
	var produce := str(crop["produce"])
	if Inventory.add(produce, amount, quality) != amount:
		return false
	if rng.randf() < HARVEST_FERTILITY_LOSS:
		tile["fertility"] = maxi(int(tile["fertility"]) - 1, 0)
	tile["flawless_bonus"] = 0.0
	var regrow := int(crop.get("regrow", 0))
	if regrow > 0:
		tile["growth"] = float(total_days(crop) - regrow)
		tile["days"] = 0
	else:
		tile["crop"] = ""
		tile["days"] = 0
		tile["growth"] = 0.0
	tile["ready"] = false
	last_harvest = {"id": produce, "amount": amount, "quality": quality}
	var price := int(Data.by_id("items", produce).get("price", 0))
	Skills.add_xp("farming", 3 + price / 20)
	# 26.1: a new crop +2 land notes, every 20 harvests +1.
	if not Game.flag("harvested_" + produce):
		Game.set_flag("harvested_" + produce)
		Knowledge.add_points("land", 2)
	Game.add_stat("harvests")
	if Game.stat("harvests") % 20 == 0:
		Knowledge.add_points("land", 1)
	Events.crop_harvested.emit(produce, quality)
	Events.farm_changed.emit()
	return true


func _clear_crop(tile: Dictionary) -> void:
	tile["crop"] = ""
	tile["days"] = 0
	tile["growth"] = 0.0
	tile["ready"] = false


func tile_center(cell: Vector2i, plot: String = "beds") -> Vector2:
	return (PLOTS[plot]["origin"] as Vector2) + Vector2(cell) * 16.0 + Vector2(8, 8)


# 13.7: barrels water the 4 neighbours, cisterns the 8 around, the wind pump a 5×5 square (not in a calm).
func _fixture_cells(obj: Dictionary, plot: String = "beds") -> Array:
	var origin: Vector2 = PLOTS[plot]["origin"]
	var center := Vector2i(floori((float(obj["x"]) - origin.x) / 16.0), floori((float(obj["y"]) - origin.y) / 16.0))
	var out: Array = []
	var reach := {"watering_barrel": 1, "cistern": 1, "wind_pump": 2}.get(str(obj["id"]), 0) as int
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dy == 0:
				continue
			if str(obj["id"]) == "watering_barrel" and absi(dx) + absi(dy) != 1:
				continue
			out.append(center + Vector2i(dx, dy))
	return out


func _auto_water() -> void:
	var rain := Weather.current in ["rain", "storm"]
	var water_days: Dictionary = Game.balance("garden", {}).get("water_days", {})
	for obj in Crafting.placed.get("cape", []):
		var id := str(obj["id"])
		if id not in ["watering_barrel", "cistern", "wind_pump"]:
			continue
		if rain and water_days.has(id):
			obj["water"] = int(water_days[id])
		if id == "wind_pump" and Weather.calm:
			continue
		if id != "wind_pump" and int(obj.get("water", 0)) <= 0:
			continue
		var used := false
		for plot in opened:
			for cell in _fixture_cells(obj, plot):
				var tile := get_tile(cell, plot)
				if not tile.is_empty() and not bool(tile["watered"]):
					tile["watered"] = true
					used = true
		if used and id != "wind_pump" and not rain:
			obj["water"] = int(obj.get("water", 0)) - 1


# 13.8: gulls take a ripe crop 1% a morning unless a scarer, the scarecrow or Wick sits within reach.
func guarded(at: Vector2) -> bool:
	var cfg: Dictionary = Game.balance("garden", {})
	var guard: Dictionary = cfg.get("guard", {})
	var cat_at: Array = cfg.get("cat_at", [600, 360])
	if at.distance_to(Vector2(float(cat_at[0]), float(cat_at[1]))) <= float(guard.get("cat", 8)) * 16.0:
		return true
	for obj in Crafting.placed.get("cape", []):
		var radius := float(guard.get(str(obj["id"]), 0))
		if radius > 0.0 and at.distance_to(Vector2(float(obj["x"]), float(obj["y"]))) <= radius * 16.0 + 8.0:
			return true
	return false


# Night step 3: growth, reset watering, storm damage, rain on the new day.
func advance_day(storm_night: bool = false) -> void:
	for key in tiles:
		var tile: Dictionary = tiles[key]
		var parsed := parse_key(key)
		var plot: String = parsed[0]
		var cell: Vector2i = parsed[1]
		var inside := indoor(plot)
		if str(tile["crop"]) != "":
			var crop := Data.by_id("crops", str(tile["crop"]))
			if crop.is_empty() or (Clock.season not in crop.get("seasons", []) and not inside):
				_clear_crop(tile)
			else:
				if not inside and bool(tile["ready"]) and _rng(cell, 353).randf() < float(Game.balance("garden", {}).get("gull_chance", 0.01)) \
						and not guarded(tile_center(cell, plot)):
					_clear_crop(tile)
					tile["watered"] = false
					tile["gulls"] = Clock.day_index
					continue
				if storm_night and not inside and not bool(tile["ready"]) and not Crafting.sheltered("cape", tile_center(cell)) \
						and _rng(cell, 911).randf() < STORM_STAGE_LOSS:
					if stage(tile) <= 1:
						_clear_crop(tile)
						tile["watered"] = false
						continue
					var boundary := 0.0
					var lengths: Array = crop.get("stage_days", [])
					for i in stage(tile) - 1:
						boundary += float(lengths[i])
					tile["growth"] = boundary
				if bool(tile["watered"]) and not bool(tile["ready"]):
					var fert := fertility(tile)
					var speed := (1.10 if fert >= 3 else (1.05 if fert == 2 else 1.0)) * (1.1 if Skills.has_profession("northern_gardener") else 1.0)
					tile["days"] = int(tile["days"]) + 1
					tile["growth"] = float(tile["growth"]) + speed
					tile["ready"] = float(tile["growth"]) >= float(total_days(crop)) - 0.001
		tile["watered"] = Weather.current in ["rain", "storm"] and not inside
	_auto_water()
	Events.farm_changed.emit()


# Seasonal foraging spots of 18.1 appear each morning inside the open zones of each region.
func spawn_wild(index: int) -> void:
	var config: Dictionary = Data.tables.get("forage", {})
	var season_name: String = Clock.SEASONS[(index % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON]
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 48271 + index * 6007 + 11, 2147483647)
	var bounds: Array = config.get("spots_per_zone", [2, 4])
	wild.clear()
	for map_id in config.get("zones", {}):
		var table: Array = []
		for spot in config.get("seasonal", {}).get(season_name, []):
			if str(spot[1]) == map_id:
				table.append([spot[0], spot[2]])
		if table.is_empty():
			continue
		var list: Array = []
		for zone in config["zones"][map_id]:
			for n in rng.randi_range(int(bounds[0]), int(bounds[1])):
				list.append({"item": Sea._pick(rng, table),
					"x": int(zone[0]) + rng.randi_range(0, int(zone[2]) - 1),
					"y": int(zone[1]) + rng.randi_range(0, int(zone[3]) - 1)})
		wild[map_id] = list
	# 13.4: hmar-caps come up by themselves on the cape and the graveyard after a Hmar Night.
	if Weather.last_hmar_day == index - 1:
		var caps: Array = wild.get("cape", [])
		for n in rng.randi_range(3, 6) * (3 if Skills.has_profession("hmar_forager") else 1):
			caps.append({"item": "hmar_mushroom", "x": rng.randi_range(20, 60), "y": rng.randi_range(14, 40)})
		wild["cape"] = caps


func scatter_rocks() -> void:
	var cfg_rocks: Dictionary = Game.balance("graveyard", {}).get("rocks", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 7919 + 3, 2147483647)
	for map_id in cfg_rocks.get("zones", {}):
		var zones: Array = cfg_rocks["zones"][map_id]
		var list: Array = []
		var used := {}
		for n in int(cfg_rocks.get(map_id, 20)):
			var zone: Array = zones[rng.randi_range(0, zones.size() - 1)]
			var cell := Vector2i(int(zone[0]) + rng.randi_range(0, int(zone[2]) - 1),
				int(zone[1]) + rng.randi_range(0, int(zone[3]) - 1))
			if used.has(cell):
				continue
			used[cell] = true
			list.append({"x": cell.x, "y": cell.y, "hp": int(cfg_rocks.get("hp", 2))})
		rocks[map_id] = list


# A pickaxe hit; a broken stone gives 1-3 stone. Returns stone gained (0 while it holds).
func hit_rock(map_id: String, rock: Dictionary) -> int:
	var list: Array = rocks.get(map_id, [])
	if not list.has(rock):
		return -1
	rock["hp"] = int(rock["hp"]) - 1 - Buildings.tool_level("tool_pick")
	if int(rock["hp"]) > 0:
		return 0
	var amount: Array = Game.balance("graveyard", {}).get("rocks", {}).get("stone", [1, 3])
	var n := _rng(Vector2i(int(rock["x"]), int(rock["y"])), 53).randi_range(int(amount[0]), int(amount[1]))
	list.erase(rock)
	Inventory.add("stone", n)
	return n


func in_peat_bog(map_id: String, cell: Vector2i) -> bool:
	var bog: Dictionary = Data.tables.get("forage", {}).get("peat_bog", {})
	var rect: Array = bog.get("rect", [0, 0, 0, 0])
	return str(bog.get("map", "")) == map_id and cell.x >= int(rect[0]) and cell.x < int(rect[0]) + int(rect[2]) \
		and cell.y >= int(rect[1]) and cell.y < int(rect[1]) + int(rect[3])


func dig_peat(map_id: String, cell: Vector2i) -> int:
	var key := _key(cell)
	if not in_peat_bog(map_id, cell) or int(peat_dug.get(key, -1)) == _season_key():
		return 0
	var amount: Array = Data.tables["forage"]["peat_bog"].get("amount", [1, 2])
	var n := _rng(cell, 977).randi_range(int(amount[0]), int(amount[1]))
	if not Inventory.can_fit("peat", n):
		return 0
	peat_dug[key] = _season_key()
	Inventory.add("peat", n)
	Skills.add_xp("foraging", 2)
	return n


func collect_wild(map_id: String, spot: Dictionary) -> bool:
	var list: Array = wild.get(map_id, [])
	var index := list.find(spot)
	if index < 0 or not Inventory.forage(str(spot["item"]), 7):
		return false
	list.remove_at(index)
	return true


func serialize() -> Dictionary:
	return {"tiles": tiles, "wild": wild, "peat_dug": peat_dug, "rocks": rocks, "opened": opened}


func deserialize(d: Dictionary) -> void:
	tiles = d.get("tiles", {}).duplicate(true)
	opened = {"beds": true}
	for plot in d.get("opened", {}):
		if PLOTS.has(str(plot)):
			opened[str(plot)] = true
	peat_dug.clear()
	rocks.clear()
	var saved_rocks: Dictionary = d.get("rocks", {})
	for map_id in saved_rocks:
		var list: Array = []
		for rock in saved_rocks[map_id]:
			list.append({"x": int(rock["x"]), "y": int(rock["y"]), "hp": int(rock["hp"])})
		rocks[map_id] = list
	var saved_peat: Dictionary = d.get("peat_dug", {})
	for key in saved_peat:
		peat_dug[str(key)] = int(saved_peat[key])
	wild.clear()
	var saved_wild: Dictionary = d.get("wild", {})
	for map_id in saved_wild:
		var list: Array = []
		for spot in saved_wild[map_id]:
			list.append({"item": str(spot["item"]), "x": int(spot["x"]), "y": int(spot["y"])})
		wild[map_id] = list
	for key in tiles:
		var tile: Dictionary = tiles[key]
		tile["salt"] = clampi(int(tile.get("salt", 0)), 0, MAX_SALT)
		tile["fertility"] = clampi(int(tile.get("fertility", 1)), 0, MAX_FERTILITY)
		tile["days"] = int(tile.get("days", 0))
		tile["growth"] = float(tile.get("growth", tile["days"]))
		tile["guano_season"] = int(tile.get("guano_season", -1))
		tile["flawless_bonus"] = float(tile.get("flawless_bonus", 0.0))
		var amended: Dictionary = tile.get("amended", {})
		for item_id in amended:
			amended[item_id] = int(amended[item_id])
		tile["amended"] = amended
	Events.farm_changed.emit()
