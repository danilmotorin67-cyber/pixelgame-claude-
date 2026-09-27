class_name BuildingArt
extends RefCounted

# PixelLab building sprites (tools/build_art.py): cropped to their pixels, drawn at
# Screen.ART_SCALE with the bottom centre on the owner's origin, which keeps Y sorting.
# Textures stay referenced here: a texture freed right after a draw call leaves the
# canvas pointing at a dead resource, which renders as a white box.
static var _cache := {}


static func texture(id: String) -> Texture2D:
	if not _cache.has(id):
		_cache[id] = load("res://assets/sprites/buildings/%s.png" % id) as Texture2D
	return _cache[id]


static func draw(canvas: CanvasItem, id: String, offset := Vector2.ZERO) -> void:
	var tex := texture(id)
	if tex == null:
		return
	var size := tex.get_size() * Screen.ART_SCALE
	canvas.draw_texture_rect(tex, Rect2(offset + Vector2(-size.x / 2.0, -size.y), size), false)


# Fitted to a footprint: at most 90% of the plot's width and two tiles taller than it, centred and
# standing on its bottom edge, so the roof rises a little above the walled plot.
static func draw_fit(canvas: CanvasItem, id: String, plot: Rect2) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	var k := minf(plot.size.x * 0.9 / tex.get_size().x, (plot.size.y + 32.0) / tex.get_size().y)
	var size := tex.get_size() * k
	canvas.draw_texture_rect(tex, Rect2(Vector2(plot.get_center().x - size.x / 2.0, plot.end.y - size.y), size), false)
	return true
