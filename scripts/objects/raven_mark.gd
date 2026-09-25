extends Node2D
class_name RavenMark

# 18.4: ravens circling over a spot of disturbed ground — dig it with a hoe or a shovel.
var t: float = 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-5, 2, 10, 4), Color("#5a4a34"))
	draw_rect(Rect2(-3, 1, 2, 1), Color("#8c6a4e"))
	draw_rect(Rect2(2, 3, 2, 1), Color("#8c6a4e"))
	for i in 3:
		var a := t * 1.6 + float(i) * TAU / 3.0
		var p := Vector2(cos(a) * 12.0, -22.0 + sin(a) * 4.0)
		# Flying towards -sin(a): the sprite faces its direction of travel.
		if CastSprite.draw(self, "raven_fly", "fly", "south", t + float(i) * 0.25, p + Vector2(0, 6), sin(a) > 0.0):
			continue
		draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 1)), Color("#1b1b22"))
		draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), Color("#1b1b22"))
