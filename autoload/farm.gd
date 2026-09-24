extends Node

# The old beds beside the cape house: 10 columns by 6 rows of salt-free soil (13.1).
const WIDTH := 10
const HEIGHT := 6
const MAX_SALT := 2
const MAX_FERTILITY := 3
const STORM_STAGE_LOSS := 0.15
const HARVEST_FERTILITY_LOSS := 0.25
var tiles: Dictionary = {}
var last_harvest: Dictionary = {}


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func _season_key() -> int:
	return Clock.day_index / Clock.DAYS_PER_SEASON


func _rng(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 92821 + Clock.day_index * 7703 + cell.x * 131 + cell.y * 17 + salt,
		2147483647)
	return rng


func get_tile(cell: Vector2i) -> Dictionary:
	return tiles.get(_key(cell), {}) if _valid(cell) else {}


func reset() -> void:
	tiles.clear()
	Events.farm_changed.emit()


func till(cell: Vector2i) -> bool:
	if not _valid(cell) or not get_tile(cell).is_empty():
		return false
	tiles[_key(cell)] = {"salt": 0, "fertility": 1, "watered": false, "crop": "", "days": 0,
		"growth": 0.0, "ready": false, "amended": {}, "guano_season": -1, "flawless_bonus": 0.0}
	Events.farm_changed.emit()
	return true


func water(cell: Vector2i) -> bool:
	var tile := get_tile(cell)
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


func plant(cell: Vector2i, seed_id: String) -> bool:
	var tile := get_tile(cell)
	if tile.is_empty() or str(tile["crop"]) != "":
		return false
	for crop in Data.all("crops"):
		if str(crop.get("seed", "")) != seed_id:
			continue
		if Clock.season not in crop.get("seasons", []) or int(tile["salt"]) > int(crop.get("salt", 0)):
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
func amend(cell: Vector2i, item_id: String) -> String:
	var tile := get_tile(cell)
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


func harvest(cell: Vector2i) -> bool:
	var tile := get_tile(cell)
	if tile.is_empty() or not bool(tile["ready"]):
		return false
	var crop := Data.by_id("crops", str(tile["crop"]))
	if crop.is_empty():
		return false
	var rng := _rng(cell, 401)
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
	Events.crop_harvested.emit(produce, quality)
	Events.farm_changed.emit()
	return true


func _clear_crop(tile: Dictionary) -> void:
	tile["crop"] = ""
	tile["days"] = 0
	tile["growth"] = 0.0
	tile["ready"] = false


# Night step 3: growth, reset watering, storm damage, rain on the new day.
func advance_day(storm_night: bool = false) -> void:
	for key in tiles:
		var tile: Dictionary = tiles[key]
		var cell := Vector2i(int(key.get_slice(",", 0)), int(key.get_slice(",", 1)))
		if str(tile["crop"]) != "":
			var crop := Data.by_id("crops", str(tile["crop"]))
			if crop.is_empty() or Clock.season not in crop.get("seasons", []):
				_clear_crop(tile)
			else:
				if storm_night and not bool(tile["ready"]) and _rng(cell, 911).randf() < STORM_STAGE_LOSS:
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
					var speed := 1.10 if fert >= 3 else (1.05 if fert == 2 else 1.0)
					tile["days"] = int(tile["days"]) + 1
					tile["growth"] = float(tile["growth"]) + speed
					tile["ready"] = float(tile["growth"]) >= float(total_days(crop)) - 0.001
		tile["watered"] = Weather.current in ["rain", "storm"]
	Events.farm_changed.emit()


func serialize() -> Dictionary:
	return {"tiles": tiles}


func deserialize(d: Dictionary) -> void:
	tiles = d.get("tiles", {}).duplicate(true)
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
