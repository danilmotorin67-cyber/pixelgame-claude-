extends Node2D

const TILE := 16
const REACH := 48.0

# Which garden plot of Farm.PLOTS this node shows (Agatha's beds or a greenhouse).
var plot: String = "beds"


func _ready() -> void:
	Events.farm_changed.connect(queue_redraw)
	queue_redraw()


func use_at(world_position: Vector2, player: Player) -> bool:
	var local := to_local(world_position)
	var cell := Vector2i(floori(local.x / TILE), floori(local.y / TILE))
	var size: Vector2i = Farm.PLOTS[plot]["size"]
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y or not Farm.opened.has(plot):
		return false
	var bed := Farm.get_tile(cell, plot)
	var selected := Inventory.selected_id()
	var field := Farm.is_field(plot)
	var clutter := Farm.clutter_at(cell, plot)
	# On the open field an untouched tile lets other tools (placing, mowing) have the click.
	if field and bed.is_empty() and clutter == "" and selected != "tool_hoe":
		return false
	if player.global_position.distance_to(to_global(Vector2(cell) * TILE + Vector2(8, 8))) > REACH:
		if field and bed.is_empty() and clutter == "":
			return false
		_hint("Подойди ближе к грядке.")
		return true
	if clutter != "":
		return _clear(cell, clutter, selected, player)
	if not bed.is_empty() and bool(bed["ready"]):
		if Farm.harvest(cell, plot):
			var got := Farm.last_harvest
			_hint("Собрано: %s ×%d · %s" % [_item_name(str(got["id"])), int(got["amount"]),
				Loc.t("quality.%d" % int(got["quality"]))])
		else:
			_hint("Нет места для урожая.")
		return true
	if not bed.is_empty() and Data.by_id("items", selected).has("soil"):
		match Farm.amend(cell, selected, plot):
			"ok":
				_hint("Грядка удобрена: соль %d, плодородие %d." % [int(bed["salt"]), Farm.fertility(bed)])
			"season":
				_hint("Эту грядку уже подкармливали этим в этом сезоне.")
		return true
	if selected in ["tool_hoe", "tool_can"] and player.energy <= 0.0:
		_hint("Нужен отдых, сил на работу нет.")
		return true
	if selected == "tool_hoe":
		if Farm.till(cell, plot):
			player.spend_energy("hoe")
			player.play_tool("hoe", to_global(Vector2(cell) * TILE + Vector2(8, 8)))
			var salt := int(Farm.get_tile(cell, plot)["salt"])
			_hint("Земля взрыхлена. Теперь посади семена." if salt == 0 else
				"Земля взрыхлена. Соль %d: сюда — солестойкие культуры (S%d и выше) или компост." % [salt, salt])
		else:
			_hint("Здесь уже есть грядка.")
	elif selected == "tool_can":
		if Farm.water(cell, plot):
			player.spend_energy("can")
			player.play_tool("can", to_global(Vector2(cell) * TILE + Vector2(8, 8)))
			_hint("Грядка полита.")
		else:
			_hint("Сначала взрыхли землю или дождись следующего дня.")
	elif Farm.plant(cell, selected, plot):
		_hint("Посажено: %s. Для роста нужен полив." % _item_name(selected))
	elif str(Data.by_id("items", selected).get("category", "")) == "seed" and not bed.is_empty():
		_hint("Не посадить: не сезон, грядка занята или земля слишком солёная.")
	else:
		_hint("Выбери мотыгу, лейку, семена или удобрение.")
	return true


const CLUTTER_NAMES := {"weed": "Бурьян", "rock": "Камень", "snag": "Коряга"}
const CLUTTER_TOOL_NAMES := {"weed": "коса", "rock": "кирка", "snag": "топор"}


# 13.1: weeds go to the scythe, stones to the pickaxe, snags to the axe.
func _clear(cell: Vector2i, clutter: String, selected: String, player: Player) -> bool:
	if selected != str(Farm.CLUTTER_TOOLS[clutter]):
		_hint("%s: нужна %s." % [CLUTTER_NAMES[clutter], CLUTTER_TOOL_NAMES[clutter]] if clutter != "snag"
			else "Коряга: нужен топор.")
		return true
	if player.energy <= 0.0:
		_hint("Нужен отдых, сил на работу нет.")
		return true
	player.spend_energy(str(Farm.CLUTTER_ENERGY[clutter]))
	player.play_tool("hoe", to_global(Vector2(cell) * TILE + Vector2(8, 8)))
	match Farm.clear_clutter(cell, plot, selected):
		"":
			_hint("%s поддаётся." % CLUTTER_NAMES[clutter])
		"stone":
			_hint("Камень убран: +1 камень. Расчищено %d тайлов поля." % Farm.field_clear_count())
		"driftwood":
			_hint("Коряга выкорчевана: +1 плавник. Расчищено %d тайлов поля." % Farm.field_clear_count())
		"hay":
			_hint("Бурьян скошен, в сенник +1 сено. Расчищено %d тайлов поля." % Farm.field_clear_count())
		_:
			_hint("Бурьян скошен. Расчищено %d тайлов поля." % Farm.field_clear_count())
	return true


func _item_name(id: String) -> String:
	return Loc.t(str(Data.by_id("items", id).get("name", id)))


func _hint(message: String) -> void:
	var hint := get_parent().get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = message


func _draw() -> void:
	if not Farm.opened.has(plot):
		return
	var size: Vector2i = Farm.PLOTS[plot]["size"]
	if Farm.indoor(plot):
		draw_rect(Rect2(Vector2(-6, -10), Vector2(size) * TILE + Vector2(12, 16)), Color("#b9d3d6"))
		draw_rect(Rect2(Vector2(-4, -8), Vector2(size) * TILE + Vector2(8, 12)), Color("#dfe9ea"))
		for x in range(0, size.x * TILE + 1, 32):
			draw_rect(Rect2(x - 1, -10, 2, size.y * TILE + 16), Color("#8c9a9e"))
	var field := Farm.is_field(plot)
	if field:
		_draw_stakes(size)
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var bed := Farm.get_tile(cell, plot)
			var at := Vector2(cell) * TILE
			if field and bed.is_empty():
				_draw_wild(at, cell, Farm.clutter_at(cell, plot))
				continue
			# Raised bed, furrows and damp glints remain visible around a crop.
			paint(at, 0, 0, 16, 16, Color("#2f4a30"))
			paint(at, 1, 2, 14, 12, Color("#6b4a33"))
			paint(at, 2, 2, 12, 2, Color("#b08f6c"))
			paint(at, 2, 12, 12, 2, Color("#4a3428"))
			paint(at, 2, 5, 12, 6, Color("#8c6a4e") if bed.is_empty() else
				(Color("#4a3428") if bool(bed["watered"]) else Color("#6b4a33")))
			paint(at, 3, 8, 3, 1, Color("#b08f6c") if bed.is_empty() else Color("#8c6a4e"))
			paint(at, 10, 6, 2, 1, Color("#b08f6c") if bed.is_empty() else Color("#8c6a4e"))
			if not bed.is_empty() and bool(bed["watered"]):
				paint(at, 3, 10, 3, 1, Color("#3f7f8f"))
			if bed.is_empty():
				continue
			# Salt crust: a couple of white grains on Salt 1, more on Salt 2.
			for n in int(bed["salt"]) * 2:
				paint(at, 3 + (n * 5) % 10, 3 + (n * 7) % 9, 1, 1, Color("#e8eef0"))
			if str(bed["crop"]) != "":
				var stage := Farm.stage(bed)
				if bool(bed["ready"]):
					paint(at, 5, 8, 6, 5, Color("#eadcb8"))
					paint(at, 6, 8, 3, 3, Color("#fff8e1"))
					paint(at, 4, 10, 2, 2, Color("#b08f6c"))
				paint(at, 7, 9 - stage, 2, 4 + stage, Color("#2f4a30"))
				paint(at, 5 - (stage >> 1), 7 - stage, 3 + (stage >> 1), 2, Color("#4e6e3a"))
				paint(at, 9, 7 - stage, 2 + stage, 2, Color("#7a964c"))
				if stage >= 2:
					paint(at, 6, 4 - stage, 3, 2, Color("#a9b36a"))


# Corner and edge stakes mark where the field runs.
func _draw_stakes(size: Vector2i) -> void:
	var w := size.x * TILE
	var h := size.y * TILE
	for x in range(0, w + 1, TILE * 6):
		for y in [0, h]:
			draw_rect(Rect2(Vector2(mini(x, w) - 1, y - 5), Vector2(2, 6)), Color("#6b4a32"))
	for y in range(0, h + 1, TILE * 3):
		for x in [0, w]:
			draw_rect(Rect2(Vector2(x - 1, mini(y, h) - 5), Vector2(2, 6)), Color("#6b4a32"))


func _draw_wild(at: Vector2, cell: Vector2i, clutter: String) -> void:
	var v := (cell.x * 7 + cell.y * 13) % 5
	match clutter:
		"weed":
			paint(at, 2 + v, 6, 2, 8, Color("#5d6b35"))
			paint(at, 6, 3 + v % 3, 2, 11, Color("#7a8a40"))
			paint(at, 10 - v % 2, 5, 2, 9, Color("#5d6b35"))
			paint(at, 5, 2 + v % 3, 4, 2, Color("#a9a36a"))
		"rock":
			paint(at, 3, 7, 10, 6, Color("#6f6a60"))
			paint(at, 4, 5, 7, 3, Color("#9a9ca3"))
			paint(at, 5, 5, 3, 1, Color("#c9c8c2"))
		"snag":
			paint(at, 2, 9, 12, 3, Color("#6b4a32"))
			paint(at, 3 + v, 5, 2, 5, Color("#8c6a4e"))
			paint(at, 10, 6, 3, 2, Color("#4a3428"))
		_:
			# Cleared ground: a little bare earth among the grass.
			paint(at, 4 + v, 7, 3, 2, Color("#5a4a34"))


func paint(at: Vector2, x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(x, y), Vector2(w, h)), color)
