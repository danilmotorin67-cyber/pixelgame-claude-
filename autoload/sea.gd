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


func reset() -> void:
	mercy = START_MERCY
	blessings.clear()
	boat = ""
	revealed.clear()
	gifts.clear()
	trash_mercy_today = 0.0


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
		var count := rng.randi_range(int(bounds[0]), int(bounds[1]))
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
		if mercy >= 40.0:
			var rare: Array = config.get("rare", ["sea_glass"])
			_place(placed, used, rng, columns, rng.randi_range(FAR_ROW, SHORE_ROWS - 1),
				str(rare[rng.randi_range(0, rare.size() - 1)]))
		gifts[map_id] = placed
	for entry in Lighthouse.pending_shore:
		var beach_id := str(entry["beach"])
		var columns: Array = config.get("beaches", {}).get(beach_id, {}).get("columns", [2, 60])
		if not gifts.has(beach_id):
			gifts[beach_id] = []
		_place(gifts[beach_id], {}, rng, columns, rng.randi_range(0, FAR_ROW - 1), str(entry["item"]))
	Lighthouse.pending_shore.clear()


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
	list.remove_at(index)
	if str(gift["item"]) == "trash":
		var config: Dictionary = Data.tables.get("forage", {})
		var bonus := minf(float(config.get("trash_mercy", 0.2)),
			float(config.get("trash_mercy_day", 2.0)) - trash_mercy_today)
		if bonus > 0.0:
			trash_mercy_today += bonus
			add_mercy(bonus)
	return true


func serialize() -> Dictionary:
	return {"mercy": mercy, "blessings": blessings, "boat": boat, "revealed": revealed,
		"gifts": gifts, "trash_mercy_today": trash_mercy_today}


func deserialize(d: Dictionary) -> void:
	mercy = clampf(float(d.get("mercy", START_MERCY)), 0.0, 100.0)
	blessings = d.get("blessings", [])
	boat = str(d.get("boat", ""))
	revealed = d.get("revealed", {})
	trash_mercy_today = float(d.get("trash_mercy_today", 0.0))
	gifts.clear()
	var saved: Dictionary = d.get("gifts", {})
	for map_id in saved:
		var list: Array = []
		for gift in saved[map_id]:
			list.append({"item": str(gift["item"]), "x": int(gift["x"]), "row": int(gift["row"])})
		gifts[map_id] = list
