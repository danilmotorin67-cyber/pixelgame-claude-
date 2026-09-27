extends Control
class_name SpyglassView

# 27.4: the view through the glass. A/D pick a target, hold Space two seconds to note it; Esc closes.
var list: Array = []
var index: int = 0
var held: float = 0.0
var _was_paused: bool = false
var _label: Label
var _note: String = ""


static func open(hud: CanvasLayer) -> SpyglassView:
	var existing := hud.get_node_or_null("SpyglassView")
	if existing:
		existing.free()
	var view := SpyglassView.new()
	view.name = "SpyglassView"
	hud.add_child(view)
	return view


func _ready() -> void:
	_was_paused = Clock.paused
	Clock.paused = true
	position = Vector2(90, 8)
	size = Vector2(300, 222)
	list = Spyglass.targets()
	_label = Label.new()
	_label.position = Vector2(10, 134)
	_label.size = Vector2(280, 84)
	_label.add_theme_font_size_override("font_size", 8)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_label)


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE) and not list.is_empty():
		held += delta
		if held >= float(Spyglass.cfg("hold", 2.0)):
			var t: Dictionary = list[index]
			_note = ("Записано: %s." % str(t["name"])) if Spyglass.observe(t, held) else "Уже в журнале."
			held = 0.0
	else:
		held = 0.0
	var lines: Array = []
	for i in list.size():
		var t: Dictionary = list[i]
		lines.append("%s %s%s" % ["▶" if i == index else " ", str(t["name"]), " ✓" if Collections.has(str(t["kind"]), str(t["id"])) else ""])
	_label.text = ("\n".join(lines) if not lines.is_empty() else "Никого в окуляре. Море, небо, чайки мимо.") \
		+ "\nПтицы %d/%d · корабли %d/%d. A/D — цель, держать Пробел — записать, Esc — закрыть. %s" % [
			Spyglass.count("birds"), Spyglass.total("birds"), Spyglass.count("ships"), Spyglass.total("ships"), _note]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_A, KEY_LEFT:
				index = posmod(index - 1, maxi(list.size(), 1))
				held = 0.0
			KEY_D, KEY_RIGHT:
				index = posmod(index + 1, maxi(list.size(), 1))
				held = 0.0
			KEY_ESCAPE:
				Clock.paused = _was_paused
				queue_free()
		get_viewport().set_input_as_handled()


# The PixelLab vignette of the target (assets/sprites/spyglass/<bird|ship>_<id>.png), shown ×2 behind a
# round lens: a thick ring of the window's colour masks the corners, a brass rim frames it.
static var _vignettes := {}


static func vignette(kind: String, id: String) -> Texture2D:
	var key := "%s_%s" % ["bird" if kind == "birds" else "ship", id]
	if not _vignettes.has(key):
		var path := "res://assets/sprites/spyglass/%s.png" % key
		_vignettes[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _vignettes[key]


func _draw() -> void:
	draw_style_box(UiKit.box("window"), Rect2(Vector2.ZERO, size))
	var c := Vector2(size.x / 2.0, 80)
	var r := 40.0
	var tex: Texture2D = null
	if not list.is_empty():
		var t: Dictionary = list[index]
		tex = vignette(str(t["kind"]), str(t["id"]))
	if tex:
		var vs := tex.get_size() * 2.0
		draw_texture_rect(tex, Rect2(c - vs / 2.0, vs), false)
		draw_arc(c, 56.0, 0, TAU, 64, Color("#252b46"), 32.0)
	else:
		draw_circle(c, r, Color("#8fb0c0"))
		if not list.is_empty():
			var t: Dictionary = list[index]
			if str(t["kind"]) == "birds":
				draw_line(c + Vector2(-10, 0), c + Vector2(0, -4), Color("#2a2a30"), 2.0)
				draw_line(c + Vector2(0, -4), c + Vector2(10, 0), Color("#2a2a30"), 2.0)
			else:
				draw_rect(Rect2(c + Vector2(-16, 4), Vector2(32, 6)), Color("#4a3428"))
				draw_rect(Rect2(c + Vector2(-2, -18), Vector2(2, 22)), Color("#4a3428"))
	draw_arc(c, r, 0, TAU, 64, Color("#6b4a32"), 4.0)
	draw_arc(c, r - 1.0, 0, TAU, 64, Color("#c9a24a"), 2.0)
	var share := clampf(held / float(Spyglass.cfg("hold", 2.0)), 0.0, 1.0)
	draw_rect(Rect2(10, 126, 280, 4), Color("#45464e"))
	draw_rect(Rect2(10, 126, 280.0 * share, 4), Color("#ffc85a"))
