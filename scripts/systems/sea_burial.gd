class_name SeaBurial

static var warned: String = ""


# 11.9: at the Resting Place, a body sewn in canvas and a weight (3 stone or an iron ingot) go to the sea.
static func perform() -> String:
	if Graveyard.carried == "":
		return "Место Упокоения. Сюда привозят тех, кого забирает море."
	var b := Graveyard.body(Graveyard.carried)
	if not bool(b.get("sewn", false)):
		return "Сначала зашейте тело в парусину."
	var weight := "iron_ingot" if Inventory.count_of("iron_ingot") > 0 else "stone"
	var need := 1 if weight == "iron_ingot" else 3
	if Inventory.count_of(weight) < need:
		return "Нужен груз: 3 камня или железный слиток."
	var horn := str(b.get("ghost", "")) == "ghost_horn" and Quests.state("g10_wrong_burial") == "active"
	if horn and Inventory.count_of("signal_flare") <= 0:
		return "Капитан Хорн хочет салюта: нужна сигнальная ракета."
	if not horn and (bool(b.get("story", false)) or str(b.get("ghost", "")) != "") and warned != str(b["id"]):
		warned = str(b["id"])
		return "Этот человек хотел бы лежать в земле. Нажмите ещё раз, если всё же отдать морю."
	Inventory.take(weight, need)
	b["where"] = "sea"
	Graveyard.carried = ""
	warned = ""
	var identified := str(b.get("identified_as", "")) != ""
	var mercy := 4.0 + (2.0 if identified else 0.0)
	if Sea.blessings.has("tish"):
		mercy *= 1.5
	Sea.add_mercy(mercy)
	Game.counters["sea_burials"] = int(Game.counters.get("sea_burials", 0)) + 1
	Skills.add_xp("keeping", 25)
	Graveyard.recalc_peace()
	Events.quest_event.emit("sea_burial", str(b["id"]))
	if horn:
		Inventory.take("signal_flare", 1)
		Events.quest_event.emit("horn_salute", str(b["id"]))
		return "Ракета уходит в небо — салют капитану Хорну. Море приняло его. Милость +%d." % int(round(mercy))
	return "Море приняло его. Милость +%d." % int(round(mercy))
