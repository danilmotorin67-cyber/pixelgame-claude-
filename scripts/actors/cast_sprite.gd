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
		offset := Vector2.ZERO, flip := false, scale := 1.0, tint := Color.WHITE) -> bool:
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
	if flip or scale != 1.0:
		canvas.draw_set_transform(offset, 0.0, Vector2(-scale if flip else scale, scale))
		canvas.draw_texture_rect_region(info["texture"], Rect2(Vector2(-scaled.x / 2.0, -foot), scaled), src, tint)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect_region(info["texture"], Rect2(offset + Vector2(-scaled.x / 2.0, -foot), scaled), src, tint)
	return true


# The head and shoulders of a character's front view for talk portraits: a 30×32 texel window
# around the top of the figure in `frame` (a region of `tex`), cached per sheet.
static var _busts := {}


static func bust(key: String, tex: Texture2D, frame: Rect2i) -> Rect2:
	if not _busts.has(key):
		var used := tex.get_image().get_region(frame).get_used_rect()
		var cx := frame.position.x + used.position.x + used.size.x / 2
		_busts[key] = Rect2(cx - 15, frame.position.y + maxi(used.position.y - 1, 0), 30, 32)
	return _busts[key]


# Draws the portrait of an NPC (or the hero) into `rect`; false when there is no sheet.
static func draw_portrait(canvas: CanvasItem, id: String, rect: Rect2) -> bool:
	var tex: Texture2D
	var frame: Rect2i
	if id == "hero":
		var hero_id := "hero_female" if str(Game.hero.get("gender", "m")) == "f" else "hero_male"
		var path := "res://assets/sprites/characters/%s.png" % hero_id
		if not ResourceLoader.exists(path):
			return false
		tex = load(path)
		var size := tex.get_width() / Player.WALK_FRAMES
		frame = Rect2i(0, Player.IDLE_ROW * size, size, size)
		id = hero_id
	else:
		var info := sheet(id)
		if info.is_empty():
			return false
		tex = info["texture"]
		var anims: Dictionary = info["anims"]
		var rows: Dictionary = anims.get("rot", anims.values()[0])
		var row: Array = rows.get("south", rows.values()[0])
		frame = Rect2i(0, int(row[0]) * int(info["frame"][1]), int(info["frame"][0]), int(info["frame"][1]))
	var src := bust(id, tex, frame)
	# 1.5 units a texel: three screen pixels each, so the pixels stay even at the HUD's ×2.
	var scale := floorf(minf(rect.size.x / src.size.x, rect.size.y / src.size.y) * 2.0) / 2.0
	var size := src.size * scale
	canvas.draw_texture_rect_region(tex, Rect2(rect.position + Vector2((rect.size.x - size.x) / 2.0, rect.size.y - size.y), size), src)
	return true
