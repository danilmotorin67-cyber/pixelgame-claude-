extends Area2D
class_name BodyObject

var body_id: String = ""
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 12)
	collision.shape = shape
	add_child(collision)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# A quiet figure wrapped in canvas; crows circle above ("the crows know").
	draw_rect(Rect2(-10, -3, 20, 7), Color("#c9b89a"))
	draw_rect(Rect2(-10, -3, 20, 1), Color("#e9dcc6"))
	draw_rect(Rect2(-12, -2, 3, 5), Color("#d8c49a"))
	for i in 2:
		var angle := _time * 1.4 + float(i) * PI
		var at := Vector2(cos(angle) * 12.0, -22.0 + sin(angle) * 4.0)
		draw_rect(Rect2(at, Vector2(4, 1)), Color("#1a1a20"))
		draw_rect(Rect2(at + Vector2(1, -1), Vector2(2, 1)), Color("#1a1a20"))


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node("HUD/Hint") as Label
	var b := Graveyard.body(body_id)
	if Graveyard.pick_up(b):
		Events.body_moved.emit(body_id, "carried")
		hint.text = "Вы несёте тело. Покойницкая — к северу от погоста. E — положить."
		queue_free()
	else:
		hint.text = "Руки заняты."
