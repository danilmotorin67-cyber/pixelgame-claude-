extends Node2D

const TILE := 16
const GRASS := Color("#566c4e")
const MEADOW := Color("#708354")
const HEATHER := Color("#71647b")
const SAND := Color("#a9977a")
const WET_SAND := Color("#7d7168")
const ROCK := Color("#777c82")
const WATER := Color("#294f63")
const FOAM := Color("#c4c4ab")
const ROAD := Color("#988873")
const ROOF := Color("#665353")
const ICE := Color("#b7c9d0")

var region: Dictionary = {}
var width: int = 0
var height: int = 0
var coast_row: int = -1
var biome: String = ""
var _shore_shapes: Array[CollisionShape2D] = []
var _shore_flooded: Array[bool] = []
var _bounds: StaticBody2D
var _water_body: StaticBody2D
var _deep_shape: CollisionShape2D


func _ready() -> void:
	region = MapInfo.region(Router.current_map)
	if region.is_empty():
		push_error("Unknown island region: %s" % Router.current_map)
		return
	var dimensions: Array = region["size"]
	width = int(dimensions[0])
	height = int(dimensions[1])
	coast_row = int(region.get("coast_row", -1))
	biome = str(region["biome"])
	_bounds = StaticBody2D.new()
	_bounds.name = "WorldBounds"
	_bounds.collision_layer = 1
	_bounds.collision_mask = 0
	add_child(_bounds)
	_add_wall(Vector2(width * TILE / 2, 8), Vector2(width * TILE, 16))
	_add_wall(Vector2(width * TILE / 2, height * TILE - 8), Vector2(width * TILE, 16))
	_add_wall(Vector2(8, height * TILE / 2), Vector2(16, height * TILE))
	_add_wall(Vector2(width * TILE - 8, height * TILE / 2), Vector2(16, height * TILE))
	_build_coast()
	_build_landmarks()
	if bool(region.get("interior", false)):
		_build_furniture()
	_build_exits()
	Events.tide_changed.connect(_on_tide_changed)
	_on_tide_changed(Clock.tide_height())


func _add_wall(at: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = at
	_bounds.add_child(collision)


func _build_coast() -> void:
	if coast_row < 0:
		return
	_water_body = StaticBody2D.new()
	_water_body.collision_layer = 1
	_water_body.collision_mask = 0
	_water_body.name = "CoastalWater"
	add_child(_water_body)
	var shore_shape := RectangleShape2D.new()
	shore_shape.size = Vector2(TILE, TILE)
	for y in range(coast_row, mini(coast_row + 6, height)):
		for x in width:
			var cell := CollisionShape2D.new()
			cell.shape = shore_shape
			cell.position = Vector2(x * TILE + TILE / 2, y * TILE + TILE / 2)
			cell.disabled = true
			_water_body.add_child(cell)
			_shore_shapes.append(cell)
			_shore_flooded.append(false)
	var deep_start := coast_row + 6
	if deep_start < height:
		var deep_shape := RectangleShape2D.new()
		deep_shape.size = Vector2(width * TILE, (height - deep_start) * TILE)
		var deep := CollisionShape2D.new()
		deep.shape = deep_shape
		deep.position = Vector2(width * TILE / 2, (height + deep_start) * TILE / 2)
		_water_body.add_child(deep)
		_deep_shape = deep


func _build_landmarks() -> void:
	for item in region.get("landmarks", []):
		var title := Label.new()
		title.text = str(item["title"])
		title.add_theme_font_size_override("font_size", 9)
		title.add_theme_color_override("font_color", Color("#f0e7cc"))
		var pos: Array = item["at"]
		title.position = Vector2(float(pos[0] * TILE), float(pos[1] * TILE - 16))
		title.z_index = 2
		add_child(title)
		var kind := str(item["kind"])
		if kind in ["house", "hall", "smith", "tavern", "chapel", "ruin", "cave"]:
			var dimensions: Array = item["size"]
			_add_wall(Vector2((float(pos[0]) + float(dimensions[0]) / 2.0) * TILE,
				(float(pos[1]) + float(dimensions[1]) / 2.0) * TILE),
				Vector2((int(dimensions[0]) - 1) * TILE, (int(dimensions[1]) - 1) * TILE))
		if kind == "lake":
			var dimensions: Array = item["size"]
			_add_wall(Vector2((float(pos[0]) + float(dimensions[0]) / 2.0) * TILE,
				(float(pos[1]) + float(dimensions[1]) / 2.0) * TILE),
				Vector2(int(dimensions[0]) * TILE, int(dimensions[1]) * TILE))
		if item.has("interior") or bool(item.get("home", false)):
			_add_door(item)
	if Router.current_map == "seal_shore":
		var mouth := GrottoEntrance.new()
		mouth.name = "GrottoEntrance"
		mouth.position = Grotto.ENTRANCE - Vector2(0, 16)
		add_child(mouth)
	if biome == "village" and coast_row > 0:
		var box := ShippingBox.new()
		box.name = "ShippingBox"
		box.position = Vector2(30 * TILE + 8, (coast_row - 2) * TILE + 8)
		add_child(box)
	if biome == "birch":
		# A narrow plank crossing at y=20 keeps both sides of the grove connected.
		_add_wall(Vector2(14 * TILE, 9 * TILE), Vector2(5 * TILE, 18 * TILE))
		_add_wall(Vector2(14 * TILE, 31 * TILE), Vector2(5 * TILE, 18 * TILE))


# Doors of 33.7: a building with an interior leads inside; a home stays locked.
func _add_door(item: Dictionary) -> void:
	var door := MapInfo.door_of(item)
	var exit_node := RegionExit.new()
	exit_node.position = Vector2((door.x + 0.5) * TILE, (door.y + 0.5) * TILE - 4.0)
	exit_node.display_name = str(item["title"])
	exit_node.collision_layer = 8
	exit_node.collision_mask = 0
	if item.has("interior"):
		var inside := MapInfo.size(str(item["interior"]))
		exit_node.destination = str(item["interior"])
		exit_node.arrival = Vector2((inside.x / 2 + 0.5) * TILE, (inside.y - 2 + 0.5) * TILE)
		exit_node.name = "Door_" + exit_node.destination
	else:
		exit_node.name = "Home_" + str(item["title"]).replace(" ", "_")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	collision.shape = shape
	exit_node.add_child(collision)
	add_child(exit_node)


const FURNITURE_COLORS := {"bar": "#5b3a26", "counter": "#6e4b33", "table": "#7a5a3c", "pew": "#5a4030", "altar": "#d8d0bc",
	"shelf": "#4e3a2a", "barrel": "#6a4a2e", "fireplace": "#3a302c", "forge": "#2e2624", "anvil": "#3d4146", "desk": "#6a4c34",
	"bed": "#8c7a6a", "workbench": "#7a5a3a", "coffin": "#4a3426", "boat": "#5c4a3a", "nets": "#8a8466", "loom": "#7a5c44",
	"hay": "#c9ad5a", "herbs": "#5d7a4a", "safe": "#3a3a40", "crates": "#8a6a44", "telegraph": "#4a4a4a", "stairs": "#5e4a3a",
	"candles": "#e8d8a0", "board": "#8a7050"}


func _build_furniture() -> void:
	for f in region.get("furniture", []):
		var at := Vector2(float(f["at"][0]), float(f["at"][1])) * TILE
		var dims := Vector2(float(f["size"][0]), float(f["size"][1])) * TILE
		if not bool(f.get("walk", false)) and not bool(f.get("hidden", false)):
			_add_wall(at + dims / 2.0, dims - Vector2(2, 2))
		if f.has("shop"):
			var counter := ShopCounter.new()
			counter.name = "Shop_" + str(f["shop"])
			counter.shop_id = str(f["shop"])
			counter.position = at + Vector2(dims.x / 2.0, dims.y + 8.0)
			add_child(counter)
		if f.has("board"):
			var notice := NoticeBoard.new()
			notice.name = "Board_" + str(f["board"])
			notice.board = str(f["board"])
			notice.position = at + dims / 2.0
			add_child(notice)
		if bool(f.get("directorate", false)):
			var desk := DirectorateDesk.new()
			desk.name = "Directorate"
			desk.position = at + Vector2(dims.x / 2.0, dims.y + 8.0)
			add_child(desk)


func _build_exits() -> void:
	for info in region.get("exits", []):
		var exit_node := RegionExit.new()
		var at: Array = info["at"]
		var spawn: Array = info["spawn"]
		exit_node.position = Vector2((int(at[0]) + 0.5) * TILE, (int(at[1]) + 0.5) * TILE)
		exit_node.destination = str(info["to"])
		exit_node.arrival = Vector2((int(spawn[0]) + 0.5) * TILE, (int(spawn[1]) + 0.5) * TILE)
		exit_node.display_name = str(info["label"])
		exit_node.gate_day_index = int(info.get("day", 0))
		exit_node.needs_bridge = bool(info.get("bridge", false))
		exit_node.collision_layer = 8
		exit_node.collision_mask = 0
		exit_node.name = "To_" + exit_node.destination
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(36, 36)
		collision.shape = shape
		exit_node.add_child(collision)
		var marker := ColorRect.new()
		marker.color = Color("#d9b875")
		marker.position = Vector2(-8, -8)
		marker.size = Vector2(16, 16)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		exit_node.add_child(marker)
		var nameplate := Label.new()
		nameplate.text = str(MapInfo.region(str(info["to"])).get("title", info["label"])) if bool(region.get("interior", false)) else str(info["label"])
		nameplate.position = Vector2(-38, -32)
		nameplate.add_theme_font_size_override("font_size", 9)
		nameplate.add_theme_color_override("font_color", Color("#f0e7cc"))
		exit_node.add_child(nameplate)
		add_child(exit_node)


func _elevation(x: int, y: int) -> float:
	return 1.25 - float(y - coast_row) * 0.5 + sin(float(x) * 0.37) * 0.06


func _lagoon_frozen() -> bool:
	return biome == "lagoon" and Clock.season == "winter" and Clock.day >= 5 and Clock.day <= 25


func _on_tide_changed(level: float) -> void:
	if coast_row < 0:
		return
	var frozen := _lagoon_frozen()
	if _deep_shape:
		_deep_shape.set_deferred("disabled", frozen)
	var i := 0
	for y in range(coast_row, mini(coast_row + 6, height)):
		for x in width:
			var flooded := not frozen and level >= _elevation(x, y)
			if flooded != _shore_flooded[i]:
				_shore_flooded[i] = flooded
				_shore_shapes[i].set_deferred("disabled", not flooded)
			i += 1
	queue_redraw()


func _tile_color(x: int, y: int) -> Color:
	if bool(region.get("interior", false)):
		if y == 0 or x == 0 or x == width - 1 or (y == height - 1 and x != width / 2):
			return Color(str(region.get("wall", "#4a3e3c")))
		return Color(str(region.get("floor", "#6b5646"))).darkened(0.06 if (x + y) % 2 == 0 else 0.0)
	if coast_row >= 0:
		if y >= coast_row + 6:
			return ICE if _lagoon_frozen() else WATER
		if y >= coast_row:
			if _lagoon_frozen():
				return ICE
			if Clock.tide_height() >= _elevation(x, y):
				return WATER
			return WET_SAND if Clock.tide_height() >= _elevation(x, y) - 0.5 else SAND
	if biome == "birch" and x >= 12 and x < 17 and (y < 18 or y > 22):
		return WATER
	if biome in ["village", "moor"] and (abs(x - width / 2) <= 1 or abs(y - height / 2) <= 1):
		return ROAD
	if biome == "beach":
		return SAND
	if biome == "moor":
		return HEATHER
	if biome == "cliffs":
		return ROCK
	if biome == "village":
		return MEADOW
	if Clock.season == "winter":
		return Color("#c4cbc4")
	return GRASS


func _draw() -> void:
	if region.is_empty():
		return
	for y in height:
		for x in width:
			var px := x * TILE
			var py := y * TILE
			var color := _tile_color(x, y)
			draw_rect(Rect2(px, py, TILE, TILE), color)
			var grain := posmod(x * 191 + y * 79 + int(Game.world_seed), 17)
			if color == WATER:
				if grain <= 2:
					draw_rect(Rect2(px + 2, py + 5, 5, 1), FOAM.darkened(0.25))
			elif color == ICE:
				if grain == 1:
					draw_rect(Rect2(px + 3, py + 5, 9, 1), Color("#e1e6df"))
			elif color == GRASS or color == MEADOW or color == HEATHER:
				if grain <= 3:
					draw_rect(Rect2(px + 4, py + 7, 2, 3),
						Color("#9eae77") if color != HEATHER else Color("#ae8dad"))
				if biome == "birch" and grain <= 2 and color == GRASS:
					draw_rect(Rect2(px + 7, py + 6, 2, 9), Color("#e4d9bd"))
					draw_rect(Rect2(px + 3, py + 2, 10, 6), Color("#7b9969"))
			elif color == SAND and grain == 1:
				draw_rect(Rect2(px + 9, py + 10, 2, 1), WET_SAND)
			elif color == ROCK and grain <= 3:
				draw_rect(Rect2(px + 2, py + 4, 7, 1), Color("#a4a1a1"))
	for item in region.get("landmarks", []):
		_draw_landmark(item)
	for f in region.get("furniture", []):
		if bool(f.get("hidden", false)):
			continue
		var color := Color(str(FURNITURE_COLORS.get(str(f["kind"]), "#6b5040")))
		var rect := Rect2(float(f["at"][0]) * TILE + 1, float(f["at"][1]) * TILE + 1, float(f["size"][0]) * TILE - 2, float(f["size"][1]) * TILE - 2)
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), color.lightened(0.2))
		if str(f["kind"]) in ["fireplace", "forge"]:
			draw_rect(Rect2(rect.position + Vector2(3, rect.size.y - 8), Vector2(rect.size.x - 6, 5)), Color("#e07a2e"))


func _draw_landmark(item: Dictionary) -> void:
	var at: Array = item["at"]
	var dimensions: Array = item["size"]
	var x := int(at[0]) * TILE
	var y := int(at[1]) * TILE
	var w := int(dimensions[0]) * TILE
	var h := int(dimensions[1]) * TILE
	var kind := str(item["kind"])
	if kind in ["house", "hall", "smith", "tavern", "chapel", "ruin"]:
		var wall := Color("#938579")
		if kind == "smith":
			wall = Color("#746965")
		elif kind == "ruin":
			wall = Color("#66696c")
		draw_rect(Rect2(x, y + 10, w, h - 10), wall)
		draw_rect(Rect2(x - 3, y, w + 6, 13), ROOF if kind != "chapel" else Color("#70848c"))
		for window_x in range(x + 12, x + w - 8, 24):
			draw_rect(Rect2(window_x, y + 23, 6, 6), Color("#dbc77d"))
		draw_rect(Rect2(x + w / 2 - 5, y + h - 13, 10, 13), Color("#4a3e3c"))
	elif kind == "lake" or kind == "stream":
		draw_rect(Rect2(x, y, w, h), WATER)
		for offset in range(8, w - 5, 24):
			draw_rect(Rect2(x + offset, y + 12, 6, 1), FOAM)
		if kind == "stream":
			draw_rect(Rect2(x - 3, 18 * TILE, w + 6, 5 * TILE), Color("#a99670"))
	elif kind == "stones":
		for n in 9:
			var angle := TAU * float(n) / 9.0
			var sx := x + w / 2 + int(cos(angle) * w * 0.34)
			var sy := y + h / 2 + int(sin(angle) * h * 0.34)
			draw_rect(Rect2(sx - 4, sy - 8, 8, 16), Color("#b1ada2"))
	elif kind == "cave":
		draw_rect(Rect2(x, y, w, h), ROCK.darkened(0.25))
		draw_rect(Rect2(x + 16, y + 8, w - 32, h - 8), Color("#252735"))
	elif kind == "wreck":
		draw_rect(Rect2(x, y + h / 2, w, 12), Color("#654c40"))
		draw_line(Vector2(x + w / 2, y + h / 2), Vector2(x + w / 2, y), FOAM, 2.0)
	elif kind == "pier":
		draw_rect(Rect2(x, y, w, h), Color("#6e5144"))
	elif kind == "bog" or kind == "reeds":
		draw_rect(Rect2(x, y, w, h), Color("#5b6750"))
		for offset in range(4, w, 9):
			draw_rect(Rect2(x + offset, y + 6 + offset % 13, 2, 9), Color("#a3aa6e"))
	elif kind == "nests":
		for n in 5:
			draw_rect(Rect2(x + 12 + n * 23, y + 16 + n % 2 * 22, 10, 5), FOAM)
	elif kind == "cliff":
		draw_rect(Rect2(x, y, w, h), Color("#555a62"))
		draw_line(Vector2(x + w / 2, y), Vector2(x + w / 2 - 12, y + h), FOAM, 2.0)
	elif kind == "clearing":
		draw_rect(Rect2(x, y, w, h), MEADOW)
