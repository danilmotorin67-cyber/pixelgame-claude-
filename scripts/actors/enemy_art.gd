class_name EnemyArt
extends RefCounted

# PixelLab enemies and bosses (tools/pixellab_spirits_enemies.py, packed as cast sheets): a combat
# world's enemy dictionary picks move or attack from its state and faces where it is heading.
const ATTACKS := ["charge", "dash", "lunge"]
const BOSS_ATTACKS := ["bubbles", "wave", "inhale", "raise", "out"]
# The whale and the moray fill their fight's radius rather than the sheet's frame.
const BOSS_SCALE := {"mother_moray": 1.25, "bone_whale": 1.6}


static func draw(canvas: CanvasItem, e: Dictionary) -> bool:
	var kind := str(e.get("kind", ""))
	if not CastSprite.has(kind):
		return false
	var anim := "attack" if str(e.get("state", "")) in ATTACKS else "move"
	var heading: Vector2 = e.get("vel", Vector2.ZERO)
	if heading.length() < 0.1:
		heading = e.get("facing", Vector2.LEFT)
	return CastSprite.draw(canvas, kind, anim, "south", _t(e), (e["pos"] as Vector2) + Vector2(0, 7), heading.x > 0.0)


static func draw_boss(canvas: CanvasItem, b: Dictionary) -> bool:
	var id := str(b.get("id", ""))
	if not CastSprite.has(id):
		return false
	if str(b.get("state", "")) == "hidden":
		return true
	var anim := "attack" if str(b.get("state", "")) in BOSS_ATTACKS else "idle"
	return CastSprite.draw(canvas, id, anim, "south", _t(b), (b["pos"] as Vector2) + Vector2(0, float(b.get("radius", 16))), false,
		float(BOSS_SCALE.get(id, 1.0)))


# Each creature gets its own phase so a school does not move in step.
static func _t(e: Dictionary) -> float:
	return Time.get_ticks_msec() / 1000.0 + float(absi(str(e.get("id", e.get("kind", ""))).hash()) % 100) * 0.07
