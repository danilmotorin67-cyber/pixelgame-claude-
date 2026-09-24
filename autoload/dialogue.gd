extends Node

# Line choice of 2.4 / 33.6: keys npc.<name>.<category>.NN, picked by the day's situation and never
# repeated while unseen lines remain. data/dialogue/<npc>.json may add conditional entries.
const FORTUNA_HINTS := 12
const EVENTS := ["wreck", "funeral", "hmar", "inspection", "wedding", "villains"]
const EVENT_DAYS := 2

var shown: Dictionary = {}
var today: Dictionary = {}


func _ready() -> void:
	Events.ship_wrecked.connect(func(_s: String) -> void: note_event("wreck"))
	Events.body_buried.connect(func(_b: String, _q: int) -> void: note_event("funeral"))
	Events.day_started.connect(_on_day)


func reset() -> void:
	shown.clear()
	today.clear()


func _on_day(index: int) -> void:
	today.clear()
	if Weather.last_hmar_day == index - 1:
		note_event("hmar")
	if Clock.day == 28:
		note_event("inspection")


func note_event(kind: String) -> void:
	Game.counters["event_" + kind] = Clock.day_index


# The freshest island event of the last two days, if any.
func recent_event() -> String:
	var best := ""
	var best_day := -1
	for kind in EVENTS:
		var day := int(Game.counters.get("event_" + kind, -100))
		if Clock.day_index - day <= EVENT_DAYS and day > best_day:
			best = kind
			best_day = day
	return best


static func short(npc: String) -> String:
	return npc.trim_prefix("npc_")


func lines(npc: String, category: String) -> PackedStringArray:
	return Loc.with_prefix("npc.%s.%s." % [short(npc), category])


func _rng(npc: String, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 7919 + Clock.day_index * 104729 + npc.hash() + salt * 31, 2147483647)
	return rng


# One unseen key from the pool (then the pool starts over).
func pick_from(npc: String, pool: PackedStringArray, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	var seen: Dictionary = shown.get(npc, {})
	var fresh: Array = []
	for key in pool:
		if not seen.has(key):
			fresh.append(key)
	if fresh.is_empty():
		for key in pool:
			seen.erase(key)
		fresh = Array(pool)
	var key: String = fresh[rng.randi_range(0, fresh.size() - 1)]
	seen[key] = true
	shown[npc] = seen
	return key


func pick(npc: String, category: String, rng: RandomNumberGenerator = null) -> String:
	return pick_from(npc, lines(npc, category), rng if rng else _rng(npc, category.hash()))


func _conditional(npc: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for entry in Data.tables.get("dialogue", {}).get(npc, {}).get("entries", []):
		if ConditionContext.check(str(entry.get("when", ""))):
			for key in entry.get("lines", []):
				out.append(str(key))
	return out


# Categories to try today, most specific first (2.4: season, weather, weekday, hearts, act, events).
func situation(npc: String) -> Array:
	var rng := _rng(npc, 1)
	var out: Array = []
	if Relationships.is_birthday(npc):
		out.append("birthday")
	var festival := Clock.festival_on()
	if not festival.is_empty():
		out.append("festival." + str(festival["id"]))
		out.append("festival")
	var event := recent_event()
	if event != "":
		out.append("event." + event)
	if Relationships.married_to != "" and Relationships.married_to != npc \
			and Clock.day_index - int(Game.counters.get("event_wedding", -100)) <= 7:
		out.append("married_other")
	if Weather.current != "clear" and rng.randf() < 0.6:
		out.append("weather." + Weather.current)
	if rng.randf() < 0.3:
		out.append("h%d" % mini(10, Relationships.hearts_of(npc) / 2 * 2))
	if rng.randf() < 0.35:
		out.append("act%d" % story_act())
	out.append(Clock.weekday)
	out.append(Clock.season)
	return out


# The act for talk (5.0): by date until the story moves it (Spring y1, Summer-Autumn y1, Winter y1 - Summer y2, Autumn y2).
func story_act() -> int:
	var by_date := 1
	if Clock.day_index >= 28:
		by_date = 2
	if Clock.day_index >= 84:
		by_date = 3
	if Clock.day_index >= 168:
		by_date = 4
	return clampi(maxi(Game.act, by_date), 1, 4)


# The line for today's first talk; later talks the same day repeat it or say an "again" line.
func talk_line(npc: String) -> String:
	if today.has(npc):
		var again := pick(npc, "again")
		return again if again != "" else str(today[npc])
	var key := ""
	var special := _conditional(npc)
	if not special.is_empty() and _rng(npc, 2).randf() < 0.4:
		key = pick_from(npc, special, _rng(npc, 3))
	if key == "":
		for category in situation(npc):
			key = pick(npc, category)
			if key != "":
				break
	if key == "":
		key = pick_from(npc, Loc.with_prefix("npc.generic.hello."), _rng(npc, 4))
	today[npc] = key
	return key


func gift_line(npc: String, reaction: String, birthday: bool) -> String:
	var key := ""
	if birthday:
		key = pick(npc, "birthday_gift")
	if key == "":
		key = pick(npc, "gift." + reaction)
	if key == "":
		key = pick_from(npc, Loc.with_prefix("npc.generic.gift.%s." % reaction), _rng(npc, 5))
	return key


# Rumours of the day in the tavern (22.5): what the island says about the keeper's latest deeds.
func rumor() -> String:
	var topics: Array = ["general"]
	if int(Game.counters.get("sea_burials", 0)) > 0:
		topics.append("sea_burial")
	if Game.stat("burials") > 0:
		topics.append("burial")
	if int(Game.counters.get("fish_total", 0)) >= 30:
		topics.append("fisher")
	if int(Game.counters.get("event_wreck", -100)) >= Clock.day_index - 7:
		topics.append("wreck")
	if Lighthouse.fire_power >= 70.0:
		topics.append("light")
	if Game.honor < 0:
		topics.append("dishonor")
	if Relationships.dating.size() > 1:
		topics.append("hearts")
	var rng := _rng("rumor", Game.stat("rumors"))
	Game.add_stat("rumors")
	var topic: String = topics[rng.randi_range(0, topics.size() - 1)]
	var key := pick_from("rumor", Loc.with_prefix("rumor.%s." % topic), rng)
	return Loc.t(key) if key != "" else Loc.t("rumor.general.01")


func greet(npc_id: String) -> String:
	return Loc.t(talk_line(npc_id))


# Fortuna speaks once a day: the first time the P2 line, later the hint of the day (4.2).
func fortuna_talk() -> String:
	var last := int(Game.counters.get("fortuna_last_day", -1))
	if last == Clock.day_index:
		return Loc.t("fortuna.again")
	var talks := int(Game.counters.get("fortuna_talks", 0))
	Game.counters["fortuna_last_day"] = Clock.day_index
	Game.counters["fortuna_talks"] = talks + 1
	Events.npc_talked.emit("npc_fortuna")
	if talks == 0:
		return Loc.t("fortuna.first")
	return hint_of_the_day()


func hint_of_the_day(index: int = -1) -> String:
	if index < 0:
		index = Clock.day_index
	return Loc.t("fortuna.hint.%d" % (1 + posmod(index * 5 + Game.world_seed, FORTUNA_HINTS)))


func fortuna_friendship() -> int:
	return mini(10, int(Game.counters.get("fortuna_talks", 0)) / 10 + int(Game.counters.get("fortuna_story", 0)))


func fortuna_reminder() -> String:
	return Loc.t("fortuna.reminder")


func serialize() -> Dictionary:
	return {"shown": shown}


func deserialize(d: Dictionary) -> void:
	shown = d.get("shown", {}).duplicate(true)
	today.clear()
