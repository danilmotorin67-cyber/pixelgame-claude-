extends Node2D

const OUTLINE := Color("#2a2a30")
const STONE := Color("#c9c8c2")
const SHADE := Color("#9a9ca3")
const LIT := Color("#eadcb8")
const RED := Color("#9b2f2a")
const RED_LIGHT := Color("#c2412d")


func _ready() -> void:
	Events.lamp_lit.connect(_on_lamp_lit)
	Events.day_started.connect(_on_day_started)


func _on_lamp_lit(_on_time: bool) -> void:
	queue_redraw()


func _on_day_started(_day_index: int) -> void:
	queue_redraw()


func _draw() -> void:
	# The lit sprite shows the beacon burning; the bottom position drives Y sorting.
	BuildingArt.draw(self, "lighthouse_lit" if Lighthouse.lamp_on else "lighthouse", Vector2(0, 4))
