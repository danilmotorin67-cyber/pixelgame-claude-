extends Area2D
class_name StoryObject

# A place of the story in the world (data/story_spots.json): E opens its panel; some open their own screens
# (the code lock, the Guild House, Neptune's counter, a festival stand), some actions are games of skill.
var spot: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 18)
	collision.shape = shape
	add_child(collision)


func kind() -> String:
	return str(spot.get("kind", ""))


func _process(delta: float) -> void:
	_time += delta
	if kind() in ["glow_water", "daughter", "ritual", "bonfire"]:
		queue_redraw()


func _draw() -> void:
	match kind():
		"bonfire":
			draw_rect(Rect2(-6, 2, 12, 4), Color("#6b4a32"))
			if Story.bonfire_lit(int(spot.get("index", 0))):
				var flicker := 2.0 * sin(_time * 9.0)
				draw_colored_polygon(PackedVector2Array([Vector2(-5, 2), Vector2(0, -10 - flicker), Vector2(5, 2)]), Color("#f0a030"))
		"glow_water", "daughter":
			var a := 0.45 + 0.25 * sin(_time * 2.5)
			draw_circle(Vector2.ZERO, 7.0, Color(0.55, 0.85, 1.0, a))
		"cat":
			draw_rect(Rect2(-4, -5, 8, 9), Color("#8a8d93"))
			draw_rect(Rect2(-3, -8, 2, 3), Color("#8a8d93"))
			draw_rect(Rect2(1, -8, 2, 3), Color("#8a8d93"))
		"board", "journal", "code_lock", "archive", "cabinet":
			draw_rect(Rect2(-7, -8, 14, 12), Color("#6b4a32"))
			draw_rect(Rect2(-5, -6, 10, 8), Color("#d8c9a0"))
		"guild", "neptune_counter", "cannery", "kronvald":
			draw_rect(Rect2(-6, -6, 12, 10), Color("#3a4a5a"))
			draw_rect(Rect2(-2, -2, 4, 6), Color("#c9a45a"))
		"ritual", "circle":
			draw_circle(Vector2.ZERO, 5.0, Color("#1a1d24"))
			draw_circle(Vector2(0, -1), 2.0, Color(0.7, 0.9, 1.0, 0.5 + 0.3 * sin(_time * 3.0)))
		"festival":
			draw_rect(Rect2(-8, -10, 16, 3), Color("#c2412d"))
			draw_rect(Rect2(-7, -7, 2, 11), Color("#6b4a32"))
			draw_rect(Rect2(5, -7, 2, 11), Color("#6b4a32"))
		_:
			draw_circle(Vector2.ZERO, 4.0, Color("#e8d27a"))
			draw_circle(Vector2.ZERO, 2.0, Color("#6b4a32"))


func _hud() -> CanvasLayer:
	return get_tree().current_scene.get_node("HUD") as CanvasLayer


func interact(_player: Player) -> void:
	match kind():
		"code_lock":
			CodeLockPanel.open(_hud())
			return
		"guild":
			Events.quest_event.emit("guild_opened", "")
			CommunityPanel.open(_hud())
			return
		"neptune_counter":
			CommunityPanel.open_neptune(_hud())
			return
		"festival":
			FestivalPanel.open(_hud())
			return
	open_panel("")


func open_panel(status: String) -> void:
	var id := str(spot.get("id", ""))
	var view := Story.spot_view(id)
	var buttons: Array = []
	for pair in view.get("actions", []):
		var action := str(pair[1])
		buttons.append([str(pair[0]), func(_p: InfoPanel) -> String: return _run(action)])
	var panel := InfoPanel.open(_hud(), str(view["title"]), func() -> String: return str(Story.spot_view(id)["text"]), buttons)
	panel.set_status(status)


func _run(action: String) -> String:
	var game := Spots.minigame(spot, action)
	if game != null:
		var panel := _hud().get_node_or_null("InfoPanel") as InfoPanel
		if panel:
			panel.close()
		MinigameView.open(_hud(), game, func(g: Minigame) -> void: _after(action, g))
		return ""
	var result := Story.spot_action(str(spot["id"]), action)
	if action.begins_with("ally:") or not ConditionContext.check(str(spot.get("when", ""))):
		call_deferred("_reopen", result)
	return result


func _reopen(status: String) -> void:
	if not ConditionContext.check(str(spot.get("when", ""))):
		var panel := _hud().get_node_or_null("InfoPanel") as InfoPanel
		if panel:
			panel.set_status(status)
		get_parent().call_deferred("refresh")
		return
	open_panel(status)


func _after(action: String, game: Minigame) -> void:
	var text := Spots.after_minigame(spot, action, game)
	InfoPanel.open(_hud(), Loc.t(str(spot.get("title", ""))), func() -> String: return text)
	get_parent().call_deferred("refresh")
