extends Area2D
class_name Mailbox


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 16)
	collision.shape = shape
	add_child(collision)
	Events.night_resolved.connect(func(_r: Dictionary) -> void: queue_redraw())


func _draw() -> void:
	draw_rect(Rect2(-1, -2, 2, 10), Color("#6b4a32"))
	draw_rect(Rect2(-5, -9, 10, 7), Color("#24405a"))
	draw_rect(Rect2(-5, -9, 10, 2), Color("#2f5a76"))
	if Mail.unread() > 0:
		draw_rect(Rect2(4, -13, 2, 5), Color("#9b2f2a"))


func interact(_player: Player) -> void:
	MailPanel.open(get_tree().current_scene.get_node("HUD"))
	queue_redraw()
