extends Node2D

# A short, pixel-snapped action overlay. The working end points toward the
# clicked garden tile; the actual farm action is still performed by Farm.
func _draw() -> void:
	var player := get_parent() as Player
	if player == null or player.tool_time <= 0.0:
		return
	var quarter_turn: float = [PI / 2.0, PI, 0.0, -PI / 2.0][player._direction_index()]
	var swing := player.tool_time < Player.TOOL_DURATION * 0.55
	var grip := Vector2(3, -13) if not swing else Vector2(4, -10)
	draw_set_transform(grip, quarter_turn, Vector2.ONE)
	if player.tool_kind == "hoe":
		_hoe(swing)
	elif player.tool_kind == "can":
		_can(swing)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hoe(swing: bool) -> void:
	var dy := 2 if swing else -2
	_px(0, dy, 14, 2, Color("#4a3428"))
	_px(1, dy, 10, 1, Color("#b08f6c"))
	_px(12, dy - 5, 3, 11, Color("#45464e"))
	_px(13, dy - 5, 4, 2, Color("#c9c8c2"))
	_px(14, dy + 4, 4, 2, Color("#9a9ca3"))


func _can(swing: bool) -> void:
	var dy := 1 if swing else -2
	_px(2, dy - 3, 10, 7, Color("#2a2a30"))
	_px(3, dy - 2, 8, 5, Color("#3f7f8f"))
	_px(4, dy - 2, 6, 1, Color("#6fb0b3"))
	_px(4, dy - 6, 5, 3, Color("#9a9ca3"))
	_px(5, dy - 5, 3, 3, Color("#4e6e3a"))
	_px(11, dy - 2, 4, 2, Color("#9a9ca3"))
	_px(15, dy - 1, 2, 1, Color("#c9c8c2"))
	if swing:
		_px(17, dy + 2, 1, 2, Color("#6fb0b3"))
		_px(19, dy + 5, 1, 2, Color("#3f7f8f"))
		_px(16, dy + 6, 1, 2, Color("#6fb0b3"))


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
