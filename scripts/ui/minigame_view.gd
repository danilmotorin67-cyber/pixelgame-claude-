extends Control
class_name MinigameView

# Draws a Minigame over the HUD and feeds it the keys: Space/E press, W/S or arrows move, A/D fine-tune,
# Esc gives up. Time stands still while it runs; when it ends the result shows for a moment, then `on_done`.
var game: Minigame
var on_done: Callable
var _was_paused: bool = false
var _after: float = -1.0
var _label: Label


static func open(hud: CanvasLayer, g: Minigame, done_cb: Callable) -> MinigameView:
	var existing := hud.get_node_or_null("MinigameView")
	if existing:
		existing.free()
	var view := MinigameView.new()
	view.name = "MinigameView"
	view.game = g
	view.on_done = done_cb
	hud.add_child(view)
	return view


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(40, 30)
	size = Vector2(400, 200)
	_label = Label.new()
	_label.position = Vector2(8, 4)
	_label.add_theme_font_size_override("font_size", 9)
	add_child(_label)


func _process(delta: float) -> void:
	if game == null:
		return
	if not game.done:
		game.tick(delta)
		_label.text = game.status() + "\nПробел — действие, W/S — смещение, Esc — сдаться"
	elif _after < 0.0:
		_after = 1.5
		_label.text = "%s — %s" % [game.title, "удача!" if game.won else "не вышло"]
	else:
		_after -= delta
		if _after <= 0.0:
			_close()
			return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#121a26"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#b08f6c"), false, 1.0)
	if game:
		game.draw(self, size)


func _input(event: InputEvent) -> void:
	if game == null or game.done or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE, KEY_E, KEY_ENTER:
			game.press("press")
		KEY_W, KEY_UP:
			game.press("up")
		KEY_S, KEY_DOWN:
			game.press("down")
		KEY_A, KEY_LEFT:
			game.press("left")
		KEY_D, KEY_RIGHT:
			game.press("right")
		KEY_ESCAPE:
			game.finish()
	get_viewport().set_input_as_handled()


func _close() -> void:
	Clock.paused = _was_paused
	var cb := on_done
	var g := game
	queue_free()
	if cb.is_valid():
		cb.call(g)
