class_name ItemIcon
extends RefCounted

# PixelLab inventory icons (assets/sprites/icons/<item id>.png, 32 px): drawn into a 16-unit
# cell, which the HUD's ×2 scale shows pixel for pixel. Items without art keep their drawn shape.
static var _cache := {}


static func texture(id: String) -> Texture2D:
	if not _cache.has(id):
		var path := "res://assets/sprites/icons/%s.png" % id
		_cache[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[id]


static func draw(canvas: CanvasItem, id: String, rect: Rect2) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	canvas.draw_texture_rect(tex, rect, false)
	return true
