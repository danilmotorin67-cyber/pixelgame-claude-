extends Area2D
class_name ShoreFeature

# A rock pool, clam bubbles or a set trap/net on the shore.
var kind: String = ""
var entry: Dictionary = {}


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 14)
	collision.shape = shape
	add_child(collision)


func refresh() -> void:
	var shown := true
	match kind:
		"pool":
			shown = Sea.pool_open()
		"clam":
			shown = Sea.clams_visible()
	visible = shown
	collision_layer = 8 if shown else 0
	queue_redraw()


func _draw() -> void:
	match kind:
		"pool":
			draw_rect(Rect2(-7, -4, 14, 8), Color("#45464e"))
			draw_rect(Rect2(-5, -3, 10, 6), Color("#3f7f8f"))
			if not Sea.pools_fished.has(str(entry.get("id", ""))):
				draw_rect(Rect2(-1, -1, 2, 2), Color("#c2412d"))
		"clam":
			for dot in [Vector2(-3, 0), Vector2(1, -2), Vector2(3, 1)]:
				draw_circle(dot, 1.0, Color("#e9dcc6"))
		"trap":
			draw_rect(Rect2(-6, -5, 12, 9), Color("#6b4a32"))
			draw_rect(Rect2(-4, -3, 8, 5), Color("#2a2a30"))
			if not entry.get("catch", []).is_empty():
				draw_rect(Rect2(-2, -9, 4, 3), Color("#c2412d"))
		"longline":
			draw_circle(Vector2(0, -3), 3, Color("#e9643a"))
			draw_rect(Rect2(-7, 0, 14, 1), Color("#c9b89a"))
			if not entry.get("catch", []).is_empty():
				draw_rect(Rect2(-2, -9, 4, 3), Color("#c2412d"))
		"net":
			for x in range(-7, 8, 3):
				draw_rect(Rect2(x, -6, 1, 12), Color("#c9b89a"))
			draw_rect(Rect2(-7, -6, 14, 1), Color("#b0784a"))


func use_tool(_player: Player, tool: String) -> String:
	if kind == "clam" and tool == "tool_shovel":
		if Sea.dig_clam(entry):
			queue_free()
			return "Мия! Песок помнит, где её спрятал."
		return "Пусто."
	if kind == "pool" and tool == "hand_net":
		return _net()
	return ""


func _net() -> String:
	var got := Sea.net_pool(entry)
	queue_redraw()
	if got.is_empty():
		return "Сачком уже водили сегодня или вода не ушла." if Inventory.count_of("hand_net") > 0 else "Нужен сачок."
	var names: Array[String] = []
	for id in got:
		names.append(Loc.t(str(Data.by_id("items", str(id)).get("name", id))))
	return "В сачке: " + ", ".join(names)


func interact(_player: Player) -> void:
	var hint := get_tree().current_scene.get_node("HUD/Hint") as Label
	match kind:
		"pool":
			hint.text = _net()
		"clam":
			hint.text = "Пузырьки на песке. Копать — лопатой (ЛКМ)."
		"trap", "net", "longline":
			if entry.get("catch", []).is_empty() and kind in ["trap", "longline"] and Input.is_key_pressed(KEY_SHIFT):
				if Sea.take_up_gear(entry):
					hint.text = "Снасть убрана в рюкзак."
					queue_free()
					return
			var got := Sea.lift_gear(entry)
			if not got.is_empty():
				var names: Array[String] = []
				for item in got:
					names.append("%s ×%d" % [Loc.t(str(Data.by_id("items", str(item[0])).get("name", item[0]))), int(item[1])])
				hint.text = "Улов: " + ", ".join(names)
				if kind == "net":
					queue_free()
			elif kind == "longline":
				hint.text = "Перемёт стоит до утра. Shift+E — снять пустой."
			elif kind == "trap":
				hint.text = "Наживка на месте. Утром проверим." if Sea.bait_trap(entry) \
					else ("Ловушка ждёт утра." if bool(entry.get("baited", false)) else "Нужна наживка: рыбная, черви или мойва.")
			else:
				hint.text = "Сеть снимают на следующем отливе."
	queue_redraw()
