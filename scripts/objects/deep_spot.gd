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


const CHESTS := {"kelp": "deep_chest_kelp", "old_solvick": "deep_chest_solvik", "bone_abyss": "deep_chest_bone"}


func _process(_delta: float) -> void:
	if kind == "resource":
		queue_redraw()


func _draw() -> void:
	match kind:
		"rope_up":
			# A bell station every few levels; the bell when the keeper dives in one; else the rope up.
			var art := "deep_station" if DeepGen.has_station(Deep.level) else ("deep_bell" if Deep.gear() == "bell" else "deep_rope_up")
			if not PropArt.draw(self, art, Vector2(0, 8)):
				draw_rect(Rect2(-1, -40, 2, 40), Color("#c9b89a"))
				if Deep.gear() == "bell":
					draw_arc(Vector2(0, -6), 12, PI, TAU, 12, Color("#b87333"), 3.0)
		"rope_down":
			if not PropArt.draw(self, "deep_rope_down", Vector2(0, 8)):
				draw_rect(Rect2(-1, -8, 2, 16), Color("#c9b89a"))
		"resource":
			var r := Deep.resource_at(cell)
			if r.is_empty():
				return
			# The find itself, bobbing a little, with a glint now and then.
			var t := Time.get_ticks_msec() / 1000.0 + float(cell.x * 7 + cell.y * 3) * 0.37
			var icon := ItemIcon.texture(str(r["item"]))
			var bob := roundf(sin(t * 2.0))
			if icon:
				draw_texture_rect(icon, Rect2(Vector2(-6, -8 + bob), Vector2(12, 12)), false)
			else:
				draw_circle(Vector2.ZERO, 4, Color("#dfe9ea"))
			if fmod(t, 3.0) < 0.25:
				draw_rect(Rect2(3, -8 + bob, 1, 3), Color(1, 1, 0.85, 0.9))
				draw_rect(Rect2(2, -7 + bob, 3, 1), Color(1, 1, 0.85, 0.9))
		"chest":
			var opened := Deep.taken.has("c%d:%d:%d" % [Deep.level, cell.x, cell.y])
			var art := "deep_chest_open" if opened else str(CHESTS.get(str(Deep.data["biome"]), "deep_chest_kelp"))
			if not PropArt.draw(self, art, Vector2(0, 7)):
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
					AudioMgr.play_sfx("bell_descent", -6.0)
					Router.goto_map("deep", Deep.cell_center(Deep.data["entry"]))
				"depth":
					_say("Глубже с этим снаряжением не спуститься.")
		"resource":
			var item := Deep.take_resource(cell)
			_say("Взято: " + Crafting.item_name(item) if item != "" else "Здесь пусто (или рюкзак полон).")
			if item != "":
				Fx.burst("pickup", global_position + Vector2(0, -4))
			queue_redraw()
		"chest":
			var got := Deep.open_chest(cell)
			_say("Сундук: " + Crafting.item_name(got) if got != "" else "Сундук пуст.")
			queue_redraw()


func use_tool(_player: Player, tool: String) -> String:
	if kind == "rope_down" and Deep.break_debris(tool):
		Fx.burst("sparks", global_position)
		Fx.burst("dust", global_position)
		get_parent().queue_redraw()
		return "Обломки разбиты — трос вниз свободен."
	return ""
