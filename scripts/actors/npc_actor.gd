extends Area2D
class_name NpcActor

# An islander drawn from its "look" colours; it follows the logical position kept by NPCs.
const SPEED := 48.0

var npc_id: String = ""
var look: Dictionary = {}
var child: bool = false
var facing: String = "down"
var anim: String = ""
var _walk: float = 0.0
var _clock: float = 0.0
var _moving: bool = false
var _label: Label


func setup(id: String) -> void:
	npc_id = id
	name = "Npc_" + id
	var info := NPCs.info(id)
	look = info.get("look", {})
	child = bool(info.get("child", false))
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 18)
	collision.shape = shape
	collision.position = Vector2(0, -6)
	add_child(collision)
	_label = Label.new()
	_label.text = Loc.t(str(info.get("name", id)))
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color("#f0e7cc"))
	_label.add_theme_color_override("font_outline_color", Color("#121a26"))
	_label.add_theme_constant_override("outline_size", 2)
	_label.position = Vector2(-30, -40 if CastSprite.has(id) else -30)
	_label.size = Vector2(60, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)
	snap()


func goal() -> Vector2:
	var s := NPCs.where_is(npc_id)
	var tile: Vector2i = s.get("tile", Vector2i.ZERO)
	return Vector2(tile.x * 16 + 8, tile.y * 16 + 12)


func snap() -> void:
	position = goal()


func _process(delta: float) -> void:
	var s := NPCs.where_is(npc_id)
	var target := goal()
	var d := target - position
	_moving = d.length() > 0.5
	if d.length() > 48.0:
		position = target
	elif _moving and (not Clock.paused or Cutscenes.playing):
		position += d.normalized() * minf(d.length(), SPEED * delta * (7.0 / maxf(Clock.seconds_per_10min, 1.0)))
		if absf(d.x) > absf(d.y):
			facing = "right" if d.x > 0 else "left"
		else:
			facing = "down" if d.y > 0 else "up"
		_walk += delta
	else:
		facing = str(s.get("face", facing))
	anim = str(s.get("anim", ""))
	_clock += delta
	var layer := get_parent() as NpcLayer
	_label.visible = layer != null and layer.nearest == self
	queue_redraw()


func _draw() -> void:
	if CastSprite.has(npc_id):
		_draw_sprite()
		return
	var skin := Color(str(look.get("skin", "#e0c0a0")))
	var hair := Color(str(look.get("hair", "#4a3a2a")))
	var coat := Color(str(look.get("coat", "#4a5a6a")))
	var k := 0.8 if child else 1.0
	var bob := -1.0 if _moving and int(_walk * 8.0) % 2 == 0 else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(k, k))
	draw_rect(Rect2(-6, 1, 12, 3), Color(0, 0, 0, 0.25))
	var step := 1.0 if _moving and int(_walk * 6.0) % 2 == 0 else 0.0
	draw_rect(Rect2(-4, -3, 3, 5 - step), coat.darkened(0.55))
	draw_rect(Rect2(1, -3, 3, 5 - (1.0 - step) * (1.0 if _moving else 0.0)), coat.darkened(0.55))
	draw_rect(Rect2(-5, -12, 10, 10), coat)
	draw_rect(Rect2(-5, -12, 10, 2), coat.lightened(0.15))
	draw_rect(Rect2(-4, -19, 8, 7), skin)
	match facing:
		"up":
			draw_rect(Rect2(-4, -20, 8, 7), hair)
		"left":
			draw_rect(Rect2(-4, -20, 8, 3), hair)
			draw_rect(Rect2(1, -20, 3, 6), hair)
			draw_rect(Rect2(-3, -16, 1, 1), Color("#1e1a18"))
		"right":
			draw_rect(Rect2(-4, -20, 8, 3), hair)
			draw_rect(Rect2(-4, -20, 3, 6), hair)
			draw_rect(Rect2(2, -16, 1, 1), Color("#1e1a18"))
		_:
			draw_rect(Rect2(-4, -20, 8, 3), hair)
			draw_rect(Rect2(-4, -18, 1, 3), hair)
			draw_rect(Rect2(3, -18, 1, 3), hair)
			draw_rect(Rect2(-2, -16, 1, 1), Color("#1e1a18"))
			draw_rect(Rect2(1, -16, 1, 1), Color("#1e1a18"))
	if anim in ["drink", "toast"]:
		draw_rect(Rect2(5, -9, 3, 4), Color("#c9a24a"))
	elif anim in ["write", "read", "notes"]:
		draw_rect(Rect2(-3, -8, 6, 4), Color("#efe6cf"))
	elif anim in ["fish"]:
		draw_line(Vector2(5, -8), Vector2(12, -20), Color("#6b4a32"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# PixelLab sprite: walking while moving, the signature action while busy at the
# schedule spot, breathing otherwise.
func _draw_sprite() -> void:
	draw_rect(Rect2(-6, -1, 12, 3), Color(0, 0, 0, 0.22))
	var state := "idle"
	var dir := facing
	if _moving:
		state = "walk"
	elif anim != "" and CastSprite.has_anim(npc_id, "work"):
		state = "work"
		dir = "down"
	CastSprite.draw(self, npc_id, state, dir, _walk if _moving else _clock)


const EMOTES := {"happy": "♪", "love": "♥", "surprise": "!", "question": "?", "sad": "…", "angry": "#"}


func emote(kind: String) -> void:
	var bubble := Label.new()
	bubble.text = str(EMOTES.get(kind, kind))
	bubble.add_theme_font_size_override("font_size", 10)
	bubble.add_theme_color_override("font_color", Color("#121a26"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f0e7cc")
	style.set_corner_radius_all(3)
	bubble.add_theme_stylebox_override("normal", style)
	bubble.position = Vector2(-5, -38)
	add_child(bubble)
	get_tree().create_timer(1.0, true).timeout.connect(bubble.queue_free)


func interact(_player: Player) -> void:
	var hud := get_tree().current_scene.get_node("HUD") as CanvasLayer
	var box := DialogueBox.talk(hud, npc_id)
	var trades := str(NPCs.info(npc_id).get("trades", ""))
	# Story business after the day's line: hand-ins, asking for help, Helga's tales (5, 27.3).
	var options := Story.npc_options(npc_id)
	if not options.is_empty():
		var labels: Array = []
		for o in options:
			labels.append(str(o[1]))
		labels.append(Loc.t("story.opt.nothing"))
		box.say(npc_id, "neutral", Loc.t("story.opt.prompt"), labels)
		box.finished.connect(func(choice: int) -> void: _story_option(hud, options, choice, trades), CONNECT_ONE_SHOT)
		return
	if trades != "" and Economy.shop_closed_reason(trades) == "":
		box.finished.connect(func(_c: int) -> void: ShopPanel.open(hud, trades), CONNECT_ONE_SHOT)


func _story_option(hud: CanvasLayer, options: Array, choice: int, trades: String) -> void:
	if choice >= 0 and choice < options.size():
		var answer := Story.npc_action(npc_id, str(options[choice][0]))
		if answer != "":
			var reply := DialogueBox.of(hud)
			reply.say(npc_id, "neutral", answer)
		return
	if trades != "" and Economy.shop_closed_reason(trades) == "":
		ShopPanel.open(hud, trades)


func receive_gift(_player: Player) -> void:
	var hud := get_tree().current_scene.get_node("HUD") as CanvasLayer
	DialogueBox.gift(hud, npc_id, Inventory.selected_hotbar)
