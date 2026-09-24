extends Node2D

# The scene of one Deep level: rock drawn from Deep.data, walls, the ropes, finds and chests; enemies and
# bosses are drawn from the fight model each frame.
const TILE := 16
const COLORS := {"k": "#4e8a3a", "n": "#8c7a5a", "v": "#e9643a", "u": "#3a2a40"}

var _message_t: float = 0.0


func _ready() -> void:
	if not Deep.active:
		return
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	var rows: Array = Deep.data["rows"]
	for y in DeepGen.H:
		var x := 0
		while x < DeepGen.W:
			if str(rows[y])[x] == "#":
				var start := x
				while x < DeepGen.W and str(rows[y])[x] == "#":
					x += 1
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2((x - start) * TILE, TILE)
				shape.shape = rect
				shape.position = Vector2((start + x) * TILE / 2.0, y * TILE + TILE / 2.0)
				walls.add_child(shape)
			else:
				x += 1
	_spot("rope_up", Deep.data["entry"])
	_spot("rope_down", Deep.data["exit"])
	for r in Deep.data["resources"]:
		_spot("resource", Vector2i(int(r["x"]), int(r["y"])))
	for c in Deep.data["chests"]:
		_spot("chest", Vector2i(int(c["x"]), int(c["y"])))
	_hint()


func _spot(kind: String, cell: Vector2i) -> void:
	var spot := DeepSpot.new()
	spot.kind = kind
	spot.cell = cell
	spot.position = Deep.cell_center(cell)
	add_child(spot)


func _process(delta: float) -> void:
	if not Deep.active or Clock.paused:
		return
	var player := get_parent().get_node_or_null("Player") as Player
	if player == null:
		return
	Deep.world.player["facing"] = player.facing
	Deep.world.player["lantern"] = player.lantern_on
	if Deep.tick(delta, player.global_position) == "passed_out":
		Game.player_state["health"] = 50.0
		Router.goto_map("cape", Vector2(600, 360))
		return
	player.health = float(Deep.world.player["hp"])
	var picked := Deep.world.collect_drops()
	if not picked.is_empty():
		_hint("Подобрано: " + ", ".join(picked.map(func(d: Dictionary) -> String: return Crafting.item_name(str(d["item"])))))
	_message_t = maxf(0.0, _message_t - delta)
	if _message_t <= 0.0:
		_hint()
	queue_redraw()


func _hint(text: String = "") -> void:
	var hint := get_parent().get_node_or_null("HUD/Hint") as Label
	if hint == null:
		return
	if text != "":
		hint.text = text
		_message_t = 3.0
		return
	var gear := {"bell": "колокол", "suit": "скафандр", "gills": "«Жабры»"}.get(Deep.gear(), "") as String
	hint.text = "%s · Глубь %d · воздух %d/%d (%s)%s" % [Loc.t("biome." + str(Deep.data["biome"])), Deep.level, int(Deep.air),
		int(Deep.air_max()), gear, " · трос открыт" if Deep.exit_open() else ""]


func _draw() -> void:
	if not Deep.active:
		return
	var biome := Data.by_id("deep_biomes", str(Deep.data["biome"]))
	var colors: Dictionary = biome.get("colors", {})
	var floor_c := Color(str(colors.get("floor", "#2f5a5a")))
	var wall_c := Color(str(colors.get("wall", "#4a4a3e")))
	var rows: Array = Deep.data["rows"]
	for y in DeepGen.H:
		for x in DeepGen.W:
			var ch := str(rows[y])[x]
			var at := Vector2(x * TILE, y * TILE)
			draw_rect(Rect2(at, Vector2(TILE, TILE)), wall_c if ch == "#" else floor_c)
			if ch == "#" and (x + y) % 3 == 0:
				draw_rect(Rect2(at + Vector2(3, 4), Vector2(6, 2)), wall_c.lightened(0.15))
			elif COLORS.has(ch):
				draw_rect(Rect2(at + Vector2(6, 2), Vector2(3, 12)), Color(str(COLORS[ch])))
	if not Deep.debris_broken:
		var d := Deep.cell_center(Deep.data["exit"])
		draw_rect(Rect2(d - Vector2(9, 7), Vector2(18, 14)), Color("#6b5040"))
	var world := Deep.world
	for e in world.alive():
		var info := CombatWorld.enemy_info(str(e["kind"]))
		if bool(e["hidden"]):
			continue
		var c := Color("#c0392b") if float(info.get("hp", 0)) > 0 else Color("#8c8a9a")
		if str(e["kind"]).begins_with("hmar"):
			c = Color(0.7, 0.8, 0.9, 0.6)
		draw_circle(e["pos"], 6.0, c)
		if float(e["max_hp"]) > 0.0 and float(e["hp"]) < float(e["max_hp"]):
			draw_rect(Rect2((e["pos"] as Vector2) + Vector2(-7, -10), Vector2(14.0 * float(e["hp"]) / float(e["max_hp"]), 2)), Color("#e06a6a"))
	if not world.boss.is_empty() and float(world.boss["hp"]) > 0.0:
		var b := world.boss
		draw_circle(b["pos"], float(b["radius"]), Color("#5a2a3a") if bool(b["vulnerable"]) else Color("#3a2a3a"))
		for node in b.get("nodes", []):
			if float(node["hp"]) > 0.0:
				draw_circle(node["pos"], 6.0, Color("#9fe0ff"))
		if str(b.get("state", "")) == "bubbles":
			draw_circle(b["warning"], 10.0, Color(0.8, 0.9, 1.0, 0.5))
		if b.has("wave") and str(b["state"]) == "wave":
			draw_arc(b["pos"], float(b["wave"]), 0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
		draw_rect(Rect2(Vector2(40, 8) + (get_parent().get_node("Player") as Node2D).global_position - Vector2(200, 120),
			Vector2(320.0 * float(b["hp"]) / float(b["max_hp"]), 4)), Color("#e06a6a"))
	for s in world.shots:
		draw_circle(s["pos"], 2.0, Color("#dfe9ea"))
	for d in world.drops:
		draw_rect(Rect2((d["pos"] as Vector2) - Vector2(3, 3), Vector2(6, 6)), Color("#ffc85a"))
	var blind := float(world.player["blind"])
	if blind > 0.0:
		var p: Vector2 = (get_parent().get_node("Player") as Node2D).global_position
		draw_rect(Rect2(p - Vector2(400, 300), Vector2(800, 600)), Color(0.02, 0.02, 0.05, minf(0.85, blind / 2.0)))
