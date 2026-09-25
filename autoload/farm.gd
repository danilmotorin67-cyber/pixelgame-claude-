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
	# 13.1: the rest of the cape's ≈900 tiles, overgrown — stones (pickaxe), snags (axe), weeds (scythe);
	# the soil is salty: 60% Salt 2, 40% Salt 1. The southern field lies within reach of storm spray.
	"field_nw": {"origin": Vector2(96, 96), "size": Vector2i(36, 9), "indoor": false, "field": true},
	"field_ne": {"origin": Vector2(784, 96), "size": Vector2i(30, 9), "indoor": false, "field": true},
	"field_s": {"origin": Vector2(400, 672), "size": Vector2i(30, 10), "indoor": false, "field": true},
}
const FIELDS := ["field_nw", "field_ne", "field_s"]
# What overgrows the field and which tool clears it.
const CLUTTER_TOOLS := {"weed": "tool_scythe", "rock": "tool_pick", "snag": "tool_axe"}
const CLUTTER_ENERGY := {"weed": "scythe", "rock": "pick", "snag": "axe"}
var opened: Dictionary = {"beds": true, "field_nw": true, "field_ne": true, "field_s": true}
# Field tiles still overgrown: key -> {"k": weed|rock|snag, "hp": hits left}.
var clutter: Dictionary = {}
var field_ready: bool = false
# 9: the can holds 40/55/70/85/100 of fresh water by its level; a tile takes one.
const CAN_VOLUME := [40, 55, 70, 85, 100]
# 9: held, the hoe and the can reach 1 / 3 / 5 / 3×3 / 6×3 tiles (charge steps open with the tool's level).
const CHARGE_TILES := [1, 3, 5, 9, 18]
# Agatha's rain butt by the beds: fresh water before there is a well.
const RAIN_BUTT := Vector2(656, 300)
var can_water: int = 40
# 18.4: ravens circle 2-4 spots a day across the island: map -> [{x, y}] in tiles.
var raven_marks: Dictionary = {}
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


func is_field(plot: String) -> bool:
	return bool(PLOTS.get(plot, {}).get("field", false))


# The field's own salt before any care: 60% Salt 2, 40% Salt 1 (fixed per world).
func base_salt(cell: Vector2i, plot: String) -> int:
	if not is_field(plot):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 6089 + plot.hash() + cell.x * 257 + cell.y * 31, 2147483647)
	return 2 if rng.randf() < 0.6 else 1


# Overgrows the whole field at the start of a world: most tiles hold weeds, stones or snags.
func scatter_field() -> void:
	clutter.clear()
	var cfg: Dictionary = Game.balance("garden", {}).get("field", {})
	var shares: Dictionary = cfg.get("clutter", {"weed": 0.45, "rock": 0.15, "snag": 0.1})
	var hp: Dictionary = cfg.get("hp", {"weed": 1, "rock": 2, "snag": 2})
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 3571 + 17, 2147483647)
	for plot in FIELDS:
		var size: Vector2i = PLOTS[plot]["size"]
		for y in size.y:
			for x in size.x:
				var roll := rng.randf()
				for kind in ["weed", "rock", "snag"]:
					roll -= float(shares.get(kind, 0.0))
					if roll < 0.0:
						clutter[_key(Vector2i(x, y), plot)] = {"k": kind, "hp": int(hp.get(kind, 1))}
						break
	field_ready = true
	Events.farm_changed.emit()


func clutter_at(cell: Vector2i, plot: String) -> String:
	return str(clutter.get(_key(cell, plot), {}).get("k", ""))


func field_clear_count() -> int:
	var total := 0
	for plot in FIELDS:
		var size: Vector2i = PLOTS[plot]["size"]
		total += size.x * size.y
	return total - clutter.size()


# One blow of the right tool: "wrong" for the wrong tool, "" while it holds, else what fell off it.
func clear_clutter(cell: Vector2i, plot: String, tool: String) -> String:
	var key := _key(cell, plot)
	if not clutter.has(key):
		return "none"
	var entry: Dictionary = clutter[key]
	var kind := str(entry["k"])
	if str(CLUTTER_TOOLS[kind]) != tool:
		return "wrong"
	entry["hp"] = int(entry["hp"]) - 1 - Buildings.tool_level(tool)
	if int(entry["hp"]) > 0:
		return ""
	clutter.erase(key)
	var got := ""
	match kind:
		"rock":
			Inventory.add("stone", 1)
			got = "stone"
		"snag":
			Inventory.add("driftwood", 1)
			got = "driftwood"
		"weed":
			if Buildings.level("hayloft") > 0 and _rng(cell, 719).randf() < 0.5 and Buildings.mow(0.0) > 0:
				got = "hay"
			else:
				got = "weed"
	Skills.add_xp("foraging", 1)
	Game.add_stat("field_cleared")
	Events.quest_event.emit("field_cleared", kind)
	Events.farm_changed.emit()
	return got


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
	opened = {"beds": true, "field_nw": true, "field_ne": true, "field_s": true}
	wild.clear()
	peat_dug.clear()
	rocks.clear()
	clutter.clear()
	field_ready = false
	can_water = CAN_VOLUME[0]
	raven_marks.clear()
	Events.farm_changed.emit()


func till(cell: Vector2i, plot: String = "beds") -> bool:
	if not _valid(cell, plot) or not get_tile(cell, plot).is_empty() or clutter.has(_key(cell, plot)):
		return false
	tiles[_key(cell, plot)] = {"salt": base_salt(cell, plot), "fertility": 1, "watered": false, "crop": "", "days": 0,
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


func can_capacity() -> int:
	return int(CAN_VOLUME[clampi(Buildings.tool_level("tool_can"), 0, CAN_VOLUME.size() - 1)])


func fill_can() -> int:
	var added := maxi(can_capacity() - can_water, 0)
	can_water = can_capacity()
	return added


# Watering with the can itself: "ok", "empty" or "no" (nothing to water there).
func water_with_can(cell: Vector2i, plot: String = "beds") -> String:
	if can_water <= 0:
		return "empty"
	if not water(cell, plot):
		return "no"
	can_water -= 1
	return "ok"


# Only fresh water fills the can: the rain butt, the well, a cistern, the moor's and the grove's streams.
func fresh_water_at(map_id: String, at: Vector2) -> bool:
	if map_id in ["moor", "birch"]:
		return Fishing.is_water(map_id, at)
	if map_id != "cape":
		return false
	if at.distance_to(RAIN_BUTT) <= 20.0:
		return true
	if Buildings.level("well") > 0 and at.distance_to(BuildingObject.home_of("well")) <= 24.0:
		return true
	for obj in Crafting.placed.get("cape", []):
		if str(obj["id"]) == "cistern" and at.distance_to(Vector2(float(obj["x"]), float(obj["y"]))) <= 20.0:
			return true
	return false


func max_charge(tool_id: String) -> int:
	return clampi(Buildings.tool_level(tool_id), 0, CHARGE_TILES.size() - 1)


# The tiles a charged blow covers, from the aimed tile onward in the facing direction.
static func charge_cells(cell: Vector2i, facing: Vector2i, step: int) -> Array:
	var forward := facing if facing != Vector2i.ZERO else Vector2i(0, 1)
	var side := Vector2i(-forward.y, forward.x)
	var out: Array = []
	var length: int = [1, 3, 5, 3, 6][clampi(step, 0, 4)]
	var width := 1 if step < 3 else 3
	for i in length:
		for j in width:
			out.append(cell + forward * i + side * (j - width / 2))
	return out


# A charged hoe: tills every free tile it covers; returns how many.
func till_area(cell: Vector2i, plot: String, facing: Vector2i, step: int) -> int:
	var n := 0
	for c in charge_cells(cell, facing, step):
		if till(c, plot):
			n += 1
	return n


# A charged can: waters until the can runs dry; returns how many tiles.
func water_area(cell: Vector2i, plot: String, facing: Vector2i, step: int) -> int:
	var n := 0
	for c in charge_cells(cell, facing, step):
		if water_with_can(c, plot) == "ok":
			n += 1
	return n


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
		Events.quest_event.emit("planted", seed_id)
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
	Events.quest_event.emit("soil_improved", item_id)
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


# Q2.13 failed: the Hmar spoils the cape's crops by `stages` stages (the first stage dies back to seed).
func setback(stages: int) -> int:
	var hit := 0
	for key in tiles:
		var tile: Dictionary = tiles[key]
		var plot: String = parse_key(key)[0]
		if str(tile["crop"]) == "" or indoor(plot):
			continue
		var crop := Data.by_id("crops", str(tile["crop"]))
		var lengths: Array = crop.get("stage_days", [])
		var target := maxi(0, stage(tile) - stages)
		var boundary := 0.0
		for i in mini(target, lengths.size()):
			boundary += float(lengths[i])
		tile["growth"] = minf(float(tile["growth"]), boundary)
		tile["ready"] = false
		hit += 1
	Events.farm_changed.emit()
	return hit


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
				if storm_night and not inside and not bool(tile["ready"]) and not Crafting.sheltered("cape", tile_center(cell, plot)) \
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
		if storm_night and not inside:
			salinize(tile, cell, plot)
		tile["watered"] = Weather.current in ["rain", "storm"] and not inside
	_auto_water()
	Events.farm_changed.emit()


# 13.3: after a storm, unsheltered tiles within 12 tiles of the shore turn saltier (25%).
func near_shore(cell: Vector2i, plot: String) -> bool:
	var cfg: Dictionary = Game.balance("garden", {})
	return float(cfg.get("shore_y", 864)) - tile_center(cell, plot).y <= float(cfg.get("salt_shore_tiles", 12)) * 16.0


func salinize(tile: Dictionary, cell: Vector2i, plot: String) -> bool:
	if int(tile["salt"]) >= MAX_SALT or not near_shore(cell, plot) or Crafting.sheltered("cape", tile_center(cell, plot)):
		return false
	if _rng(cell + Vector2i(0, plot.length() * 100), 1301).randf() >= float(Game.balance("garden", {}).get("salt_chance", 0.25)):
		return false
	tile["salt"] = int(tile["salt"]) + 1
	return true


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
	spawn_raven_marks(index)
	# 13.4: hmar-caps come up by themselves on the cape and the graveyard after a Hmar Night.
	if Weather.last_hmar_day == index - 1:
		var caps: Array = wild.get("cape", [])
		for n in rng.randi_range(3, 6) * (3 if Skills.has_profession("hmar_forager") else 1):
			caps.append({"item": "hmar_mushroom", "x": rng.randi_range(20, 60), "y": rng.randi_range(14, 40)})
		wild["cape"] = caps


# 18.4: each morning 2-4 raven marks over the island's open ground (the forage zones).
func spawn_raven_marks(index: int) -> void:
	raven_marks.clear()
	var zones: Dictionary = Data.tables.get("forage", {}).get("zones", {})
	if zones.is_empty():
		return
	var maps: Array = zones.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 5413 + index * 211 + 7, 2147483647)
	for n in rng.randi_range(2, 4):
		var map_id := str(maps[rng.randi_range(0, maps.size() - 1)])
		var list: Array = zones[map_id]
		var zone: Array = list[rng.randi_range(0, list.size() - 1)]
		var marks: Array = raven_marks.get(map_id, [])
		marks.append({"x": int(zone[0]) + rng.randi_range(0, int(zone[2]) - 1), "y": int(zone[1]) + rng.randi_range(0, int(zone[3]) - 1)})
		raven_marks[map_id] = marks


func raven_mark_at(map_id: String, at: Vector2) -> Dictionary:
	for mark in raven_marks.get(map_id, []):
		if at.distance_to(Vector2(int(mark["x"]) * 16 + 8, int(mark["y"]) * 16 + 8)) <= 20.0:
			return mark
	return {}


# A hoe or a shovel at a raven mark: an artifact, a bottle, old coins, worms, now and then a raven's feather
# (and, rarely, the Raven's Eye). The Raven's Eye profession finds artifacts twice as often.
func dig_raven_mark(map_id: String, mark: Dictionary) -> Dictionary:
	var list: Array = raven_marks.get(map_id, [])
	if not list.has(mark):
		return {}
	list.erase(mark)
	var rng := _rng(Vector2i(int(mark["x"]), int(mark["y"])), 1601)
	var artifact := 0.5 if Skills.has_profession("raven_eye") else 0.25
	var roll := rng.randf()
	var got := {}
	if rng.randf() < 0.02 and Inventory.count_of("crow_eye") == 0 and not Game.equipment.values().has("crow_eye"):
		got = {"item": "crow_eye", "count": 1}
	elif roll < artifact:
		var pool: Array = []
		for item in Data.all("items"):
			if str(item.get("category", "")) == "artifact" and int(item.get("price", 0)) > 0:
				pool.append(str(item["id"]))
		got = {"item": str(pool[rng.randi_range(0, pool.size() - 1)]), "count": 1}
	elif roll < artifact + 0.1:
		got = {"item": "message_bottle", "count": 1}
	elif roll < artifact + 0.3:
		got = {"money": rng.randi_range(40, 120)}
	elif roll < 0.92:
		got = {"item": "worms", "count": rng.randi_range(3, 6)}
	else:
		got = {"item": "raven_feather", "count": 1}
	if got.has("money"):
		Economy.add(int(got["money"]))
	else:
		Inventory.add(str(got["item"]), int(got["count"]))
	Skills.add_xp("foraging", 5)
	Game.add_stat("raven_marks")
	return got


# What the Raven's Eye (profession or charm) shows on the map: today's marks and the bottles on the beaches.
func raven_sight() -> bool:
	return Skills.has_profession("raven_eye") or Game.effect("raven_sight") > 0.0


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
	return {"tiles": tiles, "wild": wild, "peat_dug": peat_dug, "rocks": rocks, "opened": opened, "clutter": clutter,
		"field_ready": field_ready, "can_water": can_water, "raven_marks": raven_marks}


func deserialize(d: Dictionary) -> void:
	tiles = d.get("tiles", {}).duplicate(true)
	opened = {"beds": true, "field_nw": true, "field_ne": true, "field_s": true}
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
	clutter.clear()
	can_water = int(d.get("can_water", can_capacity()))
	raven_marks.clear()
	var saved_marks: Dictionary = d.get("raven_marks", {})
	for map_id in saved_marks:
		var marks: Array = []
		for m in saved_marks[map_id]:
			marks.append({"x": int(m["x"]), "y": int(m["y"])})
		raven_marks[str(map_id)] = marks
	field_ready = bool(d.get("field_ready", false))
	var saved_clutter: Dictionary = d.get("clutter", {})
	for key in saved_clutter:
		clutter[str(key)] = {"k": str(saved_clutter[key]["k"]), "hp": int(saved_clutter[key]["hp"])}
	# A save from before the field existed gets it overgrown.
	if not d.has("field_ready"):
		scatter_field()
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
