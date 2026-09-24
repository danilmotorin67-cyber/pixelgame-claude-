class_name GuessGame
extends Minigame

# "Guess the cod's weight" (24.2): up and down pick a number, a press settles it; within a tenth wins.
var target: float = 5.0
var value: float = 3.0
var step_size: float = 0.1
var lo: float = 1.0
var hi: float = 12.0


func setup(p: Dictionary) -> void:
	lo = float(p.get("lo", 1.0))
	hi = float(p.get("hi", 12.0))
	step_size = float(p.get("step", 0.1))
	target = snappedf(rng.randf_range(lo + 1.0, hi - 1.0), step_size)
	value = snappedf((lo + hi) / 2.0, step_size)
	limit = float(p.get("limit", 30.0))


func press(action: String) -> void:
	if done:
		return
	match action:
		"up":
			value = minf(hi, value + step_size)
		"down":
			value = maxf(lo, value - step_size)
		"right":
			value = minf(hi, value + step_size * 10.0)
		"left":
			value = maxf(lo, value - step_size * 10.0)
		"press":
			score = maxf(0.0, 10.0 - absf(value - target) * 10.0)
			finish()


func judge() -> bool:
	return absf(value - target) <= target * 0.1


func bot(skill: float) -> void:
	# A skilled eye starts close: the error shrinks with skill, then the bot settles.
	value = snappedf(clampf(target + rng.randf_range(-1.0, 1.0) * (1.0 - skill) * 3.0, lo, hi), step_size)
	press("press")


func status() -> String:
	return "%s  %.1f кг" % [title, value]


func draw(ci: CanvasItem, size: Vector2) -> void:
	var w := size.x - 60
	ci.draw_rect(Rect2(30, size.y / 2.0 - 6, w, 12), Color("#2a3140"))
	ci.draw_rect(Rect2(30 + (value - lo) / (hi - lo) * w - 2, size.y / 2.0 - 12, 4, 24), Color("#f2e3b3"))
	if done:
		ci.draw_rect(Rect2(30 + (target - lo) / (hi - lo) * w - 2, size.y / 2.0 - 12, 4, 24), Color("#6fbf73"))
