extends Area2D
class_name RestPlaceBuoy

var _t: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision.shape = shape
	add_child(collision)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 2.0) * 1.5
	draw_rect(Rect2(-4, -10 + bob, 8, 12), Color("#c2412d"))
	draw_rect(Rect2(-4, -6 + bob, 8, 2), Color("#fff8e1"))
	draw_rect(Rect2(-1, -16 + bob, 2, 6), Color("#45464e"))


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node("HUD/Hint") as Label
	hint.text = SeaBurial.perform()
