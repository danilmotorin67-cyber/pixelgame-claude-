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
