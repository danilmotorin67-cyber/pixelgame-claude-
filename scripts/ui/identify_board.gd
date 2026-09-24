class_name IdentifyBoard

static var filter_on: bool = true


static func open(hud: CanvasLayer, body_id: String) -> InfoPanel:
	var b := Graveyard.body(body_id)
	var candidates := func() -> Array:
		return Graveyard.candidates(Graveyard.body(body_id), filter_on)
	var body_text := func() -> String:
		var current := Graveyard.body(body_id)
		var named := str(current["identified_as"])
		return "Приметы: %s.\nФильтр по приметам: %s.%s" % [MorguePanel.clues_text(current), "вкл" if filter_on else "выкл",
			("\nВыбрано: " + str(Graveyard.registry_entry(named).get("name", ""))) if named != "" else ""]
	var lines := func() -> Array:
		var out: Array = []
		for reg in candidates.call():
			var clue_names: Array[String] = []
			for clue in reg.get("clues", []):
				clue_names.append(Graveyard.clue_text(str(clue)))
			out.append("%s, %d · %s · %s" % [reg["name"], int(reg.get("age", 0)), reg.get("ship", ""), "; ".join(clue_names)])
		return out
	var toggle := func(_panel: InfoPanel) -> String:
		filter_on = not filter_on
		return "Фильтр: %s" % ("вкл" if filter_on else "выкл")
	var confirm := func(panel: InfoPanel) -> String:
		var list: Array = candidates.call()
		var index := panel.selected_index()
		if index < 0 or index >= list.size():
			return "Выберите запись реестра."
		if Graveyard.identify(Graveyard.body(body_id), str(list[index]["id"])):
			return "Имя записано. Письмо семье — у Олафа в управе (20 кр)."
		return "Нельзя: имя уже отправлено семье или занято."
	if b.is_empty():
		return null
	return InfoPanel.open(hud, "Доска опознания", body_text, [["Фильтр", toggle], ["Подтвердить", confirm]], lines)
