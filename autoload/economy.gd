extends Node

const START_MONEY := 500
const QUALITY_MULT := [1.0, 1.25, 1.5, 2.0]
const UNSELLABLE := ["tool", "weapon", "quest"]
const PICKUP_MINUTE := 18 * 60

var money: int = START_MONEY
# Each entry: {id, count, quality, due} where `due` is the day the «Чайка» takes it.
var shipping: Array = []


func add(n: int) -> void:
	money = maxi(0, money + n)
	Events.money_changed.emit(money)


func can_pay(n: int) -> bool:
	return money >= n


func pay(n: int) -> bool:
	if not can_pay(n):
		return false
	add(-n)
	return true


func reset() -> void:
	money = START_MONEY
	shipping.clear()


func sell_price(id: String, quality: int = 0) -> int:
	var item := Data.by_id("items", id)
	if item.is_empty() or str(item.get("category", "")) in UNSELLABLE:
		return 0
	var mult := 1.0
	# 23.2: the mended fish market pays a tenth more for fish (not Neptune's pier).
	if str(item.get("category", "")) in ["fish", "shellfish"] and Game.flag("fish_market") and not Community.paid.has("fishers"):
		mult = 1.1
	# 5.6: after the trial Grim's house is the Solvik Artel and buys 15% dearer.
	if Game.flag("artel"):
		mult *= 1.15
	return int(round(float(item.get("price", 0)) * QUALITY_MULT[clampi(quality, 0, 3)] * Skills.price_mult(item) * mult))


func ship_slot(index: int) -> bool:
	if index < 0 or index >= Inventory.slots.size():
		return false
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	var count := int(slot["count"])
	var quality := int(slot["quality"])
	if id == "" or sell_price(id, quality) <= 0 or not Inventory.take_slot(index, count):
		return false
	var due := Clock.day_index if Clock.minutes < PICKUP_MINUTE else Clock.day_index + 1
	shipping.append({"id": id, "count": count, "quality": quality, "due": due})
	return true


# The last stack can be taken back until the «Чайка» has carried it off.
func take_back_last() -> bool:
	if shipping.is_empty():
		return false
	var entry: Dictionary = shipping[-1]
	if int(entry["due"]) == Clock.day_index and Clock.minutes >= PICKUP_MINUTE:
		return false
	if Inventory.add(str(entry["id"]), int(entry["count"]), int(entry["quality"])) != int(entry["count"]):
		return false
	shipping.pop_back()
	return true


func shipping_value() -> int:
	var total := 0
	for entry in shipping:
		total += sell_price(str(entry["id"]), int(entry["quality"])) * int(entry["count"])
	return total


# Night step 10: pay for everything the «Чайка» collected at 18:00; storms keep the box waiting.
func collect_shipping(night_index: int, storm: bool) -> Dictionary:
	var income := 0
	var sold := 0
	var waiting: Array = []
	for entry in shipping:
		if storm or int(entry["due"]) > night_index:
			if storm and int(entry["due"]) <= night_index:
				entry["due"] = night_index + 1
			waiting.append(entry)
			continue
		income += sell_price(str(entry["id"]), int(entry["quality"])) * int(entry["count"])
		sold += int(entry["count"])
	shipping = waiting
	if income > 0:
		add(income)
		Game.add_stat("money_from_shipping", income)
	return {"income": income, "sold": sold, "storm": storm, "waiting": waiting.size()}


func shop(shop_id: String) -> Dictionary:
	return Data.by_id("shops", shop_id)


# "" when open, otherwise "day" (weekly day off), "hours" or "unknown".
func shop_closed_reason(shop_id: String) -> String:
	var info := shop(shop_id)
	if info.is_empty():
		return "unknown"
	if Clock.weekday in info.get("closed", []):
		return "day"
	if Clock.hour < int(info.get("open", 0)) or Clock.hour >= int(info.get("close", 24)):
		return "hours"
	return ""


func shop_stock(shop_id: String) -> Array:
	var offer: Array = []
	var stock: Array = shop(shop_id).get("stock", [])
	if shop(shop_id).has("rotating"):
		stock = rotating_stock(shop_id)
	for entry in stock:
		if entry.has("when") and not ConditionContext.check(str(entry["when"])):
			continue
		if bool(entry.get("once", false)) and Game.flag("bought_" + str(entry.get("item", ""))):
			continue
		if entry.has("days") and Clock.weekday not in entry["days"]:
			continue
		if entry.has("hours") and (Clock.hour < int(entry["hours"][0]) or Clock.hour >= int(entry["hours"][1])):
			continue
		if entry.has("seasons") and Clock.season not in entry["seasons"]:
			continue
		if Clock.day < int(entry.get("from_day", 1)):
			continue
		if entry.has("requires") and Skills.level(str(entry["requires"][0])) < int(entry["requires"][1]):
			continue
		if str(entry.get("upgrade", "")) == "backpack":
			if int(entry["slots"]) != Inventory.capacity + Inventory.HOTBAR:
				continue
		if str(entry.get("upgrade", "")) == "boathouse" and Sea.boat != "yalik":
			continue
		if entry.has("recipe") and Crafting.learned.has(str(entry["recipe"])):
			continue
		offer.append(entry)
	offer.append_array(_dynamic_stock(shop_id))
	return offer


# Ilm takes building orders (21.5) and Margit sells animals (14.2); both lists follow the game state.
func _dynamic_stock(shop_id: String) -> Array:
	var out: Array = []
	match shop_id:
		"shop_ilm":
			for b in Data.all("buildings"):
				var id := str(b["id"])
				var reason := Buildings.blocked_reason(id)
				if reason in ["done", "blueprint", "unknown", "boat"]:
					continue
				out.append({"building": id, "price": int(Buildings.next_level_info(id).get("price", 0))})
		"shop_smith":
			for tool_id in Buildings.TOOL_KEYS:
				var cost := Buildings.tool_upgrade_price(str(tool_id))
				if not cost.is_empty():
					out.append({"tool_upgrade": str(tool_id), "price": int(cost[1])})
		"shop_margit":
			for a in Data.all("animals"):
				if Clock.day_index >= int(a.get("after_day", 0)):
					out.append({"animal": str(a["id"]), "price": int(a["price"])})
	return out


# Sandro's shebeka brings ten of its wares each week (21.3), chosen from the week and the world seed.
func rotating_stock(shop_id: String) -> Array:
	var pool: Array = shop(shop_id).get("stock", []).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 613 + (Clock.day_index / 7) * 7919 + shop_id.hash(), 2147483647)
	var out: Array = []
	while not pool.is_empty() and out.size() < int(shop(shop_id)["rotating"]):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


var last_service: String = ""


func _service(entry: Dictionary) -> String:
	match str(entry["service"]):
		"open_chest":
			var index := -1
			for i in Inventory.slots.size():
				if str(Inventory.slots[i]["id"]) == "overgrown_chest":
					index = i
			if index < 0:
				return "nothing"
			var rng := RandomNumberGenerator.new()
			rng.seed = posmod(Game.world_seed * 17 + Clock.day_index * 131 + Clock.minutes + int(Game.counters.get("chests_opened", 0)) * 977, 2147483647)
			Inventory.take_slot(index, 1)
			Game.counters["chests_opened"] = int(Game.counters.get("chests_opened", 0)) + 1
			var names: Array[String] = []
			for loot in Lighthouse.roll_loot("overgrown_chest", rng):
				Inventory.add(str(loot[0]), int(loot[1]))
				names.append("%s ×%d" % [Loc.t(str(Data.by_id("items", str(loot[0])).get("name", loot[0]))), int(loot[1])])
			last_service = "Тора вскрыла сундучок: " + ", ".join(names) + "."
		"rumor":
			last_service = Dialogue.rumor()
		"boat_blessing":
			if Sea.boat == "":
				return "nothing"
			Game.counters["boat_blessed_until"] = Clock.day_index + 7
			last_service = "Бенедикт благословил лодку кистью на трёхметровом шесте. Корпус крепче на неделю."
	return "ok"


func buy(shop_id: String, entry: Dictionary, count: int = 1) -> String:
	if shop_closed_reason(shop_id) != "":
		return "closed"
	if not shop_stock(shop_id).has(entry) or count <= 0:
		return "unknown"
	var total := int(entry["price"]) * count
	if not can_pay(total):
		return "money"
	if entry.has("building"):
		return Buildings.place_order(str(entry["building"]))
	if entry.has("tool_upgrade"):
		return Buildings.order_tool(str(entry["tool_upgrade"]))
	if entry.has("animal"):
		return Animals.buy(str(entry["animal"]))
	if entry.has("recipe"):
		if not pay(total):
			return "money"
		Crafting.learn(str(entry["recipe"]))
		return "ok"
	if entry.has("service"):
		last_service = ""
		var done := _service(entry)
		if done == "ok":
			pay(int(entry["price"]))
		return done
	if str(entry.get("upgrade", "")) == "backpack":
		pay(total)
		Inventory.upgrade_capacity(int(entry["slots"]))
		return "ok"
	if str(entry.get("upgrade", "")) == "boathouse":
		for need in entry.get("items", []):
			if Inventory.count_of(str(need[0])) < int(need[1]):
				return "materials"
		for need in entry.get("items", []):
			Inventory.take(str(need[0]), int(need[1]))
		pay(total)
		Sea.set_boat("sloop")
		return "ok"
	var id := str(entry["item"])
	if not Inventory.can_fit(id, count):
		return "space"
	pay(total)
	Inventory.add(id, count)
	if bool(entry.get("once", false)):
		Game.set_flag("bought_" + id)
	return "ok"


# Direct sale at a shop's own profile pays the base price at once (21.2).
func sell_to_shop(shop_id: String, index: int) -> int:
	if shop_closed_reason(shop_id) != "" or index < 0 or index >= Inventory.slots.size():
		return 0
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	var category := str(Data.by_id("items", id).get("category", ""))
	if id == "" or category not in shop(shop_id).get("buys", []):
		return 0
	var income := sell_price(id, int(slot["quality"])) * int(slot["count"])
	if income <= 0 or not Inventory.take_slot(index, int(slot["count"])):
		return 0
	add(income)
	return income


func serialize() -> Dictionary:
	return {"money": money, "shipping": shipping}


func deserialize(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	shipping.clear()
	var loaded: Variant = d.get("shipping", [])
	if loaded is Array:
		for entry in loaded:
			if entry is Dictionary and Data.exists("items", str(entry.get("id", ""))):
				shipping.append({"id": str(entry["id"]), "count": int(entry.get("count", 0)),
					"quality": int(entry.get("quality", 0)), "due": int(entry.get("due", 0))})
