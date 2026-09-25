extends Area2D
class_name KidObject

# 22.3: a toddler plays in the yard; a child feeds the hens or wanders to the graveyard with a grim question.
var child: Dictionary = {}
var index: int = 0
var _t: float = 0.0
var _home: Vector2 = Vector2.ZERO
var _facing := "down"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 14)
	collision.shape = shape
	add_child(collision)
	_home = position


func _process(delta: float) -> void:
	_t += delta
	var before := position
	position = _home + Vector2(sin(_t * 0.7 + float(index)) * 18.0, cos(_t * 0.5 + float(index)) * 6.0)
	var d := position - before
	if d.length() > 0.001:
		_facing = ("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) * 1.5 else ("down" if d.y > 0 else "up")
	queue_redraw()


# The first child is drawn as a boy and the second as a girl (the save keeps no gender).
func sprite_id() -> String:
	return "kid_%s_%s" % ["toddler" if Family.stage(child) == "toddler" else "child", "boy" if index % 2 == 0 else "girl"]


func _draw() -> void:
	if CastSprite.draw(self, sprite_id(), "walk", _facing, _t):
		return
	var small := Family.stage(child) == "toddler"
	var h := 8.0 if small else 12.0
	draw_rect(Rect2(-3, -h, 6, h - 3), Color("#4a6e8a") if index == 0 else Color("#8a3a2e"))
	draw_rect(Rect2(-3, -h - 5, 6, 5), Color("#e8c6a0"))
	draw_rect(Rect2(-3, -h - 6, 6, 2), Color("#b08f6c"))
	draw_rect(Rect2(-3, -3, 2, 3), Color("#2a2a30"))
	draw_rect(Rect2(1, -3, 2, 3), Color("#2a2a30"))


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint == null:
		return
	if Family.stage(child) == "toddler":
		hint.text = "%s тянет к вам руки и говорит «маяк». Почти." % str(child["name"])
	else:
		hint.text = "%s: «%s»" % [str(child["name"]), Family.kid_line(index)]
