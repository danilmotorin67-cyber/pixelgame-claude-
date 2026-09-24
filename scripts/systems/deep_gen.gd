class_name DeepGen
extends RefCounted

# 17.2: a level of the Deep is 40×30 tiles — a 4×3 grid of 10×10 fragments of its biome, each fragment
# keeping its four gates open. Enemies, resources and the way down are placed by the level's seed.
# Levels 10/30/50 are treasuries, 20/40/60 boss arenas, 61+ the bottomless Deep (enemies +5% a level).
const W := 40
const H := 30
const FRAG := 10
const PASSABLE := ".rekunvdCSX<"


static func cfg(key: String) -> Variant:
	return Game.balance("deep", {}).get(key)


static func biome_for(level: int) -> Dictionary:
	for b in Data.all("deep_biomes"):
		if level >= int(b["levels"][0]) and level <= int(b["levels"][1]):
			return b
	return Data.by_id("deep_biomes", "bone_abyss")


static func _in(level: int, key: String) -> bool:
	for v in cfg(key):
		if int(v) == level:
			return true
	return false


static func is_boss(level: int) -> bool:
	return _in(level, "boss_levels")


static func is_treasury(level: int) -> bool:
	return _in(level, "treasure_levels")


static func has_station(level: int) -> bool:
	return level % int(cfg("stations_every")) == 0


static func boss_for(level: int) -> String:
	for b in Data.all("bosses"):
		if int(b["level"]) == level:
			return str(b["id"])
	return ""


static func passable(ch: String) -> bool:
	return ch != "#"


static func _pick(rng: RandomNumberGenerator, table: Array) -> String:
	var total := 0.0
	for row in table:
		total += float(row[1])
	var roll := rng.randf() * total
	for row in table:
		roll -= float(row[1])
		if roll <= 0.0:
			return str(row[0])
	return str(table[-1][0])


static func generate(level: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(seed_value * 2654435 + level * 97531, 2147483647)
	var biome := biome_for(level)
	var rows: Array = []
	if is_boss(level):
		rows = _arena(rng)
	else:
		for y in H:
			rows.append("")
		var frags: Array = biome["fragments"]
		for gy in 3:
			for gx in 4:
				var frag: Array = frags[rng.randi_range(0, frags.size() - 1)]
				for fy in FRAG:
					rows[gy * FRAG + fy] += str(frag[fy])
	# the outer rim is rock
	for y in H:
		var row: String = rows[y]
		if y == 0 or y == H - 1:
			row = "#".repeat(W)
		else:
			row = "#" + row.substr(1, W - 2) + "#"
		rows[y] = row
	var entry := _nearest_open(rows, Vector2i(4, 4))
	var dist := _bfs(rows, entry)
	# whatever the rim cut off becomes rock, so nothing is unreachable
	for y in H:
		var chars: PackedStringArray = str(rows[y]).split("")
		for x in W:
			if chars[x] != "#" and not dist.has(Vector2i(x, y)):
				chars[x] = "#"
		rows[y] = "".join(chars)
	var level_data := {"level": level, "biome": str(biome["id"]), "rows": rows, "entry": entry, "station": has_station(level),
		"resources": [], "enemies": [], "chests": [], "exit_kind": "debris", "boss": "", "exit": entry}
	if is_boss(level):
		level_data["boss"] = boss_for(level)
		level_data["exit_kind"] = "boss"
		level_data["exit"] = Vector2i(W / 2, H / 2)
		return level_data
	# the way down: the farthest open tile from the entry
	var far := entry
	for cell in dist:
		if int(dist[cell]) > int(dist.get(far, 0)):
			far = cell
	level_data["exit"] = far
	if is_treasury(level):
		level_data["exit_kind"] = "open"
	elif rng.randf() < float(cfg("locked_chance")):
		level_data["exit_kind"] = "locked"
	# resources and enemies on their marks
	var res_table: Array = biome["resources"].filter(func(r: Array) -> bool: return level >= int(r[2]) and level <= int(r[3]))
	var foe_table: Array = biome["enemies"].filter(func(r: Array) -> bool: return level >= int(r[2]))
	var foes_left := mini(4 + level / 5, 14)
	for y in H:
		for x in W:
			var cell := Vector2i(x, y)
			if cell == far or cell == entry or not dist.has(cell):
				continue
			var ch := str(rows[y])[x]
			match ch:
				"r":
					if is_treasury(level):
						if rng.randf() < 0.35:
							level_data["chests"].append({"x": x, "y": y})
					elif not res_table.is_empty() and rng.randf() < 0.7:
						level_data["resources"].append({"item": _pick(rng, res_table), "x": x, "y": y})
				"e":
					if not is_treasury(level) and foes_left > 0 and not foe_table.is_empty() and cell.distance_to(entry) > 6.0:
						level_data["enemies"].append({"kind": _pick(rng, foe_table), "x": x, "y": y})
						foes_left -= 1
				"u":
					if not is_treasury(level):
						level_data["enemies"].append({"kind": "urchin", "x": x, "y": y})
				"n":
					if not is_treasury(level) and rng.randf() < 0.4:
						level_data["enemies"].append({"kind": "net_trap", "x": x, "y": y})
				"v":
					if not is_treasury(level) and rng.randf() < 0.5:
						level_data["enemies"].append({"kind": "hot_vent", "x": x, "y": y})
	if level_data["chests"].is_empty() and is_treasury(level):
		level_data["chests"].append({"x": far.x, "y": far.y})
	if level == 55:
		level_data["chests"].append({"x": far.x, "y": far.y, "item": "grandma_anchor"})
	return level_data


static func _arena(rng: RandomNumberGenerator) -> Array:
	var rows: Array = []
	for y in H:
		var row := ""
		for x in W:
			var pillar := (x % 9 == 4 and y % 8 == 3) and absi(x - W / 2) > 3 and rng.randf() < 0.8
			row += "#" if pillar else "."
		rows.append(row)
	return rows


static func _nearest_open(rows: Array, near: Vector2i) -> Vector2i:
	for r in 20:
		for y in range(near.y - r, near.y + r + 1):
			for x in range(near.x - r, near.x + r + 1):
				if x > 0 and y > 0 and x < W - 1 and y < H - 1 and passable(str(rows[y])[x]):
					return Vector2i(x, y)
	return near


static func _bfs(rows: Array, from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or dist.has(n) or not passable(str(rows[n.y])[n.x]):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


# A reachable open cell halfway between the entry and the way down, for a story chest (n-th one shifts along).
static func story_cell(level_data: Dictionary, n: int) -> Vector2i:
	var dist := _bfs(level_data["rows"], level_data["entry"])
	var far := int(dist.get(level_data["exit"], 1))
	var want := maxi(2, far / 2 + n * 3)
	var best: Vector2i = level_data["exit"]
	var best_gap := 1 << 30
	for cell in dist:
		var gap := absi(int(dist[cell]) - want)
		if gap < best_gap and cell != level_data["exit"] and cell != level_data["entry"]:
			best = cell
			best_gap = gap
	return best


# "No dead ends": the exit, every resource, chest and foe can be reached from the entry.
static func check(level_data: Dictionary) -> Array:
	var problems: Array = []
	var dist := _bfs(level_data["rows"], level_data["entry"])
	if not dist.has(level_data["exit"]):
		problems.append("exit unreachable")
	for key in ["resources", "enemies", "chests"]:
		for thing in level_data[key]:
			if not dist.has(Vector2i(int(thing["x"]), int(thing["y"]))):
				problems.append("%s at %d,%d unreachable" % [key, int(thing["x"]), int(thing["y"])])
	return problems


static func walkable(level_data: Dictionary, at: Vector2) -> bool:
	var cell := Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
	if cell.x < 0 or cell.y < 0 or cell.x >= W or cell.y >= H:
		return false
	return passable(str(level_data["rows"][cell.y])[cell.x])
