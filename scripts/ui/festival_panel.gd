class_name FestivalPanel

# The festival stand (24.2): the day's activities; games of skill open over the HUD and come back with a result.


static func open(hud: CanvasLayer, status: String = "") -> InfoPanel:
	var id := Festivals.active
	if id == "":
		var f := Festivals.today()
		if f.is_empty():
			return null
		Festivals.begin(str(f["id"]))
		id = Festivals.active
	var info := Festivals.info(id)
	var body := func() -> String:
		var lines: Array = [Loc.t("fest.started") % Festivals.name_of(id)]
		for a in info.get("activities", []):
			lines.append(("✓ " if Festivals.done(str(a["id"])) else "• ") + Loc.t(str(a["label"])))
		if Inventory.count_of("fair_token") > 0:
			lines.append("Жетоны: %d" % Inventory.count_of("fair_token"))
		return "\n".join(lines)
	var buttons: Array = []
	for a in info.get("activities", []):
		var act := str(a["id"])
		if str(a["kind"]) == "shop":
			var shop_id := str(a["params"].get("shop", ""))
			buttons.append([Loc.t(str(a["label"])), func(p: InfoPanel) -> String:
				p.close()
				ShopPanel.open(hud, shop_id)
				return ""])
			continue
		buttons.append([Loc.t(str(a["label"])), func(p: InfoPanel) -> String: return _run(hud, p, act)])
	if id == "herring_fair":
		var stock: Array = Story.cfg("token_shop", [])
		for i in stock.size():
			var index := i
			buttons.append(["Жетоны: " + Crafting.item_name(str(stock[i][0])), func(_p: InfoPanel) -> String: return Festivals.token_shop(index)])
	var panel := InfoPanel.open(hud, Festivals.name_of(id), body, buttons)
	panel.set_status(status)
	return panel


static func _run(hud: CanvasLayer, panel: InfoPanel, act: String) -> String:
	var result: Variant = Festivals.run(act)
	if result is Minigame:
		panel.close()
		MinigameView.open(hud, result, func(g: Minigame) -> void: open(hud, Festivals.finish(act, g)))
		return ""
	return str(result)
