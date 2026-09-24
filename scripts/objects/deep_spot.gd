extends Area2D
class_name DeepSpot

# Ropes, finds and chests on a Deep level; E interacts, a gaff or pickaxe breaks the debris on the rope.
var kind: String = ""
var cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 18)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	match kind:
		"rope_up", "rope_down":
			draw_rect(Rect2(-1, -40 if kind == "rope_up" else -8, 2, 40 if kind == "rope_up" else 16), Color("#c9b89a"))
			if kind == "rope_up" and Deep.gear() == "bell":
				draw_arc(Vector2(0, -6), 12, PI, TAU, 12, Color("#b87333"), 3.0)
		"resource":
			if not Deep.resource_at(cell).is_empty():
				draw_circle(Vector2.ZERO, 4, Color("#dfe9ea"))
		"chest":
			draw_rect(Rect2(-6, -4, 12, 8), Color("#6b4a32"))
			draw_rect(Rect2(-1, -2, 2, 2), Color("#ffc85a"))


func _say(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = text


func interact(_player: Player) -> void:
	match kind:
		"rope_up":
			Deep.surface()
			var well: Array = SeaChart.cfg("drowned_well")
			Router.goto_map("sea", Vector2(int(well[0]) * 16 + 8, int(well[1]) * 16 - 8))
		"rope_down":
			if not Deep.exit_open():
				_say({"debris": "Трос завален обломками: багор или кирка (ЛКМ).", "locked": "Трос появится, когда уровень будет зачищен.",
					"boss": "Сначала — хозяин этого уровня."}.get(str(Deep.data["exit_kind"]), "Закрыто.") as String)
				return
			match Deep.descend():
				"ok":
					Router.goto_map("deep", Deep.cell_center(Deep.data["entry"]))
				"depth":
					_say("Глубже с этим снаряжением не спуститься.")
		"resource":
			var item := Deep.take_resource(cell)
			_say("Взято: " + Crafting.item_name(item) if item != "" else "Здесь пусто (или рюкзак полон).")
			queue_redraw()
		"chest":
			var got := Deep.open_chest(cell)
			_say("Сундук: " + Crafting.item_name(got) if got != "" else "Сундук пуст.")


func use_tool(_player: Player, tool: String) -> String:
	if kind == "rope_down" and Deep.break_debris(tool):
		get_parent().queue_redraw()
		return "Обломки разбиты — трос вниз свободен."
	return ""
