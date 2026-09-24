class_name RannStone

# The flat black boulder under the cape (12.3): one offering a day (two with Priliva's blessing),
# laid on the stone at low water or thrown into the wave over it at high water.
const TILE := 16


static func cfg() -> Dictionary:
	return Game.balance("rann", {})


static func position() -> Vector2:
	var at: Array = cfg().get("at", [70, 56])
	return Vector2(int(at[0]) * TILE + 8, int(at[1]) * TILE + 8)


# 11.6: the stone is dry when h <= 0.
static func dry() -> bool:
	return Clock.tide_height() <= 0.0


static func taste(id: String, quality: int = 0) -> String:
	var c := cfg()
	var item := Data.by_id("items", id)
	var category := str(item.get("category", ""))
	if id in c.get("hates", []):
		return "hates"
	var fish := Data.by_id("fish", id)
	if id in c.get("loves", []) or bool(fish.get("legendary", false)):
		return "loves"
	if id in c.get("likes", []) or (category == "fish" and quality >= 2):
		return "likes"
	if id in c.get("neutral", []) or category in ["fish", "shellfish"]:
		return "neutral"
	if id in c.get("dislikes", []) or category == "trash":
		return "dislikes"
	return ""


static func _today() -> int:
	if int(Game.counters.get("rann_day", -1)) != Clock.day_index:
		Game.counters["rann_day"] = Clock.day_index
		Game.counters["rann_offers"] = 0
	return int(Game.counters["rann_offers"])


static func offers_left() -> int:
	return (2 if Sea.blessings.has("priliva") else 1) - _today()


static func whisper(kind: String) -> String:
	var n := int(Game.counters.get("rann_total", 0))
	return Loc.t("rann.%s_%d" % [kind, n % 2 + 1])


# Offers one item from the backpack slot; returns what the surf answers.
static func offer(index: int) -> Dictionary:
	if index < 0 or index >= Inventory.slots.size() or str(Inventory.slots[index]["id"]) == "":
		return {"ok": false, "text": "Возьмите в руки то, что хотите отдать морю."}
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	var kind := taste(id, int(slot["quality"]))
	if kind == "":
		return {"ok": false, "text": "Прибой не шевелится. Такое морю не нужно."}
	if offers_left() <= 0:
		return {"ok": false, "text": "Сегодня Камень уже принял дар. Вода ровная, как стол."}
	var name := Loc.t(str(Data.by_id("items", id).get("name", id)))
	Inventory.take_slot(index, 1)
	var mercy := float(cfg().get("mercy", {}).get(kind, 0))
	Sea.add_mercy(mercy)
	Game.counters["rann_offers"] = int(Game.counters["rann_offers"]) + 1
	var line := whisper(kind)
	Game.counters["rann_total"] = int(Game.counters.get("rann_total", 0)) + 1
	Events.quest_event.emit("rann_offering", id)
	var act := "Вы кладёте %s на мокрый чёрный камень." if dry() else "Вы бросаете %s в волну над камнем."
	return {"ok": true, "kind": kind, "mercy": mercy, "text": "%s\n«%s»" % [act % name, line]}


# "Calm tomorrow" (12.3): mercy >= 60, once a week; costs 5 mercy unless beloved (>= 80) or blessed by Tish.
static func request_calm() -> Dictionary:
	var c := cfg()
	if Sea.mercy < float(c.get("calm_min_mercy", 60)):
		return {"ok": false, "text": "Море не слушает просьб от тех, кого не знает."}
	var week := Clock.day_index / 7
	if int(Game.counters.get("rann_calm_week", -1)) == week:
		return {"ok": false, "text": "Одна просьба в неделю. Море помнит и эту."}
	var free := Sea.mercy >= float(c.get("calm_free_mercy", 80)) or Sea.blessings.has("tish")
	if not free:
		Sea.add_mercy(-float(c.get("calm_cost", 5)))
	Game.counters["rann_calm_week"] = week
	Weather.requested_calm = Clock.day_index + 1
	Weather.forecast_refresh()
	return {"ok": true, "free": free, "text": "«Завтра мы будем спать», — шепчет прибой."}


# Letting a fish go (12.1): +0.1 for an ordinary one up to +1 a day, +10 for a legend.
static func release(id: String, quality: int = 0) -> bool:
	var index := -1
	for i in Inventory.slots.size():
		if str(Inventory.slots[i]["id"]) == id and (index < 0 or int(Inventory.slots[i]["quality"]) == quality):
			index = i
	if not Inventory.take_slot(index, 1):
		return false
	var c := cfg()
	if bool(Data.by_id("fish", id).get("legendary", false)):
		Sea.add_mercy(float(c.get("release_legend", 10)))
		Game.set_flag("caught_" + id)
	else:
		var given := float(Game.counters.get("released_today", 0.0))
		var gain := minf(float(c.get("release_mercy", 0.1)), float(c.get("release_cap", 1.0)) - given)
		if gain > 0.0:
			Sea.add_mercy(gain)
			Game.counters["released_today"] = given + gain
	Game.counters["fish_released"] = int(Game.counters.get("fish_released", 0)) + 1
	Events.quest_event.emit("fish_released", id)
	return true
