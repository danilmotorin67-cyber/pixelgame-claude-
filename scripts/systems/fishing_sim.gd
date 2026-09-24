class_name FishingSim
extends RefCounted

# "Tension" of 15.2: hold to reel in (tension rises by reel speed + the fish's pull), release to
# give line (tension falls by the release speed while the fish keeps pulling).
const START_PROGRESS := 30.0
const SNAP_SECONDS := 0.4
const LOW_TENSION := 20.0
const BEHAVIORS := ["calm", "darting", "sinking", "jumping", "school"]

var fish: Dictionary = {}
var behavior: String = "calm"
var difficulty: float = 30.0
var tension: float = 55.0
var progress: float = START_PROGRESS
var green_low: float = 35.0
var green_high: float = 75.0
var reel_speed: float = 70.0
var release_speed: float = 60.0
var assist: bool = false
var sinking_mult: float = 1.0
var perfect: bool = true
var result: String = ""
var chest_active: bool = false
var chest_hold: float = 0.0
var chest_won: bool = false
var double_catch: bool = false
var _t: float = 0.0
var _over: float = 0.0
var _phase: float = 0.0
var _mode: String = "calm"
var _mode_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(target: Dictionary, options: Dictionary = {}) -> void:
	fish = target
	behavior = str(target.get("behavior", "calm"))
	difficulty = float(options.get("difficulty", target.get("difficulty", 30)))
	_rng.seed = int(options.get("seed", 1))
	var width := 40.0 + 3.0 * float(options.get("level", 0)) + float(options.get("green", 0))
	if bool(options.get("assist", false)):
		width *= 2.0
		assist = true
	width = minf(width, 90.0)
	green_low = 55.0 - width / 2.0
	green_high = 55.0 + width / 2.0
	reel_speed *= float(options.get("reel", 1.0))
	release_speed += difficulty * 0.3
	sinking_mult = float(options.get("sinking", 1.0))
	chest_active = _rng.randf() < 0.05 * float(options.get("chest", 1.0))
	_mode = behavior if behavior not in ["cunning", "legendary"] else "calm"


func strength() -> float:
	return 20.0 + difficulty * 0.9


func gain() -> float:
	return maxf(8.0, 18.0 - difficulty * 0.06)


func in_green() -> bool:
	return tension >= green_low and tension <= green_high


# The fish's pull (tension per second) for its behaviour; also moves "jumping" slack.
func pull(dt: float) -> float:
	var s := strength()
	if behavior in ["cunning", "legendary"]:
		_mode_left -= dt
		if _mode_left <= 0.0:
			_mode = BEHAVIORS[_rng.randi_range(0, BEHAVIORS.size() - 2)]
			_mode_left = _rng.randf_range(1.0, 2.0) if behavior == "legendary" else _rng.randf_range(2.0, 4.0)
		if behavior == "legendary":
			var drift := sin(_t * 0.7) * 0.2
			green_low += drift
			green_high += drift
	_phase += dt
	match _mode:
		"calm":
			return s * 0.6 * sin(_t * 1.5)
		"school":
			return s * 0.4 * sin(_t * 2.0)
		"darting":
			var cycle := fmod(_phase, 1.5)
			return s * 1.6 if cycle < 0.25 else -s * 0.1
		"sinking":
			var cycle := fmod(_phase, 3.0)
			return 0.0 if cycle > 2.5 else s * 0.55 * sinking_mult
		"jumping":
			var cycle := fmod(_phase, 2.5)
			if cycle < dt:
				tension -= 30.0
			return s * 1.4 if cycle > 0.2 and cycle < 0.5 else 0.0
	return 0.0


func step(dt: float, holding: bool) -> String:
	if result != "":
		return result
	_t += dt
	var force := pull(dt)
	tension += ((reel_speed if holding else -release_speed) + force) * dt
	tension = clampf(tension, 0.0, 100.0)
	if in_green():
		progress += gain() * dt
	else:
		perfect = false
		if tension < LOW_TENSION:
			progress -= gain() * 0.5 * dt
	if chest_active and not chest_won and tension > 66.0:
		chest_hold += dt
		chest_won = chest_hold >= 2.0
	if tension >= 100.0 and not assist:
		_over += dt
		if _over > SNAP_SECONDS:
			result = "snapped"
			return result
	else:
		_over = 0.0
	if progress >= 100.0:
		result = "caught"
		double_catch = behavior == "school" and _rng.randf() < 0.3
	elif progress <= 0.0:
		result = "escaped"
	return result


# A steady player for tests and the bell tackle: keeps the tension near the middle of the green zone.
func autoplay(max_seconds: float = 60.0, dt: float = 1.0 / 60.0) -> String:
	var elapsed := 0.0
	while result == "" and elapsed < max_seconds:
		step(dt, tension < (green_low + green_high) / 2.0)
		elapsed += dt
	return result
