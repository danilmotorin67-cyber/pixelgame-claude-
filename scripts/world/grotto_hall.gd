extends Node2D

# One hall of the Ebb Grottoes, drawn from its rows; things to touch are GrottoSpots; crabs come from
# the fight model; the tide counts down in the hint.
const TILE := 16
const LOOK := {"#": "#3a3440", ".": "#5a5448", "P": "#2f6a7a", "M": "#2a2a40", "S": "#dfe9ea", "s": "#b9c3c6", "W": "#1f4a6a",
	"O": "#1f4a6a", "~": "#2f6a7a", "R": "#6b6058", "g": "#8c8a8a", "T": "#b9b0a0", "B": "#8c8a8a", "p": "#6b6b73", "C": "#6b4a32",
	"K": "#e4d9bd", "$": "#c9a24a", "L": "#e9a64a", "H": "#b87333", "X": "#4a3428", "F": "#8c6a4e", "G": "#9a9ca3", "E": "#4a3428", "A": "#9a9ca3"}
const TOUCH := "PMSBpgOTXFGCKR$LHE~A"

var _message_t: float = 0.0
var _synced: bool = false


func _ready() -> void:
	if not Grotto.active:
		return
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	var rows := Grotto.rows()
	for y in rows.size():
		for x in str(rows[y]).length():
			var ch := str(rows[y])[x]
			var cell := Vector2i(x, y)
			if Grotto.blocked(ch):
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(TILE, TILE)
				shape.shape = rect
				shape.position = Grotto.cell_center(cell)
				shape.name = "Wall_%d_%d" % [x, y]
				walls.add_child(shape)
			if ch in TOUCH or ch in ["<", ">"]:
				var spot := GrottoSpot.new()
				spot.cell = cell
				spot.ch = ch
				spot.position = Grotto.cell_center(cell)
				add_child(spot)
	Events.time_tick.connect(_on_tick)
	_hint()


func refresh_walls() -> void:
	var walls := get_node_or_null("Walls")
	if walls == null:
		return
	for shape in walls.get_children():
		var parts := str(shape.name).split("_")
		var ch := Grotto.tile(Vector2i(int(parts[1]), int(parts[2])))
		(shape as CollisionShape2D).disabled = not Grotto.blocked(ch)
	queue_redraw()


func _on_tick(_v: Variant = null) -> void:
	if not Grotto.active:
		return
	var result := Grotto.check_water()
	if result == "rumble":
		_hint("Гул в камне, по стенам бегут струйки: вода вернётся меньше чем через полчаса.")
	elif result.begins_with("flood"):
		var player := get_parent().get_node_or_null("Player") as Player
		if player:
			player.energy = maxf(0.0, player.energy - Grotto.flood_energy())
		var lost := result.substr(6)
		Router.goto_map("seal_shore", Grotto.ENTRANCE + Vector2(0, 16))
		Game.set_flag("grotto_flood_message")
		if lost != "":
			Game.counters["grotto_flood_day"] = Clock.day_index
		return
	if _message_t <= 0.0:
		_hint()


func _process(delta: float) -> void:
	if not Grotto.active or Clock.paused:
		return
	var player := get_parent().get_node_or_null("Player") as Player
	if player == null:
		return
	if not _synced:
		_synced = true
		Grotto.world.player["max_hp"] = player.max_health()
		Grotto.world.player["hp"] = player.health
	Grotto.world.player["pos"] = player.global_position
	Grotto.world.player["facing"] = player.facing
	Grotto.world.player["lantern"] = player.lantern_on
	Grotto.world.step(delta)
	player.health = float(Grotto.world.player["hp"])
	if bool(Grotto.world.player["down"]):
		Grotto.leave()
		Router.goto_map("seal_shore", Grotto.ENTRANCE + Vector2(0, 16))
		return
	Grotto.world.collect_drops()
	if Grotto.dive_tick(delta, player.global_position) == "gasp":
		player.global_position = Grotto.cell_center(Grotto.entry_cell())
		_hint("Воздух кончился — вы вынырнули у входа в зал.")
	_message_t = maxf(0.0, _message_t - delta)
	queue_redraw()


func _hint(text: String = "") -> void:
	var hint := get_parent().get_node_or_null("HUD/Hint") as Label
	if hint == null:
		return
	if text != "":
		hint.text = text
		_message_t = 3.0
		return
	var info := Grotto.hall_info()
	var left := Grotto.minutes_left(int(info["band"]))
	hint.text = "Зал %d «%s» · вода вернётся через %d:%02d%s" % [Grotto.hall + 1, Loc.t(str(info["name"])), left / 60, left % 60,
		(" · воздух %d" % int(Grotto.breath)) if Grotto.hall == 6 else ""]


func _draw() -> void:
	if not Grotto.active:
		return
	var rows := Grotto.rows()
	for y in rows.size():
		for x in str(rows[y]).length():
			var ch := str(rows[y])[x]
			var at := Vector2(x * TILE, y * TILE)
			draw_rect(Rect2(at, Vector2(TILE, TILE)), Color(str(LOOK.get(".", "#5a5448"))))
			if ch == "g" and Grotto.gate_open():
				continue
			if ch == "R" and Game.flag("grotto_rubble"):
				continue
			if LOOK.has(ch) and ch != ".":
				var inset := 0 if ch in ["#", "W", "O", "~", "s", "R", "g"] else 4
				draw_rect(Rect2(at + Vector2(inset, inset), Vector2(TILE - inset * 2, TILE - inset * 2)), Color(str(LOOK[ch])))
			if ch in ["<", ">"]:
				draw_rect(Rect2(at + Vector2(4, 2), Vector2(8, 12)), Color("#1e1a18"))
	for e in Grotto.world.alive():
		draw_circle(e["pos"], 6.0, Color("#c0392b"))
	if Grotto.carrying:
		var p: Vector2 = (get_parent().get_node("Player") as Node2D).global_position
		draw_circle(p + Vector2(0, -18), 5.0, Color("#8c8a8a"))
