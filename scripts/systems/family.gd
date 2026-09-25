class_name Family

# 22.3: the spouse lives at the cape (the village on weekdays, home in the evenings and at weekends), helps
# around the house on 40% of mornings, and at 12+ hearts lights the fire at 21:00 (70%) when the keeper is
# not at the lighthouse — the night's Power x0.9. With the house at level 2, 14 days married and 12+ hearts
# the spouse raises children; up to two: a baby 14 days, a toddler 14 days, then a child for good.
const HELP := ["water", "animals", "fences", "breakfast", "glass"]
const BABY_DAYS := 14
const TODDLER_DAYS := 14
const KID_LINES := ["А мы тоже станем знаками?", "Папа моря — это Ранн? А мама?", "Почему у этого креста нет имени?",
	"Я покормил кур. Одна на меня посмотрела. Как утопленник.", "Можно я буду смотрителем, когда ты станешь призраком?"]


static func spouse() -> String:
	return Relationships.married_to


static func married_days() -> int:
	if spouse() == "":
		return 0
	return Clock.day_index - int(Game.counters.get("event_wedding", Clock.day_index))


static func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 4099 + Clock.day_index * 37 + salt, 2147483647)
	return rng


# The spouse's day at the cape: the usual daytime in the village on weekdays, the cape at dawn, evening and weekends.
static func spouse_entry(usual: Dictionary) -> Dictionary:
	var path: Array = [["06:00", "cape", "house_door", "down", ""]]
	if Clock.weekday in ["sat", "sun"]:
		path.append(["10:00", "cape", "garden", "down", ""])
		path.append(["14:00", "cape", "graveyard_bench", "down", ""])
		path.append(["18:00", "cape", "house_door", "down", ""])
	else:
		for step in usual.get("path", []):
			var at := NPCs.parse_time(str(step[0]))
			if at >= 9 * 60 and at < 17 * 60 and str(step[1]) not in ["home", "away"]:
				path.append(step)
		path.append(["17:30", "cape", "garden", "down", ""])
	path.append(["22:00", "cape", "house_door", "up", "sleep"])
	return {"priority": 1000, "path": path}


# Night step: one chore with 40%. Returns the chore done ("" for none).
static func morning_help() -> String:
	if spouse() == "":
		return ""
	var rng := _rng(3)
	if rng.randf() >= 0.4:
		return ""
	var chore: String = HELP[rng.randi_range(0, HELP.size() - 1)]
	match chore:
		"water":
			var n := 0
			for key in Farm.tiles:
				var tile: Dictionary = Farm.tiles[key]
				if n < 20 and not bool(tile["watered"]) and not Farm.indoor(Farm.parse_key(key)[0]):
					tile["watered"] = true
					n += 1
		"animals":
			for a in Animals.herd:
				Animals.pet(int(a["id"]))
		"fences":
			Game.counters["fences_mended"] = int(Game.counters.get("fences_mended", 0)) + 5
		"breakfast":
			var dishes := ["barley_porridge", "eggs_onion", "keeper_soup", "fish_pie"]
			Mail.send("mail.spouse_breakfast", [Loc.t(str(Data.by_id("npcs", spouse()).get("name", spouse())))], 0,
				[[dishes[rng.randi_range(0, dishes.size() - 1)], 1]])
		"glass":
			Lighthouse.cleanliness = 10.0
	Game.counters["spouse_help"] = int(Game.counters.get("spouse_help", 0)) + 1
	return chore


# 21:00 and the lamp still dark: at 12+ hearts the spouse climbs the tower (70%).
static func evening_fire() -> bool:
	if spouse() == "" or Relationships.hearts_of(spouse()) < 12 or Lighthouse.lamp_on or not Lighthouse.fire_needed():
		return false
	if _rng(5).randf() >= 0.7 or not Lighthouse.light_lamp():
		return false
	Game.counters["spouse_lit"] = Clock.day_index
	return true


static func spouse_lit_tonight() -> bool:
	return int(Game.counters.get("spouse_lit", -1)) == Clock.day_index


# ---- children ----

static func children() -> Array:
	return Relationships.children


static func can_ask_children() -> bool:
	return spouse() != "" and Buildings.level("house") >= 2 and married_days() >= 14 \
		and Relationships.hearts_of(spouse()) >= 12 and children().size() < 2 and int(Game.counters.get("baby_due", -1)) < 0


# "Yes" to the spouse's talk: a baby in 14 days.
static func agree() -> bool:
	if not can_ask_children():
		return false
	Game.counters["baby_due"] = Clock.day_index + BABY_DAYS
	return true


static func night() -> bool:
	var due := int(Game.counters.get("baby_due", -1))
	if due < 0 or Clock.day_index < due:
		return false
	Game.counters.erase("baby_due")
	var names := ["Агата", "Хедда", "Линнея"] if children().size() % 2 == 0 else ["Ян", "Бьярне", "Ульф"]
	var name: String = names[_rng(9).randi_range(0, names.size() - 1)]
	Relationships.children.append({"name": name, "born": Clock.day_index})
	Game.counters["children"] = children().size()
	Mail.send("mail.baby", [name])
	Events.quest_event.emit("child_born", name)
	return true


static func stage(child: Dictionary) -> String:
	var age := Clock.day_index - int(child["born"])
	if age < BABY_DAYS:
		return "baby"
	if age < BABY_DAYS + TODDLER_DAYS:
		return "toddler"
	return "child"


static func kid_line(index: int) -> String:
	return KID_LINES[posmod(index + Clock.day_index, KID_LINES.size())]
