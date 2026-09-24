extends Node2D
class_name GraveyardWorld

const FENCE := Color("#6b4a32")
const EARTH := Color("#4a3428")
const MOUND := Color("#8c6a4e")


func _ready() -> void:
	name = "GraveyardWorld"
	z_index = -1
	for plot in Graveyard.graves.size():
		var node := GravePlot.new()
		node.name = "Plot_%d" % plot
		node.plot = plot
		node.position = Graveyard.plot_position(plot)
		add_child(node)
	var morgue := MorgueDoor.new()
	morgue.name = "MorgueDoor"
	var at: Array = Graveyard.cfg("morgue")
	morgue.position = Vector2(float(at[0]), float(at[1]))
	add_child(morgue)
	var pump := WaterPump.new()
	pump.name = "WaterPump"
	var pump_at: Array = Graveyard.cfg("pump")
	pump.position = Vector2(float(pump_at[0]), float(pump_at[1]))
	add_child(pump)
	Events.night_resolved.connect(func(_r: Dictionary) -> void: queue_redraw())


func _draw() -> void:
	var origin: Array = Graveyard.cfg("origin")
	var size: Array = Graveyard.cfg("plot")
	var w := float(size[0]) * float(Graveyard.cfg("cols"))
	var h := float(size[1]) * float(Graveyard.cfg("rows"))
	var rect := Rect2(float(origin[0]) - 6, float(origin[1]) - 6, w + 12, h + 12)
	draw_rect(rect, Color("#3f5a36"))
	for x in range(int(rect.position.x), int(rect.end.x), 8):
		draw_rect(Rect2(x, rect.position.y, 2, 6), FENCE)
		draw_rect(Rect2(x, rect.end.y - 6, 2, 6), FENCE)
	for y in range(int(rect.position.y), int(rect.end.y), 8):
		draw_rect(Rect2(rect.position.x, y, 2, 6), FENCE)
		draw_rect(Rect2(rect.end.x - 2, y, 2, 6), FENCE)
	draw_rect(Rect2(rect.position.x, rect.position.y + 2, rect.size.x, 1), FENCE)
	draw_rect(Rect2(rect.position.x, rect.end.y - 4, rect.size.x, 1), FENCE)
	var morgue: Array = Graveyard.cfg("morgue")
	var m := Vector2(float(morgue[0]), float(morgue[1]))
	draw_rect(Rect2(m + Vector2(-26, -34), Vector2(52, 30)), Color("#9a9ca3"))
	draw_rect(Rect2(m + Vector2(-30, -40), Vector2(60, 8)), Color("#45464e"))
	draw_rect(Rect2(m + Vector2(-7, -18), Vector2(14, 14)), Color("#4a3428"))
