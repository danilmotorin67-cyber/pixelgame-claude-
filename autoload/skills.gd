extends Node

const NAMES: PackedStringArray = ["farming", "fishing", "seafaring", "diving", "crafting", "foraging", "keeping"]
const THRESHOLDS: Array[int] = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]

var xp: Dictionary = {}
var levels: Dictionary = {}
var professions: Dictionary = {}
# Levels 5 and 10 waiting for the keeper to pick a profession (25.1): [{skill, level}].
var pending: Array = []


func _ready() -> void:
	reset()


func reset() -> void:
	xp.clear()
	levels.clear()
	professions.clear()
	pending.clear()
	for n in NAMES:
		xp[n] = 0
		levels[n] = 0


# The learned level (unlocks and discoveries); `level` adds food buffs on top (section 20).
func base_level(skill: String) -> int:
	return int(levels.get(skill, 0))


func level(skill: String) -> int:
	return base_level(skill) + int(Game.effect("skill_" + skill) + Game.effect("skill_all"))


func has_profession(id: String) -> bool:
	for skill in professions:
		if id in professions[skill]:
			return true
	return false


func add_xp(skill: String, amount: int) -> void:
	if not NAMES.has(skill) or amount <= 0:
		return
	var bonus := Game.effect("xp_" + skill)
	xp[skill] = int(xp.get(skill, 0)) + int(round(float(amount) * (1.0 + bonus)))


func level_for_xp(value: int) -> int:
	var lv := 0
	for need in THRESHOLDS:
		if value >= need:
			lv += 1
	return lv


# New levels are only counted while the keeper sleeps (25.1).
func apply_levels() -> Array:
	var gained: Array = []
	for n in NAMES:
		var lv := level_for_xp(int(xp.get(n, 0)))
		while base_level(n) < lv:
			levels[n] = base_level(n) + 1
			gained.append({"skill": n, "level": base_level(n)})
			if base_level(n) in [5, 10]:
				pending.append({"skill": n, "level": base_level(n)})
			Events.level_up.emit(n, base_level(n))
	return gained


# The two professions offered at level 5, or the two branches of the level-5 choice at level 10.
func options(skill: String, at_level: int) -> Array:
	var tree: Dictionary = Data.by_id("skills", skill).get("professions", {})
	if at_level == 5:
		return tree.get("5", []).duplicate()
	var first := ""
	for id in professions.get(skill, []):
		if str(id) in tree.get("5", []):
			first = str(id)
	return tree.get("10", {}).get(first, []).duplicate()


# The Well of Oblivion (10 000): one skill's professions are forgotten and chosen anew at the next sleep.
func forget_professions(skill: String) -> bool:
	if not professions.has(skill) or (professions[skill] as Array).is_empty() or not Economy.pay(10000):
		return false
	professions.erase(skill)
	for i in range(pending.size() - 1, -1, -1):
		if str(pending[i]["skill"]) == skill:
			pending.remove_at(i)
	for at in [5, 10]:
		if base_level(skill) >= at:
			pending.append({"skill": skill, "level": at})
	return true


func choose(skill: String, id: String) -> bool:
	for i in pending.size():
		var entry: Dictionary = pending[i]
		if str(entry["skill"]) == skill and id in options(skill, int(entry["level"])):
			var list: Array = professions.get(skill, [])
			list.append(id)
			professions[skill] = list
			pending.remove_at(i)
			return true
	return false


const ANIMAL_PRODUCTS := ["egg", "egg_large", "duck_egg", "duck_feather", "eider_down", "wool", "milk", "goat_milk"]
const COOP_PRODUCTS := ["egg", "egg_large", "duck_egg", "duck_feather", "eider_down"]
const GLASS_GOODS := ["glass", "sea_glass", "sea_glass_ring", "stained_glass", "decor_stained_window"]


# Sale price multiplier from professions and worn charms (25.2, 19.5).
func price_mult(item: Dictionary) -> float:
	var id := str(item.get("id", ""))
	var category := str(item.get("category", ""))
	var tags: Array = item.get("tags", [])
	var bonus := 0.0
	if category == "crop" and has_profession("gardener"):
		bonus += 0.10
	if category == "crop" and has_profession("salt_farmer"):
		for crop in Data.all("crops"):
			if str(crop.get("produce", "")) == id and int(crop.get("salt", 0)) == 2:
				bonus += 0.25
	if ("berry" in tags or id == "apple") and has_profession("northern_gardener"):
		bonus += 0.25
	if id in ANIMAL_PRODUCTS and has_profession("herder"):
		bonus += 0.20
	if id in COOP_PRODUCTS and has_profession("down_keeper"):
		bonus += 0.40
	if category == "fish":
		bonus += 0.50 if has_profession("pier_legend") else (0.25 if has_profession("angler") else 0.0)
		bonus += Game.effect("fish_price")
	if category == "shellfish" and has_profession("shellman"):
		bonus += 1.0
	if category == "cargo" and has_profession("smuggler"):
		bonus += 0.50
	if (category == "artisan" or bool(item.get("artisan", false))) and has_profession("cooper"):
		bonus += 0.40
	if id in GLASS_GOODS and has_profession("glassblower"):
		bonus += 0.50
	if category == "forage":
		bonus += Game.effect("forage_price")
	return 1.0 + bonus


func serialize() -> Dictionary:
	return {"xp": xp, "levels": levels, "professions": professions, "pending": pending}


func deserialize(d: Dictionary) -> void:
	reset()
	var saved_xp: Dictionary = d.get("xp", {})
	var saved_levels: Dictionary = d.get("levels", {})
	for n in NAMES:
		xp[n] = int(saved_xp.get(n, 0))
		levels[n] = clampi(int(saved_levels.get(n, 0)), 0, 10)
	professions = d.get("professions", {}).duplicate(true)
	pending.clear()
	for entry in d.get("pending", []):
		pending.append({"skill": str(entry["skill"]), "level": int(entry["level"])})
