extends Area2D

const INSIDE := Vector2(10 * 16 + 8, 10 * 16 + 8)


func interact(_player: Player) -> void:
	if Clock.paused:
		return
	Router.goto_map("lh_1", INSIDE)
