extends Area2D
class_name AnimalObject

# An animal out in the yard (7:00-18:00 in fair weather): E pets it once a day (14.3).
const COLORS := {"chicken": "#f0e7cc", "duck": "#dfe9ea", "eider": "#6b5a4a", "sheep": "#eee8da", "goat": "#b08f6c",
	"cow": "#8a5a3a", "pony": "#6b4a32"}
const SIZES := {"chicken": Vector2(8, 7), "duck": Vector2(9, 7), "eider": Vector2(10, 7), "sheep": Vector2(16, 11),
	"goat": Vector2(14, 11), "cow": Vector2(20, 13), "pony": Vector2(18, 14)}

var animal_id: int = 0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func kind() -> String:
	return str(Animals.find(animal_id).get("kind", ""))


func _draw() -> void:
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
