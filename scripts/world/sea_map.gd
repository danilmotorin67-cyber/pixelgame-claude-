extends Node2D

const TILE := 16
const DEEP := Color("#1b2b3c")
const WATER := Color("#24405a")
const WAVE := Color("#2f5a76")
const FOAM := Color("#cfe6e2")
const ROCK := Color("#45464e")

var width: int = 120
var height: int = 90
var _barrier: CollisionShape2D
var _t: float = 0.0


func _ready() -> void:
	var size: Array = SeaChart.cfg("size")
	width = int(size[0])
	height = int(size[1])
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var coast := int(SeaChart.cfg("coast_rows"))
	_wall(walls, Vector2(width * TILE / 2.0, coast * TILE / 2.0), Vector2(width * TILE, coast * TILE))
	_wall(walls, Vector2(width * TILE / 2.0, height * TILE + 8), Vector2(width * TILE, 16))
	_wall(walls, Vector2(-8, height * TILE / 2.0), Vector2(16, height * TILE))
	_wall(walls, Vector2(width * TILE + 8, height * TILE / 2.0), Vector2(16, height * TILE))
	for reef in SeaChart.cfg("reefs"):
		_wall(walls, Vector2(int(reef[0]) * TILE + 8, int(reef[1]) * TILE + 8), Vector2(14, 12))
	for place in ["eider_isle", "dead_fire"]:
		_wall(walls, SeaChart.place_pos(place), Vector2(48, 32))
	var zone_row := int(SeaChart.cfg("zone2_row"))
	_barrier = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width * TILE, 16)
	_barrier.shape = shape
	_barrier.position = Vector2(width * TILE / 2.0, zone_row * TILE - 8)
	_barrier.disabled = int(SeaChart.boat_info().get("zones", 1)) >= 2
	walls.add_child(_barrier)
	var barrier3 := CollisionShape2D.new()
	var shape3 := RectangleShape2D.new()
	shape3.size = Vector2(width * TILE, 16)
	barrier3.shape = shape3
	barrier3.position = Vector2(width * TILE / 2.0, int(SeaChart.cfg("zone3_row")) * TILE - 8)
	barrier3.disabled = int(SeaChart.boat_info().get("zones", 1)) >= 3
	walls.add_child(barrier3)
	_wall(walls, SeaChart.place_pos("nameless_isle"), Vector2(64, 40))
	if Clock.season == "winter" and Inventory.count_of("icebreaker_bow") <= 0:
		# 16.5: icebergs ring the ice field in winter; the icebreaker bow cuts through thin ice.
		var field := SeaChart.place_pos("ice_field")
		for i in 8:
			_wall(walls, field + Vector2.from_angle(i * TAU / 8.0) * 90.0, Vector2(28, 20))
	var dock: Array = SeaChart.cfg("dock")
	var exit_node := RegionExit.new()
	exit_node.name = "To_cape"
	exit_node.destination = "cape"
	var landing: Array = SeaChart.cfg("cape_landing")
	exit_node.arrival = Vector2(float(landing[0]), float(landing[1]))
	exit_node.position = Vector2(int(dock[0]) * TILE + 8, (int(dock[1]) - 1) * TILE + 8)
	exit_node.collision_layer = 8
	exit_node.collision_mask = 0
	var collision := CollisionShape2D.new()
	var exit_shape := RectangleShape2D.new()
	exit_shape.size = Vector2(40, 30)
	collision.shape = exit_shape
	exit_node.add_child(collision)
	add_child(exit_node)
	var garden := Node2D.new()
	garden.name = "SeaGarden"
	add_child(garden)
	rebuild_garden()
	var events := Node2D.new()
	events.name = "SeaEvents"
	add_child(events)
	Sea.roll_outing()
	rebuild_events()
	var well := DeepEntrance.new()
	well.name = "DrownedWell"
	var well_at: Array = SeaChart.cfg("drowned_well")
	well.position = Vector2(int(well_at[0]) * TILE + 8, int(well_at[1]) * TILE + 8)
	add_child(well)
	var buoy := RestPlaceBuoy.new()
	buoy.name = "RestPlace"
	buoy.position = SeaChart.place_pos("rest_place")
	add_child(buoy)


func rebuild_events() -> void:
	var layer := get_node_or_null("SeaEvents")
	if layer == null:
		return
	for child in layer.get_children():
		child.queue_free()
	for ev in Sea.outing:
		var node := SeaEventObject.new()
		node.entry = ev
		node.position = Vector2(float(ev["x"]), float(ev["y"]))
		layer.add_child(node)
	if Sea.outing.any(func(e: Dictionary) -> bool: return str(e["id"]) == "squall"):
		var hint := get_parent().get_node_or_null("HUD/Hint") as Label
		if hint:
			hint.text = Loc.t("sea_event.squall")


func rebuild_garden() -> void:
	var layer := get_node_or_null("SeaGarden")
	if layer == null:
		return
	for child in layer.get_children():
		child.free()
	for g in Sea.sea_garden:
		var node := SeaGardenObject.new()
		node.entry = g
		node.position = Vector2(int(g["x"]) * TILE + 8, int(g["y"]) * TILE + 8)
		layer.add_child(node)


func _wall(body: StaticBody2D, at: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	body.add_child(collision)


func _process(delta: float) -> void:
	_t += delta
	# The water tiles follow the camera, so the sea redraws every frame.
	queue_redraw()


# The part of the sea the camera sees, in cells, with a margin.
func _visible_cells() -> Rect2i:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2i(0, 0, width, height)
	var half := get_viewport_rect().size / cam.zoom / 2.0
	var c := cam.get_screen_center_position()
	var a := Vector2i(floori((c.x - half.x) / TILE) - 2, floori((c.y - half.y) / TILE) - 2)
	var b := Vector2i(ceili((c.x + half.x) / TILE) + 2, ceili((c.y + half.y) / TILE) + 2)
	return Rect2i(a, b - a)


# The water by zone in the game's palette: near water, beyond the Teeth, the open sea; each border is
# dithered over one row, and short crests drift across the visible part.
const ZONE_COLORS := [Color("#2f6f80"), Color("#24405a"), Color("#1b2b3c")]


func _draw_water() -> bool:
	var view := _visible_cells()
	var rows := [0, int(SeaChart.cfg("zone2_row")), int(SeaChart.cfg("zone3_row")), height]
	var left := view.position.x * TILE
	var span := view.size.x * TILE
	draw_rect(Rect2(left, view.position.y * TILE, span, view.size.y * TILE), ZONE_COLORS[2])
	for z in 3:
		var top := maxi(int(rows[z]), view.position.y)
		var bottom := mini(int(rows[z + 1]), view.end.y)
		if bottom > top:
			draw_rect(Rect2(left, top * TILE, span, (bottom - top) * TILE), ZONE_COLORS[z])
		# Dither the border row into the next zone.
		if z < 2 and rows[z + 1] >= view.position.y and rows[z + 1] <= view.end.y:
			var y0: int = int(rows[z + 1]) * TILE - 8
			for x in range(left, left + span, 4):
				for dy in range(0, 16, 4):
					if (x / 4 + dy / 4) % 2 == 0:
						draw_rect(Rect2(x, y0 + dy, 4, 4), ZONE_COLORS[z + 1] if dy < 8 else ZONE_COLORS[z])
	var crest := Color(0.8, 0.93, 0.95, 0.35)
	for i in 420:
		var x := (i * 97 + int(_t * 6.0) * (1 + i % 3)) % (width * TILE)
		var y := (i * 53) % (height * TILE)
		if not view.has_point(Vector2i(x / TILE, y / TILE)):
			continue
		var phase := fmod(_t * 0.8 + i * 0.37, 3.0)
		if phase < 2.0:
			var w := 3 + i % 4
			draw_rect(Rect2(x, y, w, 1), crest)
			draw_rect(Rect2(x + 1, y - 1, w - 2, 1), Color(crest, 0.18))
	return true


func _draw() -> void:
	if _draw_water():
		_draw_sea_art()
		return
	draw_rect(Rect2(-400, -400, width * TILE + 800, height * TILE + 800), DEEP)
	draw_rect(Rect2(0, 0, width * TILE, height * TILE), WATER)
	var zone_row := int(SeaChart.cfg("zone2_row"))
	draw_rect(Rect2(0, zone_row * TILE, width * TILE, (height - zone_row) * TILE), DEEP)
	var zone3 := int(SeaChart.cfg("zone3_row"))
	draw_rect(Rect2(0, zone3 * TILE, width * TILE, (height - zone3) * TILE), DEEP.darkened(0.25))
	var patch := SeaGarden.area()
	draw_rect(Rect2(Vector2(patch.position) * TILE, Vector2(patch.size) * TILE), Color(0.9, 0.8, 0.5, 0.18), false, 1.0)
	if Clock.season == "winter":
		var field := SeaChart.place_pos("ice_field")
		draw_circle(field, 110.0, Color(0.85, 0.9, 0.95, 0.35))
		for i in 8:
			draw_rect(Rect2(field + Vector2.from_angle(i * TAU / 8.0) * 90.0 - Vector2(14, 10), Vector2(28, 20)), Color("#dfe9ea"))
	var isle_n := SeaChart.place_pos("nameless_isle")
	draw_rect(Rect2(isle_n - Vector2(32, 20), Vector2(64, 40)), Color("#5e6a4e"))
	var fairway := SeaChart.place_pos("fairway")
	for x in range(0, width * TILE, 40):
		draw_rect(Rect2(x, fairway.y, 20, 2), Color(0.9, 0.9, 0.7, 0.3))
	var frame := int(_t * 4.0)
	for i in 260:
		var x := (i * 97) % (width * TILE)
		var y := (i * 53 + frame * 3) % (height * TILE)
		draw_rect(Rect2(x, y, 6 + i % 5, 1), WAVE)
	var coast := int(SeaChart.cfg("coast_rows"))
	draw_rect(Rect2(0, 0, width * TILE, coast * TILE - 12), Color("#4e6e3a"))
	draw_rect(Rect2(0, coast * TILE - 12, width * TILE, 12), Color("#d8c49a"))
	for x in range(0, width * TILE, 12):
		draw_rect(Rect2(x, coast * TILE - 1 + (frame + x / 12) % 2, 8, 1), FOAM)
	var dock: Array = SeaChart.cfg("dock")
	draw_rect(Rect2(int(dock[0]) * TILE - 8, (coast - 1) * TILE, 32, 24), Color("#8c6a4e"))
	for x in range(0, width * TILE, 24):
		draw_rect(Rect2(x, zone_row * TILE - 2, 12, 2), Color(0.8, 0.9, 0.9, 0.25))
	for reef in SeaChart.cfg("reefs"):
		var at := Vector2(int(reef[0]) * TILE + 8, int(reef[1]) * TILE + 8)
		draw_rect(Rect2(at + Vector2(-7, -5), Vector2(14, 10)), ROCK)
		draw_rect(Rect2(at + Vector2(-8, 4), Vector2(16, 2)), FOAM)
	var seal := SeaChart.place_pos("seal_rock")
	draw_rect(Rect2(seal + Vector2(-20, -10), Vector2(40, 20)), Color("#6f6a60"))
	draw_rect(Rect2(seal + Vector2(-12, -14), Vector2(8, 4)), Color("#9a9ca3"))
	var well := SeaChart.place_pos("drowned_well")
	for ring in 3:
		draw_arc(well, 10.0 + ring * 6.0 + fmod(_t * 3.0, 6.0), 0.0, TAU, 24, Color(0.1, 0.12, 0.16, 0.8), 2.0)
	var garden := SeaChart.place_pos("sea_garden")
	draw_rect(Rect2(garden + Vector2(-96, -64), Vector2(192, 128)), Color(0.3, 0.45, 0.35, 0.25))
	for place in ["eider_isle", "dead_fire"]:
		var isle := SeaChart.place_pos(place)
		draw_rect(Rect2(isle + Vector2(-28, -18), Vector2(56, 36)), Color("#6f6a60"))
		draw_rect(Rect2(isle + Vector2(-22, -20), Vector2(44, 8)), Color("#4e6e3a") if place == "eider_isle" else Color("#45464e"))
	for place in SeaChart.cfg("places"):
		var label_at := SeaChart.place_pos(place) + Vector2(-30, -30)
		draw_string(ThemeDB.fallback_font, label_at, Loc.t("sea." + place), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color("#f0e7cc"))


func _night() -> bool:
	return Clock.hour >= 21 or Clock.hour < 5


# The sea drawn with PixelLab art: a light wave shimmer on the tiles, the coast, the islands and rocks, the
# whirlpool of the Drowned Well, the sea garden, icebergs in winter, the steamer by day, ship lights by night
# and the ghost ship Eleonora on Hmar nights.
func _draw_sea_art() -> void:
	var frame := int(_t * 4.0)
	var view := _visible_cells()
	var coast := int(SeaChart.cfg("coast_rows"))
	var sand := WangGround.seasonal("tiles_grass_sand", Clock.season)
	if not sand.is_empty():
		var grass_tile := WangGround.full_tile(sand, false)
		var sand_tile := WangGround.full_tile(sand, true)
		for x in range(maxi(view.position.x, 0), mini(view.end.x, width)):
			for y in coast:
				draw_texture_rect_region(sand["texture"], Rect2(x * TILE, y * TILE, TILE, TILE), sand_tile if y == coast - 1 else grass_tile)
	for x in range(0, width * TILE, 12):
		draw_rect(Rect2(x, coast * TILE - 1 + (frame + x / 12) % 2, 8, 1), FOAM)
	var dock: Array = SeaChart.cfg("dock")
	if not BuildingArt.draw_fit(self, "pier_cape", Rect2(int(dock[0]) * TILE - 12, (coast - 1) * TILE - 4, 40, 32)):
		draw_rect(Rect2(int(dock[0]) * TILE - 8, (coast - 1) * TILE, 32, 24), Color("#8c6a4e"))
	var fairway := SeaChart.place_pos("fairway")
	for x in range(0, width * TILE, 40):
		draw_rect(Rect2(x, fairway.y, 20, 2), Color(0.9, 0.9, 0.7, 0.25))
	# Reefs: rocks with foam; the Teeth get their own jagged cluster.
	for reef in SeaChart.cfg("reefs"):
		var at := Vector2(int(reef[0]) * TILE + 8, int(reef[1]) * TILE + 8)
		draw_rect(Rect2(at + Vector2(-9, 3), Vector2(18, 2)), FOAM)
		if not PropArt.draw(self, "rock_%d" % (1 + (int(reef[0]) + int(reef[1])) % 4), at + Vector2(0, 5)):
			draw_rect(Rect2(at + Vector2(-7, -5), Vector2(14, 10)), ROCK)
	SeaArt.draw(self, "teeth", SeaChart.place_pos("teeth"))
	SeaArt.draw(self, "seal_rock", SeaChart.place_pos("seal_rock"))
	SeaArt.draw(self, "eider_isle", SeaChart.place_pos("eider_isle"))
	SeaArt.draw(self, "nameless_isle", SeaChart.place_pos("nameless_isle"))
	if BuildingArt.texture("dead_fire"):
		BuildingArt.draw(self, "dead_fire", SeaChart.place_pos("dead_fire") + Vector2(0, 18))
	SeaArt.draw_loop(self, "whirlpool", SeaChart.place_pos("drowned_well"), _t, 6.0)
	var garden := SeaChart.place_pos("sea_garden")
	for i in 3:
		SeaArt.draw(self, "sea_garden", garden + Vector2(-48 + i * 48, -24 + (i % 2) * 20))
	if Clock.season == "winter":
		var field := SeaChart.place_pos("ice_field")
		for i in 8:
			SeaArt.draw(self, "iceberg_%d" % (1 + i % 3), field + Vector2.from_angle(i * TAU / 8.0) * 90.0)
		for i in 5:
			SeaArt.draw(self, "iceberg_3", field + Vector2.from_angle(i * 1.3) * 40.0)
	# The Gull runs the fairway by day; ships show only their lights by night.
	if not _night() and Clock.hour >= 8 and Clock.hour < 18 and Weather.current not in ["storm", "blizzard"]:
		var run := fmod(float(Clock.minutes - 8 * 60) / 600.0, 1.0)
		SeaArt.draw(self, "steamer", Vector2(run * width * TILE, fairway.y - 20))
	elif _night():
		for i in 2:
			var along := fmod(float(Clock.minutes) * (0.6 + i * 0.25) + i * 700.0, float(width * TILE))
			var blink := 0.75 + 0.25 * sin(_t * 3.0 + i)
			SeaArt.draw(self, "ship_lights", Vector2(along, fairway.y + 30 + i * 60), Color(1, 1, 1, blink))
	if Weather.hmar_night and _night():
		var drift := Vector2(sin(_t * 0.05) * 120.0, cos(_t * 0.04) * 40.0)
		SeaArt.draw(self, "eleonora", SeaChart.place_pos("nameless_isle") + Vector2(-140, 40) + drift,
			Color(0.7, 1.0, 0.85, 0.5 + 0.15 * sin(_t * 1.3)))
	for place in SeaChart.cfg("places"):
		var label_at := SeaChart.place_pos(place) + Vector2(-30, -34)
		draw_string(UiKit.font(), label_at + Vector2(0, 1), Loc.t("sea." + place), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.5))
		draw_string(UiKit.font(), label_at, Loc.t("sea." + place), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#f0e7cc"))
