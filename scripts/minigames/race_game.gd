class_name RaceGame
extends Minigame

# The regatta (24.2): the keeper trims the sail when the gust gauge is in the green; rivals sail by their
# nature — Hedda is fast, Erland cuts along the current, Einar is new to it, the Skaus cut in.
var length: float = 100.0
var pos: float = 0.0
var gauge: float = 0.0
var gauge_dir: float = 1.0
var boost: float = 0.0
var rivals: Array = []
var place: int = 0


func setup(p: Dictionary) -> void:
	length = float(p.get("length", 100.0))
	limit = float(p.get("limit", 120.0))
	for r in p.get("rivals", []):
		rivals.append({"id": str(r[0]), "speed": float(r[1]), "pos": 0.0, "done": -1.0})


func step(delta: float) -> void:
	gauge += gauge_dir * 1.3 * delta
	if gauge >= 1.0 or gauge <= 0.0:
		gauge_dir *= -1.0
		gauge = clampf(gauge, 0.0, 1.0)
	boost = maxf(0.0, boost - delta * 0.6)
	pos += (2.4 + 2.2 * boost) * delta
	for r in rivals:
		if float(r["done"]) < 0.0:
			var wobble := 0.85 + 0.3 * rng.randf()
			r["pos"] = float(r["pos"]) + float(r["speed"]) * wobble * delta
			if float(r["pos"]) >= length:
				r["done"] = time
	if pos >= length:
		place = 1
		for r in rivals:
			if float(r["done"]) >= 0.0:
				place += 1
		score = float(place)
		finish()


func judge() -> bool:
	return place == 1


func in_green() -> bool:
	return gauge >= 0.4 and gauge <= 0.6


func press(action: String) -> void:
	if done or action != "press":
		return
	if in_green():
		boost = minf(1.0, boost + 0.5)
	else:
		boost = maxf(0.0, boost - 0.3)


func bot(skill: float) -> void:
	if in_green() and absf(gauge - 0.5) < 0.05 and rng.randf() < 0.1 + 0.9 * skill:
		press("press")


func status() -> String:
	return "%s  %d%%" % [title, int(100.0 * pos / length)]


func draw(ci: CanvasItem, size: Vector2) -> void:
	var w := size.x - 60
	var rows := rivals.size() + 1
	var h := (size.y - 60) / float(rows)
	ci.draw_rect(Rect2(30 + w * pos / length - 5, 20 + h / 2.0 - 4, 10, 8), Color("#f2f2f2"))
	for i in rivals.size():
		ci.draw_rect(Rect2(30 + w * minf(1.0, float(rivals[i]["pos"]) / length) - 5, 20 + (i + 1) * h + h / 2.0 - 4, 10, 8), Color("#9fb7c9"))
	ci.draw_rect(Rect2(30 + w, 20, 2, size.y - 60), Color("#c2412d"))
	ci.draw_rect(Rect2(30, size.y - 30, w, 10), Color("#2a3140"))
	ci.draw_rect(Rect2(30 + 0.4 * w, size.y - 30, 0.2 * w, 10), Color("#4e8a5a"))
	ci.draw_rect(Rect2(30 + gauge * w - 1, size.y - 34, 3, 18), Color("#f2e3b3"))
