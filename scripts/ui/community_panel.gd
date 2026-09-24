class_name CommunityPanel

# The Guild House (23): the six rooms and their offerings; the selected hotbar item goes to whichever open slot
# of the chosen room it fits. Neptune's counter at Grim's house sells the rooms instead (23.3).


static func _rooms() -> Array:
	return Data.all("bundles")


static func room_line(room: Dictionary) -> String:
	var id := str(room["id"])
	if Community.done.has(id):
		return "✓ " + Loc.t(str(room["name"]))
	if Community.paid.has(id):
		return "⚓ " + Loc.t(str(room["name"])) + " («Нептун»)"
	var parts: Array = []
	for s in room["slots"]:
		var sid := str(s["id"])
		parts.append("%s %d/%d" % [Loc.t(str(s["name"])), Community.slot_given(id, sid).size(), int(s["need"])])
	return Loc.t(str(room["name"])) + ": " + ", ".join(parts)


static func open(hud: CanvasLayer) -> InfoPanel:
	var body := func() -> String:
		return Loc.t("community.head") % Community.rooms_done()
	var lines := func() -> Array:
		var out: Array = []
		for room in _rooms():
			out.append(room_line(room))
		return out
	var offer := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		if index < 0:
			return ""
		var room: Dictionary = _rooms()[index]
		if str(room["id"]) == "chest":
			for s in room["slots"]:
				if not Community.slot_done("chest", str(s["id"])):
					return Community.offer_money("chest", str(s["id"]))
			return ""
		return Community.offer(str(room["id"]), Inventory.selected_hotbar)
	var needs := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		if index < 0:
			return ""
		var room: Dictionary = _rooms()[index]
		var out: Array = []
		for s in room["slots"]:
			if Community.slot_done(str(room["id"]), str(s["id"])):
				continue
			var names: Array = []
			for entry in s["items"]:
				if str(entry[0]) == "money":
					names.append("%d кр" % int(entry[1]))
				elif not Community.slot_given(str(room["id"]), str(s["id"])).has(str(entry[0])):
					names.append("%s ×%d" % [_name(str(entry[0])), int(entry[1])])
			out.append("%s (%d): %s" % [Loc.t(str(s["name"])), int(s["need"]), ", ".join(names)])
		return "\n".join(out)
	return InfoPanel.open(hud, Loc.t("story.spot.guild_house"), body, [[Loc.t("community.offer"), offer], ["Что нужно", needs]], lines)


static func _name(pattern: String) -> String:
	var first := pattern.split("|")[0].split("@")[0]
	if first.begins_with("tag:"):
		return "дар призрака" if first == "tag:ghost_gift" else first.substr(4)
	return Crafting.item_name(first)


static func open_neptune(hud: CanvasLayer) -> InfoPanel:
	var body := func() -> String:
		if Community.contract_active():
			return "Договор действует. Комнату можно оплатить — Туманники из неё уйдут."
		return "Предложение «Нептуна» лежит на стойке до Зимы 28."
	var lines := func() -> Array:
		var out: Array = []
		for room in _rooms():
			var price := int(room.get("neptune_price", 0))
			out.append("%s — %s" % [room_line(room), ("%d кр" % price) if price > 0 else "отказ"])
		return out
	var sign := func(_panel: InfoPanel) -> String:
		return Loc.t("neptune.signed") if Community.sign_contract() else ""
	var pay := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		if index < 0:
			return ""
		return Community.pay_room(str(_rooms()[index]["id"]))
	var buttons: Array = [[Loc.t("community.pay"), pay]]
	if Community.can_sign():
		buttons.push_front([Loc.t("neptune.sign"), sign])
	return InfoPanel.open(hud, Loc.t("story.spot.neptune_counter"), body, buttons, lines)
