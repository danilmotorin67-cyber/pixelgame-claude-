class_name CastSprite
extends RefCounted

# PixelLab NPC and animal sheets (tools/build_art.py): one row per animation and
# direction. Frames are drawn at Screen.ART_SCALE with the feet on the owner's origin.
const FPS := 8.0
const DIRS := {"down": "south", "up": "north", "left": "west", "right": "east"}

static var _cache := {}


static func sheet(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var info := {}
	var tex := load("res://assets/sprites/cast/%s.png" % id) as Texture2D if ResourceLoader.exists("res://assets/sprites/cast/%s.png" % id) else null
	var file := FileAccess.open("res://assets/sprites/cast/%s.json" % id, FileAccess.READ)
	if tex and file:
		info = JSON.parse_string(file.get_as_text())
		info["texture"] = tex
	_cache[id] = info
	return info


static func has(id: String) -> bool:
	return not sheet(id).is_empty()


static func has_anim(id: String, anim: String) -> bool:
	return sheet(id).get("anims", {}).has(anim)


# anim: walk / idle / work / graze / sleep / rot or a critter's own animation;
# facing: down/up/left/right or south/north/west/east. A missing direction falls back
# to south, a missing animation to the still rotation.
static func draw(canvas: CanvasItem, id: String, anim: String, facing: String, t: float,
		offset := Vector2.ZERO, flip := false) -> bool:
	var info := sheet(id)
	if info.is_empty():
		return false
	var anims: Dictionary = info["anims"]
	var dir: String = DIRS.get(facing, facing)
	if not anims.has(anim):
		anim = "rot"
	var rows: Dictionary = anims[anim]
	if not rows.has(dir):
		# East and west mirror each other for creatures drawn only one way.
		if dir == "west" and rows.has("east"):
			dir = "east"
			flip = not flip
		elif rows.has("south"):
			dir = "south"
		else:
			dir = rows.keys()[0]
	var row: Array = rows[dir]
	var frame := int(t * FPS) % int(row[1])
	var size := Vector2(info["frame"][0], info["frame"][1])
	var src := Rect2(Vector2(frame * size.x, int(row[0]) * size.y), size)
	var scaled := size * Screen.ART_SCALE
	var foot := float(info.get("foot", size.y)) * Screen.ART_SCALE
	if flip:
		canvas.draw_set_transform(offset, 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(info["texture"], Rect2(Vector2(-scaled.x / 2.0, -foot), scaled), src)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect_region(info["texture"], Rect2(offset + Vector2(-scaled.x / 2.0, -foot), scaled), src)
	return true
