extends Area2D
class_name GravePlot

var plot: int = 0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 36)
	collision.shape = shape
	add_child(collision)
	Events.body_buried.connect(func(_id: String, _q: int) -> void: queue_redraw())


func grave() -> Dictionary:
	return Graveyard.graves[plot]


func _draw() -> void:
	var g := grave()
	if bool(g["old"]):
		draw_rect(Rect2(-9, -4, 18, 14), Color("#6b5a48"))
		if bool(g["repaired"]):
			draw_rect(Rect2(-7, -14, 14, 8), Color("#9a9ca3"))
		else:
			draw_rect(Rect2(-7, -10, 5, 5), Color("#6f6a60"))
			draw_rect(Rect2(1, -8, 6, 3), Color("#6f6a60"))
	elif bool(g["filled"]):
		draw_rect(Rect2(-9, -4, 18, 14), Color("#8c6a4e") if not bool(g["sunk"]) else Color("#4a3428"))
		match str(g["marker"]):
			"mound":
				draw_rect(Rect2(-8, -8, 16, 5), Color("#9a9ca3"))
				draw_rect(Rect2(-5, -11, 10, 3), Color("#c9c8c2"))
			"wooden_cross", "carved_cross":
				draw_rect(Rect2(-1, -18, 3, 16), Color("#6b4a32"))
				draw_rect(Rect2(-5, -14, 11, 3), Color("#6b4a32"))
	elif bool(g["open"]):
		draw_rect(Rect2(-8, -6, 16, 16), Color("#2a2a30"))
		if str(g["body"]) != "":
			draw_rect(Rect2(-5, -4, 10, 12), Color("#d8c49a"))
	elif int(g["dug"]) > 0:
		draw_rect(Rect2(-8, -4, 16, 12), Color("#4a3428"))
	else:
		draw_rect(Rect2(-9, -4, 18, 14), Color(0.29, 0.2, 0.16, 0.35))
	if bool(g["weeds"]):
		for x in [-8, -2, 5]:
			draw_rect(Rect2(x, 4, 2, 6), Color("#7a964c"))


func use_tool(player: Player, tool: String) -> String:
	var g := grave()
	var result := ""
	if tool == "tool_scythe" and Graveyard.tend(plot, tool):
		result = "Сорняки скошены."
	elif tool == "tool_shovel":
		if bool(g["sunk"]) and Graveyard.tend(plot, tool):
			result = "Проседание засыпано."
		elif str(g["body"]) != "" and not bool(g["filled"]):
			if Graveyard.fill(plot):
				player.spend_energy("shovel")
				result = "Могила засыпана. Качество %d. Поставьте знак: E с крестом или 10 камнями." % int(g["quality"])
		elif not bool(g["old"]) and str(g["body"]) == "" and not bool(g["open"]):
			var state := Graveyard.dig(plot)
			player.energy = maxf(0.0, player.energy - float(Graveyard.cfg("dig_energy")))
			result = "Могила выкопана. Положите тело: E с ношей." if state == "open" \
				else "Копаете: %d из %d." % [int(g["dug"]), Graveyard.dig_hits_needed()]
	queue_redraw()
	return result


func interact(player: Player) -> void:
	var hint := get_tree().current_scene.get_node("HUD/Hint") as Label
	var g := grave()
	if Graveyard.carried != "":
		hint.text = "Тело уложено. Засыпьте могилу лопатой." if Graveyard.lay(plot) \
			else "Сначала выкопайте могилу лопатой (ЛКМ)."
		Events.body_moved.emit(str(g["body"]), "grave")
	elif bool(g["old"]) and not bool(g["repaired"]):
		hint.text = "Старая могила приведена в порядок." if Graveyard.repair_old(plot) \
			else "Старая разбитая могила. Нужны 5 камня и коса."
	elif bool(g["filled"]) and str(g["marker"]) == "":
		var selected := Inventory.selected_id()
		var marker := "mound" if selected == "stone" else selected
		if Graveyard.place_marker(plot, marker):
			hint.text = "Знак поставлен. Качество могилы %d." % int(g["quality"])
			if marker == "headstone":
				_choose_epitaph()
		else:
			hint.text = "Выберите на панели крест или камень (10 шт.) и нажмите E."
	elif str(g["body"]) != "" and Clock.is_night() and Inventory.selected_id() == "tool_shovel":
		hint.text = "Эксгумация. Честь −10." if Graveyard.exhume(plot) else "Нельзя."
	else:
		var b := Graveyard.body(str(g["body"]))
		var name := str(g["name"]) if str(g["name"]) != "" else "Безымянный"
		hint.text = ("%s · качество %d%s" % [name, int(g["quality"]),
			(" · «%s»" % str(g["epitaph"])) if str(g.get("epitaph", "")) != "" else ""]) if not b.is_empty() or bool(g["old"]) \
			else "Свободное место. Копать — лопатой (ЛКМ)."
		if str(g["marker"]) == "headstone" and str(g.get("epitaph", "")) == "":
			_choose_epitaph()
	queue_redraw()


# 11.5: the headstone waits for its words — serious, warm or ironic (the Book of Epitaphs adds two).
func _choose_epitaph() -> void:
	var hud := get_tree().current_scene.get_node("HUD") as CanvasLayer
	var options := Graveyard.epitaph_options(plot)
	var body := func() -> String:
		var lines: Array = ["Что высечь на камне?"]
		for o in options:
			lines.append("• " + str(o["text"]))
		return "\n".join(lines)
	var names := {"serious": "Строго", "warm": "Тепло", "ironic": "С усмешкой", "sea": "По-морскому", "masterpiece": "Шедевр"}
	var buttons: Array = []
	for i in options.size():
		var index := i
		buttons.append([str(names.get(str(options[i]["style"]), options[i]["style"])), func(p: InfoPanel) -> String:
			Graveyard.set_epitaph(plot, index)
			p.close()
			queue_redraw()
			return ""])
	InfoPanel.open(hud, "Эпитафия", body, buttons)
