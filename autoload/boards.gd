extends Node

# 21.2: the errand board in the tavern (1-2 a day: bring a thing within 2 days — crowns and +150 friendship),
# the week's demand (one category +25%, announced on Monday at Grim's Trading House) and the week's big order
# there (so many of one thing by Sunday for about 1.5x their worth).
const CATEGORY_NAMES := {"fish": "рыба", "crop": "урожай", "forage": "дары леса и берега", "artisan": "изделия",
	"food": "еда", "shellfish": "моллюски", "egg": "яйца"}

# Errands the keeper took: {npc, item, count, reward, posted, due, state: "taken"|"done"|"late"}.
var errands: Array = []
# Pieces handed in toward this week's order and the week (its Monday) they count for; -1 marks it paid.
var order_week: int = -1
var order_given: int = 0
var order_paid: bool = false


func reset() -> void:
	errands.clear()
	order_week = -1
	order_given = 0
	order_paid = false


func cfg(key: String, default: Variant = null) -> Variant:
	return Game.balance("boards", {}).get(key, default)


func _rng(day: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 7727 + day * 131 + salt, 2147483647)
	return rng


func _season_of(day: int) -> String:
	return Clock.SEASONS[(day % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON]


# The last field of an entry is its season ("" for any).
func _fits(entry: Array, day: int) -> bool:
	var season := str(entry[entry.size() - 1])
	return season == "" or season == _season_of(day)


func item_name(id: String) -> String:
	return Loc.t(str(Data.by_id("items", id).get("name", id)))


func npc_name(id: String) -> String:
	return Loc.t(str(Data.by_id("npcs", id).get("name", id)))


# ---- the errand board ----

func errand_reward(item: String, count: int) -> int:
	var price := int(Data.by_id("items", item).get("price", 0))
	return maxi(int(cfg("reward_min", 80)), int(round(float(price * count) * float(cfg("reward_mult", 2.0)) / 10.0)) * 10)


# Today's notices (1-2), the same for the whole day; ones already taken are marked.
func posted(day: int = Clock.day_index) -> Array:
	var pool: Array = []
	for entry in cfg("errands", []):
		if _fits(entry, day) and _npc_here(str(entry[0])):
			pool.append(entry)
	var bounds: Array = cfg("errands_per_day", [1, 2])
	var rng := _rng(day, 11)
	var n := mini(rng.randi_range(int(bounds[0]), int(bounds[1])), pool.size())
	var out: Array = []
	var used := {}
	var guard := 0
	while out.size() < n and guard < 200:
		guard += 1
		var entry: Array = pool[rng.randi_range(0, pool.size() - 1)]
		if used.has(str(entry[0])):
			continue
		used[str(entry[0])] = true
		out.append({"npc": str(entry[0]), "item": str(entry[1]), "count": int(entry[2]),
			"reward": errand_reward(str(entry[1]), int(entry[2])), "posted": day,
			"due": day + int(cfg("errand_days", 2)) - 1})
	return out


func _npc_here(npc: String) -> bool:
	var info := Data.by_id("npcs", npc)
	return not info.is_empty() and str(info.get("home", {}).get("map", "")) != "away" and not Game.flag("gone_" + npc)


func taken(notice: Dictionary) -> bool:
	for e in errands:
		if int(e["posted"]) == int(notice["posted"]) and str(e["npc"]) == str(notice["npc"]):
			return true
	return false


func take(notice: Dictionary) -> bool:
	if taken(notice) or int(notice["posted"]) != Clock.day_index:
		return false
	var e := notice.duplicate()
	e["state"] = "taken"
	errands.append(e)
	return true


func open_errands() -> Array:
	var out: Array = []
	for e in errands:
		if str(e["state"]) == "taken":
			out.append(e)
	return out


# The asker takes the thing in person: crowns, +150 friendship.
func npc_options(npc: String) -> Array:
	var out: Array = []
	for i in errands.size():
		var e: Dictionary = errands[i]
		if str(e["state"]) == "taken" and str(e["npc"]) == npc:
			out.append(["errand:%d" % i, "Поручение: %s ×%d" % [item_name(str(e["item"])), int(e["count"])]])
	return out


func deliver(index: int) -> String:
	if index < 0 or index >= errands.size():
		return ""
	var e: Dictionary = errands[index]
	if str(e["state"]) != "taken":
		return ""
	if Clock.day_index > int(e["due"]):
		e["state"] = "late"
		return "«Поздно, уже обошлись. Но спасибо, что вспомнили»."
	if Inventory.count_of(str(e["item"])) < int(e["count"]):
		return "«Мне нужно %s ×%d — пока не хватает»." % [item_name(str(e["item"])), int(e["count"])]
	Inventory.take(str(e["item"]), int(e["count"]))
	e["state"] = "done"
	Economy.add(int(e["reward"]))
	Relationships.add_friendship(str(e["npc"]), int(cfg("friendship", 150)))
	Game.add_stat("errands_done")
	Events.quest_event.emit("errand_done", str(e["npc"]))
	return "«Выручили! Вот, как договаривались» (+%d кр)." % int(e["reward"])


# Overdue errands lapse overnight.
func night() -> void:
	for e in errands:
		if str(e["state"]) == "taken" and Clock.day_index > int(e["due"]):
			e["state"] = "late"
	if errands.size() > 40:
		errands = errands.slice(errands.size() - 40)


# ---- the week at the Trading House ----

func week_of(day: int = Clock.day_index) -> int:
	return day - posmod(day, 7)


func demand(day: int = Clock.day_index) -> String:
	var list: Array = cfg("demand", ["fish"])
	return str(list[_rng(week_of(day), 29).randi_range(0, list.size() - 1)])


func demand_mult(item: Dictionary) -> float:
	return float(cfg("demand_mult", 1.25)) if str(item.get("category", "")) == demand() else 1.0


func order(day: int = Clock.day_index) -> Dictionary:
	var week := week_of(day)
	var pool: Array = []
	for entry in cfg("orders", []):
		if _fits(entry, week):
			pool.append(entry)
	if pool.is_empty():
		return {}
	var entry: Array = pool[_rng(week, 47).randi_range(0, pool.size() - 1)]
	var price := int(Data.by_id("items", str(entry[0])).get("price", 0))
	return {"item": str(entry[0]), "count": int(entry[1]), "week": week, "due": week + 6,
		"reward": int(round(float(price * int(entry[1])) * float(cfg("order_mult", 1.5)) / 50.0)) * 50}


func _sync_week() -> void:
	if order_week != week_of():
		order_week = week_of()
		order_given = 0
		order_paid = false


# Hands in what the keeper carries toward the order; pays once the count is met. Returns a line for the board.
func hand_in_order() -> String:
	_sync_week()
	var o := order()
	if o.is_empty():
		return "Заказов на этой неделе нет."
	if order_paid:
		return "Заказ этой недели уже закрыт. Следующий — в понедельник."
	var need := int(o["count"]) - order_given
	var have := mini(Inventory.count_of(str(o["item"])), need)
	if have <= 0:
		return "Нужно ещё %s ×%d." % [item_name(str(o["item"])), need]
	Inventory.take(str(o["item"]), have)
	order_given += have
	if order_given < int(o["count"]):
		return "Принято %d. Осталось %d." % [have, int(o["count"]) - order_given]
	order_paid = true
	Economy.add(int(o["reward"]))
	Game.add_stat("orders_done")
	Events.quest_event.emit("order_done", str(o["item"]))
	return "Заказ выполнен: +%d кр." % int(o["reward"])


func order_text() -> String:
	_sync_week()
	var o := order()
	var lines: Array = ["Спрос недели: %s (+25%%)." % str(CATEGORY_NAMES.get(demand(), demand()))]
	if o.is_empty():
		return lines[0]
	lines.append("Большой заказ: %s ×%d к воскресенью — %d кр." % [item_name(str(o["item"])), int(o["count"]), int(o["reward"])])
	lines.append("Сдано: %d из %d.%s" % [order_given, int(o["count"]), " Оплачен." if order_paid else ""])
	return "\n".join(lines)


func errands_text() -> String:
	var lines: Array = []
	for notice in posted():
		lines.append("%s %s просит %s ×%d до конца %s — %d кр." % ["✓" if taken(notice) else "•", npc_name(str(notice["npc"])),
			item_name(str(notice["item"])), int(notice["count"]), "завтрашнего дня" if int(notice["due"]) > Clock.day_index else "дня",
			int(notice["reward"])])
	for e in open_errands():
		if int(e["posted"]) != Clock.day_index:
			lines.append("◎ %s ждёт %s ×%d (до конца %s)." % [npc_name(str(e["npc"])), item_name(str(e["item"])), int(e["count"]),
				"сегодня" if int(e["due"]) == Clock.day_index else "дня %d" % (int(e["due"]) % Clock.DAYS_PER_SEASON + 1)])
	return "\n".join(lines) if not lines.is_empty() else "Сегодня поручений нет."


func serialize() -> Dictionary:
	return {"errands": errands, "order_week": order_week, "order_given": order_given, "order_paid": order_paid}


func deserialize(d: Dictionary) -> void:
	reset()
	for e in d.get("errands", []):
		errands.append({"npc": str(e["npc"]), "item": str(e["item"]), "count": int(e["count"]), "reward": int(e["reward"]),
			"posted": int(e["posted"]), "due": int(e["due"]), "state": str(e.get("state", "taken"))})
	order_week = int(d.get("order_week", -1))
	order_given = int(d.get("order_given", 0))
	order_paid = bool(d.get("order_paid", false))
