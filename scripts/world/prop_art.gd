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
