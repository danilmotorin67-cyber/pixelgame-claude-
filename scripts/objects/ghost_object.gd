extends Area2D
class_name GhostObject

var ghost_id: String = ""
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 24)
	collision.shape = shape
	add_child(collision)


func _process(delta: float) -> void:
	_time += delta
	position.y += sin(_time * 2.0) * 0.05
	queue_redraw()


func _draw() -> void:
	var glow := Color(0.75, 0.9, 0.95, 0.55 + 0.15 * sin(_time * 3.0))
	draw_rect(Rect2(-5, -12, 10, 18), glow)
	draw_rect(Rect2(-4, -16, 8, 5), glow)
	draw_rect(Rect2(-2, -14, 1, 1), Color("#121a26"))
	draw_rect(Rect2(1, -14, 1, 1), Color("#121a26"))


func interact(_player: Player) -> void:
	var name := Loc.t(str(Data.by_id("ghosts", ghost_id).get("name", ghost_id)))
	var line := Graveyard.talk_ghost(ghost_id)
	InfoPanel.open(get_tree().current_scene.get_node("HUD"), name, func() -> String: return line)
	if Graveyard.laid_ghosts.has(ghost_id):
		queue_free()
