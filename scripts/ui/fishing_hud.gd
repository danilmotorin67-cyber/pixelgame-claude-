extends Control
class_name FishingHud

# Drives one cast from charge to landing and draws the float and the tension bar (15.2).
var state: String = "idle"
var player: Player
var charge: float = 0.0
var target: Vector2 = Vector2.ZERO
var wait_left: float = 0.0
var bite_left: float = 0.0
var rod_id: String = ""
var bait: String = ""
var tackles: Array = []
var fish: Dictionary = {}
var sim: FishingSim
var landed: Dictionary = {}
var landed_left: float = 0.0
var _rng := RandomNumberGenerator.new()


static func of(hud: CanvasLayer) -> FishingHud:
	var existing := hud.get_node_or_null("FishingHud") as FishingHud
	if existing:
		return existing
	var node := FishingHud.new()
	node.name = "FishingHud"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(node)
	return node


func active() -> bool:
	return state != "idle"


func _hint(text: String) -> void:
	var hint := get_parent().get_node_or_null("Hint") as Label
	if hint:
		hint.text = text


func begin(keeper: Player, rod: String) -> void:
	if state != "idle":
		return
	player = keeper
	rod_id = rod
	charge = 0.0
	state = "charging"
	_rng.seed = posmod(Game.world_seed * 17 + Clock.day_index * 1009 + Clock.minutes * 7 + Time.get_ticks_msec(), 2147483647)


func _cast() -> void:
	var range_tiles := 1.0 + 4.0 * charge + float(Fishing.rod(rod_id).get("range", 0))
	var dir := (player.get_global_mouse_position() - player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = player.facing
	target = player.global_position + dir * range_tiles * 16.0
	var tags := Fishing.spot_tags(Router.current_map, target)
	if tags.is_empty():
		state = "idle"
		_hint("Поплавок упал на землю. Рыбы там нет, даже в сапогах.")
		return
	if not player.spend_energy("cast"):
		state = "idle"
		_hint("Нужен отдых, сил на заброс нет.")
		return
	bait = Fishing.bait_for(rod_id)
	tackles = Fishing.tackles_for(rod_id)
	var ctx := Fishing.context(tags, player.lantern_on)
	fish = Fishing.pick(ctx, _rng, bait == "legend_lure")
	wait_left = Fishing.wait_seconds(rod_id, bait, _rng)
	state = "waiting"
	_hint("Поплавок покачивается…")


# A few seconds after a catch E lets the fish go back to the sea (12.1).
func _input(event: InputEvent) -> void:
	if landed_left > 0.0 and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		landed_left = 0.0
		if RannStone.release(str(landed["id"]), int(landed["quality"])):
			_hint("Рыба ушла в глубину. Море заметило.")


func _process(delta: float) -> void:
	landed_left = maxf(0.0, landed_left - delta)
	var holding := Input.is_action_pressed("use_tool")
	match state:
		"charging":
			charge = minf(1.0, charge + delta)
			if not holding:
				_cast()
		"waiting":
			wait_left -= delta
			if Input.is_action_just_pressed("use_tool"):
				state = "idle"
				_hint("Смотали леску.")
			elif wait_left <= 0.0:
				state = "bite"
				bite_left = 0.8 + Fishing.tackle_bonus(tackles, "window", 0.0)
				_hint("Плюх! Подсекай!")
		"bite":
			bite_left -= delta
			if Input.is_action_just_pressed("use_tool") or _auto_strike():
				_start_reel()
			elif bite_left <= 0.0:
				state = "idle"
				_hint("Сорвалась. Рыба тоже умеет разочаровывать.")
		"reeling":
			var result := sim.step(delta, holding)
			if result != "":
				_finish(result)
	queue_redraw()


func _auto_strike() -> bool:
	return Fishing.tackle_bonus(tackles, "auto", 0.0) > float(fish.get("difficulty", 999))


func _start_reel() -> void:
	if bool(fish.get("trash", false)):
		var got := Fishing.land(fish, false, tackles, bait)
		state = "idle"
		_hint("Улов: %s. Море вернуло вам ваше." % Loc.t(str(Data.by_id("items", str(got.get("id", ""))).get("name", ""))))
		return
	sim = FishingSim.new(fish, Fishing.sim_options(rod_id, tackles, fish, _rng.randi()))
	if _auto_strike():
		sim.autoplay()
		_finish(sim.result)
		return
	state = "reeling"


func _finish(result: String) -> void:
	state = "idle"
	match result:
		"caught":
			var got := Fishing.land(fish, sim.perfect, tackles, bait, 1 if sim.double_catch else 0)
			if sim.chest_won:
				Inventory.add("overgrown_chest", 1)
			var name := Loc.t(str(Data.by_id("items", str(fish["id"])).get("name", fish["id"])))
			_hint("%s · %d см%s%s · E — отпустить" % [name, int(got.get("size", 0)), " · идеально!" if sim.perfect else "",
				" · и сундучок!" if sim.chest_won else ""])
			if not got.is_empty():
				landed = got
				landed_left = 3.0
		"snapped":
			if bait != "":
				Inventory.take(bait, 1)
			_hint("Леска лопнула. Рыба ушла с наживкой и чувством превосходства.")
		_:
			_hint("Ушла. Бывает.")


func _draw() -> void:
	if state == "idle":
		return
	if state == "charging":
		draw_rect(Rect2(200, 190, 80, 6), Color("#121a26"))
		draw_rect(Rect2(200, 190, 80.0 * charge, 6), Color("#ffc85a"))
		return
	var screen := get_viewport().get_canvas_transform() * target
	var bob := sin(Time.get_ticks_msec() / 250.0) * 1.5 if state == "waiting" else 3.0
	draw_rect(Rect2(screen + Vector2(-2, -3 + bob), Vector2(4, 4)), Color("#c2412d"))
	draw_rect(Rect2(screen + Vector2(-2, -3 + bob), Vector2(4, 1)), Color("#fff8e1"))
	if state != "reeling":
		return
	var bar := Rect2(458, 70, 12, 120)
	draw_rect(bar.grow(1), Color("#b08f6c"))
	draw_rect(bar, Color("#121a26"))
	var green_top := bar.end.y - bar.size.y * sim.green_high / 100.0
	var green_bottom := bar.end.y - bar.size.y * sim.green_low / 100.0
	draw_rect(Rect2(bar.position.x, green_top, bar.size.x, green_bottom - green_top), Color("#7fbf4a"))
	var mark := bar.end.y - bar.size.y * sim.tension / 100.0
	draw_rect(Rect2(bar.position.x - 3, mark - 1, bar.size.x + 6, 3), Color("#ffe9a8"))
	draw_circle(Vector2(440, 130), 12.0, Color("#121a26"))
	draw_arc(Vector2(440, 130), 10.0, -PI / 2.0, -PI / 2.0 + TAU * sim.progress / 100.0, 24, Color("#9fd8d0"), 3.0)
	if sim.chest_active and not sim.chest_won:
		draw_rect(Rect2(472, bar.end.y - bar.size.y * 0.8, 6, 5), Color("#c9a24a"))
