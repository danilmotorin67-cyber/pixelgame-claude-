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
