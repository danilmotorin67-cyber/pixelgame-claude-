extends Area2D
class_name AnimalObject

# An animal out in the yard (7:00-18:00 in fair weather): E pets it once a day (14.3).
const COLORS := {"chicken": "#f0e7cc", "duck": "#dfe9ea", "eider": "#6b5a4a", "sheep": "#eee8da", "goat": "#b08f6c",
	"cow": "#8a5a3a", "pony": "#6b4a32"}
const SIZES := {"chicken": Vector2(8, 7), "duck": Vector2(9, 7), "eider": Vector2(10, 7), "sheep": Vector2(16, 11),
	"goat": Vector2(14, 11), "cow": Vector2(20, 13), "pony": Vector2(18, 14)}

var animal_id: int = 0
# A little life for the PixelLab sprites: stand, graze or peck, now and then amble a few steps.
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _state := "idle"
var _left := 0.0
var _clock := 0.0
var _facing := "down"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	_home = position
	_target = position
	_rng.seed = animal_id * 7919 + 17
	_left = _rng.randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	_clock += delta
	_left -= delta
	if _state == "walk":
		var d := _target - position
		if d.length() < 1.0:
			_state = "idle"
		else:
			position += d.normalized() * minf(d.length(), 12.0 * delta)
			_facing = ("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) else ("down" if d.y > 0 else "up")
	if _left <= 0.0 and _state != "walk":
		var roll := _rng.randf()
		if roll < 0.35:
			_state = "walk"
			_target = _home + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-10, 10))
		elif roll < 0.7 and (CastSprite.has_anim(kind(), "graze") or CastSprite.has_anim(kind(), "idle")):
			_state = "graze" if CastSprite.has_anim(kind(), "graze") else "idle"
			_facing = "down" if _rng.randf() < 0.5 else "right"
		else:
			_state = "rest"
		_clock = 0.0
		_left = _rng.randf_range(2.0, 5.0)
	queue_redraw()


func kind() -> String:
	return str(Animals.find(animal_id).get("kind", ""))


func _draw() -> void:
	if CastSprite.has(kind()):
		draw_rect(Rect2(-5, -1, 10, 2), Color(0, 0, 0, 0.2))
		var anim: String = {"walk": "walk", "graze": "graze", "idle": "idle"}.get(_state, "rot")
		# Birds peck only facing south; the rest shows the still pose.
		CastSprite.draw(self, kind(), anim, _facing, _clock)
		return
	var size: Vector2 = SIZES.get(kind(), Vector2(10, 8))
	draw_rect(Rect2(-size / 2.0, size), Color(str(COLORS.get(kind(), "#f0e7cc"))))
	draw_rect(Rect2(Vector2(size.x / 2.0 - 3, -size.y / 2.0 - 3), Vector2(5, 5)), Color(str(COLORS.get(kind(), "#f0e7cc"))).darkened(0.1))
	draw_rect(Rect2(Vector2(size.x / 2.0 - 1, -size.y / 2.0 - 2), Vector2(1, 1)), Color("#1e1a18"))
	if kind() in ["chicken", "duck", "eider"]:
		draw_rect(Rect2(Vector2(size.x / 2.0 + 2, -size.y / 2.0 - 1), Vector2(2, 1)), Color("#e9a64a"))
	else:
		draw_rect(Rect2(Vector2(-size.x / 2.0 + 1, size.y / 2.0), Vector2(2, 3)), Color("#4a3428"))
		draw_rect(Rect2(Vector2(size.x / 2.0 - 3, size.y / 2.0), Vector2(2, 3)), Color("#4a3428"))


func interact(_player: Player) -> void:
	var a := Animals.find(animal_id)
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if a.is_empty() or hint == null:
		return
	if kind() == "pony" and Animals.pet(animal_id) == false:
		hint.text = "Пони осёдлан." if Animals.toggle_ride() else "Вы спешились."
		return
	hint.text = "%s довольно фыркает. Дружба: %d." % [str(a["name"]), int(a["friendship"])] if Animals.pet(animal_id) \
		else "Сегодня %s уже гладили." % str(a["name"])
