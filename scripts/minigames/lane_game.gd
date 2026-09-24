class_name LaneGame
extends Minigame

# Three lanes, things coming: dodge them (breaker race, the boat in the false fire's beam, the dog and the
# patrol in Grim's yard) or catch them (eggs on the ropes). The run ends at `distance`; too many hits lose it.
var lanes: int = 3
var lane: int = 1
var things: Array = []
var travelled: float = 0.0
var distance: float = 100.0
var speed: float = 10.0
var gap: float = 1.2
var next_in: float = 0.5
var hits: int = 0
var allowed: int = 2
var collect: bool = false
var density: float = 0.75
const PLAYER_X := 12.0
const HORIZON := 60.0


func setup(p: Dictionary) -> void:
	lanes = int(p.get("lanes", 3))
	lane = lanes / 2
	distance = float(p.get("distance", 100.0))
	speed = float(p.get("speed", 10.0))
	gap = float(p.get("gap", 1.2))
	allowed = int(p.get("allowed", 2))
	collect = bool(p.get("collect", false))
	density = float(p.get("density", 0.75))
	limit = float(p.get("limit", distance / speed + 5.0))


func step(delta: float) -> void:
	travelled += speed * delta
	next_in -= delta
	if next_in <= 0.0:
		next_in = gap * rng.randf_range(0.6, 1.4)
		var free := rng.randi_range(0, lanes - 1)
		if collect:
			things.append({"lane": free, "x": HORIZON})
		else:
			for l in lanes:
				if l != free and rng.randf() < density:
					things.append({"lane": l, "x": HORIZON})
	var keep: Array = []
	for t in things:
		var before := float(t["x"])
		t["x"] = before - speed * delta
		if before >= PLAYER_X and float(t["x"]) < PLAYER_X and int(t["lane"]) == lane:
			if collect:
				score += 1.0
			else:
				hits += 1
			continue
		if float(t["x"]) > 0.0:
			keep.append(t)
	things = keep
	if not collect and hits > allowed:
		finish()
		return
	if not collect:
		score = travelled
	if travelled >= distance:
		finish()


func judge() -> bool:
	if collect:
		return score >= float(params.get("need", 5))
	return hits <= allowed and travelled >= distance


func press(action: String) -> void:
	if done:
		return
	if action == "up":
		lane = maxi(0, lane - 1)
	elif action == "down":
		lane = mini(lanes - 1, lane + 1)


func _lane_busy(l: int) -> bool:
	for t in things:
		if int(t["lane"]) == l and float(t["x"]) > PLAYER_X - 1.0 and float(t["x"]) < PLAYER_X + speed * 0.6:
			return true
	return false


func bot(skill: float) -> void:
	# A slow hand reacts in a frame now and then, a quick one almost every frame.
	if rng.randf() > 0.01 + 0.5 * skill:
		return
	if collect:
		var best := -1.0
		for t in things:
			if float(t["x"]) > PLAYER_X and (best < 0.0 or float(t["x"]) < best):
				best = float(t["x"])
				if int(t["lane"]) < lane:
					press("up")
				elif int(t["lane"]) > lane:
					press("down")
		return
	if _lane_busy(lane):
		for l in [lane - 1, lane + 1]:
			if l >= 0 and l < lanes and not _lane_busy(l):
				press("up" if l < lane else "down")
				return


func status() -> String:
	if collect:
		return "%s  %d  %d с" % [title, int(score), maxi(0, int(limit - time))]
	return "%s  %d%%  удары %d/%d" % [title, int(100.0 * travelled / distance), hits, allowed]


func draw(ci: CanvasItem, size: Vector2) -> void:
	var h := (size.y - 40) / float(lanes)
	var sx := (size.x - 40) / HORIZON
	for l in lanes:
		ci.draw_rect(Rect2(20, 20 + l * h, size.x - 40, h - 2), Color("#1f2a38") if l % 2 == 0 else Color("#243142"))
	for t in things:
		ci.draw_rect(Rect2(20 + float(t["x"]) * sx - 5, 20 + int(t["lane"]) * h + h / 2.0 - 5, 10, 10),
			Color("#e8d27a") if collect else Color("#c2412d"))
	ci.draw_rect(Rect2(20 + PLAYER_X * sx - 6, 20 + lane * h + h / 2.0 - 6, 12, 12), Color("#f2f2f2"))
