class_name Fx
extends RefCounted

# Small particle effects in the pixel grid (CPUParticles2D, square pixels without a texture): chimney smoke
# and one-shot bursts — soil clods, dust, stone sparks, wood chips, cut grass, splashes, bubbles, ink,
# feathers, healing and level-up sparkles, the glint of a find. A burst frees itself when it is done.

# kind: [colours, amount, speed min, speed max, spread (deg), gravity y, lifetime, size min, size max, direction]
const KINDS := {
	"clod": [["#5a4030", "#7a5a3e"], 8, 20.0, 40.0, 50.0, 130.0, 0.45, 1.5, 2.5, Vector2.UP],
	"dust": [["#cdbb9a", "#b8a47e"], 10, 8.0, 18.0, 180.0, -6.0, 0.6, 1.0, 2.5, Vector2.UP],
	"sparks": [["#ffe9a8", "#ffc85a"], 12, 30.0, 60.0, 70.0, 150.0, 0.35, 1.0, 1.0, Vector2.UP],
	"chips": [["#b08f6c", "#e4d9bd"], 8, 25.0, 45.0, 60.0, 140.0, 0.5, 1.5, 2.0, Vector2.UP],
	"grass": [["#6f8f4e", "#9eae77"], 8, 15.0, 30.0, 70.0, 60.0, 0.5, 1.0, 2.0, Vector2.UP],
	"splash": [["#dfe9ea", "#9fd3e0"], 14, 25.0, 45.0, 35.0, 160.0, 0.5, 1.0, 2.0, Vector2.UP],
	"splash_small": [["#dfe9ea", "#9fd3e0"], 6, 18.0, 30.0, 35.0, 160.0, 0.4, 1.0, 1.5, Vector2.UP],
	"bubbles": [["#cfe8f0", "#9fd3e0"], 5, 8.0, 14.0, 20.0, -30.0, 1.2, 1.0, 2.0, Vector2.UP],
	"ink": [["#1e1a28", "#2e2440"], 24, 5.0, 20.0, 180.0, 0.0, 1.6, 2.5, 4.0, Vector2.UP],
	"feathers": [["#eeeeee", "#9a9ca3"], 10, 15.0, 35.0, 180.0, 25.0, 1.2, 1.5, 2.0, Vector2.UP],
	"heal": [["#8fe08a", "#dfffd0"], 10, 10.0, 18.0, 30.0, -10.0, 0.9, 1.0, 1.5, Vector2.UP],
	"levelup": [["#ffe28a", "#fff6c8"], 24, 15.0, 30.0, 40.0, -20.0, 1.2, 1.0, 2.0, Vector2.UP],
	"pickup": [["#fff6c8", "#ffe28a"], 6, 10.0, 20.0, 180.0, 0.0, 0.4, 1.0, 1.0, Vector2.UP],
}


static func _particles(colors: Array, amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.texture = null
	p.z_index = 40
	var start := Gradient.new()
	start.set_color(0, Color(str(colors[0])))
	start.set_color(1, Color(str(colors[1])))
	p.color_initial_ramp = start
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


static func _layer() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null


# The sound each burst makes (AudioMgr; silence until the file exists).
const SOUNDS := {"clod": "hoe_dig", "sparks": "pick_stone", "chips": "axe_chop", "grass": "scythe_swish",
	"splash": "splash", "splash_small": "splash_small", "bubbles": "bubbles", "ink": "octopus_ink", "feathers": "gull_down",
	"heal": "eat", "levelup": "ui_levelup", "pickup": "pickup"}


# A one-shot burst of `kind` at a world position; `sound` false leaves its sound to the caller.
static func burst(kind: String, at: Vector2, parent: Node = null, sound := true) -> void:
	var spec: Array = KINDS.get(kind, [])
	var host := parent if parent else _layer()
	if spec.is_empty() or host == null or not host.is_inside_tree():
		return
	if sound:
		AudioMgr.play_sfx(str(SOUNDS.get(kind, "")))
	var p := _particles(spec[0], int(spec[1]), float(spec[6]))
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = spec[9]
	p.spread = float(spec[4])
	p.initial_velocity_min = float(spec[2])
	p.initial_velocity_max = float(spec[3])
	p.gravity = Vector2(0, float(spec[5]))
	p.scale_amount_min = float(spec[7])
	p.scale_amount_max = float(spec[8])
	if kind in ["heal", "levelup"]:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = 7.0
	elif kind == "ink":
		p.damping_min = 12.0
		p.damping_max = 20.0
	host.add_child(p)
	p.global_position = at
	p.emitting = true
	host.get_tree().create_timer(float(spec[6]) + 0.3).timeout.connect(p.queue_free)


# A burst a moment later — when the blow lands rather than when the swing starts.
static func burst_later(kind: String, at: Vector2, delay: float) -> void:
	var host := _layer()
	if host == null or not host.is_inside_tree():
		return
	host.get_tree().create_timer(delay).timeout.connect(func() -> void: burst(kind, at))


# Chimney smoke: a thin grey column that drifts with the wind, thicker in the cold months.
static func smoke() -> CPUParticles2D:
	var p := _particles(["#eeece6", "#b4b5ba"], 18, 3.5)
	p.z_index = 5
	# Already drifting when the map opens; each puff swells as it rises and thins out.
	p.preprocess = 3.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.direction = Vector2.UP
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector2(3.0 * PropArt.wind_lean(), -2.0)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 3.5
	var swell := Curve.new()
	swell.add_point(Vector2(0, 0.7))
	swell.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = swell
	p.emitting = true
	return p


# Whether chimneys smoke now: people are up, and the colder the season the likelier.
static func smoking() -> bool:
	if Clock.hour < 6 or Clock.hour >= 23:
		return false
	return Clock.season in ["autumn", "winter"] or Clock.hour < 9 or Clock.hour >= 17


# Each fallen foe of a fight model once: ink from an octopus, feathers from a gull, bubbles under water,
# dust on land.
static func fallen(world: CombatWorld, underwater: bool) -> void:
	if world == null:
		return
	for f in world.fallen:
		if f.has("fx"):
			continue
		f["fx"] = true
		var kind := str(f["kind"])
		var what := "ink" if kind == "octopus" else ("feathers" if kind == "gull_marauder" else ("bubbles" if underwater else "dust"))
		burst(what, f["pos"])
