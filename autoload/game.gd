extends Node

var flags: Dictionary = {}
var counters: Dictionary = {}
var stats: Dictionary = {}
var act: int = 0
var honor: int = 0
var luck: float = 0.0
var hero: Dictionary = {
	"name": "Смотритель",
	"gender": "m",
	"love": "",
	"skin": 1,
	"hair": 0,
	"hair_color": 0,
	"eyes": 0,
	"shirt": 0,
	"pants": 0,
	"shoes": 0,
}
var world_seed: int = 1
var playtime_sec: float = 0.0
var player_state: Dictionary = {}
# Food and potion effects (section 20, 19.6): [{effects, until}] where `until` is an absolute game minute.
var buffs: Array = []
# Clothes (three slots) and two charms (19.4-19.5): slot -> item id.
const EQUIP_SLOTS := ["head", "body", "feet", "amulet_1", "amulet_2"]
var equipment: Dictionary = {}


func _process(delta: float) -> void:
	if not Clock.paused:
		playtime_sec += delta


func flag(id: String) -> bool:
	return bool(flags.get(id, false))


func set_flag(id: String, v: bool = true) -> void:
	flags[id] = v


func stat(name: String) -> int:
	return int(stats.get(name, 0))


func add_stat(name: String, n: int = 1) -> void:
	stats[name] = stat(name) + n


func add_honor(n: int) -> void:
	honor = clampi(honor + n, -100, 100)


func balance(key: String, fallback: Variant) -> Variant:
	var table: Variant = Data.tables.get("balance", {})
	return table.get(key, fallback) if table is Dictionary else fallback


func max_energy() -> float:
	return (float(balance("energy_max", 270)) + float(balance("energy_star_amber", 30)) \
		* float(clampi(int(counters.get("star_amber", 0)), 0, 7))) * (1.0 + effect("energy_share"))


# Energy for one action of spec 8.1, reduced by the linked skill down to 1.
func action_cost(action: String, cold: float = 0.0) -> float:
	var info: Dictionary = balance("energy_actions", {}).get(action, {})
	var cost := float(info.get("cost", 0))
	if info.has("skill"):
		cost = maxf(1.0, cost - float(info.get("per_level", 0.0)) * float(Skills.level(str(info["skill"]))))
	if cold >= float(balance("cold_energy_threshold", 50)):
		cost *= float(balance("cold_energy_mult", 1.25))
	return cost


static func minute_now() -> int:
	return Clock.day_index * Clock.MINUTES_PER_DAY + Clock.minutes


# A dish or drink with a "buff" block: effects last `hours`, or until the keeper sleeps with `until_night`.
func add_buff(effects: Dictionary) -> void:
	var until := minute_now() + int(round(float(effects.get("hours", 0)) * 60.0))
	if bool(effects.get("until_night", false)):
		until = (Clock.day_index + 1) * Clock.MINUTES_PER_DAY + 2 * 60
	var kept: Dictionary = {}
	for key in effects:
		if key not in ["hours", "until_night"]:
			kept[key] = effects[key]
	buffs.append({"effects": kept, "until": until})


func expire_buffs() -> void:
	var now := minute_now()
	buffs = buffs.filter(func(b: Dictionary) -> bool: return int(b["until"]) > now)


# The sum of one effect over active buffs and equipped clothes and charms.
func effect(key: String) -> float:
	var total := 0.0
	var now := minute_now()
	for b in buffs:
		if int(b["until"]) > now:
			total += float(b["effects"].get(key, 0.0))
	for slot in equipment:
		total += float(Data.by_id("items", str(equipment[slot])).get("effect", {}).get(key, 0.0))
	return total


func luck_total() -> float:
	return luck + effect("luck")


# Q on clothes or a charm puts it on (or takes it off into the backpack).
func equip(item_id: String) -> String:
	var item := Data.by_id("items", item_id)
	var slot := str(item.get("slot", ""))
	if str(item.get("category", "")) == "amulet":
		for s in ["amulet_1", "amulet_2"]:
			if str(equipment.get(s, "")) == item_id:
				return unequip(s)
		slot = "amulet_1" if not equipment.has("amulet_1") else ("amulet_2" if not equipment.has("amulet_2") else "amulet_1")
	if slot == "" or Inventory.count_of(item_id) <= 0:
		return ""
	if equipment.has(slot) and str(equipment[slot]) == item_id:
		return unequip(slot)
	if equipment.has(slot) and unequip(slot) == "":
		return ""
	Inventory.take(item_id, 1)
	equipment[slot] = item_id
	return "on"


func unequip(slot: String) -> String:
	if not equipment.has(slot) or not Inventory.can_fit(str(equipment[slot]), 1):
		return ""
	Inventory.add(str(equipment[slot]), 1)
	equipment.erase(slot)
	return "off"


func roll_luck(index: int, aurora_bonus: bool) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(world_seed * 40503 + index * 7919 + 313, 2147483647)
	luck = rng.randf_range(-0.1, 0.1) + (0.05 if aurora_bonus else 0.0)
	return luck


func reset() -> void:
	flags.clear()
	counters.clear()
	stats.clear()
	act = 0
	honor = 0
	luck = 0.0
	hero = {"name": "Смотритель", "gender": "m", "love": "",
		"skin": 1, "hair": 0, "hair_color": 0, "eyes": 0,
		"shirt": 0, "pants": 0, "shoes": 0}
	world_seed = randi()
	playtime_sec = 0.0
	player_state = {}
	buffs.clear()
	equipment.clear()


func serialize() -> Dictionary:
	return {
		"flags": flags, "counters": counters, "stats": stats,
		"act": act, "honor": honor, "luck": luck, "hero": hero,
		"world_seed": world_seed, "playtime_sec": playtime_sec,
		"player_state": player_state, "buffs": buffs, "equipment": equipment,
	}


func deserialize(d: Dictionary) -> void:
	flags = d.get("flags", {})
	counters = d.get("counters", {})
	stats = d.get("stats", {})
	for key in counters:
		counters[key] = int(counters[key])
	for key in stats:
		stats[key] = int(stats[key])
	act = int(d.get("act", 0))
	honor = int(d.get("honor", 0))
	luck = clampf(float(d.get("luck", 0.0)), -0.1, 0.15)
	hero = d.get("hero", hero)
	for key in ["skin", "hair", "hair_color", "eyes", "shirt", "pants", "shoes"]:
		if hero.has(key):
			hero[key] = int(hero[key])
	world_seed = int(d.get("world_seed", 1))
	playtime_sec = float(d.get("playtime_sec", 0.0))
	player_state = d.get("player_state", {}).duplicate(true)
	buffs.clear()
	for b in d.get("buffs", []):
		if b is Dictionary and b.has("effects"):
			buffs.append({"effects": b["effects"], "until": int(b.get("until", 0))})
	equipment.clear()
	var worn: Dictionary = d.get("equipment", {})
	for slot in worn:
		if slot in EQUIP_SLOTS and Data.exists("items", str(worn[slot])):
			equipment[slot] = str(worn[slot])
