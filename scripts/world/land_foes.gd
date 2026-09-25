extends Node2D
class_name LandFoes

# 17.7: on a Hmar Night the drowned, hmar-things and wet dogs come ashore — on the beaches, by the
# graveyard when Peace is under 60, at the village edge. The lighthouse beam burns and scatters them for
# 5 s, hmar-things keep out of the lantern's circle, every grown rowan on the cape means 5% fewer (≤ 25%).
static var current: CombatWorld

var map_id: String = ""
var world: CombatWorld
var _spawned_night: int = -1


static func active_now() -> bool:
	return Weather.hmar_night and (Clock.hour >= 21 or Clock.hour < 5)


static func rowan_cut() -> float:
	var grown := Crafting.objects("cape", "tree").filter(func(t: Dictionary) -> bool:
		return str(t.get("tree", "")) == "tree_rowan" and bool(t.get("grown", false))).size()
	return minf(0.25, 0.05 * float(grown))


# Where and what comes ashore on this map tonight: [[kind, at], ...].
static func spawns(map_id: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var row0 := Sea.first_row(map_id) if map_id != "cape" else 54
	var count := 0
	match map_id:
		"cape":
			count = 6
		"seal_shore", "wreck_bay", "lagoon":
			count = 4
		"village":
			count = 3
	count = int(round(float(count) * (1.0 - rowan_cut())))
	# 11.6: Peace 60+ halves the cape's Hmar creatures, 80+ ("Quiet nights") keeps them all away.
	if map_id == "cape":
		count = int(round(float(count) * Graveyard.hmar_cape_mult()))
		if Graveyard.hmar_cape_mult() <= 0.0:
			return out
	for n in count:
		var kind := "drowned" if n % 2 == 0 else "hmarnik"
		var at := Vector2(rng.randi_range(6, 60) * 16 + 8, (row0 - 2) * 16 + 8)
		if map_id == "village":
			kind = "wet_dog"
			at = Vector2(rng.randi_range(2, 10) * 16 + 8, rng.randi_range(10, 40) * 16 + 8)
		out.append([kind, at])
	if map_id == "cape" and Graveyard.peace < 60.0:
		for n in 2:
			out.append(["hmarnik", Graveyard.plot_position(rng.randi_range(0, 11))])
	return out


func _ready() -> void:
	name = "LandFoes"
	world = CombatWorld.new(Game.world_seed * 5 + Clock.day_index, func(_p: Vector2) -> bool: return true)
	world.underwater = false
	current = world


func _exit_tree() -> void:
	if current == world:
		current = null


func _process(delta: float) -> void:
	if Clock.paused:
		return
	var player := get_parent().get_node_or_null("Player") as Player
	if player == null:
		return
	if not active_now():
		if not world.enemies.is_empty():
			world.enemies.clear()
			queue_redraw()
		return
	if _spawned_night != Clock.day_index:
		_spawned_night = Clock.day_index
		var rng := RandomNumberGenerator.new()
		rng.seed = posmod(Game.world_seed * 101 + Clock.day_index * 7 + map_id.hash(), 2147483647)
		for s in spawns(map_id, rng):
			world.spawn(str(s[0]), s[1])
		world.player["max_hp"] = player.max_health()
	world.player["pos"] = player.global_position
	world.player["facing"] = player.facing
	world.player["lantern"] = player.lantern_on
	world.player["hp"] = player.health
	if map_id == "cape" and Lighthouse.lamp_on:
		_beam(delta)
	world.step(delta)
	player.health = float(world.player["hp"])
	player.velocity += world.player["push"] as Vector2
	world.player["push"] = Vector2.ZERO
	world.collect_drops()
	if bool(world.player["down"]):
		world.enemies.clear()
		world.player["down"] = false
		player.health = player.max_health() * 0.5
		Router.goto_map("cape", Vector2(600, 360))
		return
	queue_redraw()


# The beam sweeps once every 8 seconds from the lamp room; what it passes over burns and runs.
func _beam(delta: float) -> void:
	var lamp := Vector2(724, 240)
	var angle := fmod(Time.get_ticks_msec() / 1000.0 * TAU / 8.0, TAU)
	for e in world.alive():
		var to: Vector2 = (e["pos"] as Vector2) - lamp
		if to.length() < 420.0 and absf(angle_difference(to.angle(), angle)) < 0.12:
			e["hp"] = float(e["hp"]) - 30.0 * delta
			e["stun"] = 5.0
			e["pos"] = (e["pos"] as Vector2) + to.normalized() * 60.0 * delta
			if float(e["hp"]) <= 0.0:
				world._kill(e)


func _draw() -> void:
	for e in world.alive():
		var c := Color(0.7, 0.8, 0.9, 0.6) if str(e["kind"]).begins_with("hmar") else (Color("#3a4a3a") if str(e["kind"]) == "drowned" else Color("#4a4038"))
		draw_circle(e["pos"], 6.0, c)
	for d in world.drops:
		draw_rect(Rect2((d["pos"] as Vector2) - Vector2(3, 3), Vector2(6, 6)), Color("#ffc85a"))
