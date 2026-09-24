extends Node

# The Great Tide (Q4.5) and what follows (5.6-5.7): phase 1 holds the fire (FireHold), phase 2 walks the seabed
# to the Gates and meets Halvdan, phase 3 is the choice in Rann's Halls. Then the morning's judgement (Q4.6),
# Fortuna's fate, the epilogue slides and the changed world; the postponed pact (D) sets it all a year on.
const ENDINGS := ["A", "B", "C", "D"]

# "", "fire", "path", "halls", "choice", "done"
var phase: String = ""
var hold: FireHold
var tries: int = 0
var court_done: bool = false
var epilogue_shown: bool = false


func _ready() -> void:
	Events.hour_changed.connect(_on_hour)
	Cutscenes.scene_finished.connect(_on_scene_finished)


func reset() -> void:
	phase = ""
	hold = null
	tries = 0
	court_done = false
	epilogue_shown = false


func finale_today() -> bool:
	return Clock.day_index == Story.finale_day and Story.ending in ["", "D"] and phase in ["", "fire", "path", "halls", "choice"]


# 21:00 of the Great Tide: the keeper is called to the lantern room wherever he is (a checkpoint save first).
func _on_hour(hour: int) -> void:
	if hour == 21 and finale_today() and phase == "":
		Save.save_game()
		begin()
		if get_tree() and get_tree().current_scene and get_tree().current_scene.get_node_or_null("HUD"):
			Router.goto_map("lh_4")
			call_deferred("_open_view")


func _open_view() -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.get_node_or_null("HUD"):
		FinaleView.open(scene.get_node("HUD") as CanvasLayer)


func begin() -> void:
	phase = "fire"
	tries += 1
	hold = FireHold.new(posmod(Game.world_seed * 29 + tries, 2147483647), Story.allies)
	if Story.has_ally("npc_benedict"):
		Game.set_flag("finale_blessing")


# Phase 1 is over: kept — the sea goes out; lost — Fortuna offers to forget it and start from 21:00 again.
func fire_result() -> String:
	if hold == null or not hold.done():
		return ""
	if not hold.won():
		return "lost"
	phase = "path"
	Events.quest_event.emit("finale", "fire")
	return "kept"


func retry() -> void:
	begin()


# Phase 2: the seabed path and the talk with Halvdan (its lines depend on the evidence and on Ingrid).
func path_scene() -> String:
	return "ev_story_tide_path"


func after_path() -> void:
	if phase != "path":
		return
	phase = "halls"
	Events.quest_event.emit("finale", "path")


func halls_scene() -> String:
	return "ev_story_halls"


func after_halls() -> void:
	if phase == "halls":
		phase = "choice"


func _on_scene_finished(id: String) -> void:
	if id == path_scene():
		after_path()
		Cutscenes.queue(halls_scene())
	elif id == halls_scene():
		after_halls()
		call_deferred("_open_endings")


func _open_endings() -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.get_node_or_null("HUD"):
		EndingPanel.open(scene.get_node("HUD") as CanvasLayer)


# ---- the choice (5.6) ----

func has_gills() -> bool:
	return Inventory.count_of("rann_gills") > 0 or Game.equipment.values().has("rann_gills")


# Why an ending is closed: [] when it is open.
func missing(ending: String) -> Array:
	var out: Array = []
	match ending:
		"A":
			if not Story.stone_whole:
				out.append("stone")
			if not Game.flag("twenty_buried"):
				out.append("twenty")
			if Lighthouse.fire_power < 80.0:
				out.append("light80")
			if Graveyard.peace < 70.0:
				out.append("peace70")
			if Sea.mercy < 60.0:
				out.append("sea60")
			if Game.honor < 0:
				out.append("honor")
			if not has_gills():
				out.append("gills")
			if Community.contract_active():
				out.append("neptune")
		"B":
			if not Story.stone_whole:
				out.append("stone")
			if Sea.mercy < 40.0:
				out.append("sea40")
			if not has_gills():
				out.append("gills")
		"C":
			if Lighthouse.fire_power < 70.0:
				out.append("light70")
			if Lighthouse.lens != "great_eye":
				out.append("great_eye")
	return out


func available(ending: String) -> bool:
	return missing(ending).is_empty()


# Without the gills and without 70 Light the pact is simply postponed.
func forced_postpone() -> bool:
	return not has_gills() and Lighthouse.fire_power < 70.0


func choose(ending: String) -> bool:
	if phase != "choice" or not (ending in ENDINGS) or not available(ending):
		return false
	if forced_postpone() and ending != "D":
		return false
	Story.ending = ending
	Events.quest_event.emit("finale", "choice")
	_apply(ending)
	phase = "done" if ending != "D" else ""
	return true


func _apply(ending: String) -> void:
	match ending:
		"A":
			Daughters.grant("hmar")
			Game.set_flag("title_two_seas")
			Game.set_flag("agatha_day")
			Game.set_flag("hmar_gone")
			Achievements.unlock("ach_new_pact")
		"B":
			Game.set_flag("agatha_alive")
			if Relationships.hearts_of("npc_kai") >= 8:
				Game.set_flag("kai_sacrifice")
			else:
				Story.resolution = "taken"
				Game.set_flag("halvdan_taken")
			Achievements.unlock("ach_price_of_light")
		"C":
			Game.set_flag("hmar_gone")
			Game.set_flag("ghosts_gone")
			Game.set_flag("sea_frozen")
			Sea.mercy = 0.0
			Sea.blessings.clear()
			Achievements.unlock("ach_broken_pact")
		"D":
			Story.finale_day += Clock.DAYS_PER_YEAR
			Quests.states.erase("q4_5_great_tide")
			Quests.states.erase("q4_4_drowned_night_2")
			Game.set_flag("finale_done", false)
			Game.set_flag("pact_postponed")
			Achievements.unlock("ach_postponed")
	Story.add_page(24)
	Story.update_act()


# How often the Hmar still comes: never after A and C, 30% after B.
func hmar_mult() -> float:
	if Game.flag("hmar_gone"):
		return 0.0
	if Game.flag("agatha_alive"):
		return 0.3
	return 1.0


# ---- the morning after (Q4.6): the villains, Palm's grade, Fortuna ----

func can_pardon() -> bool:
	return Relationships.hearts_of("npc_ingrid") >= 8 and Game.honor >= 30 and Story.resolution != "taken"


func judge(pardon: bool = false) -> String:
	if court_done:
		return Story.resolution
	court_done = true
	if Story.resolution != "taken":
		var n := Story.evidence_count()
		if pardon and can_pardon():
			Story.resolution = "pardon"
			Game.set_flag("dead_fire_keeper")
			Game.set_flag("artel")
		elif n >= 5:
			Story.resolution = "trial"
			Game.set_flag("artel")
			Game.set_flag("neptune_ruined")
			Game.set_flag("stern_arrested")
		elif n >= 3:
			Story.resolution = "arrest"
			Game.set_flag("poseidon_open")
		else:
			Story.resolution = "fled"
			Game.set_flag("poseidon_open")
			Sea.schedule_gift("halvdan_hat", "cape", Clock.day_index + 7)
	Events.quest_event.emit("court", Story.resolution)
	Mail.send("court.%s" % Story.resolution)
	Lighthouse.inspect()
	return Story.resolution


func fortuna_can_choose() -> bool:
	return Game.flag("eleonora_buried") and Story.fortuna_fate == ""


# Fortuna decides to stay if the friendship is special (8+); the keeper may still ask her to go.
func fortuna(release: bool) -> String:
	if not fortuna_can_choose():
		return Story.fortuna_fate
	if release:
		Story.fortuna_fate = "released"
		Achievements.unlock("ach_release_fortuna")
	else:
		Story.fortuna_fate = "stays" if Dialogue.fortuna_friendship() >= 8 else "rests"
	return Story.fortuna_fate


# ---- the epilogue slides (5.6): 6-8 pictures of how things ended ----

func epilogue_slides() -> Array:
	var slides: Array = []
	slides.append("epilogue.ending.%s" % Story.ending.to_lower())
	slides.append("epilogue.court.%s" % (Story.resolution if Story.resolution != "" else "none"))
	slides.append("epilogue.fortuna.%s" % (Story.fortuna_fate if Story.fortuna_fate != "" else "silent"))
	if Game.flag("tuve_met"):
		slides.append("epilogue.tuve.%s" % ("stays" if Game.flag("tuve_stays") else ("left" if Game.flag("tuve_left") else "sea")))
	slides.append("epilogue.community.%s" % ("all" if Community.rooms_done() >= 6 else ("some" if Community.rooms_done() > 0 else "none")))
	slides.append("epilogue.neptune.%s" % Community.neptune if Community.neptune in ["signed", "annulled", "torn"] else "epilogue.neptune.never")
	if Relationships.married_to != "":
		slides.append("epilogue.spouse")
	if int(Game.counters.get("children", 0)) > 0:
		slides.append("epilogue.children")
	Story.epilogue = slides
	return slides


func night(night_index: int) -> void:
	if phase == "done" and night_index >= Story.finale_day and not court_done:
		judge(false)
	if phase == "done" and Story.ending == "A" and Clock.day_index == Story.finale_day + 1:
		Game.set_flag("agatha_visiting")
	elif Game.flag("agatha_visiting") and Clock.day_index > Story.finale_day + 1:
		Game.set_flag("agatha_visiting", false)


# Runs the whole night without a screen (tests, "skip"): phase 1 by a bot of the given skill, scenes simulated.
func simulate(skill: float, ending: String, pardon: bool = false, release_fortuna: bool = false) -> String:
	if phase == "":
		begin()
	var guard := 0
	while phase == "fire" and guard < 6:
		hold.autoplay(skill)
		if fire_result() == "lost":
			retry()
		guard += 1
	if phase != "path":
		return "lost"
	Cutscenes.simulate(path_scene())
	after_path()
	Cutscenes.simulate(halls_scene())
	after_halls()
	var pick := ending if available(ending) and not (forced_postpone() and ending != "D") else "D"
	choose(pick)
	if pick != "D":
		judge(pardon)
		fortuna(release_fortuna)
	return pick


func serialize() -> Dictionary:
	return {"phase": phase, "tries": tries, "court_done": court_done, "epilogue_shown": epilogue_shown}


func deserialize(d: Dictionary) -> void:
	reset()
	phase = str(d.get("phase", ""))
	# A saved night in progress restarts at its checkpoint (21:00).
	if phase in ["fire", "path", "halls", "choice"]:
		phase = ""
	tries = int(d.get("tries", 0))
	court_done = bool(d.get("court_done", false))
	epilogue_shown = bool(d.get("epilogue_shown", false))
