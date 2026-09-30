extends Node2D

# Ground of the cape from the PixelLab tilesets of the current season: grass inside,
# bare rock round the edge, a sand strip by the water and worn paths between the
# house, the beacon, the garden gate and the road to the village.
const W := 90
const H := 70
const GRASS := 0
const ROCK := 1
const PATH := 2
const SAND := 3
const TERRAINS := {GRASS: "tiles_grass_path", ROCK: "tiles_grass_cliff", PATH: "tiles_grass_path", SAND: "tiles_grass_sand"}
const PATHS := [
	[Vector2(600, 344), Vector2(640, 292), Vector2(700, 262), Vector2(744, 262)],
	[Vector2(676, 280), Vector2(697, 300)],
	[Vector2(592, 348), Vector2(420, 400), Vector2(250, 470), Vector2(40, 488)],
]

var _corners := PackedInt32Array()


func _ready() -> void:
	add_to_group("terrain")
	_corners = corners()
	Events.season_changed.connect(func(_s: String) -> void: queue_redraw())


static func corners() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize((W + 1) * (H + 1))
	for vy in H + 1:
		for vx in W + 1:
			var at := Vector2(vx, vy) * WangGround.CELL
			var t := GRASS
			if vy >= 56:
				t = SAND
			elif vx < 5 or vx > 80 or vy < 5:
				t = ROCK
			if t != SAND and _near_path(at):
				t = PATH
			out[vy * (W + 1) + vx] = t
	return out


# What the feet meet at a point (footsteps): the tide wets the shore rows as TideShore floods them.
func surface_at(at: Vector2) -> String:
	var row := int(at.y / WangGround.CELL) - 54
	if row >= 0 and Clock.tide_height() >= 1.25 - float(row) * 0.5 + sin(float(int(at.x / WangGround.CELL)) * 0.37) * 0.06 - 0.5:
		return "water"
	var v := Vector2i((at / float(WangGround.CELL)).round())
	var t := _corners[clampi(v.y, 0, H) * (W + 1) + clampi(v.x, 0, W)] if not _corners.is_empty() else GRASS
	if t == SAND:
		return "sand"
	if t == ROCK:
		return "stone"
	return "snow" if Clock.season == "winter" else "grass"


static func _near_path(at: Vector2) -> bool:
	for line in PATHS:
		for i in line.size() - 1:
			if Geometry2D.get_closest_point_to_segment(at, line[i], line[i + 1]).distance_to(at) < 11.0:
				return true
	return false


func _draw() -> void:
	WangGround.draw(self, Vector2.ZERO, W, H, _corners, TERRAINS, Clock.season)
	# A few low fence posts and a gate make the garden legible from above.
	for x in range(661, 853, 16):
		if x > 681 and x < 714:
			continue
		_px(x, 290, 3, 16, Color("#6b4a33"))
		_px(x + 1, 290, 1, 2, Color("#d8c49a"))
	_px(659, 296, 24, 2, Color("#b08f6c"))
	_px(714, 296, 140, 2, Color("#b08f6c"))


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
