class_name TimingGame
extends Minigame

# A cursor runs back and forth; a press inside the window scores. Rounds: barrels on the pier, boots, gulls,
# the rower's beat, skating strides, bites under the ice. A round with no press is lost after two sweeps.
var rounds: int = 8
var round_no: int = 0
var cursor: float = 0.0
var dir: float = 1.0
var speed: float = 0.8
var width: float = 0.18
var center: float = 0.5
var sweeps: float = 0.0
var hits: Array = []


func setup(p: Dictionary) -> void:
	rounds = int(p.get("rounds", 8))
	speed = float(p.get("speed", 0.8))
	width = float(p.get("width", 0.18))
	limit = float(p.get("limit", 120.0))
	_next_window()


func _next_window() -> void:
	center = rng.randf_range(width, 1.0 - width)
	sweeps = 0.0


func step(delta: float) -> void:
	cursor += dir * speed * delta
	sweeps += speed * delta
	if cursor >= 1.0:
		cursor = 1.0
		dir = -1.0
	elif cursor <= 0.0:
		cursor = 0.0
		dir = 1.0
	if sweeps >= 4.0:
		_resolve(false)


func inside() -> bool:
	return absf(cursor - center) <= width / 2.0


func press(action: String) -> void:
	if done or action != "press":
		return
	_resolve(inside())


func _resolve(hit: bool) -> void:
	hits.append(hit)
	if hit:
		# Closer to the middle of the window is worth more (a boot flies further).
		score += 1.0
		params["last_quality"] = 1.0 - absf(cursor - center) / (width / 2.0)
	round_no += 1
	if round_no >= rounds:
		finish()
	else:
		_next_window()


func bot(skill: float) -> void:
	# A clumsy hand presses too early now and then; a sure one waits for the middle of the window.
	if not inside() and rng.randf() < 0.03 * (1.0 - skill):
		press("press")
	elif inside() and absf(cursor - center) <= width * 0.25 and rng.randf() < 0.25 + 0.75 * skill:
		press("press")


func draw(ci: CanvasItem, size: Vector2) -> void:
	var bar := Rect2(20, size.y / 2.0 - 8, size.x - 40, 16)
	ci.draw_rect(bar, Color("#2a3140"))
	ci.draw_rect(Rect2(bar.position.x + (center - width / 2.0) * bar.size.x, bar.position.y, width * bar.size.x, bar.size.y), Color("#4e8a5a"))
	ci.draw_rect(Rect2(bar.position.x + cursor * bar.size.x - 1, bar.position.y - 4, 3, bar.size.y + 8), Color("#f2e3b3"))
	for i in hits.size():
		ci.draw_rect(Rect2(20 + i * 10, bar.position.y + 28, 7, 7), Color("#6fbf73") if bool(hits[i]) else Color("#bf5a4a"))
