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
var _check_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	Events.item_added.connect(func(_id: String, _n: int) -> void: play_sfx("item_get", -8.0))
	Events.money_changed.connect(func(_amount: int) -> void: play_sfx("ui_coins", -6.0))


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
	var stream := _sfx_stream(id)
	if stream == null:
		return
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	p.bus = "UI" if id in UI_SOUNDS else "SFX"
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 if id in UI_SOUNDS else randf_range(0.95, 1.05)
	p.play()


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
