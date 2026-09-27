class_name SeaArt
extends RefCounted

# PixelLab sea art (tools/pixellab_sea.py, packed by build_art.py into assets/sprites/sea/): the boats in
# 8 directions with their states (base: empty, sail up; keeper_sail; keeper_oars), the sea's objects and
# looping animations (the whirlpool). Drawn at Screen.ART_SCALE; textures are cached.
static var _tex := {}
static var _meta := {}


static func texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := "res://assets/sprites/sea/%s.png" % name
		_tex[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[name]


static func meta(name: String) -> Dictionary:
	if not _meta.has(name):
		var path := "res://assets/sprites/sea/%s.json" % name
		_meta[name] = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return _meta[name]


# The sheet column for a heading: south, south-east, east, north-east, north, north-west, west, south-west.
static func dir_index(heading: Vector2) -> int:
	return posmod(roundi((90.0 - rad_to_deg(heading.angle())) / 45.0), 8)


static func has_boat(boat: String, state: String = "base") -> bool:
	return texture("boat_%s_%s" % [boat, state]) != null


static func draw_boat(canvas: CanvasItem, boat: String, state: String, heading: Vector2, at: Vector2, tint := Color.WHITE) -> bool:
	var name := "boat_%s_%s" % [boat, state]
	var tex := texture(name)
	if tex == null:
		return false
	var fr: Array = meta(name).get("frame", [68, 68])
	var size := Vector2(float(fr[0]), float(fr[1]))
	var src := Rect2(dir_index(heading) * size.x, 0, size.x, size.y)
	var scaled := size * Screen.ART_SCALE
	canvas.draw_texture_rect_region(tex, Rect2(at - scaled / 2.0, scaled), src, tint)
	return true


# A sea object centred on `at` (bottom-centred when `grounded`).
static func draw(canvas: CanvasItem, name: String, at: Vector2, tint := Color.WHITE, grounded := false) -> bool:
	var tex := texture(name)
	if tex == null:
		return false
	var scaled := tex.get_size() * Screen.ART_SCALE
	var pos := at - Vector2(scaled.x / 2.0, scaled.y if grounded else scaled.y / 2.0)
	canvas.draw_texture_rect(tex, Rect2(pos, scaled), false, tint)
	return true


# A looping animation (<name>_loop strip) at `at`, frame from time `t`.
static func draw_loop(canvas: CanvasItem, name: String, at: Vector2, t: float, fps := 6.0, tint := Color.WHITE) -> bool:
	var tex := texture(name + "_loop")
	if tex == null:
		return draw(canvas, name, at, tint)
	var m := meta(name + "_loop")
	var fr: Array = m.get("frame", [64, 64])
	var size := Vector2(float(fr[0]), float(fr[1]))
	var frame := int(t * fps) % maxi(int(m.get("frames", 1)), 1)
	var scaled := size * Screen.ART_SCALE
	canvas.draw_texture_rect_region(tex, Rect2(at - scaled / 2.0, scaled), Rect2(frame * size.x, 0, size.x, size.y), tint)
	return true
