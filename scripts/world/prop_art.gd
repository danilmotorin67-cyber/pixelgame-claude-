class_name PropArt
extends RefCounted

# PixelLab map props (assets/sprites/props/<id>.png, tools/build_art.py): drawn at
# Screen.ART_SCALE with the bottom centre on the given point. Missing art returns false,
# so callers keep their drawn shapes.
static var _cache := {}


static func texture(id: String) -> Texture2D:
	if not _cache.has(id):
		var path := "res://assets/sprites/props/%s.png" % id
		_cache[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[id]


static func draw(canvas: CanvasItem, id: String, bottom := Vector2.ZERO, modulate := Color.WHITE) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	var size := tex.get_size() * Screen.ART_SCALE
	canvas.draw_texture_rect(tex, Rect2(bottom + Vector2(-size.x / 2.0, -size.y), size), false, modulate)
	return true


# Swaying in the wind: the base stays put, the top leans by up to `lean` units; neighbours sway out of step.
static func draw_sway(canvas: CanvasItem, id: String, bottom: Vector2, t: float, lean := 1.0, modulate := Color.WHITE) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	var size := tex.get_size() * Screen.ART_SCALE
	var shift := roundf(sin(t * 1.7 + bottom.x * 0.071 + bottom.y * 0.037) * lean)
	canvas.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-shift / maxf(size.y, 1.0), 1), bottom))
	canvas.draw_texture_rect(tex, Rect2(Vector2(-size.x / 2.0, -size.y), size), false, modulate)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


# How hard the wind blows for swaying things.
static func wind_lean() -> float:
	match Weather.current:
		"storm", "blizzard":
			return 2.5
		"rain", "snow", "cloud":
			return 1.4
	return 0.8


static var _loops := {}


# A looping strip (<id>.png + <id>.json: frame, frames, anchor) placed so that the anchor — the still
# sprite's bottom centre — lands on `bottom`; the frame follows time `t`. False when there is no strip.
static func draw_loop(canvas: CanvasItem, id: String, bottom: Vector2, t: float, fps := 6.0) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	if not _loops.has(id):
		var path := "res://assets/sprites/props/%s.json" % id
		_loops[id] = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	var m: Dictionary = _loops[id]
	if m.is_empty():
		return false
	var fr: Array = m["frame"]
	var anchor: Array = m.get("anchor", [float(fr[0]) / 2.0, float(fr[1])])
	var size := Vector2(float(fr[0]), float(fr[1]))
	var frame := int(t * fps) % maxi(int(m.get("frames", 1)), 1)
	var at := bottom - Vector2(float(anchor[0]), float(anchor[1])) * Screen.ART_SCALE
	canvas.draw_texture_rect_region(tex, Rect2(at, size * Screen.ART_SCALE), Rect2(frame * size.x, 0, size.x, size.y))
	return true


# Fitted to a footprint (furniture): as wide as the plot, standing on its bottom edge.
static func draw_fit(canvas: CanvasItem, id: String, plot: Rect2) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	var size := tex.get_size() * (plot.size.x / tex.get_size().x)
	canvas.draw_texture_rect(tex, Rect2(Vector2(plot.position.x, plot.end.y - size.y), size), false)
	return true


# A stable variant for a map position: "rock" + cell -> "rock_3".
static func variant(base: String, count: int, seed: int) -> String:
	return "%s_%d" % [base, posmod(seed, count) + 1]
