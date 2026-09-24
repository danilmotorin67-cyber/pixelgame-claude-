extends Area2D
class_name DirectorateDesk

const OPEN := 8
const CLOSE := 17


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 20)
	collision.shape = shape
	add_child(collision)


func interact(_player: Player) -> void:
	var hint: Label = get_tree().current_scene.get_node("HUD/Hint")
	if Clock.weekday == "sun" or Clock.hour < OPEN or Clock.hour >= CLOSE:
		hint.text = "Лоцманская управа открыта с 8 до 17, кроме воскресенья."
		return
	var handed := Lighthouse.hand_in_crates()
	hint.text = "Олаф принял ящиков: %d. Честь +%d." % [handed, 3 * handed] if handed > 0 \
		else "Олаф: «Ящики с крушений — сюда. Остальное — по записи»."
