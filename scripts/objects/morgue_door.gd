extends Area2D
class_name MorgueDoor


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 20)
	collision.shape = shape
	add_child(collision)


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node("HUD/Hint") as Label
	if Graveyard.carried != "":
		if Graveyard.store_in_morgue():
			hint.text = "Тело в покойницкой. «Стучите. Нам торопиться некуда»."
		return
	MorguePanel.open(get_tree().current_scene.get_node("HUD"))
