class_name PortraitArt
extends RefCounted

# Talk portraits, 64×64 (tools/pixellab_portraits.py): assets/sprites/portraits/<id>_<emotion>.png for the
# islanders, Agatha, the hero (hero_male / hero_female) and the daughters of Rann. An emotion without
# its own picture falls back to the neutral face.
const EMOTIONS := ["neutral", "happy", "sad", "angry", "surprised", "special"]
static var _cache := {}


static func key(id: String) -> String:
	if id == "hero":
		return "hero_female" if str(Game.hero.get("gender", "m")) == "f" else "hero_male"
	return id


static func texture(id: String, emotion: String = "neutral") -> Texture2D:
	var k := "%s_%s" % [key(id), emotion]
	if not _cache.has(k):
		var path := "res://assets/sprites/portraits/%s.png" % k
		_cache[k] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var tex: Texture2D = _cache[k]
	if tex == null and emotion != "neutral":
		return texture(id, "neutral")
	return tex


# Draws the portrait into `rect` (64 units: one unit a texel); false when there is none.
static func draw(canvas: CanvasItem, id: String, emotion: String, rect: Rect2) -> bool:
	var tex := texture(id, emotion if emotion in EMOTIONS else "neutral")
	if tex == null:
		return false
	canvas.draw_texture_rect(tex, Rect2(rect.position + (rect.size - Vector2(64, 64)) / 2.0, Vector2(64, 64)), false)
	return true
