extends Node2D

# The keeper's house grows with its upgrades: house_1, house_2 and house_3.


var _smoke: Array = []


func _ready() -> void:
	Events.day_started.connect(func(_d: int) -> void:
		queue_redraw()
		_build_smoke())
	Events.hour_changed.connect(func(_h: int) -> void:
		for s in _smoke:
			s.emitting = Fx.smoking())
	_build_smoke()


# Smoke from the chimney of the house as it stands now (house_2 has none).
func _build_smoke() -> void:
	for s in _smoke:
		s.queue_free()
	_smoke.clear()
	for point in BuildingArt.chimneys_at("house_%d" % clampi(Buildings.level("house") + 1, 1, 3), Vector2(0, 4)):
		var s := Fx.smoke()
		s.position = point
		s.emitting = Fx.smoking()
		add_child(s)
		_smoke.append(s)


func _draw() -> void:
	BuildingArt.draw(self, "house_%d" % clampi(Buildings.level("house") + 1, 1, 3), Vector2(0, 4))
