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
	return int(round(float(item.get("price", 0)) * QUALITY_MULT[clampi(quality, 0, 3)]))


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
	for entry in shop(shop_id).get("stock", []):
		if entry.has("seasons") and Clock.season not in entry["seasons"]:
			continue
		if Clock.day < int(entry.get("from_day", 1)):
			continue
		if str(entry.get("upgrade", "")) == "backpack":
			if int(entry["slots"]) != Inventory.capacity + Inventory.HOTBAR:
				continue
		offer.append(entry)
	return offer


func buy(shop_id: String, entry: Dictionary, count: int = 1) -> String:
	if shop_closed_reason(shop_id) != "":
		return "closed"
	if not shop_stock(shop_id).has(entry) or count <= 0:
		return "unknown"
	var total := int(entry["price"]) * count
	if not can_pay(total):
		return "money"
	if str(entry.get("upgrade", "")) == "backpack":
		pay(total)
		Inventory.upgrade_capacity(int(entry["slots"]))
		return "ok"
	var id := str(entry["item"])
	if not Inventory.can_fit(id, count):
		return "space"
	pay(total)
	Inventory.add(id, count)
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
