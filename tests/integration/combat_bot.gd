class_name CombatBot
extends RefCounted

# A scripted keeper for the fight model: walks to the target, swings when it can, dodges warnings,
# burns glowing nodes with the lantern, steps away from an inhaling whale and eats when hurt.
const SPEED := 70.0

var world: CombatWorld
var weapon_id: String = "oar"
var food: String = "cod_solvik"
var bounds: Rect2 = Rect2(-400, -300, 800, 600)


func _init(w: CombatWorld, weapon: String) -> void:
	world = w
	weapon_id = weapon


func _walk(target: Vector2, delta: float, away: bool = false) -> void:
	var p: Dictionary = world.player
	if float(p["held"]) > 0.0 or float(p["stun"]) > 0.0:
		return
	var pos: Vector2 = p["pos"]
	var dir := (target - pos).normalized() * (-1.0 if away else 1.0)
	p["facing"] = (target - pos).normalized() if not away else p["facing"]
	var next := pos + dir * SPEED * delta
	if bool(world.walkable.call(next)) and bounds.has_point(next):
		p["pos"] = next


func _nearest_enemy() -> Dictionary:
	var best: Dictionary = {}
	for e in world.alive():
		if bool(CombatWorld.enemy_info(str(e["kind"])).get("invulnerable", false)):
			continue
		if best.is_empty() or (e["pos"] as Vector2).distance_to(world.player["pos"]) < (best["pos"] as Vector2).distance_to(world.player["pos"]):
			best = e
	return best


func tick(delta: float) -> void:
	var p: Dictionary = world.player
	p["pos"] = (p["pos"] as Vector2) + (p["push"] as Vector2) * delta
	p["push"] = (p["push"] as Vector2) * 0.8
	if float(p["hp"]) < float(p["max_hp"]) * 0.4 and Inventory.take(food, 1):
		p["hp"] = minf(float(p["max_hp"]), float(p["hp"]) + float(Data.by_id("items", food)["edible"]["health"]))
	var boss := world.boss
	var warn := false
	for ev in world.events.slice(maxi(0, world.events.size() - 4)):
		if float(ev["t"]) > world.time - delta * 1.5 and str(ev["event"]) in ["bell_strike", "charge", "bubbles"]:
			warn = true
	if warn:
		world.dodge()
	var target := Vector2.ZERO
	var enemy := _nearest_enemy()
	if not boss.is_empty() and float(boss["hp"]) > 0.0:
		match str(boss["id"]):
			"bone_whale":
				p["lantern"] = true
				if str(boss["state"]) == "inhale":
					_walk(boss["mouth"], delta, true)
					world.step(delta)
					return
				if not bool(boss["vulnerable"]):
					for node in boss["nodes"]:
						if float(node["hp"]) > 0.0:
							target = node["pos"]
							break
					if (target - (p["pos"] as Vector2)).length() > 2.0 * CombatWorld.TILE:
						_walk(target, delta)
					world.step(delta)
					return
				target = boss["pos"]
			"mother_moray":
				if not bool(boss["vulnerable"]):
					if not enemy.is_empty():
						target = enemy["pos"]
					else:
						target = boss["warning"] if str(boss["state"]) == "bubbles" else boss["center"]
						if str(boss["state"]) == "bubbles" and (p["pos"] as Vector2).distance_to(target) < 50.0:
							_walk(target, delta, true)
							world.step(delta)
							return
				else:
					target = boss["pos"]
			_:
				target = enemy["pos"] if not enemy.is_empty() and (enemy["pos"] as Vector2).distance_to(p["pos"]) < (boss["pos"] as Vector2).distance_to(p["pos"]) else boss["pos"]
	elif not enemy.is_empty():
		target = enemy["pos"]
	else:
		world.step(delta)
		return
	var reach := float(world.weapon(weapon_id).get("reach", 1)) * CombatWorld.TILE + CombatWorld.CONTACT - 2.0
	var radius := float(boss.get("radius", 0.0)) if not boss.is_empty() and target == boss.get("pos", Vector2.INF) else 0.0
	if (target - (p["pos"] as Vector2)).length() > reach + radius:
		_walk(target, delta)
	else:
		p["facing"] = (target - (p["pos"] as Vector2)).normalized()
		world.attack(weapon_id)
	world.step(delta)


# Runs until the fight is decided or `limit` seconds pass; returns "won", "lost" or "timeout".
func fight(limit: float = 300.0) -> String:
	var delta := 1.0 / 20.0
	var t := 0.0
	while t < limit:
		tick(delta)
		t += delta
		if bool(world.player["down"]):
			return "lost"
		if (world.boss.is_empty() and world.hostile_count() == 0) or world.boss_done():
			return "won"
	return "timeout"
