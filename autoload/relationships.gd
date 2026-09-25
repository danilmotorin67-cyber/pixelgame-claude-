extends Node

# Friendship of 22.1: 250 points a heart, talk +20 once a day, gifts by taste (birthday ×8),
# two gifts a week (plus the birthday one), decay without talk from two hearts, romance caps.
const HEART := 250
const TALK := 20
const GIFT_POINTS := {"love": 80, "like": 45, "neutral": 20, "dislike": -20, "hate": -40}
const WEEK_GIFTS := 2

var points: Dictionary = {}
var talked_today: Dictionary = {}
var gifted_today: Dictionary = {}
var gifts_week: Dictionary = {}
var birthday_gift: Dictionary = {}
var dating: Array = []
var married_to: String = ""
var engaged_to: String = ""
var wedding_day: int = -1
# 22.2: after a divorce the ex is cold for 28 days (no friendship gained).
var ex_spouse: String = ""
var ex_cold_until: int = -1
# 22.3: the keeper's children: [{name, born}].
var children: Array = []
var hearts: Dictionary: # read-only view kept for old callers
	get:
		var out := {}
		for id in points:
			out[id] = hearts_of(id)
		return out


func reset() -> void:
	points.clear()
	talked_today.clear()
	gifted_today.clear()
	gifts_week.clear()
	birthday_gift.clear()
	dating.clear()
	married_to = ""
	engaged_to = ""
	wedding_day = -1
	ex_spouse = ""
	ex_cold_until = -1
	children.clear()


func hearts_of(npc: String) -> int:
	return int(points.get(npc, 0)) / HEART


func cap(npc: String) -> int:
	var info := Data.by_id("npcs", npc)
	if info.has("max_hearts"):
		return int(info["max_hearts"])
	if not bool(info.get("romance", false)):
		return 10
	if married_to == npc:
		return 14
	return 10 if dating.has(npc) else 8


func add_friendship(npc: String, pts: int) -> void:
	var freeze := int(Data.by_id("npcs", npc).get("freeze_after_act", 0))
	if freeze > 0 and Dialogue.story_act() > freeze:
		return
	if pts > 0 and is_cold(npc):
		return
	var before := hearts_of(npc)
	points[npc] = clampi(int(points.get(npc, 0)) + pts, 0, cap(npc) * HEART)
	if hearts_of(npc) != before:
		Events.quest_event.emit("hearts", npc)


func set_hearts(npc: String, n: int) -> void:
	points[npc] = clampi(n, 0, 14) * HEART
	if n > 8 and bool(Data.by_id("npcs", npc).get("romance", false)) and not dating.has(npc) and married_to != npc:
		dating.append(npc)
	points[npc] = mini(int(points[npc]), cap(npc) * HEART)


# Talking once a day: +20 (22.1).
func talk(npc: String) -> bool:
	if talked_today.has(npc):
		return false
	talked_today[npc] = true
	add_friendship(npc, TALK)
	Events.npc_talked.emit(npc)
	return true


func is_birthday(npc: String) -> bool:
	var b: Dictionary = Data.by_id("npcs", npc).get("birthday", {})
	return not b.is_empty() and str(b["season"]) == Clock.season and int(b["day"]) == Clock.day


static func _tag_has(tag: String, id: String, item: Dictionary, depth: int = 0) -> bool:
	if str(item.get("category", "")) == tag or tag in item.get("tags", []):
		return true
	if depth > 3:
		return false
	for member in Data.tables.get("gifts", {}).get("groups", {}).get(tag, []):
		var m := str(member)
		if m == id or (m.begins_with("cat:") and str(item.get("category", "")) == m.substr(4)):
			return true
		if m.begins_with("tag:") and _tag_has(m.substr(4), id, item, depth + 1):
			return true
	return false


# "id", "id@q", "tag:x", "tag:x@q" (33.4: @1 good, @2 excellent, @3 flawless).
static func matches(pattern: String, id: String, quality: int) -> bool:
	var parts := pattern.split("@")
	if parts.size() > 1 and quality < int(parts[1]):
		return false
	var p := parts[0]
	if p.begins_with("tag:"):
		return _tag_has(p.substr(4), id, Data.by_id("items", id))
	return p == id


func taste(npc: String, id: String, quality: int = 0) -> String:
	var own: Dictionary = Data.by_id("npcs", npc).get("gifts", {})
	for kind in ["hate", "love", "like", "dislike"]:
		for pattern in own.get(kind, []):
			if matches(str(pattern), id, quality):
				return kind
	var universal: Dictionary = Data.tables.get("gifts", {}).get("universal", {})
	for kind in ["love", "hate", "like", "dislike"]:
		for pattern in universal.get(kind, []):
			if matches(str(pattern), id, quality):
				return kind
	return "neutral"


func giftable(id: String) -> bool:
	var item := Data.by_id("items", id)
	return not item.is_empty() and str(item.get("category", "")) not in Data.tables.get("gifts", {}).get("not_giftable", [])


func gift_block(npc: String, id: String) -> String:
	if not giftable(id):
		return "not_giftable"
	if gifted_today.has(npc):
		return "today"
	if is_birthday(npc):
		return "" if int(birthday_gift.get(npc, 0)) != Clock.year else "today"
	if int(gifts_week.get(npc, 0)) >= WEEK_GIFTS:
		return "week"
	return ""


# Gives one item from a backpack slot; returns {"ok", "reaction", "points"} or {"ok": false, "reason"}.
func give(npc: String, index: int) -> Dictionary:
	if index < 0 or index >= Inventory.slots.size():
		return {"ok": false, "reason": "empty"}
	var slot: Dictionary = Inventory.slots[index]
	var id := str(slot["id"])
	if id == "":
		return {"ok": false, "reason": "empty"}
	var romance := bool(Data.by_id("npcs", npc).get("romance", false))
	if romance and id in ["bouquet_armeria", "amber_ring"]:
		return _courtship(npc, index, id)
	var block := gift_block(npc, id)
	if block != "":
		return {"ok": false, "reason": block}
	var quality := int(slot["quality"])
	var reaction := taste(npc, id, quality)
	var gained := int(GIFT_POINTS[reaction])
	var birthday := is_birthday(npc)
	if birthday:
		gained *= 8
		birthday_gift[npc] = Clock.year
	else:
		gifts_week[npc] = int(gifts_week.get(npc, 0)) + 1
	gifted_today[npc] = true
	Inventory.take_slot(index, 1)
	add_friendship(npc, gained)
	Game.add_stat("gifts_given")
	Events.gift_given.emit(npc, id, reaction)
	Events.quest_event.emit("gift", npc)
	return {"ok": true, "reaction": reaction, "points": gained, "item": id, "birthday": birthday}


# 22.3: the armeria bouquet at 8 hearts means courting; the amber ring at 10 hearts (courting, a house of
# level 1) means a wedding in the chapel three days later.
func _courtship(npc: String, index: int, id: String) -> Dictionary:
	if id == "bouquet_armeria":
		if dating.has(npc) or married_to == npc:
			return {"ok": false, "reason": "already", "line": "bouquet_again"}
		if hearts_of(npc) < 8:
			return {"ok": false, "reason": "too_soon", "line": "bouquet_no"}
		Inventory.take_slot(index, 1)
		dating.append(npc)
		Events.quest_event.emit("dating", npc)
		return {"ok": true, "reaction": "love", "points": 0, "item": id, "birthday": false, "line": "bouquet_yes"}
	if married_to != "" or engaged_to != "":
		return {"ok": false, "reason": "taken", "line": "ring_taken"}
	if not dating.has(npc) or hearts_of(npc) < 10:
		return {"ok": false, "reason": "too_soon", "line": "ring_no"}
	if Buildings.level("house") < 1:
		return {"ok": false, "reason": "house", "line": "ring_house"}
	Inventory.take_slot(index, 1)
	engaged_to = npc
	wedding_day = Clock.day_index + 3
	Events.quest_event.emit("engaged", npc)
	return {"ok": true, "reaction": "love", "points": 0, "item": id, "birthday": false, "line": "ring_yes"}


func wedding_today() -> bool:
	if engaged_to == "" or Clock.day_index < wedding_day:
		return false
	married_to = engaged_to
	dating.erase(married_to)
	engaged_to = ""
	wedding_day = -1
	Game.counters["event_wedding"] = Clock.day_index
	Events.quest_event.emit("married", married_to)
	return true


# Night step 11 (after the date changed): decay without talk (from two hearts; the spouse -20 but not below 10 hearts), new day, new week.
func night() -> void:
	for npc in points.keys():
		if talked_today.has(npc):
			continue
		if npc == married_to:
			points[npc] = maxi(int(points[npc]) - 20, mini(int(points[npc]), 10 * HEART))
		elif hearts_of(npc) >= 2:
			points[npc] = int(points[npc]) - 2
	talked_today.clear()
	gifted_today.clear()
	wedding_today()
	if Clock.weekday == "mon":
		gifts_week.clear()


# Night mail (step 9): residents write when friendship reaches a letter's hearts ("letters" in npcs.json).
func night_letters() -> int:
	var sent := 0
	for npc in Data.all("npcs"):
		var id := str(npc["id"])
		for need in npc.get("letters", {}):
			var flag := "letter_%s_%s" % [id, need]
			if hearts_of(id) < int(need) or Game.flag(flag):
				continue
			var letter: Dictionary = npc["letters"][need]
			Game.set_flag(flag)
			Mail.send(str(letter["text"]), [], int(letter.get("money", 0)), letter.get("items", []))
			if letter.has("recipe"):
				Crafting.learn(str(letter["recipe"]))
			Effects.apply(letter.get("effects", []))
			sent += 1
	return sent


func is_cold(npc: String) -> bool:
	return npc != "" and npc == ex_spouse and Clock.day_index < ex_cold_until


# At the Pilot Directorate, 50 crowns ("We do not judge here. We only stamp."). The ex drops to 2 hearts.
func divorce() -> bool:
	if married_to == "" or not Economy.pay(50):
		return false
	ex_spouse = married_to
	married_to = ""
	ex_cold_until = Clock.day_index + 28
	points[ex_spouse] = mini(int(points.get(ex_spouse, 0)), 2 * HEART)
	Game.set_flag("divorced")
	Events.quest_event.emit("divorced", ex_spouse)
	return true


# The Well of Oblivion (30 000): the island forgets the divorce; the ex is back at 6 hearts.
func forget_divorce() -> bool:
	if ex_spouse == "" or not Economy.pay(30000):
		return false
	points[ex_spouse] = maxi(int(points.get(ex_spouse, 0)), 6 * HEART)
	ex_cold_until = -1
	ex_spouse = ""
	Game.set_flag("divorced", false)
	return true


func serialize() -> Dictionary:
	return {"points": points, "talked_today": talked_today, "gifted_today": gifted_today, "gifts_week": gifts_week,
		"birthday_gift": birthday_gift, "dating": dating, "married_to": married_to, "engaged_to": engaged_to,
		"wedding_day": wedding_day, "ex_spouse": ex_spouse, "ex_cold_until": ex_cold_until, "children": children}


func deserialize(d: Dictionary) -> void:
	reset()
	for npc in d.get("points", {}):
		points[npc] = int(d["points"][npc])
	for npc in d.get("hearts", {}): # saves before M6 kept hearts only
		points[npc] = int(d["hearts"][npc]) * HEART
	talked_today = d.get("talked_today", {}).duplicate()
	gifted_today = d.get("gifted_today", {}).duplicate()
	for npc in d.get("gifts_week", {}):
		gifts_week[npc] = int(d["gifts_week"][npc])
	for npc in d.get("birthday_gift", {}):
		birthday_gift[npc] = int(d["birthday_gift"][npc])
	dating = d.get("dating", []).duplicate()
	married_to = str(d.get("married_to", ""))
	engaged_to = str(d.get("engaged_to", ""))
	wedding_day = int(d.get("wedding_day", -1))
	ex_spouse = str(d.get("ex_spouse", ""))
	ex_cold_until = int(d.get("ex_cold_until", -1))
	for c in d.get("children", []):
		children.append({"name": str(c["name"]), "born": int(c["born"])})
