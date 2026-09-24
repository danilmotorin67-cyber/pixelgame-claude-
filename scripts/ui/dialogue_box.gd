extends Control
class_name DialogueBox

# The talk window of 2.4: portrait, name, hearts, up to three lines per page, 2-3 choices.
# E, Space, Enter or a click turns the page; 1-3 pick a choice. Time stands still while it is open.
signal finished(choice: int)

const LINES := 3

var _queue: Array = []
var _choices: Array = []
var _npc: String = ""
var _emotion: String = ""
var _was_paused: bool = false
var _panel: Panel
var _name: Label
var _text: Label
var _hearts: Label
var _choice_box: VBoxContainer
var _portrait: Control
var _picked: int = -1


static func of(hud: CanvasLayer) -> DialogueBox:
	var existing := hud.get_node_or_null("DialogueBox") as DialogueBox
	if existing:
		return existing
	var box := DialogueBox.new()
	box.name = "DialogueBox"
	hud.add_child(box)
	return box


static func is_open(hud: CanvasLayer) -> bool:
	return hud != null and hud.get_node_or_null("DialogueBox") != null


static func talk(hud: CanvasLayer, npc: String) -> DialogueBox:
	var first := Relationships.talk(npc)
	var key := Dialogue.talk_line(npc)
	var box := of(hud)
	box.say(npc, "neutral", Loc.t(key))
	if first:
		Game.add_stat("talks")
	return box


const REFUSALS := {"not_giftable": "gift.refuse.not_giftable", "today": "gift.refuse.today", "week": "gift.refuse.week",
	"empty": "gift.refuse.empty"}


static func gift(hud: CanvasLayer, npc: String, index: int) -> DialogueBox:
	var result := Relationships.give(npc, index)
	var box := of(hud)
	if result.has("line"):
		var key := Dialogue.pick(npc, str(result["line"]))
		if key == "":
			key = "npc.generic.%s" % result["line"]
		box.say(npc, "happy" if bool(result["ok"]) else "neutral", Loc.t(key))
		return box
	if not bool(result["ok"]):
		box.say(npc, "neutral", Loc.t(str(REFUSALS.get(str(result["reason"]), "gift.refuse.today"))))
		return box
	var emotion := {"love": "happy", "like": "happy", "neutral": "neutral", "dislike": "sad", "hate": "angry"}
	box.say(npc, str(emotion[result["reaction"]]), Loc.t(Dialogue.gift_line(npc, str(result["reaction"]), bool(result["birthday"]))))
	return box


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_was_paused = Clock.paused
	Clock.paused = true
	_panel = Panel.new()
	_panel.position = Vector2(10, 194)
	_panel.size = Vector2(460, 68)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1b2433")
	style.border_color = Color("#b08f6c")
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_portrait = Control.new()
	_portrait.position = Vector2(6, 6)
	_portrait.size = Vector2(52, 56)
	_portrait.draw.connect(_draw_portrait)
	_panel.add_child(_portrait)
	_name = _label(Vector2(66, 3), Vector2(250, 12), 9, Color("#ffc85a"))
	_hearts = _label(Vector2(320, 3), Vector2(132, 12), 8, Color("#e06a6a"))
	_hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text = _label(Vector2(66, 17), Vector2(386, 46), 9, Color("#f0e7cc"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.max_lines_visible = LINES
	_choice_box = VBoxContainer.new()
	_choice_box.position = Vector2(76, 120)
	_choice_box.size = Vector2(330, 70)
	_choice_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(_choice_box)


func _label(at: Vector2, size_: Vector2, font: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = size_
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", color)
	_panel.add_child(label)
	return label


# Queues a line; choices (Array of texts) come after the last page of the last queued line.
func say(npc: String, emotion: String, text: String, choices: Array = []) -> void:
	_queue.append({"npc": npc, "emo": emotion, "text": text, "choices": choices})
	if _queue.size() == 1:
		_show()


func _show() -> void:
	if _queue.is_empty():
		return
	var line: Dictionary = _queue[0]
	_npc = str(line["npc"])
	_emotion = str(line["emo"])
	var info := Data.by_id("npcs", _npc)
	_name.text = Loc.t(str(info.get("name", ""))) if not info.is_empty() else (str(Game.hero.get("name", "")) if _npc == "hero" else "")
	_portrait.visible = _npc != "narrator"
	var hearts := Relationships.hearts_of(_npc)
	_hearts.text = ("♥".repeat(hearts) + "♡".repeat(maxi(0, Relationships.cap(_npc) - hearts))) if not info.is_empty() and not bool(info.get("visitor", false)) else ""
	_text.text = str(line["text"])
	_text.lines_skipped = 0
	_portrait.queue_redraw()
	_clear_choices()


func page_count() -> int:
	return maxi(1, ceili(float(_text.get_line_count()) / float(LINES)))


func current_text() -> String:
	return _text.text


func advance() -> void:
	if not _choice_box.get_children().is_empty():
		return
	if _text.lines_skipped + LINES < _text.get_line_count():
		_text.lines_skipped += LINES
		return
	var line: Dictionary = _queue[0]
	if not (line["choices"] as Array).is_empty() and _choice_box.get_child_count() == 0:
		_offer(line["choices"])
		return
	_queue.pop_front()
	if _queue.is_empty():
		close(-1)
	else:
		_show()


func _offer(choices: Array) -> void:
	for i in choices.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, str(choices[i])]
		button.add_theme_font_size_override("font_size", 9)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(choose.bind(i))
		_choice_box.add_child(button)
	(_choice_box.get_child(0) as Button).grab_focus()


func _clear_choices() -> void:
	for child in _choice_box.get_children():
		child.queue_free()
		_choice_box.remove_child(child)


func choose(index: int) -> void:
	_clear_choices()
	_queue.pop_front()
	_picked = index
	if _queue.is_empty():
		close(index)
	else:
		_show()


func close(choice: int = -1) -> void:
	if choice < 0:
		choice = _picked
	Clock.paused = _was_paused
	finished.emit(choice)
	queue_free()


func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and _choice_box.get_child_count() > 0:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < _choice_box.get_child_count():
			choose(n)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _choice_box.get_child_count() > 0 and not (event is InputEventKey and event.is_action_pressed("interact")):
			return
		advance()
		get_viewport().set_input_as_handled()


func _draw_portrait() -> void:
	var look: Dictionary = Data.by_id("npcs", _npc).get("look", {})
	if look.is_empty():
		look = {"skin": "#e0c0a0", "hair": "#6b4a32", "coat": "#2f4a5c"}
	var skin := Color(str(look["skin"]))
	var hair := Color(str(look["hair"]))
	var coat := Color(str(look["coat"]))
	var p := _portrait
	p.draw_rect(Rect2(Vector2.ZERO, p.size), Color("#28344a"))
	p.draw_rect(Rect2(8, 40, 36, 16), coat)
	p.draw_rect(Rect2(14, 12, 24, 28), skin)
	p.draw_rect(Rect2(12, 6, 28, 9), hair)
	p.draw_rect(Rect2(12, 12, 4, 16), hair)
	p.draw_rect(Rect2(36, 12, 4, 16), hair)
	var eye := Color("#1e1a18")
	match _emotion:
		"happy":
			p.draw_rect(Rect2(19, 22, 4, 1), eye)
			p.draw_rect(Rect2(29, 22, 4, 1), eye)
			p.draw_rect(Rect2(21, 32, 10, 2), Color("#8a3a2e"))
		"sad":
			p.draw_rect(Rect2(20, 22, 3, 3), eye)
			p.draw_rect(Rect2(29, 22, 3, 3), eye)
			p.draw_rect(Rect2(22, 34, 8, 1), Color("#8a3a2e"))
		"angry":
			p.draw_rect(Rect2(18, 19, 6, 1), eye)
			p.draw_rect(Rect2(28, 19, 6, 1), eye)
			p.draw_rect(Rect2(20, 22, 3, 3), eye)
			p.draw_rect(Rect2(29, 22, 3, 3), eye)
			p.draw_rect(Rect2(21, 33, 10, 1), Color("#8a3a2e"))
		_:
			p.draw_rect(Rect2(20, 22, 3, 3), eye)
			p.draw_rect(Rect2(29, 22, 3, 3), eye)
			p.draw_rect(Rect2(22, 33, 8, 1), Color("#8a3a2e"))
