class_name FireHold
extends RefCounted

# Q4.5, phase 1 "Hold the Fire" (21:00-01:00 of game time): storm and Hmar together. Fuel burns three times
# faster, the glass fogs, the mechanism jams, the fog signal is due every ten minutes, saboteurs climb the stairs
# and hmar-things creep to the lamp. The Queen of Kronvald passes 23:40-00:50: if the light was out longer than
# 3 minutes in that window (6 with Olaf at the telegraph), the night is lost.
const START := 21 * 60
const END := 25 * 60
const QUEEN_IN := 23 * 60 + 40
const QUEEN_OUT := 24 * 60 + 50
const DURATION := {"relight": 2.0, "refill": 4.0, "wipe": 2.0, "repair": 4.0, "stun": 2.0, "lantern": 1.0, "bell": 1.0, "water": 1.0}

var t: float = START
var fuel: float = 100.0
var glass: float = 1.0
var jammed: bool = false
var lit: bool = true
var horn_due: float = START + 10.0
var horns_missed: int = 0
var saboteurs: Array = []
var hmar: Array = []
var dark: float = 0.0
var busy: float = 0.0
var allowed: float = 3.0
var light_water: int = 0
var allies: Array = []
var events: Array = []
var rng := RandomNumberGenerator.new()
var next_saboteur: float = 22 * 60
var next_hmar: float = START + 8.0
var next_jam: float = START + 30.0
var saboteurs_left: int = 6


func _init(seed_value: int = 1, ally_list: Array = []) -> void:
	rng.seed = seed_value
	allies = ally_list.duplicate()
	if has("npc_olaf"):
		allowed = 6.0
	if has("npc_kai"):
		allowed += 1.0
	if has("npc_liv"):
		light_water = 3
	if has("npc_knud"):
		next_saboteur += 5.0
	if has("npc_rud"):
		saboteurs_left -= 1
	if has("npc_hedda"):
		saboteurs_left -= 2
	next_jam += rng.randf_range(0.0, 15.0)


func has(npc: String) -> bool:
	return allies.has(npc)


func done() -> bool:
	return t >= END


func won() -> bool:
	return done() and dark <= allowed


func burning() -> bool:
	return lit and fuel > 0.0 and glass >= 0.25


# A jammed mechanism keeps the lamp burning but the beam stands still: half as bad as darkness.
func light_ok() -> bool:
	return burning() and not jammed


func in_window() -> bool:
	return t >= QUEEN_IN and t <= QUEEN_OUT


func tick(minutes: float) -> void:
	var left := minutes
	while left > 0.0 and not done():
		var m := minf(0.5, left)
		left -= m
		_step(m)


func _step(m: float) -> void:
	t += m
	busy = maxf(0.0, busy - m)
	if lit:
		fuel = maxf(0.0, fuel - 0.9 * m)
	# The storm fogs the glass (Tuve calms the sea a step).
	glass = maxf(0.0, glass - (0.014 if has("npc_tuve") else 0.02) * m)
	if t >= next_jam:
		next_jam = t + rng.randf_range(25.0, 45.0)
		if has("npc_tora"):
			events.append([t, "jam_fixed"])
		else:
			jammed = true
			events.append([t, "jam"])
	if t >= horn_due:
		horns_missed += 1
		horn_due += 10.0
		events.append([t, "horn_missed"])
		if in_window():
			dark += 0.5
	if t >= next_saboteur and saboteurs_left > 0:
		saboteurs_left -= 1
		next_saboteur = t + rng.randf_range(28.0, 40.0) * (2.0 if has("npc_einar") else 1.0)
		saboteurs.append({"progress": 0.0})
		events.append([t, "saboteur"])
	for s in saboteurs:
		s["progress"] = float(s["progress"]) + m / 8.0
	var still: Array = []
	for s in saboteurs:
		if float(s["progress"]) >= 1.0:
			lit = false
			events.append([t, "sabotaged"])
		else:
			still.append(s)
	saboteurs = still
	if t >= next_hmar:
		next_hmar = t + rng.randf_range(12.0, 18.0)
		hmar.append({"hp": 1 if Game.flag("finale_blessing") else 2, "timer": 6.0})
	var left_hmar: Array = []
	for h in hmar:
		h["timer"] = float(h["timer"]) - m
		if float(h["timer"]) <= 0.0:
			glass = maxf(0.0, glass - 0.4)
			events.append([t, "hmar_glass"])
		else:
			left_hmar.append(h)
	hmar = left_hmar
	if in_window():
		if not burning():
			dark += m
		elif jammed:
			dark += m * 0.5


# The keeper's hands: one thing at a time, each takes a few minutes.
func act(action: String) -> bool:
	if busy > 0.0 or done():
		return false
	match action:
		"relight":
			if lit or fuel <= 0.0:
				return false
			lit = true
		"refill":
			fuel = 100.0
		"wipe":
			glass = 1.0
		"repair":
			if not jammed:
				return false
			jammed = false
		"stun":
			if saboteurs.is_empty():
				return false
			saboteurs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["progress"]) > float(b["progress"]))
			saboteurs.pop_front()
		"lantern":
			if hmar.is_empty():
				return false
			hmar[0]["hp"] = int(hmar[0]["hp"]) - 1
			if int(hmar[0]["hp"]) <= 0:
				hmar.pop_front()
		"bell":
			horn_due = t + 10.0
		"water":
			if light_water <= 0:
				return false
			light_water -= 1
			fuel = 100.0
			glass = 1.0
		_:
			return false
	busy = float(DURATION[action])
	return true


# What a keeper of this skill would do now.
func bot(skill: float) -> void:
	if busy > 0.0 or rng.randf() > 0.2 + 0.8 * skill:
		return
	var plan: Array = []
	if not lit and fuel > 0.0:
		plan.append("relight")
	if fuel < 20.0 or (fuel < 45.0 and t < QUEEN_IN and t > QUEEN_IN - 40.0):
		plan.append("water" if light_water > 0 and glass < 0.6 else "refill")
	if jammed:
		plan.append("repair")
	for s in saboteurs:
		if float(s["progress"]) > 0.5:
			plan.append("stun")
			break
	if horn_due - t <= 1.0:
		plan.append("bell")
	if not hmar.is_empty() and float(hmar[0]["timer"]) < 3.0:
		plan.append("lantern")
	if glass < 0.45 or (glass < 0.7 and t < QUEEN_IN and t > QUEEN_IN - 20.0):
		plan.append("wipe")
	if not saboteurs.is_empty():
		plan.append("stun")
	if not hmar.is_empty():
		plan.append("lantern")
	for action in plan:
		if act(str(action)):
			return


func autoplay(skill: float) -> FireHold:
	while not done():
		bot(skill)
		tick(0.5)
	return self


func status() -> String:
	var clock := int(t) % (24 * 60)
	return "%02d:%02d  топливо %d  стекло %d%%  %s%s  саботажники %d  хмарники %d  без огня %.1f/%.0f мин" % [clock / 60, clock % 60,
		int(fuel), int(glass * 100.0), "ОГОНЬ" if light_ok() else "ТЕМНО", "  (механизм заел)" if jammed else "",
		saboteurs.size(), hmar.size(), dark, allowed]
