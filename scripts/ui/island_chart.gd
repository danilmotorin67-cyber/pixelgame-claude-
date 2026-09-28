class_name IslandChart
extends RefCounted

# The island chart (M, tab «Остров»): the PixelLab picture of the whole island (tools/island_map.py), open
# whole from the start, the names of the land maps, the keeper, and with the Raven's Eye today's raven marks
# and the bottles on the beaches. data/island_map.json says where each map lies on it.
const IMAGE := "res://assets/sprites/ui/island_map.png"
const SCALE := 0.5
const INK := Color("#2b1f1a")
const LABEL := Color("#f4f7f6")
const RED := Color("#c2412d")

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null and ResourceLoader.exists(IMAGE):
		_texture = load(IMAGE) as Texture2D
	return _texture


static func chart() -> Dictionary:
	return Data.tables.get("island_map", {}).get("chart", {})


# The chart's size on screen, in interface units.
static func size() -> Vector2:
	var s: Array = chart().get("size", [416, 288])
	return Vector2(float(s[0]), float(s[1])) * SCALE


static func region_rect(map_id: String) -> Rect2:
	var r: Array = chart().get("regions", {}).get(map_id, [])
	if r.size() < 4:
		return Rect2()
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func title(map_id: String) -> String:
	return str(Data.tables.get("island_map", {}).get("names", {}).get(map_id, MapInfo.region(map_id).get("title", map_id)))


# A point of a land map (in pixels of that map) on the chart, in chart pixels.
static func point(map_id: String, at: Vector2) -> Vector2:
	var rect := region_rect(map_id)
	var tiles := MapInfo.size(map_id)
	if rect.size == Vector2.ZERO or tiles.x <= 0:
		return rect.get_center()
	var f := Vector2(clampf(at.x / (tiles.x * 16.0), 0.0, 1.0), clampf(at.y / (tiles.y * 16.0), 0.0, 1.0))
	return rect.position + rect.size * f


# Where the keeper stands on the island: [land map, point on the chart]; empty at sea and in the Deep.
static func keeper(map_id: String, at: Vector2) -> Array:
	if region_rect(map_id).size != Vector2.ZERO:
		return [map_id, point(map_id, at)]
	if Router.TOWER_MAPS.has(map_id):
		return ["cape", point("cape", Vector2(724, 264))]
	if map_id == "grotto":
		return ["seal_shore", point("seal_shore", Grotto.ENTRANCE)]
	if MapInfo.is_interior(map_id):
		var exits: Array = MapInfo.region(map_id).get("exits", [])
		if not exits.is_empty():
			var spawn: Array = exits[0].get("spawn", [0, 0])
			var parent := str(exits[0].get("to", ""))
			return [parent, point(parent, Vector2(float(spawn[0]) * 16.0, float(spawn[1]) * 16.0))]
	return []


# The part of the chart shown in `frame` at `zoom` (1: the whole island; 2: twice as close, centred on
# the keeper), in chart pixels.
static func view(frame: Rect2, zoom: int, map_id: String, at: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, size() / SCALE)
	if zoom <= 1:
		return full
	var span := frame.size / (SCALE * zoom)
	var where := keeper(map_id, at)
	var centre: Vector2 = where[1] if not where.is_empty() else full.get_center()
	var corner := (centre - span / 2.0).clamp(Vector2.ZERO, full.size - span)
	return Rect2(corner.round(), span)


static func draw(canvas: CanvasItem, frame: Rect2, zoom: int, map_id: String, at: Vector2) -> void:
	var src := view(frame, zoom, map_id, at)
	var k := frame.size.x / src.size.x
	var to_screen := func(p: Vector2) -> Vector2: return frame.position + (p - src.position) * k
	var tex := texture()
	if tex:
		canvas.draw_texture_rect_region(tex, frame, src)
	else:
		canvas.draw_rect(frame, Color("#24405a"))
	var regions: Dictionary = chart().get("regions", {})
	# With the Raven's Eye: today's raven marks and the bottles washed up.
	if Farm.raven_sight():
		for id in Farm.raven_marks:
			if not regions.has(id):
				continue
			for mark in Farm.raven_marks[id]:
				var p: Vector2 = to_screen.call(point(str(id), Vector2(int(mark["x"]) * 16 + 8, int(mark["y"]) * 16 + 8)))
				if frame.grow(-2).has_point(p):
					raven_mark(canvas, p)
		for id in Sea.gifts:
			if not regions.has(id):
				continue
			var coast := int(MapInfo.region(str(id)).get("coast_row", 54))
			for gift in Sea.gifts[id]:
				if str(gift.get("item", "")) != "message_bottle":
					continue
				var p: Vector2 = to_screen.call(point(str(id), Vector2(int(gift["x"]) * 16 + 8, (coast + int(gift["row"])) * 16 + 8)))
				if frame.grow(-3).has_point(p):
					bottle(canvas, p)
	# The names of the land maps.
	var font := UiKit.font()
	for id in regions:
		var name := title(str(id))
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at_label: Vector2 = (to_screen.call(region_rect(str(id)).get_center()) + Vector2(-w / 2.0, 3)).round()
		if not frame.encloses(Rect2(at_label - Vector2(1, 8), Vector2(w + 2, 10))):
			continue
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			canvas.draw_string(font, at_label + d, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
		canvas.draw_string(font, at_label, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LABEL)
	var where := keeper(map_id, at)
	if not where.is_empty():
		keeper_pin(canvas, (to_screen.call(where[1]) as Vector2).round(), 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0))


# The keeper: a gold pin with an ink rim and a soft glow.
static func keeper_pin(canvas: CanvasItem, p: Vector2, glow := 1.0) -> void:
	canvas.draw_circle(p, 4.0, Color(1.0, 0.78, 0.35, 0.35 * glow))
	canvas.draw_circle(p, 2.5, INK)
	canvas.draw_circle(p, 1.5, Color("#ffc85a"))


static func raven_mark(canvas: CanvasItem, p: Vector2) -> void:
	canvas.draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), INK, 2.0)
	canvas.draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), INK, 2.0)
	canvas.draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), RED, 1.0)
	canvas.draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), RED, 1.0)


static func bottle(canvas: CanvasItem, p: Vector2) -> void:
	canvas.draw_rect(Rect2(p - Vector2(1, 2), Vector2(3, 5)), INK)
	canvas.draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), Color("#6fb0b3"))
