class_name MapInfo

# One view of every walkable map for NPCs (33.7): sizes, exits between maps, named spots,
# blocked cells and a cached AStarGrid2D per map.
const TILE := 16
const SOLID := ["house", "hall", "smith", "tavern", "chapel", "ruin", "cave", "lake"]
const CAPE := {"title": "Вороний мыс", "size": [90, 70], "coast_row": 54,
	"exits": [{"at": [3, 30], "to": "village", "spawn": [76, 30]}]}

static var _grids: Dictionary = {}
static var _exits: Dictionary = {}


static func clear_cache() -> void:
	_grids.clear()
	_exits.clear()


static func region(id: String) -> Dictionary:
	if id == "cape":
		return CAPE
	var regions: Dictionary = Data.tables.get("regions", {})
	if regions.has(id):
		return regions[id]
	return Data.tables.get("interiors", {}).get(id, {})


static func exists(id: String) -> bool:
	return not region(id).is_empty()


static func is_interior(id: String) -> bool:
	return bool(region(id).get("interior", false))


static func size(id: String) -> Vector2i:
	var s: Array = region(id).get("size", [0, 0])
	return Vector2i(int(s[0]), int(s[1]))


static func door_of(landmark: Dictionary) -> Vector2i:
	var at: Array = landmark["at"]
	var s: Array = landmark["size"]
	return Vector2i(int(at[0]) + int(s[0]) / 2, int(at[1]) + int(s[1]))


# Region exits plus the doors of buildings with interiors, as {at, to, spawn} with Vector2i tiles.
static func exits(id: String) -> Array:
	if _exits.has(id):
		return _exits[id]
	var out: Array = []
	var info := region(id)
	for e in info.get("exits", []):
		out.append({"at": Vector2i(int(e["at"][0]), int(e["at"][1])), "to": str(e["to"]),
			"spawn": Vector2i(int(e["spawn"][0]), int(e["spawn"][1])), "label": str(e.get("label", e["to"]))})
	for lm in info.get("landmarks", []):
		if lm.has("interior"):
			var inside := region(str(lm["interior"]))
			var s := Vector2i(int(inside["size"][0]), int(inside["size"][1]))
			out.append({"at": door_of(lm), "to": str(lm["interior"]), "spawn": Vector2i(s.x / 2, s.y - 2),
				"label": str(lm["title"])})
	_exits[id] = out
	return out


static func landmark(id: String, key: String, value: String) -> Dictionary:
	for lm in region(id).get("landmarks", []):
		if str(lm.get(key, "")) == value:
			return lm
	return {}


# Named spots: places.json, the spots of an interior, "door:<interior>" and "home:<title>".
static func spot(map_id: String, name: String) -> Vector2i:
	if name.begins_with("door:"):
		var lm := landmark(map_id, "interior", name.substr(5))
		return door_of(lm) if not lm.is_empty() else Vector2i(-1, -1)
	if name.begins_with("home:"):
		var home := landmark(map_id, "title", name.substr(5))
		return door_of(home) if not home.is_empty() else Vector2i(-1, -1)
	var places: Dictionary = Data.tables.get("places", {}).get(map_id, {})
	var at: Variant = places.get(name, region(map_id).get("spots", {}).get(name, null))
	if at is Array:
		return Vector2i(int(at[0]), int(at[1]))
	return Vector2i(-1, -1)


static func _block_rect(grid: AStarGrid2D, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if grid.is_in_boundsv(Vector2i(xx, yy)):
				grid.set_point_solid(Vector2i(xx, yy), true)


static func grid(id: String) -> AStarGrid2D:
	if _grids.has(id):
		return _grids[id]
	var s := size(id)
	var g := AStarGrid2D.new()
	g.region = Rect2i(Vector2i.ZERO, s)
	g.cell_size = Vector2(TILE, TILE)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	g.update()
	var info := region(id)
	_block_rect(g, 0, 0, s.x, 1)
	_block_rect(g, 0, s.y - 1, s.x, 1)
	_block_rect(g, 0, 0, 1, s.y)
	_block_rect(g, s.x - 1, 0, 1, s.y)
	var coast := int(info.get("coast_row", -1))
	if coast >= 0:
		_block_rect(g, 0, coast, s.x, s.y - coast)
	for lm in info.get("landmarks", []):
		if str(lm.get("kind", "")) in SOLID:
			_block_rect(g, int(lm["at"][0]), int(lm["at"][1]), int(lm["size"][0]), int(lm["size"][1]))
	if str(info.get("biome", "")) == "birch":
		_block_rect(g, 12, 0, 5, 18)
		_block_rect(g, 12, 23, 5, s.y - 23)
	if bool(info.get("interior", false)):
		_block_rect(g, 0, 0, s.x, 1)
		for f in info.get("furniture", []):
			if not bool(f.get("walk", false)):
				_block_rect(g, int(f["at"][0]), int(f["at"][1]), int(f["size"][0]), int(f["size"][1]))
	# Every exit, door and named spot stays open.
	for e in exits(id):
		g.set_point_solid(e["at"], false)
	if bool(info.get("interior", false)):
		g.set_point_solid(Vector2i(s.x / 2, s.y - 2), false)
	for name in Data.tables.get("places", {}).get(id, {}):
		g.set_point_solid(spot(id, name), false)
	for name in info.get("spots", {}):
		g.set_point_solid(spot(id, name), false)
	_grids[id] = g
	return g


static func walkable(id: String, cell: Vector2i) -> bool:
	var g := grid(id)
	return g.is_in_boundsv(cell) and not g.is_point_solid(cell)


static func path(id: String, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var g := grid(id)
	if not g.is_in_boundsv(from) or not g.is_in_boundsv(to):
		return []
	var was_solid := g.is_point_solid(from)
	g.set_point_solid(from, false)
	var out := g.get_id_path(from, to)
	g.set_point_solid(from, was_solid)
	return out


# Maps to pass through, as the exits taken from `from` to reach `to` (breadth-first over the map graph).
static func route(from: String, to: String) -> Array:
	if from == to:
		return []
	var came: Dictionary = {from: {}}
	var queue: Array = [from]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for e in exits(current):
			var next := str(e["to"])
			if came.has(next) or not exists(next):
				continue
			came[next] = {"map": current, "exit": e}
			if next == to:
				var steps: Array = []
				var node := to
				while node != from:
					steps.push_front(came[node]["exit"])
					node = str(came[node]["map"])
				return steps
			queue.append(next)
	return []
