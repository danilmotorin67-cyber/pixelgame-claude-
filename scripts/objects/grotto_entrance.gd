extends Area2D
class_name GrottoEntrance

# The mouth of the Ebb Grottoes on the Seal Shore (17.6): a stone at first (pickaxe at the great ebb).


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 20)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-16, -14, 32, 20), Color("#1e1a18"))
	if not Game.flag("grotto_open"):
		draw_rect(Rect2(-14, -12, 28, 18), Color("#8c8a8a"))


func _say(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = text


func interact(_player: Player) -> void:
	match Grotto.entrance_state():
		"rock":
			_say("Камень закрывает вход. На большом отливе (с Весны 15) его можно разбить киркой.")
		"water":
			_say("Вход под водой. Гроты открываются на отливе (прилив ниже −0.4).")
		_:
			if Grotto.enter():
				Router.goto_map("grotto", Grotto.cell_center(Grotto.entry_cell()))


func use_tool(_player: Player, tool: String) -> String:
	if Grotto.break_entrance(tool):
		queue_redraw()
		return "Камень раскололся. Вход в гроты открыт."
	return "" if tool != "tool_pick" else "Камень держится — ждите большого отлива."
