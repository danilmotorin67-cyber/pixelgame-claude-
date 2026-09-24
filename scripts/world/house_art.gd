extends Node2D

const OUTLINE := Color("#2a2a30")
const ROOF := Color("#24405a")
const ROOF_LIGHT := Color("#2f5a76")
const PLASTER := Color("#d8c49a")
const SHADOW := Color("#8c6a4e")


func _draw() -> void:
	_px(-52, -5, 104, 7, Color("#2f4a30"))
	_px(-49, -43, 98, 43, OUTLINE)
	_px(-47, -42, 94, 40, SHADOW)
	_px(-44, -40, 87, 32, PLASTER)
	_px(-44, -39, 87, 3, Color("#eadcb8"))
	# Uneven courses of exposed stone sit under the wooden roof.
	for row in range(3):
		var y := -33 + row * 11
		for col in range(8):
			var x := -43 + col * 11 + (5 if row % 2 == 1 else 0)
			if x < -36 or x > 34:
				continue
			_px(x, y, 6, 1, Color("#b08f6c"))
			_px(x + 7, y + 1, 1, 5, Color("#b08f6c"))
	_px(-52, -10, 104, 3, SHADOW)
	# Pixel stepped slate roof. Each successive course widens toward the eaves.
	for step in range(19):
		var x := -5 - step * 3
		var y := -75 + step * 2
		_px(x, y, 10 + step * 6, 3, OUTLINE)
		_px(x + 3, y, 5 + step * 6, 2, ROOF if step % 4 else ROOF_LIGHT)
	for row in range(4):
		for col in range(7):
			var x := -40 + col * 12 + (6 if row % 2 else 0)
			var y := -47 + row * 4
			if abs(x) > 42 - row * 3:
				continue
			_px(x, y, 7, 1, Color("#3f7f8f"))
	_px(-38, -88, 11, 19, OUTLINE)
	_px(-36, -86, 7, 15, Color("#9b2f2a"))
	_px(-37, -89, 10, 3, Color("#c9c8c2"))
	# Warm sash windows and an accessible door marking the bed interaction.
	for x in [-33, 20]:
		_px(x - 2, -33, 18, 23, OUTLINE)
		_px(x, -31, 14, 18, Color("#6b4a33"))
		_px(x + 2, -29, 10, 13, Color("#ffc85a"))
		_px(x + 2, -29, 5, 7, Color("#ffe9a8"))
		_px(x + 6, -30, 2, 17, OUTLINE)
		_px(x + 1, -23, 12, 2, OUTLINE)
		_px(x - 4, -11, 21, 2, Color("#c9c8c2"))
	_px(-12, -27, 24, 27, OUTLINE)
	_px(-10, -25, 20, 25, Color("#4a3428"))
	_px(-8, -22, 15, 22, Color("#6b4a33"))
	_px(5, -13, 2, 3, Color("#ffc85a"))
	_px(-14, -2, 29, 2, Color("#c9c8c2"))


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
