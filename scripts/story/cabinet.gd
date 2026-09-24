class_name Cabinet

# The cabinet of curiosities on the lighthouse's ground floor (27.2): thirty artifacts and twenty gifts of the
# sea; Fortuna remarks on every exhibit and the shelf rewards the keeper at 5, 10, 15, 20, 25, 30, 40 and 50.


static func wanted() -> Array:
	return Story.cfg("cabinet", [])


static func count() -> int:
	return Collections.found.get("cabinet", {}).size()


static func has(id: String) -> bool:
	return Collections.has("cabinet", id)


static func donate(index: int) -> String:
	var id := str(Inventory.slots[index]["id"])
	if id == "" or not wanted().has(id):
		return Loc.t("cabinet.not")
	if has(id):
		return Loc.t("cabinet.have")
	Inventory.take_slot(index, 1)
	Collections.mark("cabinet", id)
	Knowledge.add_points("rest", 1)
	var text := Loc.t("cabinet.took") % [Crafting.item_name(id), Loc.t("cabinet.c%d" % (1 + posmod(id.hash(), 4)))]
	var reward: Array = Story.cfg("cabinet_rewards", {}).get(str(count()), [])
	if not reward.is_empty():
		Effects.apply(reward)
		text += "\n" + Loc.t("cabinet.reward") % str(count())
	return text


static func full() -> bool:
	return count() >= wanted().size()
