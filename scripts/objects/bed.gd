extends Area2D

# 5.1: the house is locked until the key under the cat is found ("The key is under the cat").


func interact(_player: Player) -> void:
	if Clock.paused:
		return
	if not Game.flag("house_key") and Game.flag("prologue_done"):
		var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
		if hint:
			hint.text = "Дверь заперта. Агата писала: «Ключ — под кошкой»."
		return
	Night.end_day(false)
