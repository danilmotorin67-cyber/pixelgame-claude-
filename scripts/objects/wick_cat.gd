extends Area2D
class_name WickCat

# Wick, the lighthouse cat ("there's always a cat at the lighthouse", tale 7): once the key under him is
# found he ambles about the tower door by day and sleeps curled up by it at night and in foul weather.
# E strokes him.
const HOME := Vector2(700, 300)

var _target := HOME
var _state := "idle"
var _left := 1.0
var _clock := 0.0
var _facing := "down"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 10)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	_rng.seed = Game.world_seed * 31 + Clock.day_index
	position = HOME


static func sleeping() -> bool:
	return Clock.hour >= 21 or Clock.hour < 6 or Weather.current in ["rain", "storm", "blizzard"]


func _process(delta: float) -> void:
	_clock += delta
	_left -= delta
	if sleeping():
		_state = "sleep"
		position = position.move_toward(HOME, 20.0 * delta)
	elif _state == "walk":
		var d := _target - position
		if d.length() < 1.0:
			_state = "idle"
		else:
			position += d.normalized() * minf(d.length(), 16.0 * delta)
			_facing = ("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) else ("down" if d.y > 0 else "up")
	if _left <= 0.0 and _state != "walk" and not sleeping():
		if _rng.randf() < 0.5:
			_state = "walk"
			_target = HOME + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-16, 24))
		else:
			_state = "idle"
			_facing = ["down", "left", "right"][_rng.randi() % 3]
		_clock = 0.0
		_left = _rng.randf_range(2.0, 6.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-4, -1, 8, 2), Color(0, 0, 0, 0.2))
	var anim := "sleep" if _state == "sleep" else ("walk" if _state == "walk" else "idle")
	if not CastSprite.draw(self, "cat_wick", anim, "down" if anim == "sleep" else _facing, _clock, Vector2(0, 2)):
		draw_rect(Rect2(-4, -5, 8, 6), Color("#2a2a30"))


func interact(player: Player) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = "Фитиль приоткрывает жёлтый глаз и снова засыпает." if sleeping() \
			else "Фитиль позволяет себя поднять и громко мурлычет."
	if player and not sleeping():
		# The keeper holds him a moment; he is part of the picture meanwhile.
		player.play_pose("lift_cat", 1.6)
		visible = false
		get_tree().create_timer(1.6).timeout.connect(func() -> void: visible = true)
