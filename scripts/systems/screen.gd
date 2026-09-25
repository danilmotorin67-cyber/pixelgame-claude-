class_name Screen

# 960×540 rendering, ×2 to 1920×1080. The world keeps its units (a tile is 16 units, the logic, the maps and the
# saves are unchanged); the camera shows it at ZOOM screen pixels per unit, so art drawn at 32 px per tile is
# shown pixel for pixel with a sprite scale of 1 / ZOOM. The interface is laid out in BASE units and scaled.
const ZOOM := 2
const BASE := Vector2(480, 270)
const SIZE := Vector2(960, 540)
# Sprites drawn at the new resolution (32 px per tile) use this scale in the world.
const ART_SCALE := 1.0 / ZOOM


static func layout_root(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = BASE
	control.scale = Vector2(ZOOM, ZOOM)
