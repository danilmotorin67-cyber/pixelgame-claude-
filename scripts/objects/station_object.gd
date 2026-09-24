extends Area2D
class_name StationObject

var uid: int = 0
var station_id: String = ""


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 16)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	match station_id:
		"workbench":
			draw_rect(Rect2(-10, -6, 20, 4), Color("#8c6a4e"))
			draw_rect(Rect2(-9, -2, 2, 7), Color("#6b4a32"))
			draw_rect(Rect2(7, -2, 2, 7), Color("#6b4a32"))
			draw_rect(Rect2(-6, -8, 5, 2), Color("#9a9ca3"))
		"hearth":
			draw_rect(Rect2(-9, -3, 18, 7), Color("#45464e"))
			draw_rect(Rect2(-5, -8, 10, 6), Color("#2a2a30"))
			draw_rect(Rect2(-3, -1, 6, 3), Color("#e9a64a"))
		"compost_pit":
			draw_rect(Rect2(-10, -5, 20, 10), Color("#6b4a32"))
			draw_rect(Rect2(-8, -3, 16, 6), Color("#4a3428"))
			draw_rect(Rect2(-6, -2, 5, 2), Color("#4e6e3a"))
		"chest":
			draw_rect(Rect2(-8, -6, 16, 11), Color("#6b4a32"))
			draw_rect(Rect2(-8, -6, 16, 3), Color("#8c6a4e"))
			draw_rect(Rect2(-1, -3, 2, 3), Color("#ffc85a"))


func interact(_player: Player) -> void:
	var hud: CanvasLayer = get_tree().current_scene.get_node("HUD")
	StationPanel.open(hud, uid)
