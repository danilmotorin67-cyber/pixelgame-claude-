extends Node

# The Guild House and the Mistfolk (23): six rooms of offerings; a finished room is mended and rewards the island,
# takes 5% off the Hmar Nights and all six halve them. The Neptune path (23.3) pays rooms off instead — the sea
# resents it, the Mistfolk leave the paid rooms, and the New Pact is closed while the contract stands.
# neptune: "" (not offered yet), "offer" (thinking, until Winter 28 y1), "signed", "torn", "expired", "annulled".
var neptune: String = ""
# room id -> {slot id -> [item ids given]}; rooms done by offering or paid to Neptune.
var given: Dictionary = {}
var done: Dictionary = {}
var paid: Dictionary = {}


func cfg(key: String) -> Variant:
	return Data.tables.get("neptune", {}).get(key)


func reset() -> void:
	neptune = ""
	given.clear()
	done.clear()
	paid.clear()


func room(id: String) -> Dictionary:
	return Data.by_id("bundles", id)


func room_done(id: String) -> bool:
	return done.has(id) or paid.has(id)


func rooms_done() -> int:
	return done.size() + paid.size()


# Rooms whose Mistfolk stayed: each takes 5% off the Hmar Nights (7.4).
func mist_rooms() -> int:
	return done.size()


func hmar_mult() -> float:
	if done.size() >= 6 or Game.flag("guild_house_restored"):
		return 0.5
	return 1.0 - 0.05 * float(done.size())


func slot(room_id: String, slot_id: String) -> Dictionary:
	for s in room(room_id).get("slots", []):
		if str(s["id"]) == slot_id:
			return s
	return {}


func slot_given(room_id: String, slot_id: String) -> Array:
	return given.get(room_id, {}).get(slot_id, [])


func slot_done(room_id: String, slot_id: String) -> bool:
	return slot_given(room_id, slot_id).size() >= int(slot(room_id, slot_id).get("need", 1))


# The first slot of the room the item fits and still needs: [slot id, item pattern] or [].
func _fit(room_id: String, index: int) -> Array:
	for s in room(room_id).get("slots", []):
		if slot_done(room_id, str(s["id"])):
			continue
		for entry in s["items"]:
			var need := str(entry[0])
			if need == "money" or slot_given(room_id, str(s["id"])).has(need):
				continue
			if Inventory.slot_matches(index, need) and Inventory.count_matching(need) >= int(entry[1]):
				return [str(s["id"]), need, int(entry[1])]
	return []


# Offers the item in the hotbar slot `index` to a room; returns the Mistfolk's answer.
func offer(room_id: String, index: int) -> String:
	if room_done(room_id) or room(room_id).is_empty():
		return ""
	var fit := _fit(room_id, index)
	if fit.is_empty():
		return Loc.t("community.nothing")
	var id := str(Inventory.slots[index]["id"])
	var need := str(fit[1])
	var ghost_gift := need == "tag:ghost_gift"
	if ghost_gift:
		# 23.1: the Mistfolk only remember the ghosts' gifts and give them back.
		if Inventory.count_matching(need) < int(fit[2]):
			return Loc.t("community.nothing")
	elif not Inventory.take_matching(need, int(fit[2])):
		return Loc.t("community.nothing")
	_record(room_id, str(fit[0]), need)
	Events.quest_event.emit("community_offering", room_id)
	var text := Loc.t("community.offered") % Crafting.item_name(id)
	if ghost_gift:
		text += " " + Loc.t("community.returned")
	if need == "solvik_bell":
		Events.quest_event.emit("solvik_bell_offered", "")
	return text + _check_room(room_id)


func offer_money(room_id: String, slot_id: String) -> String:
	var s := slot(room_id, slot_id)
	if s.is_empty() or slot_done(room_id, slot_id) or room_done(room_id):
		return ""
	var amount := int(s["items"][0][1])
	if not Economy.pay(amount):
		return Loc.t("story.deliver.missing") + " %d кр" % amount
	_record(room_id, slot_id, "money")
	Events.quest_event.emit("community_offering", room_id)
	return Loc.t("community.offered") % ("%d кр" % amount) + _check_room(room_id)


func _record(room_id: String, slot_id: String, what: String) -> void:
	if not given.has(room_id):
		given[room_id] = {}
	if not given[room_id].has(slot_id):
		given[room_id][slot_id] = []
	given[room_id][slot_id].append(what)


func _check_room(room_id: String) -> String:
	for s in room(room_id)["slots"]:
		if not slot_done(room_id, str(s["id"])):
			return ""
	done[room_id] = Clock.day_index
	Effects.apply(room(room_id).get("reward", []))
	Events.quest_event.emit("room_done", room_id)
	var text := "\n" + Loc.t("community.room_done") % [Loc.t(str(room(room_id)["name"])), Loc.t(str(room(room_id)["done"]))]
	if done.size() >= 6:
		Game.set_flag("guild_house_restored")
		Inventory.add("star_amber", 1)
		Achievements.unlock("ach_homecoming")
		text += "\n" + Loc.t("community.all_done")
	return text


# ---- the Neptune path (23.3) ----

func neptune_choice(choice: String) -> void:
	match choice:
		"sign":
			sign_contract()
		"think":
			if neptune == "":
				neptune = "offer"
		"tear":
			neptune = "torn"


func can_sign() -> bool:
	return neptune in ["", "offer"] and Clock.day_index <= int(cfg("offer_until"))


func sign_contract() -> bool:
	if not can_sign():
		return false
	neptune = "signed"
	Economy.add(int(cfg("sign_money")))
	Sea.add_mercy(float(cfg("sign_mercy")))
	Game.set_flag("neptune_signed")
	return true


func contract_active() -> bool:
	return neptune == "signed"


# Paying Neptune for a room: built with a sign, but the Mistfolk leave it; the Memorial is refused.
func pay_room(room_id: String) -> String:
	var price := int(room(room_id).get("neptune_price", 0))
	if not contract_active() or room_done(room_id):
		return ""
	if price <= 0:
		return Loc.t("community.refused")
	if not Economy.pay(price):
		return Loc.t("story.deliver.missing") + " %d кр" % price
	paid[room_id] = Clock.day_index
	Effects.apply(room(room_id).get("reward", []))
	if room_id == "chest":
		Game.set_flag("souvenir_shop", false)
		Game.set_flag("ferry_saturdays", false)
	Game.set_flag("neptune_" + room_id)
	return Loc.t("community.paid") % Loc.t(str(room(room_id)["neptune"]))


# The cannery in Wreck Bay: fish and seafood at 90% of the price (95% with Neptune's pier), no limits.
func cannery_rate() -> float:
	return float(cfg("cannery_pier")) if paid.has("fishers") else float(cfg("cannery"))


func sell_to_cannery(index: int) -> String:
	if not contract_active():
		return ""
	var id := str(Inventory.slots[index]["id"])
	var category := str(Data.by_id("items", id).get("category", ""))
	if category not in ["fish", "shellfish"]:
		return Loc.t("neptune.not_fish")
	var count := int(Inventory.slots[index]["count"])
	var pay := int(round(float(Economy.sell_price(id, int(Inventory.slots[index]["quality"]))) * cannery_rate())) * count
	Inventory.take_slot(index, count)
	Economy.add(pay)
	return Loc.t("neptune.sold") % [Crafting.item_name(id), count, pay]


# Fish in the bay bite 15% less while the cannery works.
func bay_fish_mult() -> float:
	return float(cfg("bay_fish")) if contract_active() else 1.0


# Clause 47.3: the keeper's staged funeral ends the contract; what Neptune built stays.
func annul() -> void:
	if neptune != "signed":
		return
	neptune = "annulled"
	Sea.add_mercy(float(cfg("annul_mercy")))
	Game.set_flag("neptune_annulled")


# Night: the sea sours a little each week of the contract; the offer lapses after Winter 28 of year 1.
func night() -> Array:
	var news: Array = []
	if contract_active() and Clock.weekday == "mon":
		Sea.add_mercy(float(cfg("weekly_mercy")))
	if neptune == "offer" and Clock.day_index > int(cfg("offer_until")):
		neptune = "expired"
		news.append("neptune_expired")
	return news


func serialize() -> Dictionary:
	return {"neptune": neptune, "given": given, "done": done, "paid": paid}


func deserialize(d: Dictionary) -> void:
	reset()
	neptune = str(d.get("neptune", ""))
	given = d.get("given", {}).duplicate(true)
	for key in d.get("done", {}):
		done[str(key)] = int(d["done"][key])
	for key in d.get("paid", {}):
		paid[str(key)] = int(d["paid"][key])
