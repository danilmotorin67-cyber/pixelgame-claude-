extends Area2D
class_name GrottoSpot

# A touchable thing in a grotto hall (E), or the way on and back ('>' and '<'); a pickaxe for the rubble.
var cell: Vector2i = Vector2i.ZERO
var ch: String = ""


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 18)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _say(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint and text != "":
		hint.text = text


func interact(_player: Player) -> void:
	match ch:
		">":
			match Grotto.next_hall():
				"ok":
					Router.goto_map("grotto", Grotto.cell_center(Grotto.entry_cell()))
				"water":
					_say("Дальше залы ещё под водой: нужен отлив глубже.")
				"last":
					_say("Дальше хода нет.")
		"<":
			if Grotto.previous_hall() == "out":
				Router.goto_map("seal_shore", Grotto.ENTRANCE + Vector2(0, 16))
			else:
				var r := Grotto.rows()
				for y in r.size():
					var x := str(r[y]).find(">")
					if x >= 0:
						Router.goto_map("grotto", Grotto.cell_center(Vector2i(x - 1, y)))
						return
		_:
			_say(Grotto.interact(cell))
			var hall := get_parent()
			if hall and hall.has_method("refresh_walls"):
				hall.refresh_walls()


func use_tool(_player: Player, tool: String) -> String:
	if ch == "R" or ch == "T":
		var text := Grotto.interact(cell, tool) if ch == "R" else Grotto.strike(cell)
		var hall := get_parent()
		if hall and hall.has_method("refresh_walls"):
			hall.refresh_walls()
		return text
	return ""
