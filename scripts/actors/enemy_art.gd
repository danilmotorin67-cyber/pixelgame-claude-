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


# The fallen of a combat world play their death animation once, flash pale at the blow, then sink
# and fade out (some PixelLab death cycles barely move, the fade makes every fall read).
static func draw_fallen(canvas: CanvasItem, world: CombatWorld) -> void:
	for f in world.fallen:
		var kind := str(f["kind"])
		var elapsed := world.time - float(f["t"])
		var t := _once(kind, elapsed)
		if t >= 0.0:
			CastSprite.draw(canvas, kind, "die", "south", t, (f["pos"] as Vector2) + Vector2(0, 7 + fall_sink(elapsed)),
				bool(f["flip"]), 1.0, fall_tint(elapsed))


static func fall_tint(elapsed: float, span := 1.2) -> Color:
	var a := clampf(1.0 - (elapsed - span * 0.35) / (span * 0.65), 0.0, 1.0)
	return Color(1.6, 1.6, 1.6, a) if elapsed < 0.08 else Color(1, 1, 1, a)


static func fall_sink(elapsed: float, span := 1.2) -> float:
	return roundf(3.0 * clampf(elapsed / span, 0.0, 1.0))


# The boss's fall after its last hit; false when it has none to play (or it has finished).
static func draw_boss_death(canvas: CanvasItem, b: Dictionary, now: float) -> bool:
	var id := str(b.get("id", ""))
	if not b.has("dead_t") or not CastSprite.has_anim(id, "die"):
		return false
	var t := _once(id, now - float(b["dead_t"]), 2.0)
	if t < 0.0:
		return false
	var elapsed := now - float(b["dead_t"])
	return CastSprite.draw(canvas, id, "die", "south", t, (b["pos"] as Vector2) + Vector2(0, float(b.get("radius", 16)) + fall_sink(elapsed, 2.0)),
		false, float(BOSS_SCALE.get(id, 1.0)), fall_tint(elapsed, 2.0))


# Time into a one-shot animation: runs its frames once, holds the last one until `hold`, then -1.
static func _once(id: String, elapsed: float, hold := 1.2) -> float:
	var rows: Dictionary = CastSprite.sheet(id).get("anims", {}).get("die", {})
	if rows.is_empty() or elapsed > hold:
		return -1.0
	var frames := int((rows.values()[0] as Array)[1])
	return minf(elapsed, (float(frames) - 0.5) / CastSprite.FPS)


# Each creature gets its own phase so a school does not move in step.
static func _t(e: Dictionary) -> float:
	return Time.get_ticks_msec() / 1000.0 + float(absi(str(e.get("id", e.get("kind", ""))).hash()) % 100) * 0.07
