extends Node

const KINDS := {"sea": "sea_pts", "land": "land_pts", "rest": "rest_pts"}
const ROOTS := {"M1": true, "P1": true, "Z1": true, "S1": true, "R1": true, "T1": true}
const STUDY := {"fish": "sea", "crop": "land", "forage": "land", "egg": "land", "dairy": "land",
	"artifact": "rest", "keepsake": "rest", "mineral": "rest"}

var sea_pts: int = 0
var land_pts: int = 0
var rest_pts: int = 0
var unlocked: Dictionary = ROOTS.duplicate()
var studied: Dictionary = {}


func reset() -> void:
	sea_pts = 0
	land_pts = 0
	rest_pts = 0
	unlocked = ROOTS.duplicate()
	studied.clear()


func points(kind: String) -> int:
	return int(get(KINDS[kind])) if KINDS.has(kind) else 0


func add_points(kind: String, n: int) -> void:
	if KINDS.has(kind):
		set(KINDS[kind], points(kind) + n)


func node(id: String) -> Dictionary:
	return Data.by_id("knowledge_tree", id)


# "" when the node can be opened, otherwise why not: "unlocked", "requires", "story" or "points".
func blocked_reason(id: String) -> String:
	var info := node(id)
	if info.is_empty():
		return "unknown"
	if unlocked.has(id):
		return "unlocked"
	for req in info.get("requires", []):
		if not unlocked.has(str(req)):
			return "requires"
	if info.has("story") and not Game.flag(str(info["story"])):
		return "story"
	if info.has("when") and not ConditionContext.check(str(info["when"])):
		return "story"
	var cost: Dictionary = info.get("cost", {})
	for kind in cost:
		if points(kind) < int(cost[kind]):
			return "points"
	return ""


func unlock_node(id: String) -> bool:
	if blocked_reason(id) != "":
		return false
	var cost: Dictionary = node(id).get("cost", {})
	for kind in cost:
		add_points(kind, -int(cost[kind]))
	unlock(id)
	for tag in node(id).get("unlocks", []):
		if str(tag).begins_with("station:"):
			var item := str(Crafting.station(str(tag).substr(8)).get("item", ""))
			if item != "" and Inventory.add(item, 1) != 1:
				Mail.send("mail.station_delivery", [Loc.t(str(Data.by_id("items", item).get("name", item)))], 0, [[item, 1]])
	return true


func unlock(id: String) -> void:
	unlocked[id] = true
	Events.node_unlocked.emit(id)


func has_unlock(tag: String) -> bool:
	for id in unlocked:
		if tag in node(id).get("unlocks", []):
			return true
	return false


# The keeper's desk: the first copy of each item teaches one note (two for rare finds).
func study(item_id: String) -> int:
	if studied.has(item_id) or Inventory.count_of(item_id) <= 0:
		return 0
	var item := Data.by_id("items", item_id)
	var kind := str(STUDY.get(str(item.get("category", "")), ""))
	if kind == "":
		return 0
	var gain := 2 if bool(item.get("rare", false)) else 1
	studied[item_id] = true
	add_points(kind, gain)
	return gain


func serialize() -> Dictionary:
	return {"sea_pts": sea_pts, "land_pts": land_pts, "rest_pts": rest_pts, "unlocked": unlocked,
		"studied": studied}


func deserialize(d: Dictionary) -> void:
	reset()
	sea_pts = int(d.get("sea_pts", 0))
	land_pts = int(d.get("land_pts", 0))
	rest_pts = int(d.get("rest_pts", 0))
	for id in d.get("unlocked", {}):
		unlocked[str(id)] = true
	for id in d.get("studied", {}):
		studied[str(id)] = true
