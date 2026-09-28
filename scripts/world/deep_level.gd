extends Node2D

# The scene of one Deep level: rock drawn from Deep.data, walls, the ropes, finds and chests; enemies and
# bosses are drawn from the fight model each frame.
const TILE := 16
const COLORS := {"k": "#4e8a3a", "n": "#8c7a5a", "v": "#e9643a", "u": "#3a2a40"}
# Each biome's floor-and-wall tileset and its sea-floor decor (tools/pixellab_deep_objects.py): the first
# stands on the biome's own decor marks, the rest are scattered over the floor by the level's seed.
const TILESETS := {"kelp": "tiles_deep_kelp", "old_solvick": "tiles_deep_solvik", "bone_abyss": "tiles_deep_bone"}
const DECOR := {
	"kelp": ["deep_kelp_clump", "deep_kelp_rock", "deep_kelp_starfish", "deep_kelp_shells"],
	"old_solvick": ["deep_solvik_lamp", "deep_solvik_wheel", "deep_solvik_door", "deep_solvik_chimney", "deep_solvik_sign"],
	"bone_abyss": ["deep_bone_vent", "deep_bone_rib", "deep_bone_skull", "deep_bone_coral", "deep_bone_pile"],
}

var _message_t: float = 0.0
var _cells := PackedInt32Array()


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


# The coloured blocks the level was drawn with before its tileset existed.
func _draw_plain(rows: Array) -> void:
	var colors: Dictionary = Data.by_id("deep_biomes", str(Deep.data["biome"])).get("colors", {})
	var floor_c := Color(str(colors.get("floor", "#2f5a5a")))
	var wall_c := Color(str(colors.get("wall", "#4a4a3e")))
	for y in DeepGen.H:
		for x in DeepGen.W:
			var ch := str(rows[y])[x]
			var at := Vector2(x * TILE, y * TILE)
			draw_rect(Rect2(at, Vector2(TILE, TILE)), wall_c if ch == "#" else floor_c)
			if COLORS.has(ch):
				draw_rect(Rect2(at + Vector2(6, 2), Vector2(3, 12)), Color(str(COLORS[ch])))


# Sea-floor decor: the biome's mark letter gets its signature piece; a few more lie about by the seed,
# on open floor away from walls and from the level's ropes, finds and chests.
func _draw_decor(biome_id: String, rows: Array) -> void:
	var pieces: Array = DECOR.get(biome_id, [])
	if pieces.is_empty():
		return
	var mark := str(Data.by_id("deep_biomes", biome_id).get("decor", ""))
	var busy := {}
	for key in ["resources", "chests"]:
		for thing in Deep.data[key]:
			busy[Vector2i(int(thing["x"]), int(thing["y"]))] = true
	busy[Vector2i(Deep.data["entry"])] = true
	busy[Vector2i(Deep.data["exit"])] = true
	for y in range(1, DeepGen.H - 1):
		for x in range(1, DeepGen.W - 1):
			var ch := str(rows[y])[x]
			var cell := Vector2i(x, y)
			var seed := absi(hash(Vector3i(Deep.level, x, y)))
			var piece := ""
			if ch == mark and mark != "":
				piece = str(pieces[0]) if seed % 3 != 0 else str(pieces[seed % pieces.size()])
			elif ch == "." and seed % 29 == 0 and not busy.has(cell) and _open_around(rows, x, y):
				piece = str(pieces[1 + seed % (pieces.size() - 1)])
			if piece != "":
				PropArt.draw(self, piece, Deep.cell_center(cell) + Vector2(0, 7))


func _open_around(rows: Array, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if str(rows[y + d.y])[x + d.x] == "#":
			return false
	return true


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
	var biome_id := str(Deep.data["biome"])
	var rows: Array = Deep.data["rows"]
	if _cells.is_empty():
		_cells.resize(DeepGen.W * DeepGen.H)
		for y in DeepGen.H:
			for x in DeepGen.W:
				_cells[y * DeepGen.W + x] = 1 if str(rows[y])[x] == "#" else 0
	if not WangGround.draw_cells(self, _cells, DeepGen.W, DeepGen.H, str(TILESETS.get(biome_id, ""))):
		_draw_plain(rows)
	_draw_decor(biome_id, rows)
	if not Deep.debris_broken:
		var d := Deep.cell_center(Deep.data["exit"])
		if not PropArt.draw(self, "deep_debris", d + Vector2(0, 7)):
			draw_rect(Rect2(d - Vector2(9, 7), Vector2(18, 14)), Color("#6b5040"))
	var world := Deep.world
	EnemyArt.draw_fallen(self, world)
	for e in world.alive():
		var info := CombatWorld.enemy_info(str(e["kind"]))
		if bool(e["hidden"]):
			continue
		if not EnemyArt.draw(self, e):
			var c := Color("#c0392b") if float(info.get("hp", 0)) > 0 else Color("#8c8a9a")
			if str(e["kind"]).begins_with("hmar"):
				c = Color(0.7, 0.8, 0.9, 0.6)
			draw_circle(e["pos"], 6.0, c)
		if float(e["max_hp"]) > 0.0 and float(e["hp"]) < float(e["max_hp"]):
			draw_rect(Rect2((e["pos"] as Vector2) + Vector2(-7, -10), Vector2(14.0 * float(e["hp"]) / float(e["max_hp"]), 2)), Color("#e06a6a"))
	if not world.boss.is_empty() and float(world.boss["hp"]) <= 0.0:
		EnemyArt.draw_boss_death(self, world.boss, world.time)
	if not world.boss.is_empty() and float(world.boss["hp"]) > 0.0:
		var b := world.boss
		if not EnemyArt.draw_boss(self, b):
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
