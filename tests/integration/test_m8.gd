extends Node

# Run with: godot --headless --path . res://tests/integration/test_m8.tscn
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fresh() -> void:
	Game.reset()
	Game.world_seed = 8
	Clock.reset()
	Weather.reset()
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Graveyard, Mail, Knowledge, Quests,
			Collections, Relationships, Cutscenes, NPCs, Buildings, Animals]:
		system.reset()
	Inventory.upgrade_capacity(36)


func _arena(seed_value: int) -> CombatWorld:
	return CombatWorld.new(seed_value, func(p: Vector2) -> bool: return Rect2(-400, -300, 800, 600).has_point(p))


# 17.4-17.5: hits, crits, invulnerability, dodges, behaviours and loot.
func _check_combat() -> void:
	_fresh()
	var w := _arena(3)
	var crab := w.spawn("crab", Vector2(20, 0))
	w.player["facing"] = Vector2.RIGHT
	var hit := w.attack("cutlass")
	_check(hit.size() == 1 and float(crab["hp"]) < 20.0, "a cutlass swing hits the crab in front")
	_check(w.attack("cutlass").is_empty(), "the next swing waits for the cooldown")
	var behind := w.spawn("jellyfish", Vector2(-20, 0))
	w.player["attack_cd"] = 0.0
	w.attack("cutlass")
	_check(float(behind["hp"]) == 10.0, "a swing does not reach behind")
	w.underwater = true
	_check(is_equal_approx(w.attack_cooldown("cutlass"), 0.55 * 1.2), "attacks are 20% slower underwater")
	w.player["invuln"] = 0.0
	_check(w.hurt_player(10, Vector2(10, 0)) and not w.hurt_player(10, Vector2(10, 0)), "0.5 s of invulnerability after a hit")
	w.player["invuln"] = 0.0
	w.player["dodge_cd"] = 0.0
	_check(w.dodge() and not w.hurt_player(10, Vector2(10, 0)) and not w.dodge(), "a dodge gives i-frames and has a cooldown")
	# hmar-things: weapons a quarter, the lantern four times
	var h := w.spawn("hmarnik", Vector2(20, 0))
	var hp0 := float(h["hp"])
	w.player["attack_cd"] = 0.0
	w.attack("oar")
	_check(hp0 - float(h["hp"]) <= 6.0 * 1.5 * 0.25 + 0.01, "weapons hurt a hmar-thing at a quarter")
	w.player["lantern"] = true
	for n in 20:
		w.step(0.1)
		w.player["pos"] = Vector2.ZERO
	_check(not w.enemies.has(h), "the lantern burns the hmar-thing away")
	w.player["lantern"] = false
	# armour: the helmeted crayfish only fears the back
	w = _arena(4)
	var cray := w.spawn("helmet_crayfish", Vector2(20, 0))
	cray["facing"] = Vector2.LEFT
	w.player["facing"] = Vector2.RIGHT
	w.attack("cutlass")
	var front := 80.0 - float(cray["hp"])
	cray["hp"] = 80.0
	cray["invuln"] = 0.0
	cray["pos"] = Vector2(20, 0)
	cray["facing"] = Vector2.RIGHT
	w.player["attack_cd"] = 0.0
	w.attack("cutlass")
	_check(front < 6.0 and 80.0 - float(cray["hp"]) > front * 2.5, "the crayfish's helmet takes the front blow (%.1f / %.1f)" % [front, 80.0 - float(cray["hp"])])
	# the silver cutlass and the drowned
	_check(w.weapon("silver_cutlass")["bonus"]["drowned"] == 0.5, "silver: +50% against the drowned")
	# loot
	w = _arena(5)
	var jelly := w.spawn("jellyfish", Vector2(16, 0))
	jelly["hp"] = 1.0
	w.attack("oar")
	_check(w.events.any(func(e: Dictionary) -> bool: return str(e["event"]) == "kill"), "the jellyfish dies")
	var got := w.collect_drops(40.0)
	_check(not w.enemies.has(jelly) and Skills.xp["diving"] > 0, "kills give diving XP")
	_check(got.size() <= 1, "loot is rolled per the enemy's table")
	# the bully seal steals and gives back
	w = _arena(6)
	Inventory.add("bread_rye", 2)
	var seal := w.spawn("seal_bully", Vector2(4, 0))
	w.step(0.1)
	_check(str(seal["carry"]) == "bread_rye" and Inventory.count_of("bread_rye") == 1, "the seal steals one item")
	seal["pos"] = Vector2(14, 0)
	w.player["attack_cd"] = 0.0
	w.attack("oar")
	_check(Inventory.count_of("bread_rye") == 2 and Inventory.count_of("sea_glass") >= 1, "catch it and it gives back, with a present")
	# a random pack of the kelp forest falls to a knife
	w = _arena(7)
	for i in 4:
		w.spawn(["crab", "jellyfish", "bullhead", "moray"][i], Vector2(80 + i * 30, (i - 2) * 30))
	Skills.levels["diving"] = 2
	w.player["max_hp"] = 110.0
	w.player["hp"] = 110.0
	_check(CombatBot.new(w, "fisher_knife").fight(120.0) == "won", "a kelp pack falls to the fisher's knife")


# "Bosses are passable": a scripted keeper with the gear of that depth wins each fight.
func _check_bosses() -> void:
	for spec in [["mother_moray", "cutlass", 5, 4], ["bell_ringer", "silver_cutlass", 7, 6], ["bone_whale", "silver_cutlass", 9, 8]]:
		_fresh()
		Skills.levels["diving"] = int(spec[2])
		Inventory.add("cod_solvik", int(spec[3]))
		var w := _arena(11)
		w.player["max_hp"] = 100.0 + 5.0 * float(spec[2])
		w.player["hp"] = w.player["max_hp"]
		w.player["pos"] = Vector2(0, 120)
		w.start_boss(str(spec[0]), Vector2.ZERO)
		var bot := CombatBot.new(w, str(spec[1]))
		var result := bot.fight(600.0)
		_check(result == "won", "%s with %s at Diving %d: %s (boss hp %d, keeper hp %d, t %.0f)" % [spec[0], spec[1], spec[2], result,
			int(w.boss["hp"]), int(w.player["hp"]), w.time])
		if result == "won":
			var money := Economy.money
			w.boss_reward()
			w.player["pos"] = w.boss["pos"]
			w.collect_drops(80.0)
			_check(Game.flag("boss_" + str(spec[0])), "%s: the victory is remembered" % spec[0])
			if str(spec[0]) == "mother_moray":
				_check(Inventory.count_of("moray_fang") == 1 and Economy.money == money + 2000, "Mother Moray: the fang and 2 000 crowns")
			if str(spec[0]) == "bone_whale":
				_check(Inventory.count_of("star_amber") == 1 and Inventory.count_of("whalebone") == 10, "the Bone Whale: star amber and whalebone")


func _run() -> void:
	_check_combat()
	_check_bosses()
	print("M8 integration: %d failure(s)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
