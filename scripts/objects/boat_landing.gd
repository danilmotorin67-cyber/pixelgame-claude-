extends Area2D
class_name BoatLanding


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 20)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-14, -6, 28, 30), Color("#8c6a4e"))
	for y in range(-4, 24, 5):
		draw_rect(Rect2(-14, y, 28, 1), Color("#6b4a32"))
	if Sea.boat != "":
		draw_rect(Rect2(-8, 26, 16, 7), Color("#6b4a32"))
		draw_rect(Rect2(-6, 27, 12, 4), Color("#b08f6c"))


static func hold_lines() -> Array:
	var out: Array = []
	for slot in Sea.hold:
		if str(slot["id"]) != "":
			out.append("%s ×%d" % [Loc.t(str(Data.by_id("items", str(slot["id"])).get("name", slot["id"]))), int(slot["count"])])
	return out


func interact(_player: Player) -> void:
	var hud := get_tree().current_scene.get_node("HUD") as CanvasLayer
	var body := func() -> String:
		if Sea.boat == "":
			return "Причал смотрителя. Лодки пока нет — Ильм возьмётся за лодку Агаты."
		return "%s · корпус %d%% · трюм %d мест." % ["Ялик «Агата»" if Sea.boat == "yalik" else "Парусная шлюпка",
			int(Sea.hull), Sea.hold.size()]
	var sail := func(panel: InfoPanel) -> String:
		var reason := Sea.can_sail()
		if reason == "":
			panel.close()
			Router.goto_map("sea")
			return ""
		return {"no_boat": "Лодки нет.", "storm": "В шторм ялик не выйдет. Море сегодня не в духе."}.get(reason, "Нельзя.")
	var repair := func(_panel: InfoPanel) -> String:
		var fixed := Sea.repair_at_boathouse()
		return "Корпус +%d." % fixed if fixed > 0 else "Нужны доска и смола на каждые 10 прочности."
	var store := func(_panel: InfoPanel) -> String:
		return "В трюме." if Crafting.store({"slots": Sea.hold}, Inventory.selected_hotbar) else "Не помещается."
	var take := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		var rows: Array = []
		for i in Sea.hold.size():
			if str(Sea.hold[i]["id"]) != "":
				rows.append(i)
		if index < 0 or index >= rows.size():
			return "Выберите груз."
		return "Взято." if Crafting.retrieve({"slots": Sea.hold}, int(rows[index])) else "Рюкзак полон."
	InfoPanel.open(hud, "Причал", body, [["В море", sail], ["Починить", repair], ["В трюм", store], ["Из трюма", take]],
		func() -> Array: return hold_lines())
