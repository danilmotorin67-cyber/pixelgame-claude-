extends Node

# The old beds beside the cape house: 10 columns by 6 rows of salt-free soil.
const WIDTH := 10
const HEIGHT := 6
var tiles: Dictionary = {}


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func get_tile(cell: Vector2i) -> Dictionary:
	return tiles.get(_key(cell), {}) if _valid(cell) else {}


func reset() -> void:
	tiles.clear()
	Events.farm_changed.emit()


func till(cell: Vector2i) -> bool:
	if not _valid(cell) or not get_tile(cell).is_empty():
		return false
	tiles[_key(cell)] = {"salt": 0, "fertility": 1, "watered": false,
		"crop": "", "days": 0, "ready": false}
	Events.farm_changed.emit()
	return true


func water(cell: Vector2i) -> bool:
	var tile := get_tile(cell)
	if tile.is_empty() or bool(tile["watered"]):
		return false
	tile["watered"] = true
	Events.farm_changed.emit()
	return true


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
		tile["ready"] = false
		Events.farm_changed.emit()
		return true
	return false


func harvest(cell: Vector2i) -> bool:
	var tile := get_tile(cell)
	if tile.is_empty() or not bool(tile["ready"]):
		return false
	var crop := Data.by_id("crops", str(tile["crop"]))
	if crop.is_empty() or Inventory.add(str(crop["produce"])) != 1:
		return false
	tile["crop"] = ""
	tile["days"] = 0
	tile["ready"] = false
	Events.crop_harvested.emit(str(crop["produce"]), 0)
	Events.farm_changed.emit()
	return true


func advance_day() -> void:
	for key in tiles:
		var tile: Dictionary = tiles[key]
		if str(tile["crop"]) != "":
			var crop := Data.by_id("crops", str(tile["crop"]))
			if crop.is_empty() or Clock.season not in crop.get("seasons", []):
				tile["crop"] = ""
				tile["days"] = 0
				tile["ready"] = false
			elif bool(tile["watered"]) and not bool(tile["ready"]):
				tile["days"] = int(tile["days"]) + 1
				var total := 0
				for length in crop.get("stage_days", []):
					total += int(length)
				tile["ready"] = int(tile["days"]) >= total
		tile["watered"] = Weather.current in ["rain", "storm"]
	Events.farm_changed.emit()


func serialize() -> Dictionary:
	return {"tiles": tiles}


func deserialize(d: Dictionary) -> void:
	tiles = d.get("tiles", {}).duplicate(true)
	for key in tiles:
		var tile: Dictionary = tiles[key]
		tile["salt"] = int(tile.get("salt", 0))
		tile["fertility"] = int(tile.get("fertility", 1))
		tile["days"] = int(tile.get("days", 0))
	Events.farm_changed.emit()
