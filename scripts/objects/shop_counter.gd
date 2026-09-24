extends Area2D
class_name ShopCounter

const CLOSED_TEXT := {"day": "%s сегодня закрыта. Выходной.", "hours": "%s открыта с %d до %d."}

@export var shop_id: String = ""


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	if get_child_count() == 0:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(36, 20)
		collision.shape = shape
		add_child(collision)


func interact(_player: Player) -> void:
	var scene := get_tree().current_scene
	var info := Economy.shop(shop_id)
	var reason := Economy.shop_closed_reason(shop_id)
	if reason != "":
		var hint: Label = scene.get_node("HUD/Hint")
		hint.text = CLOSED_TEXT.get(reason, "%s закрыта.") % (
			[info.get("name", ""), int(info.get("open", 0)), int(info.get("close", 0))]
			if reason == "hours" else [info.get("name", "")])
		return
	ShopPanel.open(scene.get_node("HUD"), shop_id)
