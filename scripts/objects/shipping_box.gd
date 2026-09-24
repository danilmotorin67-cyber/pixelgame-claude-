extends Area2D
class_name ShippingBox

const WOOD := Color("#6b4a32")
const WOOD_LIGHT := Color("#8c6a4e")
const IRON := Color("#45464e")


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	if get_child_count() == 0:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 18)
		collision.shape = shape
		add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-10, -8, 20, 14), WOOD)
	draw_rect(Rect2(-10, -8, 20, 3), WOOD_LIGHT)
	draw_rect(Rect2(-10, -1, 20, 1), IRON)
	draw_rect(Rect2(-1, -6, 2, 3), IRON)


func interact(_player: Player) -> void:
	var hint: Label = get_tree().current_scene.get_node("HUD/Hint")
	if Input.is_key_pressed(KEY_SHIFT):
		hint.text = "Забрали последнее из ящика" if Economy.take_back_last() \
			else "Из ящика нечего забрать"
		return
	var index := Inventory.selected_hotbar
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	if id == "":
		hint.text = "Причальный ящик: %d кр · выберите товар на панели" % Economy.shipping_value()
		return
	var name := Loc.t(str(Data.by_id("items", id).get("name", id)))
	var count := int(slot["count"])
	if not Economy.ship_slot(index):
		hint.text = "«Чайка» такое не возьмёт: %s" % name
		return
	var when := "сегодня в 18:00" if Clock.minutes < Economy.PICKUP_MINUTE else "завтра в 18:00"
	hint.text = "В ящике: %s ×%d · «Чайка» заберёт %s · всего %d кр" % [
		name, count, when, Economy.shipping_value()]
