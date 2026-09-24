extends Area2D
class_name RannStoneObject

# The flat black boulder at the surf line under the cape; the tide covers it (12.3).


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# Reaches up the beach so the stone can be offered to from the shore at high water.
	shape.size = Vector2(28, 40)
	collision.position = Vector2(0, -12)
	collision.shape = shape
	add_child(collision)
	Events.tide_changed.connect(func(_h: float) -> void: queue_redraw())


func _draw() -> void:
	var wet := not RannStone.dry()
	draw_colored_polygon(PackedVector2Array([Vector2(-13, 4), Vector2(-9, -5), Vector2(6, -7), Vector2(14, -1),
		Vector2(11, 7), Vector2(-6, 8)]), Color("#1a1d24"))
	draw_line(Vector2(-7, -3), Vector2(8, -5), Color("#3a4150"), 1.0)
	if wet:
		draw_rect(Rect2(-15, 2, 30, 7), Color(0.36, 0.55, 0.62, 0.7))
		draw_rect(Rect2(-11, 1, 6, 1), Color("#e8f4f0"))


func interact(_player: Player) -> void:
	var hud := get_tree().current_scene.get_node("HUD") as CanvasLayer
	var body := func() -> String:
		var where := "Камень сух: подношение кладут на него." if RannStone.dry() \
			else "Камень под водой: подношение бросают в волну над ним."
		var left := RannStone.offers_left()
		return "Камень Ранн. %s\nМилость моря: %d. %s" % [where, int(Sea.mercy),
			"Сегодня можно сделать подношение." if left > 0 else "Сегодня море уже приняло дар."]
	var give := func(_panel: InfoPanel) -> String:
		return str(RannStone.offer(Inventory.selected_hotbar)["text"])
	var calm := func(_panel: InfoPanel) -> String:
		return str(RannStone.request_calm()["text"])
	var buttons: Array = [["Поднести", give]]
	if Sea.mercy >= float(RannStone.cfg().get("calm_min_mercy", 60)):
		buttons.append(["Просить штиль", calm])
	InfoPanel.open(hud, "Камень Ранн", body, buttons)
