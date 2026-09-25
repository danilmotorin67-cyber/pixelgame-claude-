class_name MorguePanel

const STATE := ["осмотрено", "обмыто", "в парусине", "в гробу", "отпето"]


static func morgue_bodies() -> Array:
	var out: Array = []
	for b in Graveyard.bodies:
		if str(b["where"]) == "morgue":
			out.append(b)
	return out


static func describe(b: Dictionary) -> String:
	var name := "Безымянный"
	if str(b["identified_as"]) != "":
		name = str(Graveyard.registry_entry(str(b["identified_as"])).get("name", name))
	var marks: Array[String] = []
	for pair in [[b["examined"], 0], [b["washed"], 1], [b["sewn"], 2], [int(b["coffin"]) > 0, 3], [b["funeral"], 4]]:
		if bool(pair[0]):
			marks.append(STATE[int(pair[1])])
	return "%s · сохранность %d · подготовка %d%s" % [name, int(b["preservation"]), Graveyard.preparation(b),
		(" · " + ", ".join(marks)) if not marks.is_empty() else ""]


static func open(hud: CanvasLayer) -> InfoPanel:
	var pick := func(panel: InfoPanel) -> Dictionary:
		var list := morgue_bodies()
		var index := panel.selected_index()
		return list[index] if index >= 0 and index < list.size() else {}
	var body_text := func() -> String:
		var list := morgue_bodies()
		if list.is_empty():
			return "Секционный стол пуст. Табличка на двери: «Стучите. Нам торопиться некуда»."
		return "Выберите тело. Приметы открываются осмотром."
	var lines := func() -> Array:
		var out: Array = []
		for b in morgue_bodies():
			out.append(describe(b))
		return out
	var player := func() -> Player:
		return hud.get_parent().get_node_or_null("Player") as Player
	var examine := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		var keeper: Player = player.call()
		if b.is_empty() or keeper == null or keeper.energy <= 0.0:
			return "Нет тела или сил."
		if bool(b["examined"]):
			return clues_text(b)
		var found := Graveyard.examine(b, Game.flag("magnifier"))
		keeper.spend_energy("examine_body")
		Clock.pass_time(60)
		return "Осмотр: " + clues_text(b) if not found.is_empty() else "Ничего нового."
	var search_box := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		if b.is_empty():
			return "Нет тела."
		if not Game.flag("morgue_cabinet"):
			return "Вещи некуда сложить: нужен шкаф и ящик для родных (15 досок, «Улучшения»)."
		var items := Graveyard.search(b, false)
		return "Вещи — в ящик для родных: %d." % items.size() if not items.is_empty() else "При нём ничего или уже обыскан."
	var wash := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		var keeper: Player = player.call()
		if b.is_empty() or keeper == null:
			return "Нет тела."
		if Graveyard.wash(b):
			keeper.spend_energy("examine_body")
			Clock.pass_time(30)
			return "Обмыто. Подготовка +8."
		return "Нужно ведро пресной воды (колонка у дома) — или умывальня."
	var sew := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		var keeper: Player = player.call()
		if b.is_empty() or keeper == null:
			return "Нет тела."
		if Graveyard.sew(b, true):
			keeper.spend_energy("examine_body")
			Clock.pass_time(60)
			return "Зашито в парусину, последний стежок — через нос. Моряк не возражал."
		return "Нужны парусина и нитки."
	var coffin := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		if b.is_empty():
			return "Нет тела."
		return "Уложено в гроб." if Graveyard.coffin(b, Inventory.selected_id()) else "Выберите гроб на панели."
	var funeral := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		var keeper: Player = player.call()
		if b.is_empty() or keeper == null:
			return "Нет тела."
		if Graveyard.self_funeral(b):
			keeper.energy = maxf(0.0, keeper.energy - 20.0)
			Clock.pass_time(30)
			return "Слово смотрителя сказано."
		return "Отпевание — у Бенедикта в воскресенье; самому нужно «Слово смотрителя» и свеча."
	var listen := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		if b.is_empty():
			return "Нет тела."
		var said := Graveyard.whisper(b)
		return said if said != "" else "Тишина. Шепчут только в первую ночь, с полуночи до двух."
	var carry := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		if b.is_empty() or not Graveyard.take_from_morgue(b):
			return "Руки заняты или нет тела."
		panel.close()
		return ""
	var board := func(panel: InfoPanel) -> String:
		var b: Dictionary = pick.call(panel)
		if b.is_empty():
			return "Нет тела."
		panel.close()
		IdentifyBoard.open(hud, str(b["id"]))
		return ""
	return InfoPanel.open(hud, "Покойницкая", body_text, [["Осмотреть", examine], ["Обыскать", search_box],
		["Обмыть", wash], ["Зашить", sew], ["В гроб", coffin], ["Отпеть", funeral], ["Слушать", listen],
		["Опознать", board], ["Нести", carry], ["Улучшения", func(panel: InfoPanel) -> String:
			panel.close()
			open_upgrades(hud)
			return ""]], lines)


# 11.11: the washroom, the lamp table, the cabinet and the graveyard bell, built from materials on the spot.
static func open_upgrades(hud: CanvasLayer) -> InfoPanel:
	var body := func() -> String:
		var lines: Array = []
		for id in Graveyard.UPGRADES:
			var info: Dictionary = Graveyard.UPGRADES[id]
			var cost: Array = []
			for pair in info["cost"]:
				cost.append("%s ×%d" % [Crafting.item_name(str(pair[0])), int(pair[1])])
			lines.append("%s %s — %s (%s)" % ["✓" if Game.flag(id) else "•", str(info["title"]), str(info["effect"]), ", ".join(cost)])
		return "\n".join(lines)
	var buttons: Array = []
	for key in Graveyard.UPGRADES:
		var id: String = key
		buttons.append([str(Graveyard.UPGRADES[id]["title"]), func(_p: InfoPanel) -> String:
			if Game.flag(id):
				return "Уже сделано."
			return "Готово: %s." % str(Graveyard.UPGRADES[id]["title"]) if Graveyard.build_upgrade(id) else "Не хватает материалов."])
	return InfoPanel.open(hud, "Улучшения покойницкой", body, buttons)


static func clues_text(b: Dictionary) -> String:
	var parts: Array[String] = []
	for clue in b["revealed"]:
		parts.append(Graveyard.clue_text(str(clue)))
	return "; ".join(parts) if not parts.is_empty() else "примет не видно"
