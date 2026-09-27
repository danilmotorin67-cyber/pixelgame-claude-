extends Control
class_name KnowledgeView

# The knowledge tree of 26 drawn as a tree: six branch tabs, the nodes of the branch laid out by depth
# (a node stands right of what it requires) and joined by lines, each node a slot with the icon of
# what it opens; the card on the right tells the picked node's cost, state and gifts and opens it.
# ← → turn the branch; K or Esc closes.
const AREA := Rect2(16, 52, 320, 204)
const CARD := Rect2(340, 52, 124, 204)
const NODE := 20.0
const BRANCH_ICONS := {"lighthouse": "hud_light", "graveyard": "hud_peace", "land": "turnip", "sea": "hud_sea",
	"craft": "tab_settings", "secret": "weather_hmar"}
const BRANCH_TITLES := {"lighthouse": "Маяк", "graveyard": "Погост", "land": "Земля", "sea": "Море", "craft": "Ремесло",
	"secret": "Тайное"}
const POINT_ICONS := {"sea": "hud_sea", "land": "sorrel", "rest": "hud_peace"}
const STATE_TEXT := {"unlocked": "Открыт.", "": "Можно открыть.", "points": "Не хватает записей.",
	"requires": "Сначала — предыдущие узлы.", "story": "Ждёт событий сюжета."}
const SPECIAL := {"ritual": "ритуал розжига", "tower_repair": "ремонт башни", "red_sector": "красный сектор",
	"dissection_table": "секционный стол", "mound": "насыпь", "cross": "крест", "wheelbarrow": "тачка",
	"shroud": "саван", "keeper_word": "слово смотрителя", "talking_candle": "говорящая свеча", "compost": "компост",
	"rod": "удочка", "cutting_table": "разделочный стол", "winch": "лебёдка", "diving_bell": "водолазный колокол",
	"bell_stations": "станции колокола", "air_bag_plus": "большой воздушный мешок", "diving_suit": "скафандр",
	"depth_60": "спуск до 60", "hose_45": "шланг на 45", "hose_60": "шланг на 60", "rann_stone": "Камень Ранн",
	"lantern_wounds_hmar": "фонарь против Хмари", "tide_song": "песнь прилива", "nine_maidens": "девять дев",
	"sea_speaker": "говорящий с морем", "lamp": "лампа", "lens": "линза", "mechanism": "механизм", "signal": "сигнал"}

var branch := 0
var picked := ""
var status := ""
var _was_paused := false
var _layout := {}
var _button: Button


static func open(hud: CanvasLayer) -> KnowledgeView:
	var existing := hud.get_node_or_null("KnowledgeView")
	if existing:
		existing.free()
	var view := KnowledgeView.new()
	view.name = "KnowledgeView"
	hud.add_child(view)
	return view


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2.ZERO
	size = Screen.BASE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button = Button.new()
	_button.text = "Открыть узел"
	_button.position = Vector2(CARD.position.x + 12, CARD.end.y - 30)
	_button.size = Vector2(CARD.size.x - 24, 18)
	_button.pressed.connect(unlock_picked)
	add_child(_button)
	_relayout()


func branch_id() -> String:
	return KnowledgeBook.BRANCHES[branch]


# Depth = one more than the deepest required node of the same branch; rows follow the parents' rows.
func _relayout() -> void:
	var nodes := KnowledgeBook.nodes_of(branch_id())
	var ids := nodes.map(func(n: Dictionary) -> String: return str(n["id"]))
	var depth := {}
	var changed := true
	for n in nodes:
		depth[str(n["id"])] = 0
	while changed:
		changed = false
		for n in nodes:
			for req in n.get("requires", []):
				if str(req) in ids and int(depth[str(n["id"])]) < int(depth[str(req)]) + 1:
					depth[str(n["id"])] = int(depth[str(req)]) + 1
					changed = true
	var max_depth := 0
	for id in depth:
		max_depth = maxi(max_depth, int(depth[id]))
	var row_of := {}
	_layout.clear()
	for d in max_depth + 1:
		var column: Array = nodes.filter(func(n: Dictionary) -> bool: return int(depth[str(n["id"])]) == d)
		var key := func(n: Dictionary) -> float:
			var rows: Array = n.get("requires", []).filter(func(r: Variant) -> bool: return row_of.has(str(r))).map(
				func(r: Variant) -> float: return float(row_of[str(r)]))
			return 0.0 if rows.is_empty() else rows.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / rows.size()
		column.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return key.call(a) < key.call(b))
		var step_x := (AREA.size.x - 28.0 - NODE) / float(maxi(max_depth, 1))
		for i in column.size():
			var id := str(column[i]["id"])
			row_of[id] = (float(i) + 0.5) / float(column.size())
			var at := Vector2(AREA.position.x + 14.0 + d * step_x, AREA.position.y + 8.0 + float(row_of[id]) * (AREA.size.y - 16.0) - NODE / 2.0)
			_layout[id] = Rect2(at.round(), Vector2(NODE, NODE))
	if picked == "" or not _layout.has(picked):
		picked = ""
		for n in nodes:
			if Knowledge.blocked_reason(str(n["id"])) in ["", "points"]:
				picked = str(n["id"])
				break
		if picked == "" and not nodes.is_empty():
			picked = str(nodes[0]["id"])
	status = ""
	queue_redraw()


func unlock_picked() -> void:
	if picked == "":
		return
	var reason := Knowledge.blocked_reason(picked)
	if Knowledge.unlock_node(picked):
		status = "Открыт: %s." % Loc.t("node.%s.name" % picked)
	else:
		status = str(STATE_TEXT.get(reason, "Нельзя."))
	queue_redraw()


func close() -> void:
	Clock.paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_knowledge") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		branch = posmod(branch - 1, KnowledgeBook.BRANCHES.size())
		picked = ""
		_relayout()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		branch = posmod(branch + 1, KnowledgeBook.BRANCHES.size())
		picked = ""
		_relayout()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if p.y >= 28 and p.y < 48:
		var tab := int((p.x - 16.0) / 75.0)
		if tab >= 0 and tab < KnowledgeBook.BRANCHES.size():
			branch = tab
			picked = ""
			_relayout()
	for id in _layout:
		if (_layout[id] as Rect2).grow(2).has_point(p):
			picked = id
			status = ""
			queue_redraw()
	accept_event()


# The icon of what a node opens: its first recipe's or station's item, else the branch's sign.
func node_icon(info: Dictionary) -> Texture2D:
	for tag in info.get("unlocks", []):
		var kind := str(tag).get_slice(":", 0)
		var id := str(tag).get_slice(":", 1)
		var item := ""
		if kind == "recipe":
			item = str(Crafting._recipe(id).get("out", [id])[0])
		elif kind == "station":
			item = str(Crafting.station(id).get("item", id))
		if item != "" and ItemIcon.texture(item):
			return ItemIcon.texture(item)
	return UiKit.icon(str(BRANCH_ICONS[branch_id()]))


static func gift_text(tag: String) -> String:
	var kind := tag.get_slice(":", 0)
	var id := tag.get_slice(":", 1)
	match kind:
		"recipe":
			return "рецепт: " + Crafting.item_name(str(Crafting._recipe(id).get("out", [id])[0]))
		"station":
			return "станок: " + Crafting.item_name(str(Crafting.station(id).get("item", id)))
		"blueprint":
			return "чертёж: " + Loc.t("building." + id)
	return str(SPECIAL.get(kind, kind.replace("_", " ")))


# A HUD icon, or an item icon of that name.
func _icon(name: String, rect: Rect2) -> void:
	var tex: Texture2D = UiKit.icon(name)
	if tex == null:
		tex = ItemIcon.texture(name)
	if tex:
		draw_texture_rect(tex, rect, false)


func _text(at: Vector2, text: String, color := UiKit.PAPER, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, font_size := 8) -> void:
	draw_string(UiKit.font(), at, text, align, width, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.5))
	draw_style_box(UiKit.box("window"), Rect2(8, 4, 464, 262))
	_text(Vector2(18, 22), "Древо знаний", UiKit.GOLD, -1, HORIZONTAL_ALIGNMENT_LEFT, 16)
	# Points: sea, land, rest.
	var x := 300.0
	for kind in ["sea", "land", "rest"]:
		_icon(str(POINT_ICONS[kind]), Rect2(x, 9, 16, 16))
		_text(Vector2(x + 18, 21), str(Knowledge.points(kind)), UiKit.PAPER)
		x += 56
	# Branch tabs.
	for i in KnowledgeBook.BRANCHES.size():
		var id: String = KnowledgeBook.BRANCHES[i]
		var r := Rect2(16 + i * 75, 28, 72, 20)
		draw_style_box(UiKit.box("button_hover" if i == branch else "button"), r)
		_icon(str(BRANCH_ICONS[id]), Rect2(r.position + Vector2(4, 2), Vector2(16, 16)))
		_text(r.position + Vector2(23, 13), str(BRANCH_TITLES[id]), UiKit.GOLD if i == branch else UiKit.PAPER)
	# The tree.
	draw_style_box(UiKit.box("inset"), AREA)
	for n in KnowledgeBook.nodes_of(branch_id()):
		var to: Rect2 = _layout[str(n["id"])]
		for req in n.get("requires", []):
			if not _layout.has(str(req)):
				continue
			var from: Rect2 = _layout[str(req)]
			var color := Color("#c9a24a") if Knowledge.unlocked.has(str(req)) else Color("#45464e")
			var a := Vector2(from.end.x, from.get_center().y)
			var b := Vector2(to.position.x, to.get_center().y)
			var mid := roundf((a.x + b.x) / 2.0)
			draw_line(a, Vector2(mid, a.y), color, 1.0)
			draw_line(Vector2(mid, a.y), Vector2(mid, b.y), color, 1.0)
			draw_line(Vector2(mid, b.y), b, color, 1.0)
	for n in KnowledgeBook.nodes_of(branch_id()):
		var id := str(n["id"])
		var r: Rect2 = _layout[id]
		var state := Knowledge.blocked_reason(id)
		draw_style_box(UiKit.box("slot_selected" if state == "unlocked" else "slot"), r)
		var tint := Color.WHITE
		if state == "points":
			tint = Color(1, 1, 1, 0.6)
		elif state in ["requires", "story"]:
			tint = Color(0.6, 0.6, 0.7, 0.35)
		var tex := node_icon(n)
		if tex:
			draw_texture_rect(tex, Rect2(r.position + Vector2(2, 2), Vector2(16, 16)), false, tint)
		if state == "story":
			_text(r.position + Vector2(7, 14), "?", UiKit.GOLD)
		elif state == "":
			draw_rect(Rect2(r.end - Vector2(5, 5), Vector2(3, 3)), Color("#7ac05a"))
		if id == picked:
			draw_rect(r.grow(1), UiKit.GOLD, false, 1.0)
	# The card.
	draw_style_box(UiKit.box("tooltip"), CARD)
	if picked == "":
		return
	var info := Knowledge.node(picked)
	var cx := CARD.position.x + 9
	var w := CARD.size.x - 18
	var font := UiKit.font()
	var y := CARD.position.y + 16
	var name := Loc.t("node.%s.name" % picked)
	draw_multiline_string(font, Vector2(cx, y), name, HORIZONTAL_ALIGNMENT_LEFT, w, 8, 3, UiKit.GOLD)
	y += font.get_multiline_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, w, 8, 3).y + 2
	var state := Knowledge.blocked_reason(picked)
	_text(Vector2(cx, y), "%s · %s" % [picked, BRANCH_TITLES[branch_id()]], UiKit.MUTED, w)
	y += 11
	_text(Vector2(cx, y), str(STATE_TEXT.get(state, "")), Color("#7ac05a") if state in ["", "unlocked"] else Color("#e0a070"), w)
	y += 12
	var cost: Dictionary = info.get("cost", {})
	var cost_x := cx
	var any := false
	for kind in cost:
		if int(cost[kind]) <= 0:
			continue
		any = true
		_icon(str(POINT_ICONS[kind]), Rect2(cost_x, y - 9, 12, 12))
		var enough := Knowledge.points(kind) >= int(cost[kind])
		_text(Vector2(cost_x + 13, y), str(int(cost[kind])), UiKit.PAPER if enough else Color("#e06a6a"))
		cost_x += 36
	if not any:
		_text(Vector2(cx, y), "бесплатно", UiKit.PAPER)
	y += 14
	_text(Vector2(cx, y), "Даёт:", UiKit.MUTED)
	y += 10
	for tag in info.get("unlocks", []):
		if y > _button.position.y - 16:
			_text(Vector2(cx, y), "…", UiKit.PAPER)
			break
		var line := "• " + gift_text(str(tag))
		draw_multiline_string(font, Vector2(cx, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, 8, 2, UiKit.PAPER)
		y += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, w, 8, 2).y
	_button.disabled = state != ""
	if status != "":
		_text(Vector2(cx, _button.position.y - 4), status, UiKit.GOLD, w)
