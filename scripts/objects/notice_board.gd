extends Area2D
class_name NoticeBoard

# 21.2: the tavern's errand board ("errands") or the Trading House's board of the week ("orders").
var board: String = "errands"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-7, -8, 14, 12), Color("#8a7050"))
	draw_rect(Rect2(-5, -6, 4, 5), Color("#eadcb8"))
	draw_rect(Rect2(1, -6, 4, 4), Color("#fff8e1"))
	draw_rect(Rect2(-2, -1, 5, 4), Color("#eadcb8"))


func interact(_player: Player) -> void:
	var hud := get_tree().current_scene.get_node("HUD") as CanvasLayer
	if board == "orders":
		InfoPanel.open(hud, "Доска Торгового дома", Boards.order_text,
			[["Сдать товар по заказу", func(_p: InfoPanel) -> String: return Boards.hand_in_order()]])
		return
	var buttons: Array = []
	for notice in Boards.posted():
		var n: Dictionary = notice
		buttons.append(["Взять: %s" % Boards.npc_name(str(n["npc"])), func(_p: InfoPanel) -> String:
			if not Boards.take(n):
				return "Это поручение уже у вас."
			return "Поручение взято: отнести %s ×%d." % [Boards.item_name(str(n["item"])), int(n["count"])]])
	InfoPanel.open(hud, "Доска поручений", Boards.errands_text, buttons)
