extends Node

# Music, ambience and sounds (spec 32). The buses are Master, Music, SFX, Ambience and UI (volumes from
# Settings). The music follows the place, the season, the hour and the weather by itself (pick): a new
# track cross-fades in, a storm or the Hmar lays its layer over it, and under water the music and the sounds
# go dull through a low-pass filter; grottoes and the chapel ring with reverb. A scene or the title screen
# may hold a track of its own (play_music) until it lets go (release_music) or the keeper changes map.
# Files are assets/audio/music/<id>.ogg, assets/audio/ambience/<id>.ogg and assets/audio/sfx/<id>(_N).ogg
# or .wav; a missing file is silence, so the game runs the same before the audio exists.
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"
const SFX_DIR := "res://assets/audio/sfx/"
const BUSES := ["Music", "SFX", "Ambience", "UI"]
const FADE := 1.6
const SILENT := -60.0
const SFX_VOICES := 8
const UI_SOUNDS := ["ui_click", "ui_back", "ui_page", "ui_coins", "ui_levelup", "ui_achievement"]
# A sound not made yet borrows another at a pitch of its own: id -> [stand-in, pitch].
const STAND_INS := {"ui_back": ["ui_click", 0.8]}

var music_id: String = ""
var ambience_id: String = ""
var layers_on: Array = []
var _forced := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _ambience: AudioStreamPlayer
var _layers := {}
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams := {}
var _last_played := {}
var _loops := {}
# Seconds until each sound of the world around the keeper comes again (_world_sounds).
var _next := {}
var _rng := RandomNumberGenerator.new()
var _was_night := false
var _ghosts_heard := {}
var _check_t := 0.0
# Without a screen (tests, servers) there is no sound: the choices are still made, nothing is played, so no
# stream is left mid-play when the engine quits.
var silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	silent = DisplayServer.get_name() == "headless"
	get_tree().auto_accept_quit = false
	_make_buses()
	for i in 2:
		_players.append(_player("Music"))
	_ambience = _player("Ambience")
	for id in _table("layers"):
		_layers[id] = _player("Ambience" if str(id).begins_with("amb_") else "Music")
	for id in ["amb_rain", "amb_wind"]:
		_layers[id] = _player("Ambience")
	for i in SFX_VOICES:
		_sfx.append(_player("SFX"))
	Events.map_entered.connect(func(_id: String) -> void:
		_forced = ""
		refresh())
	Events.hour_changed.connect(func(_h: int) -> void: refresh())
	Events.weather_changed.connect(func(_w: String) -> void: refresh())
	Events.day_started.connect(func(_d: int) -> void: refresh())
	Events.festival_started.connect(func(_f: String) -> void: refresh())
	# Moments that have a sound of their own wherever they happen.
	Events.lamp_lit.connect(func(_on_time: bool) -> void: play_sfx("lamp_light"))
	Events.achievement_unlocked.connect(func(_id: String) -> void: play_sfx("ui_achievement"))
	Events.fish_caught.connect(func(_id: String, _q: int, _s: float) -> void: play_sfx("fish_landed"))
	Events.ship_wrecked.connect(func(_ship: String) -> void: play_sfx("station_bell"))
	Events.body_buried.connect(func(_id: String, _q: int) -> void: play_sfx("grave_fill"))
	Events.item_added.connect(func(_id: String, _n: int) -> void: _item_got.call_deferred())
	Events.money_changed.connect(func(_amount: int) -> void: play_sfx("ui_coins", -6.0))
	get_tree().node_added.connect(_on_node_added)
	# The story's accents: a find, the sea's voice with a blessing, dread when a Hmar night falls.
	Events.quest_event.connect(func(what: String, _arg: String) -> void:
		if what in ["page", "evidence"]:
			play_sfx("sting_discovery", -4.0))
	Events.blessing_gained.connect(func(_id: String) -> void: play_sfx("sting_rann"))
	Events.hour_changed.connect(func(_h: int) -> void:
		var night := Clock.is_night()
		if night and not _was_night and Weather.hmar_night:
			play_sfx("sting_dread", -4.0)
		_was_night = night)


# A new thing in the pack chimes once, however many come at a time, and not over the sound of picking it up.
func _item_got() -> void:
	if not (_played_within("pickup", 200) or _played_within("item_get", 200)):
		play_sfx("item_get", -8.0)


func _played_within(id: String, msec: int) -> bool:
	return Time.get_ticks_msec() - int(_last_played.get(id, -100000)) < msec


# Every button clicks when pressed; one with the meta `sfx` plays that sound instead ("" for none).
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		b.pressed.connect(func() -> void:
			var id := str(b.get_meta("sfx", "ui_click"))
			if id != "":
				play_sfx(id))


# On quit the players let go of their streams and the cache empties, so nothing is left in use.
func _exit_tree() -> void:
	_let_go()
	_streams.clear()


# The audio thread drops a stopped stream only on its next mix, so leaving the game stops everything and
# waits a moment before quitting; closing the window goes the same way.
func quit() -> void:
	_let_go()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func _let_go() -> void:
	for p in _players + _sfx + [_ambience] + _layers.values() + _loops.values():
		var player := p as AudioStreamPlayer
		if player:
			player.stop()
			player.stream = null


func _make_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, "Master")
	for name in ["Music", "SFX", "Ambience"]:
		var index := AudioServer.get_bus_index(name)
		if AudioServer.get_bus_effect_count(index) == 0:
			var low := AudioEffectLowPassFilter.new()
			low.cutoff_hz = 900.0
			AudioServer.add_bus_effect(index, low)
			AudioServer.set_bus_effect_enabled(index, 0, false)
			if name == "SFX":
				var reverb := AudioEffectReverb.new()
				reverb.room_size = 0.7
				reverb.wet = 0.25
				AudioServer.add_bus_effect(index, reverb)
				AudioServer.set_bus_effect_enabled(index, 1, false)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = SILENT
	add_child(p)
	return p


func _process(delta: float) -> void:
	# Things no signal announces (the sail raised, a boss woken) are looked at twice a second.
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		refresh()
	_world_sounds(delta)


# Sounds of the place that no action makes: the foghorn over the fog, gulls over the shore, the rigging
# and the waves at sea, far thunder heard indoors, breath in the helmet under water.
func _world_sounds(delta: float) -> void:
	if silent or Clock.paused:
		return
	var map := Router.current_map
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") if scene else null
	var outdoors := map in Router.ISLAND_MAPS or map == "sea"
	var by_day := Clock.hour >= 6 and Clock.hour < 20
	var tower := map == "cape" or map in Router.TOWER_MAPS
	if Lighthouse.lamp_on and Lighthouse.foggy() and Lighthouse.signal_level() >= 3 and (tower or map == "sea"):
		_every("foghorn", delta, 28.0, 36.0, -4.0 if map == "cape" else -12.0)
	if by_day and Weather.current not in ["storm", "blizzard"] and map in ["cape", "seal_shore", "wreck_bay", "bird_cliffs", "lagoon", "village"]:
		_every("gulls", delta, 30.0 if map == "bird_cliffs" else 50.0, 100.0, -12.0)
	if map == "sea" and player:
		var storm := Weather.current == "storm"
		_every("wave_hit", delta, 4.0 if storm else 10.0, 8.0 if storm else 20.0, -6.0 if storm else -14.0)
		if bool(player.get("sail_up")):
			_every("rigging_creak", delta, 6.0, 14.0, -12.0)
	if Weather.current == "storm" and not outdoors and map != "deep":
		_every("thunder_far", delta, 12.0, 25.0, -8.0)
	var breathing := map == "deep" and Deep.active and Deep.gear() in ["suit", "bell"]
	if breathing:
		play_loop("helmet_breath", "helmet_breath", -10.0)
	elif looping("helmet_breath"):
		stop_loop("helmet_breath")


# A ghost come into view: its sting once a day for each ghost.
func ghost_seen(ghost_id: String) -> void:
	var key := "%s:%d" % [ghost_id, Clock.day_index]
	if not _ghosts_heard.has(key):
		_ghosts_heard[key] = true
		play_sfx("sting_ghost", -4.0)


# Plays `id` every `low`..`high` seconds (the first time after a random part of that).
func _every(id: String, delta: float, low: float, high: float, volume_db: float) -> void:
	if not _next.has(id):
		_next[id] = _rng.randf_range(low * 0.3, high)
	_next[id] = float(_next[id]) - delta
	if float(_next[id]) <= 0.0:
		_next[id] = _rng.randf_range(low, high)
		play_sfx(id, volume_db)


# --- What plays where --------------------------------------------------------------------------------------

func _table(key: String) -> Dictionary:
	return Data.tables.get("music", {}).get(key, {})


# Everything pick() looks at, read from the game as it stands.
func context() -> Dictionary:
	var map := Router.current_map
	var ctx := {"map": map, "season": Clock.season, "hour": Clock.hour, "weather": Weather.current,
		"hmar": Weather.hmar_night, "festival": str(Clock.festival_on().get("id", "")), "weekday": Clock.weekday,
		"finale": Finale.phase, "fiddle": Quests.state("g6_violin") == "done", "sail": false, "boss": "", "biome": ""}
	var scene := get_tree().current_scene if get_tree() else null
	var player := scene.get_node_or_null("Player") if scene else null
	if map == "sea" and player:
		ctx["sail"] = bool(player.get("sail_up"))
	if map == "deep" and Deep.active:
		ctx["biome"] = str(Deep.data.get("biome", ""))
		if Deep.world and not Deep.world.boss.is_empty() and float(Deep.world.boss.get("hp", 0.0)) > 0.0:
			ctx["boss"] = str(Deep.world.boss.get("id", ""))
	return ctx


# The track for a moment of the game (spec 32.2).
static func pick(ctx: Dictionary) -> String:
	var map := str(ctx.get("map", ""))
	var hour := int(ctx.get("hour", 12))
	var night := hour >= 21 or hour < 5
	var season := str(ctx.get("season", "spring"))
	match str(ctx.get("finale", "")):
		"fire":
			return "hold_the_fire"
		"path":
			return "seabed_path"
		"halls", "choice":
			return "halls_of_rann"
	if map == "deep":
		if str(ctx.get("boss", "")) != "":
			return "boss_" + str(ctx["boss"])
		return "deep_" + (str(ctx["biome"]) if str(ctx.get("biome", "")) != "" else "kelp")
	if map == "grotto":
		return "grottoes"
	if map == "sea":
		if str(ctx.get("weather", "")) == "storm":
			return "storm"
		return "sailing" if bool(ctx.get("sail", false)) else "rowing"
	if map == "lh_4":
		return "watch"
	if map == "village_tavern":
		return "tavern_fiddle" if bool(ctx.get("fiddle", false)) and str(ctx.get("weekday", "")) == "sat" and hour >= 18 else "tavern"
	if map == "village_chapel":
		return "graveyard"
	var festival := str(ctx.get("festival", ""))
	if festival != "" and (map == "village" or map.begins_with("village_")) and hour >= 8:
		return "drowned_night" if festival == "drowned_night" else "festival"
	if night:
		return "hmar" if bool(ctx.get("hmar", false)) else "night"
	if map == "village" or map.begins_with("village_"):
		return "village_" + season
	return "cape_" + season


# The music layers over the track: a storm on land, the Hmar at sea.
static func pick_layers(ctx: Dictionary) -> Array:
	var out: Array = []
	var map := str(ctx.get("map", ""))
	var hour := int(ctx.get("hour", 12))
	var outdoors := not (map.begins_with("village_") or map.begins_with("lh_") or map in ["cape_workshop", "moor_helga", "deep", "grotto"])
	if str(ctx.get("weather", "")) == "storm" and outdoors and map != "sea":
		out.append("layer_storm")
	if map == "sea" and bool(ctx.get("hmar", false)) and (hour >= 21 or hour < 5):
		out.append("layer_hmar")
	if outdoors and str(ctx.get("weather", "")) in ["rain", "storm"]:
		out.append("amb_rain")
	if outdoors and str(ctx.get("weather", "")) == "storm":
		out.append("amb_wind")
	return out


static func pick_ambience(ctx: Dictionary) -> String:
	var map := str(ctx.get("map", ""))
	var hour := int(ctx.get("hour", 12))
	match map:
		"sea":
			return "amb_sea"
		"deep":
			return "amb_underwater"
		"grotto":
			return "amb_cave"
		"village_tavern":
			return "amb_tavern"
	if map.begins_with("village_") or map.begins_with("lh_") or map in ["cape_workshop", "moor_helga"]:
		return "amb_interior"
	if hour >= 21 or hour < 5:
		return "amb_night"
	if map == "village":
		return "amb_village"
	if map in ["moor", "birch", "bird_cliffs"]:
		return "amb_moor"
	return "amb_shore"


# --- Playing ----------------------------------------------------------------------------------------------

func refresh() -> void:
	var ctx := context()
	var map := str(ctx["map"])
	_set_music(_forced if _forced != "" else pick(ctx))
	_set_ambience(pick_ambience(ctx))
	_set_layers(pick_layers(ctx))
	_set_effect("Music", 0, map == "deep")
	_set_effect("Ambience", 0, false)
	_set_effect("SFX", 0, map == "deep")
	_set_effect("SFX", 1, map in ["grotto", "village_chapel"])


# A scene, the title screen or the prologue holds a track until release_music or the next map;
# "" or "auto" lets go at once.
func play_music(id: String) -> void:
	_forced = "" if id in ["", "auto"] else id
	if is_inside_tree():
		refresh()


func release_music() -> void:
	play_music("")


func _set_music(id: String) -> void:
	if id == music_id:
		return
	music_id = id
	if silent:
		return
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	_fade(old, SILENT, true)
	var stream := _stream(MUSIC_DIR, id, _table("tracks").get(id, {}))
	if stream:
		new.stream = stream
		new.volume_db = SILENT
		new.play()
		_fade(new, 0.0)


func _set_ambience(id: String) -> void:
	if id == ambience_id:
		return
	ambience_id = id
	if silent:
		return
	var stream := _stream(AMBIENCE_DIR, id, _table("ambience").get(id, {}))
	_fade(_ambience, SILENT, true)
	if stream:
		var p := _ambience
		get_tree().create_timer(FADE).timeout.connect(func() -> void:
			if ambience_id == id:
				p.stream = stream
				p.play()
				_fade(p, -4.0))


func _set_layers(ids: Array) -> void:
	layers_on = ids
	if silent:
		return
	for id in _layers:
		var p: AudioStreamPlayer = _layers[id]
		if id in ids and not p.playing:
			var info: Dictionary = _table("layers").get(id, _table("ambience").get(id, {}))
			var stream := _stream(AMBIENCE_DIR if str(id).begins_with("amb_") else MUSIC_DIR, str(id), info)
			if stream:
				p.stream = stream
				p.volume_db = SILENT
				p.play()
				_fade(p, -3.0)
		elif not id in ids and p.playing:
			_fade(p, SILENT, true)


func _fade(p: AudioStreamPlayer, to_db: float, stop_after := false) -> void:
	if not p.playing:
		p.volume_db = to_db
		return
	var tween := create_tween()
	tween.tween_property(p, "volume_db", to_db, FADE)
	if stop_after:
		tween.tween_callback(p.stop)


func _set_effect(bus: String, effect: int, on: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0 and effect < AudioServer.get_bus_effect_count(index):
		AudioServer.set_bus_effect_enabled(index, effect, on)


# A looping stream from the folder, looping from its loop_start; null when the file is not there yet.
func _stream(dir: String, id: String, info: Dictionary) -> AudioStream:
	if id == "":
		return null
	var key := dir + id
	if _streams.has(key):
		return _streams[key]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(dir + id + ext):
			stream = load(dir + id + ext) as AudioStream
			break
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
		(stream as AudioStreamOggVorbis).loop_offset = float(info.get("loop_start", 0.0))
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(float(info.get("loop_start", 0.0)) * wav.mix_rate)
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_streams[key] = stream
	return stream


# A sound by id; `<id>_1`, `<id>_2`… are variants picked at random. Interface sounds go to the UI bus.
func play_sfx(id: String, volume_db := 0.0) -> void:
	if silent:
		return
	var stream := _sfx_stream(id)
	var pitch := 1.0
	if stream == null and STAND_INS.has(id):
		stream = _sfx_stream(str(STAND_INS[id][0]))
		pitch = float(STAND_INS[id][1])
	if stream == null:
		return
	_last_played[id] = Time.get_ticks_msec()
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	p.bus = "UI" if id in UI_SOUNDS else "SFX"
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 if id in UI_SOUNDS else randf_range(0.95, 1.05))
	p.play()


# A sound that goes on while something lasts (a reel winding, breath in a helmet, a purr), under `key` so
# the same loop is not started twice; stop_loop ends it.
func play_loop(id: String, key := "", volume_db := 0.0) -> void:
	if silent:
		return
	key = key if key != "" else id
	var p := _loops.get(key) as AudioStreamPlayer
	if p and p.playing and p.get_meta("sfx", "") == id:
		p.volume_db = volume_db
		return
	var stream := _sfx_stream(id)
	if stream == null:
		return
	if p == null:
		p = _player("SFX")
		_loops[key] = p
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	p.set_meta("sfx", id)
	p.stream = stream
	p.volume_db = volume_db
	p.play()


func stop_loop(key: String) -> void:
	var p := _loops.get(key) as AudioStreamPlayer
	if p and p.playing:
		p.stop()


func looping(key: String) -> bool:
	var p := _loops.get(key) as AudioStreamPlayer
	return p != null and p.playing


# The same, `delay` seconds from now (a bell after the candle is lit).
func play_sfx_later(id: String, delay: float, volume_db := 0.0) -> void:
	if silent:
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void: play_sfx(id, volume_db))


func _sfx_stream(id: String) -> AudioStream:
	var key := "sfx:" + id
	if not _streams.has(key):
		var variants: Array = []
		for name in [id] + range(1, 7).map(func(n: int) -> String: return "%s_%d" % [id, n]):
			for ext in [".ogg", ".wav"]:
				if ResourceLoader.exists(SFX_DIR + str(name) + ext):
					variants.append(load(SFX_DIR + str(name) + ext))
					break
		_streams[key] = variants
	var list: Array = _streams[key]
	return list[randi() % list.size()] if not list.is_empty() else null
