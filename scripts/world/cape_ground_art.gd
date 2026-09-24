extends Node2D

# Scenery sits behind the player and the interactive garden. All shapes snap to
# native screen pixels and use the palette from full.md, section 31.2.
const ROCK := Color("#45464e")
const MOSS_DARK := Color("#2f4a30")
const MOSS := Color("#4e6e3a")
const MOSS_LIGHT := Color("#7a964c")
const LICHEN := Color("#a9b36a")
const PATH := Color("#8c6a4e")
const PATH_LIGHT := Color("#b08f6c")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 1120), ROCK)
	# Each 16 pixel cell has several deliberate clusters, with no runtime RNG.
	for ty in range(5, 55):
		for tx in range(5, 80):
			var p := Vector2i(tx * 16, ty * 16)
			var seed := (tx * 73 + ty * 137 + tx * ty * 19) % 29
			draw_rect(Rect2(p, Vector2i(16, 16)), MOSS)
			if seed % 5 == 0:
				_px(p.x + 1, p.y + 2, 5, 2, MOSS_DARK)
				_px(p.x + 4, p.y + 4, 4, 1, MOSS_DARK)
				_px(p.x + 2, p.y + 10, 3, 2, MOSS_DARK)
			if seed % 7 == 0:
				_px(p.x + 2, p.y + 5, 5, 2, MOSS_LIGHT)
				_px(p.x + 4, p.y + 3, 1, 4, LICHEN)
			if seed % 4 == 1:
				_px(p.x + 11, p.y + 10, 1, 4, MOSS_DARK)
				_px(p.x + 13, p.y + 8, 1, 4, MOSS_LIGHT)
			if seed == 8 or seed == 19:
				_px(p.x + 6, p.y + 10, 4, 2, Color("#9a9ca3"))
				_px(p.x + 6, p.y + 9, 2, 1, Color("#c9c8c2"))
			if seed == 3 and (tx + ty) % 3 == 0:
				_px(p.x + 10, p.y + 6, 2, 2, Color("#a06a9e"))
				_px(p.x + 11, p.y + 5, 1, 1, Color("#dfe7ea"))

	# A compact worn trail links the house, the beacon and the garden entrance.
	draw_colored_polygon(PackedVector2Array([
		Vector2(594, 336), Vector2(608, 336), Vector2(646, 276),
		Vector2(700, 251), Vector2(742, 257), Vector2(742, 271),
		Vector2(706, 266), Vector2(655, 289), Vector2(613, 345)
	]), PATH)
	for index in range(34):
		var x := 618 + index * 4
		var y := 283 - (index / 5) + ((index * 13) % 7)
		_px(x, y, 3, 1, PATH_LIGHT)
	for index in range(8):
		_px(615 + index * 5, 339 - index * 6, 2, 2, PATH_LIGHT)

	# Dense island plants frame the playable space without obscuring crop cells.
	for i in range(33):
		var x := 470 + ((i * 59) % 445)
		var y := 143 + ((i * 103) % 310)
		if x > 658 and x < 845 and y > 280:
			continue
		if x > 558 and x < 650 and y > 245 and y < 341:
			continue
		_heather(x, y, i % 3)
	for i in range(11):
		var x := 449 + (i * 89) % 490
		var y := 168 + (i * 71) % 270
		if x > 552 and x < 847 and y > 230 and y < 417:
			continue
		_px(x, y + 4, 11, 2, MOSS_DARK)
		_px(x + 1, y + 1, 9, 4, Color("#6c6e76"))
		_px(x + 3, y, 5, 1, Color("#c9c8c2"))
		_px(x + 8, y + 2, 2, 2, Color("#9a9ca3"))

	# A few low fence posts and a gate make the garden legible from above.
	for x in range(661, 853, 16):
		if x > 681 and x < 714:
			continue
		_px(x, 290, 3, 16, Color("#6b4a33"))
		_px(x + 1, 290, 1, 2, Color("#d8c49a"))
	_px(659, 296, 24, 2, Color("#b08f6c"))
	_px(714, 296, 140, 2, Color("#b08f6c"))


func _heather(x: int, y: int, variant: int) -> void:
	_px(x + 1, y + 9, 11, 2, MOSS_DARK)
	_px(x + 3, y + 5, 8, 5, MOSS)
	_px(x, y + 7, 5, 3, MOSS_LIGHT)
	_px(x + 6, y + 2, 2, 5, Color("#6b3f6e"))
	_px(x + 5, y + 2 + variant, 4, 2, Color("#a06a9e"))
	_px(x + 9, y + 4, 3, 2, Color("#6b3f6e"))


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
