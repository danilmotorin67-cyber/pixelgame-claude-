extends Node2D

const TILE := 16
const REACH := 48.0


func _ready() -> void:
	Events.farm_changed.connect(queue_redraw)
	queue_redraw()


func use_at(world_position: Vector2, player: Player) -> bool:
	var local := to_local(world_position)
	var cell := Vector2i(floori(local.x / TILE), floori(local.y / TILE))
	if cell.x < 0 or cell.y < 0 or cell.x >= Farm.WIDTH or cell.y >= Farm.HEIGHT:
		return false
	if player.global_position.distance_to(to_global(Vector2(cell) * TILE + Vector2(8, 8))) > REACH:
		_hint("Подойди ближе к грядке.")
		return true
	var plot := Farm.get_tile(cell)
	if not plot.is_empty() and bool(plot["ready"]):
		_hint("Репа собрана." if Farm.harvest(cell) else "Нет места для урожая.")
		return true
	var selected := Inventory.selected_id()
	if selected in ["tool_hoe", "tool_can"] and player.energy < 2.0:
		_hint("Нужен отдых, сил на работу нет.")
		return true
	if selected == "tool_hoe":
		if Farm.till(cell):
			player.energy -= 2.0
			player.play_tool("hoe", to_global(Vector2(cell) * TILE + Vector2(8, 8)))
			_hint("Земля взрыхлена. Теперь посади семена.")
		else:
			_hint("Здесь уже есть грядка.")
	elif selected == "tool_can":
		if Farm.water(cell):
			player.energy -= 2.0
			player.play_tool("can", to_global(Vector2(cell) * TILE + Vector2(8, 8)))
			_hint("Грядка полита.")
		else:
			_hint("Сначала взрыхли землю или дождись следующего дня.")
	elif Farm.plant(cell, selected):
		_hint("Посажено. Для роста нужен полив.")
	else:
		_hint("Выбери мотыгу, лейку или семена репы.")
	return true


func _hint(message: String) -> void:
	var hint := get_parent().get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = message


func _draw() -> void:
	for y in Farm.HEIGHT:
		for x in Farm.WIDTH:
			var cell := Vector2i(x, y)
			var plot := Farm.get_tile(cell)
			var at := Vector2(cell) * TILE
			# Raised bed, furrows and damp glints remain visible around a crop.
			paint(at, 0, 0, 16, 16, Color("#2f4a30"))
			paint(at, 1, 2, 14, 12, Color("#6b4a33"))
			paint(at, 2, 2, 12, 2, Color("#b08f6c"))
			paint(at, 2, 12, 12, 2, Color("#4a3428"))
			paint(at, 2, 5, 12, 6, Color("#8c6a4e") if plot.is_empty() else
				(Color("#4a3428") if bool(plot["watered"]) else Color("#6b4a33")))
			paint(at, 3, 8, 3, 1, Color("#b08f6c") if plot.is_empty() else Color("#8c6a4e"))
			paint(at, 10, 6, 2, 1, Color("#b08f6c") if plot.is_empty() else Color("#8c6a4e"))
			if not plot.is_empty() and bool(plot["watered"]):
				paint(at, 3, 10, 3, 1, Color("#3f7f8f"))
			if plot.is_empty():
				continue
			if str(plot["crop"]) != "":
				var stage := mini(int(plot["days"]), 3)
				if bool(plot["ready"]):
					paint(at, 5, 8, 6, 5, Color("#eadcb8"))
					paint(at, 6, 8, 3, 3, Color("#fff8e1"))
					paint(at, 4, 10, 2, 2, Color("#b08f6c"))
				paint(at, 7, 9 - stage, 2, 4 + stage, Color("#2f4a30"))
				paint(at, 5 - (stage >> 1), 7 - stage, 3 + (stage >> 1), 2, Color("#4e6e3a"))
				paint(at, 9, 7 - stage, 2 + stage, 2, Color("#7a964c"))
				if stage >= 2:
					paint(at, 6, 4 - stage, 3, 2, Color("#a9b36a"))


func paint(at: Vector2, x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(x, y), Vector2(w, h)), color)
