extends Node2D

const OUTLINE := Color("#2a2a30")
const STONE := Color("#c9c8c2")
const SHADE := Color("#9a9ca3")
const LIT := Color("#eadcb8")
const RED := Color("#9b2f2a")
const RED_LIGHT := Color("#c2412d")


func _ready() -> void:
	Events.lamp_lit.connect(_on_lamp_lit)
	Events.day_started.connect(_on_day_started)


func _on_lamp_lit(_on_time: bool) -> void:
	queue_redraw()


func _on_day_started(_day_index: int) -> void:
	queue_redraw()


func _draw() -> void:
	# Footprint x -24..24, top -144; the bottom position drives Y sorting.
	_px(-29, -4, 58, 5, Color("#2f4a30"))
	_px(-27, -5, 54, 3, OUTLINE)
	_px(-25, -9, 50, 6, SHADE)
	_px(-23, -120, 46, 111, OUTLINE)
	_px(-21, -118, 42, 107, STONE)
	_px(-19, -116, 28, 103, LIT)
	_px(16, -116, 5, 102, SHADE)
	for y in range(-107, -13, 17):
		_px(-18, y, 33, 1, SHADE)
		_px(-10 + (y % 3) * 2, y + 1, 1, 5, STONE)
		_px(11, y + 3, 1, 4, Color("#6c6e76"))
	# Painted stripe follows the stone face, with a highlight and cast shadow.
	_px(-22, -82, 43, 15, RED)
	_px(-18, -81, 29, 12, RED_LIGHT)
	_px(-19, -68, 38, 2, Color("#5a1e1e"))
	_px(-22, -54, 43, 6, RED)
	_px(-18, -53, 30, 3, RED_LIGHT)
	_px(-10, -108, 19, 18, OUTLINE)
	_px(-8, -106, 15, 14, Color("#24405a"))
	_px(-7, -105, 8, 4, Color("#6fb0b3"))
	_px(5, -105, 2, 12, Color("#3f7f8f"))
	_px(-14, -24, 28, 15, OUTLINE)
	_px(-11, -22, 22, 13, Color("#4a3428"))
	_px(-8, -20, 16, 9, Color("#6b4a33"))
	_px(1, -18, 2, 3, Color("#e9a64a"))
	# Projecting cornice, lantern glass and characteristic red roof.
	_px(-26, -126, 52, 7, OUTLINE)
	_px(-24, -126, 48, 4, STONE)
	_px(-19, -142, 38, 18, OUTLINE)
	_px(-17, -140, 34, 15, Color("#24405a"))
	_px(-14, -138, 28, 11, Color("#ffc85a") if Lighthouse.lamp_on else Color("#3b5668"))
	_px(-11, -137, 19, 7, Color("#ffe9a8") if Lighthouse.lamp_on else Color("#517285"))
	_px(-1, -137, 4, 6, Color("#fff8e1") if Lighthouse.lamp_on else Color("#7d9aa1"))
	for x in [-17, -7, 13]:
		_px(x, -141, 3, 18, OUTLINE)
	_px(-26, -146, 52, 5, OUTLINE)
	_px(-23, -149, 46, 5, RED)
	_px(-18, -152, 36, 4, RED_LIGHT)
	_px(-11, -155, 22, 4, RED)
	_px(-1, -162, 3, 9, OUTLINE)
	_px(-29, -132, 5, 15, OUTLINE)
	_px(24, -132, 5, 15, OUTLINE)
	_px(-29, -132, 58, 2, STONE)


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
