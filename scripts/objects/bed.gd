extends Area2D


func interact(_player: Player) -> void:
	if not Clock.paused:
		Night.end_day(false)
