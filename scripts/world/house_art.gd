extends Node2D

# The keeper's house grows with its upgrades: house_1, house_2 and house_3.


func _ready() -> void:
	Events.day_started.connect(func(_d: int) -> void: queue_redraw())


func _draw() -> void:
	BuildingArt.draw(self, "house_%d" % clampi(Buildings.level("house") + 1, 1, 3), Vector2(0, 4))
