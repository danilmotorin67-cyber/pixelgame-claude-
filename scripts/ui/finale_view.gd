extends Control
class_name FinaleView

# Phase 1 of the Great Tide on screen: the gauges of FireHold and the keeper's hands on keys 1-8
# (about twelve real minutes for 21:00-01:00; Q plays it through at the keeper's skill).
const KEYS := {KEY_1: "relight", KEY_2: "refill", KEY_3: "wipe", KEY_4: "repair", KEY_5: "stun", KEY_6: "lantern", KEY_7: "bell", KEY_8: "water"}
var _label: Label
var _hud: CanvasLayer


static func open(hud: CanvasLayer) -> FinaleView:
	var existing := hud.get_node_or_null("FinaleView")
	if existing:
		existing.free()
	var view := FinaleView.new()
	view.name = "FinaleView"
	view._hud = hud
	hud.add_child(view)
	return view


func _ready() -> void:
	Clock.paused = true
	position = Vector2(30, 20)
	size = Vector2(420, 140)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.size = Vector2(404, 128)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)


func _process(delta: float) -> void:
	if Finale.hold == null:
		return
	if not Finale.hold.done():
		Finale.hold.tick(delta / 3.0)
	_label.text = "%s\n\n%s\n\n%s" % [Loc.t("finale.title"), Finale.hold.status(), Loc.t("finale.keys")]
	queue_redraw()
	if Finale.hold.done():
		_finish()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101722"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#b08f6c"), false, 1.0)
	if Finale.hold and Finale.hold.in_window():
		draw_rect(Rect2(size.x - 60, 8, 50, 10), Color("#e8d27a"))


func _input(event: InputEvent) -> void:
	if Finale.hold == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if KEYS.has(event.physical_keycode):
		Finale.hold.act(str(KEYS[event.physical_keycode]))
	elif event.physical_keycode == KEY_Q:
		Finale.hold.autoplay(clampf(float(Skills.level("keeping")) / 10.0, 0.4, 1.0))
	get_viewport().set_input_as_handled()


func _finish() -> void:
	var result := Finale.fire_result()
	if result == "lost":
		Finale.retry()
		InfoPanel.open(_hud, Loc.t("finale.title"), func() -> String: return Loc.t("finale.lost"))
		return
	queue_free()
	Clock.paused = false
	Clock.set_time(1, 0)
	InfoPanel.open(_hud, Loc.t("finale.title"), func() -> String: return Loc.t("finale.kept"))
	Cutscenes.queue(Finale.path_scene())
