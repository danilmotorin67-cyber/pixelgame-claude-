class_name MashGame
extends Minigame

# Press fast: herrings cleaned at the fair, a rope hauled. Every `per` presses make one.
var presses: int = 0
var per: int = 4


func setup(p: Dictionary) -> void:
	per = int(p.get("per", 4))
	limit = float(p.get("limit", 20.0))


func press(action: String) -> void:
	if done or action != "press":
		return
	presses += 1
	score = float(presses / per)


func bot(skill: float) -> void:
	# 4 to 12 presses a second.
	if rng.randf() < (4.0 + 8.0 * skill) / 30.0:
		press("press")


func draw(ci: CanvasItem, size: Vector2) -> void:
	var fill := float(presses % per) / float(per)
	ci.draw_rect(Rect2(20, size.y / 2.0 - 8, size.x - 40, 16), Color("#2a3140"))
	ci.draw_rect(Rect2(20, size.y / 2.0 - 8, (size.x - 40) * fill, 16), Color("#c9a45a"))
	for i in int(score):
		ci.draw_rect(Rect2(20 + (i % 30) * 9, size.y / 2.0 + 20 + (i / 30) * 9, 7, 5), Color("#9fb7c9"))
