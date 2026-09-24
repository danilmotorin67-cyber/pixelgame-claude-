extends Node2D

# Six rows of 16px shoreline tiles bridge the permanent sea and dry ground.
# Each cell has its own elevation; only tiles crossing the tide threshold change collision.
const TILE := 16
const FIRST_ROW := 54
const ROWS := 6
const COLUMNS := 90
const DEEP := Color("#1b2b3c")
const WATER := Color("#24405a")
const WAVE := Color("#2f5a76")
const SHALLOW := Color("#3f7f8f")
const FOAM := Color("#cfe6e2")
const WET_SAND := Color("#8c6a4e")
const DRY_SAND := Color("#d8c49a")

var _cells: Array[Dictionary] = []
var _body: StaticBody2D
var _wave_seconds := 0.0
var _wave_frame := 0


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.name = "TideCollision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	var tile_shape := RectangleShape2D.new()
	tile_shape.size = Vector2(TILE, TILE)
	for row in ROWS:
		for column in COLUMNS:
			var shape := CollisionShape2D.new()
			shape.shape = tile_shape
			shape.position = Vector2(column * TILE + TILE / 2, (FIRST_ROW + row) * TILE + TILE / 2)
			shape.disabled = true
			_body.add_child(shape)
			var elevation := 1.25 - float(row) * 0.5 + sin(float(column) * 0.37) * 0.06
			_cells.append({"x": column * TILE, "y": (FIRST_ROW + row) * TILE,
				"z": elevation, "wet": false, "flooded": false, "shape": shape})
	Events.tide_changed.connect(_on_tide_changed)
	_on_tide_changed(Clock.tide_height())


func _process(delta: float) -> void:
	_wave_seconds += delta
	if _wave_seconds >= 0.22:
		_wave_seconds = fmod(_wave_seconds, 0.22)
		_wave_frame = (_wave_frame + 1) % 4
		queue_redraw()


func _on_tide_changed(height: float) -> void:
	for cell in _cells:
		var flooded: bool = height >= float(cell["z"])
		cell["wet"] = height >= float(cell["z"]) - 0.5
		if flooded != bool(cell["flooded"]):
			cell["flooded"] = flooded
			var shape: CollisionShape2D = cell["shape"]
			shape.set_deferred("disabled", not flooded)
	queue_redraw()


func _draw() -> void:
	# The permanent sea continues seamlessly from the changing tidal cells.
	draw_rect(Rect2(0, 960, 1440, 160), DEEP)
	for row in range(10):
		for column in range(COLUMNS):
			var sx := column * TILE
			var sy := 960 + row * TILE
			var current := (column * 73 + row * 131 + column * row * 17) % 101
			if current % 11 == 0:
				_px(sx + 2, sy + 3, 18 + current % 11, 2, WATER)
			if (current + _wave_frame) % 17 == 0:
				_px(sx + 4, sy + 7, 9 + current % 7, 1, WAVE)
				_px(sx + 8, sy + 8, 4, 1, SHALLOW)

	for cell in _cells:
		var x: int = cell["x"]
		var y: int = cell["y"]
		var column := x / TILE
		var row := (y / TILE) - FIRST_ROW
		var seed: int = (column * 73 + row * 131 + column * row * 17) % 997
		if cell["flooded"]:
			_px(x, y, TILE, TILE, WATER)
			if seed % 8 == 0:
				_px(x + 2, y + 9, 9 + seed % 5, 2, WAVE)
			if (seed + _wave_frame) % 15 == 0:
				_px(x + 3, y + 5, 8, 1, SHALLOW)
				_px(x + 6, y + 6, 3, 1, FOAM)
			if row == 0 or not _cells[(row - 1) * COLUMNS + column]["flooded"]:
				_foam_edge(x, y, seed)
		else:
			var wet: bool = cell["wet"]
			_px(x, y, TILE, TILE, WET_SAND if wet else DRY_SAND)
			if seed % 5 == 0:
				_px(x + 1 + seed % 4, y + 2 + seed % 5, 7, 1,
					Color("#b08f6c") if wet else Color("#eadcb8"))
			if seed % 7 == 2:
				_px(x + 8, y + 7 + seed % 3, 6, 1, Color("#6b4a33") if wet else WET_SAND)
			if seed % 13 == 0:
				_px(x + 3, y + 11, 4, 2, Color("#6c6e76"))
				_px(x + 3, y + 10, 2, 1, Color("#c9c8c2"))
			if row >= 3 and not wet and seed % 17 == 0:
				_px(x + 3, y + 6, 9, 5, WAVE)
				_px(x + 5, y + 7, 4, 1, SHALLOW)
			if row == ROWS - 1:
				_foam_edge(x, y + 14, seed)

	# A broken basalt lip separates the grass from the exposed shore.
	_px(0, 860, 1440, 4, Color("#45464e"))
	for column in COLUMNS:
		var x := column * TILE
		var seed := (column * 43 + column * column * 7) % 31
		if seed % 4 == 0:
			_px(x + 3, 857, 7 + seed % 6, 3, Color("#6c6e76"))
		if seed % 9 == 0:
			_px(x + 5, 856, 4, 2, Color("#c9c8c2"))


func _foam_edge(x: int, y: int, seed: int) -> void:
	_px(x, y, 16, 2, SHALLOW)
	_px(x + 1, y, 9 + seed % 6, 1, FOAM)
	_px(x + 3 + seed % 3, y + 2, 4, 1, FOAM)
	if seed % 4 == 0:
		_px(x + 11, y + 3, 2, 1, FOAM)


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
