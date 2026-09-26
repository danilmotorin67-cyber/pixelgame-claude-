extends Area2D
class_name BuildingObject

# One of Ilm's buildings standing on the cape (21.5): the coop and barn keep their animals' products,
# the hayloft takes feed, the stable saddles the pony, the workshop door leads inside.
const LOOK := {
	"coop": {"size": Vector2(44, 34), "wall": "#b08f6c", "roof": "#8a3a2e"},
	"barn": {"size": Vector2(60, 42), "wall": "#8a3a2e", "roof": "#45464e"},
	"stable": {"size": Vector2(44, 36), "wall": "#8c6a4e", "roof": "#45464e"},
	"hayloft": {"size": Vector2(40, 38), "wall": "#c9a24a", "roof": "#6b4a32"},
	"workshop": {"size": Vector2(64, 44), "wall": "#9a9ca3", "roof": "#2f4a5c"},
	"well": {"size": Vector2(18, 18), "wall": "#9a9ca3", "roof": "#6b4a32"},
	"ice_house": {"size": Vector2(40, 28), "wall": "#dfe9ea", "roof": "#45464e"},
	"chapel": {"size": Vector2(40, 52), "wall": "#dfe9ea", "roof": "#2f4a5c"},
	"hearse": {"size": Vector2(30, 14), "wall": "#2a2a30", "roof": "#45464e"},
	"pasture": {"size": Vector2(160, 64), "wall": "#8c6a4e", "roof": ""},
}

var building: String = ""


static func home_of(id: String) -> Vector2:
	return {"coop": Vector2(890, 330), "hayloft": Vector2(965, 330), "barn": Vector2(900, 470), "stable": Vector2(985, 470),
		"workshop": Vector2(920, 600), "well": Vector2(850, 420), "ice_house": Vector2(410, 372),
		"chapel": Vector2(172, 480), "hearse": Vector2(292, 424), "pasture": Vector2(1000, 760)}.get(id, Vector2.ZERO)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = (LOOK[building]["size"] as Vector2) + Vector2(4, 4)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if building in ["coop", "barn", "stable", "hayloft", "workshop", "ice_house", "chapel"]:
		var body := StaticBody2D.new()
		var solid := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = (LOOK[building]["size"] as Vector2) - Vector2(4, 10)
		solid.shape = box
		solid.position = Vector2(0, -4)
		body.add_child(solid)
		add_child(body)


# PixelLab sprite for the building at its current level; "" keeps the drawn shape.
func sprite_id() -> String:
	var level := maxi(Buildings.level(building), 1)
	match building:
		"coop", "barn":
			return "%s_%d" % [building, mini(level, 3)]
		"hayloft":
			return "hayloft_%d" % mini(level, 2)
		"chapel":
			return "chapel_small"
		"stable", "workshop", "well", "ice_house", "hearse":
			return building
	return ""


func _draw() -> void:
	var look: Dictionary = LOOK[building]
	var size: Vector2 = look["size"]
	var top := -size / 2.0
	var art := sprite_id()
	if art != "" and BuildingArt.texture(art) != null:
		BuildingArt.draw(self, art, Vector2(0, size.y / 2.0))
		return
	if building == "pasture":
		for x in range(int(top.x), int(-top.x) + 1, 10):
			draw_rect(Rect2(x, top.y, 2, 8), Color(str(look["wall"])))
			draw_rect(Rect2(x, -top.y - 8, 2, 8), Color(str(look["wall"])))
		draw_rect(Rect2(top.x, top.y + 3, size.x, 1), Color(str(look["wall"])))
		draw_rect(Rect2(top.x, -top.y - 5, size.x, 1), Color(str(look["wall"])))
		return
	if building == "hearse":
		draw_rect(Rect2(top, size), Color(str(look["wall"])))
		draw_circle(Vector2(-9, 7), 4, Color("#6b4a32"))
		draw_circle(Vector2(9, 7), 4, Color("#6b4a32"))
		return
	if building == "well":
		draw_circle(Vector2.ZERO, 9, Color(str(look["wall"])))
		draw_circle(Vector2.ZERO, 5, Color("#2f4a5c"))
		draw_rect(Rect2(-10, -14, 20, 3), Color(str(look["roof"])))
		return
	draw_rect(Rect2(top + Vector2(0, 8), size - Vector2(0, 8)), Color(str(look["wall"])))
	draw_colored_polygon(PackedVector2Array([top + Vector2(-4, 10), Vector2(0, top.y - 6), Vector2(-top.x + 4, top.y + 10)]),
		Color(str(look["roof"])))
	draw_rect(Rect2(Vector2(-6, -top.y - 16), Vector2(12, 16)), Color("#4a3428"))
	if building == "chapel":
		draw_rect(Rect2(-1, top.y - 16, 2, 10), Color("#c9a24a"))
		draw_rect(Rect2(-4, top.y - 13, 8, 2), Color("#c9a24a"))
	if building == "hayloft":
		draw_rect(Rect2(-12, top.y + 14, 24, 6), Color("#e9d27a"))


func _hud() -> CanvasLayer:
	return get_tree().current_scene.get_node("HUD") as CanvasLayer


func _hint(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = text


func interact(_player: Player) -> void:
	match building:
		"coop", "barn":
			_open_house()
		"hayloft":
			var n := Buildings.store_feed("hay", Inventory.count_of("hay"))
			if Skills.has_profession("surf_shepherd"):
				n += Buildings.store_feed("kelp", Inventory.count_of("kelp"))
			_hint("В сеннике корма: %d из %d%s." % [Buildings.hay, Buildings.hay_capacity(), (" (+%d)" % n) if n > 0 else ""])
		"stable":
			if not Animals.has_pony():
				_hint("Конюшня пуста. Пони продаёт Маргит (с Лета 1).")
			else:
				_hint("Пони осёдлан: скорость ×1.6. E у конюшни — спешиться." if Animals.toggle_ride() else "Вы спешились.")
		"workshop":
			Router.goto_map("cape_workshop", Vector2(6 * 16 + 8, 8 * 16 + 8))
		"ice_house":
			_hint("Ледник: тела в покойницкой портятся втрое медленнее.")
		"chapel":
			_hint("Малая часовня: отпевание прямо на погосте, красота +5.")
		"hearse":
			_hint("Похоронные дроги: с пони тело везут, не сбавляя шага." if Animals.has_pony() else "Похоронные дроги ждут пони.")
		"pasture":
			_hint("Выгон: овцы и козы едят водоросли на отливе — сено не нужно.")


func _open_house() -> void:
	var rows := func() -> Array:
		var out: Array = []
		for a in Animals.herd:
			if str(Animals.kind_info(str(a["kind"])).get("home", "")) == building:
				out.append("%s (%s) · дружба %d%s%s" % [str(a["name"]), Loc.t("animal." + str(a["kind"])), int(a["friendship"]),
					" · поглажен" if int(a["petted"]) == Clock.day_index else "", " · голоден" if int(a["fed"]) < Clock.day_index - 1 else ""])
		return out
	var body := func() -> String:
		return "Мест: %d, живёт: %d. В ящике продуктов: %d. Корма в сеннике: %d." % [Buildings.capacity(building),
			Animals.count_in(building), Animals.box_count(building), Buildings.hay]
	var take := func(_panel: InfoPanel) -> String:
		var n := Animals.collect(building)
		return "Забрано: %d." % n if n > 0 else "В ящике пусто (или рюкзак полон)."
	var pet := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		var living: Array = Animals.herd.filter(func(a: Dictionary) -> bool:
			return str(Animals.kind_info(str(a["kind"])).get("home", "")) == building)
		if index < 0 or index >= living.size():
			return "Выберите животное."
		return "Погладили. Ему приятно." if Animals.pet(int(living[index]["id"])) else "Сегодня уже гладили."
	InfoPanel.open(_hud(), Loc.t("building." + building), body, [["Забрать продукты", take], ["Погладить", pet]], rows)
