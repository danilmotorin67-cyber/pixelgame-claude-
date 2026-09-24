class_name CombatWorld
extends RefCounted

# The fight of 17.4-17.5 as a model: the keeper, enemies, bosses and shots in pixels, walls from a
# walkable callable. Scenes mirror it; tests drive it with a scripted keeper. Deterministic per seed.
const TILE := 16.0
const CONTACT := 12.0

var walkable: Callable
var rng := RandomNumberGenerator.new()
var time: float = 0.0
var underwater: bool = true
var player := {"pos": Vector2.ZERO, "hp": 100.0, "max_hp": 100.0, "facing": Vector2.RIGHT, "invuln": 0.0, "dodge_t": 0.0,
	"dodge_cd": 0.0, "attack_cd": 0.0, "held": 0.0, "stun": 0.0, "blind": 0.0, "push": Vector2.ZERO, "lantern": false,
	"stolen": [], "down": false}
var enemies: Array = []
var shots: Array = []
var drops: Array = []
var events: Array = []
var boss: Dictionary = {}
var next_id: int = 1


func _init(seed_value: int = 1, walk: Callable = Callable()) -> void:
	rng.seed = seed_value
	walkable = walk if walk.is_valid() else func(_p: Vector2) -> bool: return true


static func cfg(key: String) -> Variant:
	return Game.balance("combat", {}).get(key)


static func enemy_info(kind: String) -> Dictionary:
	return Data.by_id("enemies", kind)


# ---- setup ----

func spawn(kind: String, at: Vector2, level: int = 1) -> Dictionary:
	var info := enemy_info(kind)
	var scale := 1.0 + float(Game.balance("deep", {}).get("endless_scale", 0.05)) * float(maxi(0, level - 60))
	var e := {"id": next_id, "kind": kind, "pos": at, "home": at, "hp": float(info.get("hp", 10)) * scale,
		"max_hp": float(info.get("hp", 10)) * scale, "damage": float(info.get("damage", 5)) * scale, "state": "idle", "timer": rng.randf_range(0.5, 2.0),
		"vel": Vector2.ZERO, "invuln": 0.0, "stun": 0.0, "hidden": str(info.get("behavior", "")) == "ambusher", "facing": Vector2.LEFT,
		"cool": 0.0, "carry": ""}
	next_id += 1
	enemies.append(e)
	return e


func alive() -> Array:
	return enemies.filter(func(e: Dictionary) -> bool: return float(e["hp"]) > 0.0 or bool(enemy_info(str(e["kind"])).get("invulnerable", false)))


func hostile_count() -> int:
	var n := 0
	for e in enemies:
		if not bool(enemy_info(str(e["kind"])).get("invulnerable", false)) and float(e["hp"]) > 0.0:
			n += 1
	if not boss.is_empty() and float(boss["hp"]) > 0.0:
		n += 1
	return n


# ---- the keeper ----

func weapon(id: String) -> Dictionary:
	var w := Data.by_id("weapons", id)
	return w if not w.is_empty() else Data.by_id("weapons", "oar")


func attack_cooldown(weapon_id: String) -> float:
	var speed := str(weapon(weapon_id).get("speed", "medium"))
	var base := float(cfg("speeds").get(speed, 0.55))
	return base * (float(Game.balance("deep", {}).get("attack_slow", 1.2)) if underwater else 1.0)


func roll_damage(weapon_id: String, target_kind: String) -> float:
	var w := weapon(weapon_id)
	var span: Array = w.get("damage", [3, 6])
	var dmg := rng.randf_range(float(span[0]), float(span[1]))
	dmg *= 1.0 + float(cfg("per_diving_level")) * float(Skills.level("diving"))
	dmg *= 1.0 + Game.effect("damage") + (0.15 if Skills.has_profession("deep_hunter") else 0.0)
	if str(enemy_info(target_kind).get("kind", target_kind)) == "drowned":
		dmg *= 1.0 + float(w.get("bonus", {}).get("drowned", 0.0))
	dmg *= float(enemy_info(target_kind).get("weapon_mult", 1.0))
	var crit := float(cfg("crit")) + (0.1 if Skills.has_profession("harpooner") else 0.0)
	if rng.randf() < crit:
		dmg *= float(cfg("crit_mult"))
	return dmg


# A swing (an arc in front) or a shot for ranged weapons; returns the ids hit.
func attack(weapon_id: String) -> Array:
	if float(player["attack_cd"]) > 0.0 or float(player["held"]) > 0.0 or float(player["stun"]) > 0.0 or bool(player["down"]):
		return []
	var w := weapon(weapon_id)
	if bool(w.get("underwater_only", false)) and not underwater:
		return []
	player["attack_cd"] = attack_cooldown(weapon_id)
	if int(w.get("ranged", 0)) > 0:
		if w.has("ammo") and not Inventory.take(str(w["ammo"]), 1):
			return []
		shots.append({"from": "player", "pos": player["pos"], "dir": (player["facing"] as Vector2).normalized(), "speed": 260.0,
			"range": float(w["ranged"]) * TILE, "travel": 0.0, "weapon": weapon_id, "pierce": bool(w.get("pierce", false)), "hit": []})
		return []
	var reach := float(w.get("reach", 1)) * TILE + CONTACT + float(w.get("area", 0.0)) * TILE
	var hit: Array = []
	for e in alive():
		var to: Vector2 = (e["pos"] as Vector2) - (player["pos"] as Vector2)
		if to.length() > reach or bool(e["hidden"]):
			continue
		if w.has("area") or to.length() < 6.0 or (player["facing"] as Vector2).normalized().dot(to.normalized()) > 0.4:
			_hit_enemy(e, weapon_id, to.normalized())
			hit.append(int(e["id"]))
	if not boss.is_empty():
		var to_boss: Vector2 = (boss["pos"] as Vector2) - (player["pos"] as Vector2)
		if to_boss.length() <= reach + float(boss.get("radius", 20.0)):
			_hit_boss(weapon_id)
			hit.append(0)
	return hit


func _hit_enemy(e: Dictionary, weapon_id: String, dir: Vector2) -> void:
	var info := enemy_info(str(e["kind"]))
	if bool(info.get("invulnerable", false)):
		if str(info["behavior"]) == "thief" and str(e["carry"]) != "":
			_return_stolen(e)
		return
	if float(e["invuln"]) > 0.0:
		return
	var dmg := roll_damage(weapon_id, str(e["kind"]))
	if str(info["behavior"]) == "armored" and (e["facing"] as Vector2).dot(-dir) > 0.3:
		dmg *= 0.2
	e["hp"] = float(e["hp"]) - dmg
	e["invuln"] = 0.15
	e["pos"] = (e["pos"] as Vector2) + dir * float(cfg("knockback")) * 0.25
	if Game.effect("stun_chance") > 0.0 and rng.randf() < Game.effect("stun_chance"):
		e["stun"] = 1.0
	if weapon(weapon_id).has("stun"):
		e["stun"] = float(weapon(weapon_id)["stun"])
	events.append({"t": time, "event": "hit", "id": e["id"], "damage": dmg})
	if float(e["hp"]) <= 0.0:
		_kill(e)


func _kill(e: Dictionary) -> void:
	var info := enemy_info(str(e["kind"]))
	events.append({"t": time, "event": "kill", "id": e["id"], "kind": e["kind"]})
	Skills.add_xp("diving", int(info.get("xp", 5)))
	for entry in info.get("loot", []):
		if rng.randf() < float(entry[3]):
			drops.append({"item": str(entry[0]), "count": rng.randi_range(int(entry[1]), int(entry[2])), "pos": e["pos"]})
	enemies.erase(e)


func dodge() -> bool:
	if float(player["dodge_cd"]) > 0.0 or float(player["held"]) > 0.0:
		return false
	player["dodge_t"] = float(cfg("dodge_invuln"))
	player["dodge_cd"] = float(cfg("dodge_cooldown"))
	player["invuln"] = maxf(float(player["invuln"]), float(cfg("dodge_invuln")))
	return true


func hurt_player(amount: float, from: Vector2, stun: float = 0.0) -> bool:
	if float(player["invuln"]) > 0.0 or bool(player["down"]):
		return false
	amount *= maxf(0.1, 1.0 - Game.effect("defense"))
	player["hp"] = float(player["hp"]) - amount
	player["invuln"] = float(cfg("invuln"))
	player["push"] = ((player["pos"] as Vector2) - from).normalized() * float(cfg("knockback"))
	player["stun"] = maxf(float(player["stun"]), stun)
	events.append({"t": time, "event": "hurt", "damage": amount})
	if float(player["hp"]) <= 0.0:
		player["hp"] = 0.0
		player["down"] = true
	return true


# ---- the world moves ----

func step(delta: float) -> void:
	time += delta
	for key in ["invuln", "dodge_t", "dodge_cd", "attack_cd", "held", "stun", "blind"]:
		player[key] = maxf(0.0, float(player[key]) - delta)
	for e in alive():
		e["invuln"] = maxf(0.0, float(e["invuln"]) - delta)
		e["cool"] = maxf(0.0, float(e["cool"]) - delta)
		if float(e["stun"]) > 0.0:
			e["stun"] = float(e["stun"]) - delta
			continue
		_think(e, delta)
	if bool(player["lantern"]):
		_light(delta)
	_move_shots(delta)
	if not boss.is_empty():
		_boss_step(delta)


func _move(e: Dictionary, v: Vector2, delta: float, through_walls: bool = false) -> void:
	var pos: Vector2 = e["pos"]
	var nx := pos + Vector2(v.x * delta, 0)
	if through_walls or bool(walkable.call(nx)):
		pos = nx
	var ny := pos + Vector2(0, v.y * delta)
	if through_walls or bool(walkable.call(ny)):
		pos = ny
	e["pos"] = pos
	if v.length() > 1.0:
		e["facing"] = v.normalized()


func _think(e: Dictionary, delta: float) -> void:
	var info := enemy_info(str(e["kind"]))
	var speed := float(info.get("speed", 1.0)) * 40.0
	var pos: Vector2 = e["pos"]
	var ppos: Vector2 = player["pos"]
	var to := ppos - pos
	var dist := to.length()
	e["timer"] = float(e["timer"]) - delta
	var touching := dist < CONTACT
	match str(info.get("behavior", "")):
		"dasher":
			if str(e["state"]) == "dash":
				_move(e, e["vel"], delta)
				if float(e["timer"]) <= 0.0:
					e["state"] = "idle"
					e["timer"] = 1.6
			elif dist < 3.0 * TILE and float(e["timer"]) <= 0.0:
				e["state"] = "dash"
				e["vel"] = to.normalized() * speed * 3.0
				e["timer"] = 0.4
			elif dist < 8.0 * TILE:
				_move(e, Vector2(-to.y, to.x).normalized() * speed * 0.5 + to.normalized() * speed * 0.4, delta)
		"drifter":
			if float(e["timer"]) <= 0.0:
				e["vel"] = Vector2.from_angle(rng.randf() * TAU) * speed
				e["timer"] = rng.randf_range(1.5, 3.0)
			_move(e, e["vel"], delta)
		"ambusher":
			if bool(e["hidden"]):
				if dist < 2.5 * TILE:
					e["hidden"] = false
					e["state"] = "lunge"
					e["vel"] = to.normalized() * speed * 2.5
					e["timer"] = 0.5
			elif str(e["state"]) == "lunge":
				_move(e, e["vel"], delta)
				if float(e["timer"]) <= 0.0:
					e["state"] = "back"
			else:
				var home: Vector2 = e["home"]
				_move(e, (home - pos).normalized() * speed, delta)
				if pos.distance_to(home) < 4.0:
					e["hidden"] = true
					e["state"] = "idle"
		"swarm", "pack", "tank":
			if dist < 10.0 * TILE:
				var jitter := Vector2.from_angle(rng.randf() * TAU) * speed * 0.4
				_move(e, to.normalized() * speed + jitter, delta)
		"grabber", "subdue":
			if dist < 10.0 * TILE:
				_move(e, to.normalized() * speed, delta)
			if touching and float(player["invuln"]) <= 0.0 and float(e["cool"]) <= 0.0:
				player["held"] = 1.5
				e["cool"] = 3.0
		"phaser", "shooter":
			if dist < 12.0 * TILE:
				_move(e, to.normalized() * speed * (0.6 if str(info["behavior"]) == "shooter" and dist < 4.0 * TILE else 1.0), delta, true)
			if str(info["behavior"]) == "shooter" and dist < 6.0 * TILE and float(e["cool"]) <= 0.0:
				e["cool"] = 3.0
				shots.append({"from": "enemy", "pos": pos, "dir": to.normalized(), "speed": 110.0, "range": 7.0 * TILE, "travel": 0.0,
					"damage": float(e["damage"]), "hit": []})
		"armored":
			if dist < 10.0 * TILE:
				var want := to.normalized()
				var face: Vector2 = e["facing"]
				e["facing"] = face.slerp(want, clampf(delta * 1.5, 0.0, 1.0)).normalized()
				var keep_facing: Vector2 = e["facing"]
				_move(e, keep_facing * speed, delta)
				e["facing"] = keep_facing
		"inker":
			if dist < 4.0 * TILE and float(e["cool"]) <= 0.0:
				player["blind"] = 3.0
				e["cool"] = 6.0
				events.append({"t": time, "event": "ink", "id": e["id"]})
			elif dist < 10.0 * TILE and dist > 1.5 * TILE:
				_move(e, to.normalized() * speed, delta)
			if dist < 1.8 * TILE and float(e["timer"]) <= 0.0:
				hurt_player(float(e["damage"]), pos)
				e["timer"] = 1.2
		"pulser":
			if str(e["state"]) == "charge":
				if float(e["timer"]) <= 0.0:
					e["state"] = "idle"
					e["cool"] = 4.0
					if dist < 2.5 * TILE:
						hurt_player(float(e["damage"]), pos, 1.0)
			elif dist < 2.5 * TILE and float(e["cool"]) <= 0.0:
				e["state"] = "charge"
				e["timer"] = 1.0
				events.append({"t": time, "event": "charge", "id": e["id"]})
		"lurer":
			if dist < 3.0 * TILE and float(e["cool"]) <= 0.0:
				e["cool"] = 3.0
				e["vel"] = to.normalized() * speed * 3.0
				e["state"] = "lunge"
				e["timer"] = 0.4
			if str(e["state"]) == "lunge":
				_move(e, e["vel"], delta)
				if float(e["timer"]) <= 0.0:
					e["state"] = "idle"
		"thief":
			if str(e["carry"]) == "":
				_move(e, to.normalized() * speed, delta)
				if touching:
					_steal(e)
			else:
				_move(e, -to.normalized() * speed * 0.8, delta)
				if float(e["timer"]) <= 0.0:
					e["carry"] = ""
					enemies.erase(e)
					events.append({"t": time, "event": "thief_gone"})
					return
		"snare":
			if touching and float(e["cool"]) <= 0.0:
				player["held"] = 2.0
				e["cool"] = 4.0
			return
		"vent":
			if dist < 1.2 * TILE and float(e["timer"]) <= 0.0:
				hurt_player(float(e["damage"]), pos)
				e["timer"] = 1.0
			return
		"snatcher":
			if dist < 8.0 * TILE:
				_move(e, to.normalized() * speed, delta, true)
	if touching and str(info.get("behavior", "")) not in ["thief", "snare", "vent", "subdue", "pulser", "inker"]:
		hurt_player(float(e["damage"]), pos)


func _steal(e: Dictionary) -> void:
	for index in Inventory.capacity:
		var slot: Dictionary = Inventory.slots[index]
		if str(slot["id"]) != "" and str(Data.by_id("items", str(slot["id"])).get("category", "")) not in ["tool", "weapon"]:
			e["carry"] = str(slot["id"])
			Inventory.take_slot(index, 1)
			e["timer"] = 6.0
			events.append({"t": time, "event": "stolen", "item": e["carry"]})
			return


func _return_stolen(e: Dictionary) -> void:
	Inventory.add(str(e["carry"]), 1)
	for entry in enemy_info(str(e["kind"])).get("loot", []):
		Inventory.add(str(entry[0]), rng.randi_range(int(entry[1]), int(entry[2])))
	events.append({"t": time, "event": "returned", "item": e["carry"]})
	e["carry"] = ""
	enemies.erase(e)


# The lantern (17.4): 5 a second within 3 tiles, ×4 against the Hmar.
func _light(delta: float) -> void:
	for e in alive():
		if (e["pos"] as Vector2).distance_to(player["pos"]) <= 3.0 * TILE:
			var mult := float(enemy_info(str(e["kind"])).get("light_mult", 0.0))
			if mult > 0.0:
				e["hp"] = float(e["hp"]) - 5.0 * mult * delta
				if float(e["hp"]) <= 0.0:
					_kill(e)
	if not boss.is_empty() and str(boss["id"]) == "bone_whale":
		for node in boss["nodes"]:
			if float(node["hp"]) > 0.0 and (node["pos"] as Vector2).distance_to(player["pos"]) <= 3.0 * TILE:
				node["hp"] = float(node["hp"]) - 20.0 * delta


func _move_shots(delta: float) -> void:
	var keep: Array = []
	for s in shots:
		var step_len := float(s["speed"]) * delta
		s["pos"] = (s["pos"] as Vector2) + (s["dir"] as Vector2) * step_len
		s["travel"] = float(s["travel"]) + step_len
		var done: bool = float(s["travel"]) >= float(s["range"]) or not bool(walkable.call(s["pos"]))
		if str(s["from"]) == "player":
			for e in alive():
				if int(e["id"]) in s["hit"] or (e["pos"] as Vector2).distance_to(s["pos"]) > CONTACT:
					continue
				_hit_enemy(e, str(s["weapon"]), s["dir"])
				s["hit"].append(int(e["id"]))
				done = done or not bool(s["pierce"])
			if not boss.is_empty() and (boss["pos"] as Vector2).distance_to(s["pos"]) <= float(boss.get("radius", 20.0)) and not 0 in s["hit"]:
				_hit_boss(str(s["weapon"]))
				s["hit"].append(0)
				done = done or not bool(s["pierce"])
		elif (player["pos"] as Vector2).distance_to(s["pos"]) <= CONTACT:
			hurt_player(float(s["damage"]), s["pos"])
			done = true
		if not done:
			keep.append(s)
	shots = keep


# ---- bosses (17.5) ----

func start_boss(id: String, center: Vector2) -> Dictionary:
	var info := Data.by_id("bosses", id)
	boss = {"id": id, "pos": center, "center": center, "hp": float(info["hp"]), "max_hp": float(info["hp"]), "damage": float(info["damage"]),
		"phase": 1, "state": "idle", "timer": 2.0, "radius": 20.0, "vulnerable": true, "strikes": 0, "warning": Vector2.ZERO}
	match id:
		"mother_moray":
			boss["burrows"] = [center + Vector2(-80, -40), center + Vector2(80, -40), center + Vector2(0, 60)]
			boss["burrow"] = 0
			boss["vulnerable"] = false
			boss["state"] = "hidden"
			boss["pos"] = boss["burrows"][0]
		"bell_ringer":
			boss["radius"] = 24.0
		"bone_whale":
			boss["radius"] = 40.0
			boss["mouth"] = center + Vector2(0, 44)
			boss["nodes"] = []
			for i in 4:
				boss["nodes"].append({"pos": center + Vector2.from_angle(PI + i * PI / 3.0) * 90.0, "hp": 100.0})
			boss["vulnerable"] = false
	return boss


func boss_phase() -> int:
	var share := float(boss["hp"]) / float(boss["max_hp"])
	var phases: Array = Data.by_id("bosses", str(boss["id"]))["phases"]
	var phase := 1
	for i in phases.size():
		if share <= float(phases[i]) + 0.0001:
			phase = i + 1
	return phase


func _hit_boss(weapon_id: String) -> void:
	if float(boss["hp"]) <= 0.0 or not bool(boss["vulnerable"]):
		events.append({"t": time, "event": "boss_blocked"})
		return
	var dmg := roll_damage(weapon_id, "boss")
	if str(boss["id"]) == "bell_ringer" and boss_phase() < 3:
		dmg *= 0.4
	boss["hp"] = maxf(0.0, float(boss["hp"]) - dmg)
	events.append({"t": time, "event": "boss_hit", "damage": dmg})
	if float(boss["hp"]) <= 0.0:
		events.append({"t": time, "event": "boss_down", "id": boss["id"]})


func _boss_step(delta: float) -> void:
	if float(boss["hp"]) <= 0.0:
		return
	boss["phase"] = boss_phase()
	boss["timer"] = float(boss["timer"]) - delta
	var ppos: Vector2 = player["pos"]
	match str(boss["id"]):
		"mother_moray":
			match str(boss["state"]):
				"hidden":
					if float(boss["timer"]) <= 0.0:
						boss["burrow"] = (int(boss["burrow"]) + 1 + rng.randi_range(0, 1)) % 3
						boss["warning"] = boss["burrows"][int(boss["burrow"])]
						boss["state"] = "bubbles"
						boss["timer"] = 1.5
						events.append({"t": time, "event": "bubbles", "at": boss["warning"]})
				"bubbles":
					if float(boss["timer"]) <= 0.0:
						boss["pos"] = boss["warning"]
						boss["state"] = "out"
						boss["vulnerable"] = true
						boss["timer"] = 3.5
						if ppos.distance_to(boss["pos"]) < 1.5 * TILE + 20.0:
							hurt_player(float(boss["damage"]), boss["pos"])
						if int(boss["phase"]) >= 2 and enemies.filter(func(e: Dictionary) -> bool: return str(e["kind"]) == "moray").size() < 3:
							var m := spawn("moray", boss["pos"] + Vector2(rng.randf_range(-30, 30), 30))
							m["hidden"] = false
							m["state"] = "back"
				"out":
					if ppos.distance_to(boss["pos"]) < 20.0 + CONTACT:
						hurt_player(float(boss["damage"]) * 0.5, boss["pos"])
					if float(boss["timer"]) <= 0.0:
						boss["state"] = "hidden"
						boss["vulnerable"] = false
						boss["timer"] = 1.5
		"bell_ringer":
			match str(boss["state"]):
				"idle":
					var to := ppos - (boss["pos"] as Vector2)
					if to.length() > 40.0:
						boss["pos"] = (boss["pos"] as Vector2) + to.normalized() * 20.0 * delta
					if float(boss["timer"]) <= 0.0:
						boss["state"] = "raise"
						boss["timer"] = 1.0
						events.append({"t": time, "event": "bell_raised"})
				"raise":
					if float(boss["timer"]) <= 0.0:
						boss["strikes"] = int(boss["strikes"]) + 1
						boss["state"] = "wave"
						boss["wave"] = 0.0
						boss["timer"] = 1.2
						events.append({"t": time, "event": "bell_strike"})
						if int(boss["strikes"]) % 3 == 0 and int(boss["phase"]) < 3:
							for i in 2:
								spawn("drowned", (boss["center"] as Vector2) + Vector2(-90 + i * 180, 70))
				"wave":
					var before := float(boss["wave"])
					boss["wave"] = before + 140.0 * delta
					var d := ppos.distance_to(boss["pos"])
					if d >= before and d < float(boss["wave"]):
						hurt_player(float(boss["damage"]) * 0.6, boss["pos"], 1.0)
					if float(boss["timer"]) <= 0.0:
						boss["state"] = "idle"
						boss["timer"] = 4.0 if int(boss["phase"]) < 3 else 5.0
			if ppos.distance_to(boss["pos"]) < float(boss["radius"]) + CONTACT and str(boss["state"]) == "idle":
				hurt_player(float(boss["damage"]) * 0.5, boss["pos"])
		"bone_whale":
			var burned := true
			for node in boss["nodes"]:
				burned = burned and float(node["hp"]) <= 0.0
			if not bool(boss["vulnerable"]) and burned:
				boss["vulnerable"] = true
				boss["window"] = 10.0
				events.append({"t": time, "event": "nodes_burned"})
			if bool(boss["vulnerable"]):
				boss["window"] = float(boss["window"]) - delta
				if float(boss["window"]) <= 0.0:
					boss["vulnerable"] = false
					var regrow := 2 if int(boss["phase"]) >= 2 else 4
					for i in regrow:
						boss["nodes"][i]["hp"] = 100.0
			if str(boss["state"]) == "inhale":
				# The inhale drags at about 45 px/s — slower than the keeper swims, so it can be escaped.
				var pull := ((boss["mouth"] as Vector2) - ppos).normalized() * 45.0
				player["push"] = (player["push"] as Vector2) + pull * delta * 4.0
				if ppos.distance_to(boss["mouth"]) < 20.0 + CONTACT:
					hurt_player(float(boss["damage"]), boss["mouth"])
				if float(boss["timer"]) <= 0.0:
					boss["state"] = "idle"
					boss["timer"] = 8.0
			elif float(boss["timer"]) <= 0.0:
				boss["state"] = "inhale"
				boss["timer"] = 2.0
				events.append({"t": time, "event": "inhale"})


func boss_done() -> bool:
	return not boss.is_empty() and float(boss["hp"]) <= 0.0


# Rewards of 17.5 once the boss falls.
func boss_reward() -> Dictionary:
	var info := Data.by_id("bosses", str(boss["id"]))
	var reward: Dictionary = info.get("reward", {})
	for entry in reward.get("items", []):
		drops.append({"item": str(entry[0]), "count": int(entry[1]), "pos": boss["pos"]})
	if int(reward.get("money", 0)) > 0:
		Economy.add(int(reward["money"]))
	if reward.has("flag"):
		Game.set_flag(str(reward["flag"]))
	Game.set_flag("boss_" + str(boss["id"]))
	Skills.add_xp("diving", int(info.get("xp", 200)))
	Knowledge.add_points("sea", 10)
	return reward


# The keeper picks up what fell within reach.
func collect_drops(radius: float = 24.0) -> Array:
	var got: Array = []
	var keep: Array = []
	for d in drops:
		if (d["pos"] as Vector2).distance_to(player["pos"]) <= radius and Inventory.add(str(d["item"]), int(d["count"])) > 0:
			got.append(d)
		else:
			keep.append(d)
	drops = keep
	return got
