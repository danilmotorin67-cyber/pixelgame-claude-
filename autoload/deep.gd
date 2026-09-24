extends Node

# A dive into the Deep (17.1-17.2): the current level, its fight, the air and the way down.
const BELL_RADIUS := 2.5
const TILE := 16.0

var active: bool = false
var level: int = 0
var data: Dictionary = {}
var world: CombatWorld
var air: float = 100.0
var detached: float = 0.0
var debris_broken: bool = false
var taken: Dictionary = {}
var boss_paid: bool = false


func cfg(key: String) -> Variant:
	return Game.balance("deep", {}).get(key)


func reset() -> void:
	active = false
	level = 0
	data.clear()
	world = null
	air = 100.0
	detached = 0.0
	taken.clear()


# What the keeper breathes with: gills, the suit (with the steam pump) or the bell (17.1).
func gear() -> String:
	if Game.effect("gills") > 0.0 or Game.flag("test_deep"):
		return "gills"
	if Inventory.count_of("diving_suit") > 0 or Game.flag("diving_suit"):
		return "suit"
	if Game.flag("diving_bell"):
		return "bell"
	return ""


func max_level() -> int:
	match gear():
		"gills":
			return 100000
		"suit":
			return 60 if Knowledge.unlocked.has("S11") else 40
		"bell":
			return 20
	return 0


func hose_radius() -> float:
	var hoses: Array = cfg("hose")
	var index := 2 if Knowledge.unlocked.has("S12b") else (1 if Knowledge.unlocked.has("S12") else 0)
	return float(hoses[index])


func air_max() -> float:
	var base := float(cfg("bell_air"))
	if Inventory.count_of("air_bag") > 0:
		base += float(cfg("air_bag"))
	if Knowledge.unlocked.has("S6"):
		base += 50.0
	base += Game.effect("air_flat")
	base *= 1.0 + Game.effect("air") + (0.5 if Skills.has_profession("whale_lungs") else 0.0)
	return base


# Bell stations every 5 levels (node S5): the dive can start from the deepest one reached.
func start_levels() -> Array:
	var out: Array = [1]
	if Knowledge.unlocked.has("S5") or Game.flag("test_deep"):
		var deepest := int(Game.counters.get("deep_station", 0))
		for lv in range(5, mini(deepest, max_level()) + 1, 5):
			out.append(lv)
	return out


func begin(from_level: int = 1) -> String:
	if max_level() <= 0:
		return "gear"
	if not Game.flag("test_deep") and (from_level not in start_levels() or from_level > max_level()):
		return "depth"
	level = from_level
	active = true
	taken.clear()
	_enter()
	return "ok"


func _enter() -> void:
	data = DeepGen.generate(level, Game.world_seed + Clock.day_index * 7919)
	world = CombatWorld.new(Game.world_seed * 31 + level, func(p: Vector2) -> bool: return DeepGen.walkable(data, p))
	world.underwater = true
	world.player["pos"] = cell_center(data["entry"])
	world.player["max_hp"] = 100.0 + 5.0 * float(Skills.level("diving")) + Game.effect("health")
	world.player["hp"] = world.player["max_hp"]
	for foe in data["enemies"]:
		world.spawn(str(foe["kind"]), cell_center(Vector2i(int(foe["x"]), int(foe["y"]))), level)
	if str(data["boss"]) != "":
		world.start_boss(str(data["boss"]), cell_center(data["exit"]))
	debris_broken = str(data["exit_kind"]) != "debris"
	boss_paid = false
	air = air_max()
	detached = 0.0
	var deepest := int(Game.counters.get("deep_max", 0))
	if level > deepest:
		Game.counters["deep_max"] = level
		Skills.add_xp("diving", 15)
		Knowledge.add_points("sea", 3 if level % 5 == 0 else 1)
	if DeepGen.has_station(level):
		Game.counters["deep_station"] = maxi(int(Game.counters.get("deep_station", 0)), level)


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + 8.0, cell.y * TILE + 8.0)


func level_key() -> String:
	return "%d" % level


func exit_open() -> bool:
	match str(data.get("exit_kind", "")):
		"debris":
			return debris_broken
		"locked":
			return world.hostile_count() == 0
		"boss":
			return world.boss_done()
	return true


# The rope down lies under debris: a gaff or a pickaxe breaks it (17.2).
func break_debris(tool_id: String) -> bool:
	if debris_broken or tool_id not in ["gaff_wood", "gaff_iron", "tool_pick"]:
		return false
	debris_broken = true
	Skills.add_xp("diving", 3)
	if randf() < 0.3 and Skills.has_profession("salvager"):
		Inventory.add("iron_scrap", 1)
	return true


func descend() -> String:
	if not active or not exit_open():
		return "closed"
	if level + 1 > max_level():
		return "depth"
	if str(data.get("exit_kind", "")) == "boss" and not boss_paid:
		world.boss_reward()
		boss_paid = true
	level += 1
	_enter()
	return "ok"


func surface() -> void:
	active = false
	world = null


# Resources lie on their tiles until taken (once per level per day).
func resource_at(cell: Vector2i) -> Dictionary:
	for r in data.get("resources", []):
		if int(r["x"]) == cell.x and int(r["y"]) == cell.y and not taken.has("%d:%d:%d" % [level, cell.x, cell.y]):
			return r
	return {}


func take_resource(cell: Vector2i) -> String:
	var r := resource_at(cell)
	if r.is_empty():
		return ""
	var item := str(r["item"])
	var count := 2 if item == "pearl_oyster" and Skills.has_profession("pearler") else 1
	if not Inventory.can_fit(item, count):
		return ""
	Inventory.add(item, count)
	taken["%d:%d:%d" % [level, cell.x, cell.y]] = true
	Skills.add_xp("diving", 3)
	if randf() < 0.3 and Skills.has_profession("salvager"):
		Inventory.add(item, 1)
	return item


func open_chest(cell: Vector2i) -> String:
	for c in data.get("chests", []):
		if int(c["x"]) == cell.x and int(c["y"]) == cell.y and not taken.has("c%d:%d:%d" % [level, cell.x, cell.y]):
			var item := str(c.get("item", "chest_deep"))
			if not Inventory.can_fit(item, 1):
				return ""
			Inventory.add(item, 1)
			taken["c%d:%d:%d" % [level, cell.x, cell.y]] = true
			return item
	return ""


# Air (17.1): the bell refills inside, the suit's hose is endless within its radius (60 s off it), gills need none.
func breathe(delta: float) -> void:
	var pos: Vector2 = world.player["pos"]
	var from_entry := pos.distance_to(cell_center(data["entry"])) / TILE
	match gear():
		"gills":
			air = air_max()
		"suit":
			if from_entry <= hose_radius():
				air = air_max()
				detached = 0.0
			else:
				detached += delta
				air = maxf(0.0, air_max() * (1.0 - detached / float(cfg("detach_seconds"))))
		_:
			if from_entry <= BELL_RADIUS:
				air = minf(air_max(), air + 20.0 * delta)
			else:
				air = maxf(0.0, air - float(cfg("air_per_sec")) * delta)


# One frame of the dive; returns "" or "passed_out".
func tick(delta: float, player_pos: Vector2) -> String:
	if not active:
		return ""
	world.player["pos"] = player_pos
	world.step(delta)
	breathe(delta)
	if air <= 0.0 or bool(world.player["down"]):
		pass_out()
		return "passed_out"
	return ""


# 8.5: up to three random stacks and 10% of the money (≤ 1 000); Erland hauls the keeper aboard.
func pass_out() -> Dictionary:
	var lost: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 11 + Clock.day_index * 7 + level, 2147483647)
	var candidates: Array = []
	for i in Inventory.capacity:
		var id := str(Inventory.slots[i]["id"])
		if id != "" and str(Data.by_id("items", id).get("category", "")) not in ["tool", "weapon", "quest"]:
			candidates.append(i)
	for n in mini(3, candidates.size()):
		var i: int = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		lost.append(str(Inventory.slots[i]["id"]))
		Inventory.take_slot(i, int(Inventory.slots[i]["count"]))
	var money := mini(int(floor(float(Economy.money) * 0.1)), 1000)
	Economy.add(-money)
	surface()
	return {"lost": lost, "money": money}


func serialize() -> Dictionary:
	return {"taken_day": Clock.day_index}


func deserialize(_d: Dictionary) -> void:
	reset()
