extends Node

# Scenes of 33.6 (heart events and story moments): a trigger (map, hours, condition) and a script of
# commands. Each scene plays once; a missed one waits for its next chance (22.2).
signal scene_finished(id: String)

var playing: bool = false
var current: String = ""
var seen: Dictionary = {}
var history: Array = []
var _overlay: ColorRect
var _was_paused: bool = false


func _ready() -> void:
	Events.map_entered.connect(func(_m: String) -> void: call_deferred("check"))
	Events.time_tick.connect(func(_m: int) -> void: check())


func reset() -> void:
	playing = false
	current = ""
	seen.clear()
	history.clear()


func all() -> Array:
	var out: Array = []
	for file in Data.tables.get("events", {}).values():
		if file is Array:
			out.append_array(file)
		elif file is Dictionary and file.has("events"):
			out.append_array(file["events"])
		elif file is Dictionary and file.has("id"):
			out.append(file)
	return out


func find(id: String) -> Dictionary:
	for e in all():
		if str(e.get("id", "")) == id:
			return e
	return {}


# Whether a scene may start here and now.
func ready_to_play(e: Dictionary, map_id: String) -> bool:
	if seen.has(str(e["id"])):
		return false
	var trigger: Dictionary = e.get("trigger", {})
	if trigger.has("map") and str(trigger["map"]) != map_id:
		return false
	if trigger.has("hours"):
		var hours: Array = trigger["hours"]
		var now := NPCs.now_minutes() / 60
		if now < int(hours[0]) or now >= int(hours[1]):
			return false
	if trigger.has("present") and not NPCs.on_map(map_id).has(str(trigger["present"])):
		return false
	return ConditionContext.check(str(trigger.get("when", "")))


func pending(map_id: String) -> String:
	var ordered := all()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("hearts", 0)) < int(b.get("hearts", 0)))
	for e in ordered:
		if not bool(e.get("manual", false)) and ready_to_play(e, map_id):
			return str(e["id"])
	return ""


func check() -> void:
	if playing or Clock.paused:
		return
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null or scene.get_node_or_null("HUD") == null or scene.get_node_or_null("Player") == null:
		return
	if DialogueBox.is_open(scene.get_node("HUD")):
		return
	var id := pending(Router.current_map)
	if id != "":
		play(id)


func _labels(script: Array) -> Dictionary:
	var out := {}
	for i in script.size():
		if str(script[i][0]) == "label":
			out[str(script[i][1])] = i
	return out


func _finish(id: String) -> void:
	seen[id] = Clock.day_index
	Game.add_stat("scenes_seen")
	Events.heart_event_seen.emit(id)
	Events.quest_event.emit("scene", id)


# Runs a scene without a screen (tests, skipping): effects apply, lines are logged, choices come from `choices`.
func simulate(id: String, choices: Array = []) -> Array:
	var e := find(id)
	var script: Array = e.get("script", [])
	var labels := _labels(script)
	var said: Array = []
	var pc := 0
	var picks := choices.duplicate()
	while pc < script.size():
		var cmd: Array = script[pc]
		pc += 1
		match str(cmd[0]):
			"say":
				said.append(str(cmd[3]))
			"choice":
				var options: Array = cmd[1]
				var pick: int = clampi(int(picks.pop_front()) if not picks.is_empty() else 0, 0, options.size() - 1)
				said.append(str(options[pick][0]))
				Effects.apply(options[pick][1])
				if options[pick].size() > 2 and str(options[pick][2]) != "":
					pc = int(labels.get(str(options[pick][2]), script.size()))
			"goto":
				pc = int(labels.get(str(cmd[1]), script.size()))
			"branch":
				if ConditionContext.check(str(cmd[1])):
					pc = int(labels.get(str(cmd[2]), script.size()))
			"effects":
				Effects.apply(cmd[1])
			"set_time":
				var parts := str(cmd[1]).split(":")
				Clock.set_time(int(parts[0]), int(parts[1]))
			"set_weather":
				Weather.set_weather(str(cmd[1]))
			"end":
				break
	_finish(id)
	history.append({"id": id, "said": said})
	return said


func play(id: String) -> void:
	var e := find(id)
	if e.is_empty() or playing:
		return
	playing = true
	current = id
	_was_paused = Clock.paused
	Clock.paused = true
	var script: Array = e.get("script", [])
	var labels := _labels(script)
	var pc := 0
	while pc < script.size():
		var cmd: Array = script[pc]
		pc += 1
		var op := str(cmd[0])
		if op == "end":
			break
		if op == "goto":
			pc = int(labels.get(str(cmd[1]), script.size()))
			continue
		if op == "branch":
			if ConditionContext.check(str(cmd[1])):
				pc = int(labels.get(str(cmd[2]), script.size()))
			continue
		if op == "say":
			var choices: Array = []
			if pc < script.size() and str(script[pc][0]) == "choice":
				choices = script[pc][1]
				pc += 1
			var box := DialogueBox.of(_hud())
			var texts: Array = []
			for option in choices:
				texts.append(Loc.t(str(option[0])))
			box.say(str(cmd[1]), str(cmd[2]), Loc.t(str(cmd[3])), texts)
			var picked: int = await box.finished
			if not choices.is_empty():
				var option: Array = choices[clampi(picked, 0, choices.size() - 1)]
				Effects.apply(option[1])
				if option.size() > 2 and str(option[2]) != "":
					pc = int(labels.get(str(option[2]), script.size()))
			continue
		if op == "choice":
			var box := DialogueBox.of(_hud())
			var texts: Array = []
			for option in cmd[1]:
				texts.append(Loc.t(str(option[0])))
			box.say("hero", "neutral", "…", texts)
			var picked: int = await box.finished
			var option: Array = cmd[1][clampi(picked, 0, (cmd[1] as Array).size() - 1)]
			Effects.apply(option[1])
			if option.size() > 2 and str(option[2]) != "":
				pc = int(labels.get(str(option[2]), script.size()))
			continue
		await _run_command(cmd)
	_fade(0.0, 0.3)
	playing = false
	current = ""
	Clock.paused = _was_paused
	_finish(id)
	scene_finished.emit(id)


func _hud() -> CanvasLayer:
	return get_tree().current_scene.get_node("HUD") as CanvasLayer


func _player() -> Node2D:
	return get_tree().current_scene.get_node_or_null("Player") as Node2D


func _actor(npc: String) -> NpcActor:
	var layer := get_tree().current_scene.get_node_or_null("NpcLayer") as NpcLayer
	if layer == null:
		return null
	layer.refresh()
	return layer.actor(npc)


func _tile(v: Variant) -> Vector2i:
	if v is Array:
		return Vector2i(int(v[0]), int(v[1]))
	return MapInfo.spot(Router.current_map, str(v))


func _set_npc(npc: String, tile: Vector2i, face: String = "", visible_: bool = true) -> void:
	var s: Dictionary = NPCs.state.get(npc, {})
	s["map"] = Router.current_map
	s["tile"] = tile
	s["away"] = false
	s["hidden"] = not visible_
	s["path"] = []
	if face != "":
		s["face"] = face
	NPCs.state[npc] = s


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _fade(alpha: float, seconds: float) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = ColorRect.new()
		_overlay.color = Color(0.03, 0.04, 0.07, 0.0)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		if get_tree().current_scene and get_tree().current_scene.get_node_or_null("HUD"):
			_hud().add_child(_overlay)
			_hud().move_child(_overlay, 0)
	if not is_instance_valid(_overlay) or not _overlay.is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", alpha, maxf(seconds, 0.01))


func _run_command(cmd: Array) -> void:
	match str(cmd[0]):
		"fade_out":
			_fade(1.0, float(cmd[1]))
			await _wait(float(cmd[1]))
		"fade_in":
			_fade(0.0, float(cmd[1]))
			await _wait(float(cmd[1]))
		"place", "spawn":
			var tile := _tile(cmd[2])
			if str(cmd[1]) == "hero":
				_player().global_position = Vector2(tile.x * 16 + 8, tile.y * 16 + 8)
			else:
				_set_npc(str(cmd[1]), tile, str(cmd[3]) if cmd.size() > 3 else "")
				var actor := _actor(str(cmd[1]))
				if actor:
					actor.snap()
		"despawn":
			var s: Dictionary = NPCs.state.get(str(cmd[1]), {})
			s["hidden"] = true
		"move":
			var tile := _tile(cmd[2])
			if str(cmd[1]) == "hero":
				var player := _player()
				var target := Vector2(tile.x * 16 + 8, tile.y * 16 + 8)
				var tween := create_tween()
				tween.tween_property(player, "global_position", target, player.global_position.distance_to(target) / 50.0)
				await tween.finished
			else:
				_set_npc(str(cmd[1]), tile)
				var actor := _actor(str(cmd[1]))
				var guard := 0.0
				while actor and is_instance_valid(actor) and actor.position.distance_to(actor.goal()) > 1.0 and guard < 6.0:
					await get_tree().process_frame
					guard += get_process_delta_time()
		"face":
			if str(cmd[1]) == "hero":
				var player := _player() as Player
				if player:
					player.facing = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(str(cmd[2]), Vector2.DOWN)
			else:
				var s: Dictionary = NPCs.state.get(str(cmd[1]), {})
				s["face"] = str(cmd[2])
		"wait":
			await _wait(float(cmd[1]))
		"emote":
			var actor := _actor(str(cmd[1]))
			if actor:
				actor.emote(str(cmd[2]))
			await _wait(0.8)
		"anim":
			var s: Dictionary = NPCs.state.get(str(cmd[1]), {})
			s["anim"] = str(cmd[2])
		"camera_pan":
			var camera := _player().get_node_or_null("Camera2D") as Camera2D
			if camera:
				var tile := _tile(cmd[1])
				var tween := create_tween()
				tween.tween_property(camera, "global_position", Vector2(tile.x * 16 + 8, tile.y * 16 + 8), float(cmd[2]) if cmd.size() > 2 else 1.0)
				await tween.finished
		"camera_follow":
			var camera := _player().get_node_or_null("Camera2D") as Camera2D
			if camera:
				var tween := create_tween()
				tween.tween_property(camera, "position", Vector2.ZERO, 0.6)
				await tween.finished
		"shake":
			var camera := _player().get_node_or_null("Camera2D") as Camera2D
			if camera and Settings.shake:
				for i in 8:
					camera.offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
					await get_tree().process_frame
				camera.offset = Vector2.ZERO
		"sound":
			AudioMgr.play_sfx(str(cmd[1]))
		"music":
			AudioMgr.play_music(str(cmd[1]))
		"effects":
			Effects.apply(cmd[1])
		"set_time":
			var parts := str(cmd[1]).split(":")
			Clock.set_time(int(parts[0]), int(parts[1]))
		"set_weather":
			Weather.set_weather(str(cmd[1]))
		"label":
			pass


func serialize() -> Dictionary:
	return {"seen": seen}


func deserialize(d: Dictionary) -> void:
	seen.clear()
	for id in d.get("seen", {}):
		seen[id] = int(d["seen"][id])
