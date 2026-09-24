extends Node

# The Twenty nameless of the brig Fortuna (5.9, Q2.10-Q2.11): nineteen skeletons behind the rubble of the
# eighth grotto hall and Eleonora in the niche. They leave the grottoes only at low tide — one on the
# shoulders, two on a sledge; Knud (4+ hearts) and Einar (6+) each carry five out once. In the morgue they are
# matched against the crew list and buried; every right name is worth two candles more.
const HALL := 7
const SKELETONS := 19
const ELEONORA := "t20_20"

var in_hall: int = SKELETONS
var carrying: int = 0
var carrying_eleonora: bool = false
var carried_out: int = 0
var helpers: Array = []
var buried: Array = []


func _ready() -> void:
	Events.body_buried.connect(_on_buried)


func reset() -> void:
	in_hall = SKELETONS
	carrying = 0
	carrying_eleonora = false
	carried_out = 0
	helpers.clear()
	buried.clear()


# The skeletons come out in the crew list's order shuffled by the world: skeleton n is somebody.
func _next_id() -> String:
	var ids: Array = []
	for i in SKELETONS:
		ids.append("t20_%02d" % (i + 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 911 + 20, 2147483647)
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return str(ids[carried_out]) if carried_out < ids.size() else ""


func capacity() -> int:
	return 2 if Inventory.count_of("drag_sledge") > 0 else 1


func buried_count() -> int:
	return buried.size()


# Hall 8, a bundle of canvas: the first look finds the hall; then the keeper takes what he can carry.
func take_from_hall() -> String:
	if not Game.flag("twenty_found"):
		Game.set_flag("twenty_found")
		Events.quest_event.emit("twenty_found", "")
		return Loc.t("twenty.hall.found")
	if in_hall <= 0:
		return Loc.t("twenty.hall.empty")
	if carrying + (1 if carrying_eleonora else 0) >= capacity():
		return Loc.t("twenty.hall.full")
	carrying += 1
	in_hall -= 1
	return Loc.t("twenty.hall.take") % [carrying, carrying, capacity()]


func niche_open() -> bool:
	return buried.size() >= SKELETONS and not Game.flag("eleonora_out")


func take_eleonora() -> String:
	if not niche_open():
		return Loc.t("twenty.niche.locked") if not Game.flag("eleonora_out") else Loc.t("twenty.hall.empty")
	if carrying_eleonora or carrying >= capacity():
		return Loc.t("twenty.hall.full")
	carrying_eleonora = true
	return Loc.t("twenty.niche.open")


# Out of the grottoes on the dry way: what the keeper carried lies down in the morgue.
func on_left_grotto() -> String:
	var n := carrying
	for i in n:
		_spawn(_next_id())
		carried_out += 1
	carrying = 0
	if carrying_eleonora:
		_spawn(ELEONORA)
		carrying_eleonora = false
		Game.set_flag("eleonora_out")
		n += 1
	if n <= 0:
		return ""
	Events.quest_event.emit("twenty_out", str(carried_out))
	return Loc.t("twenty.out") % [n, carried_out]


# The water came back: what was on the keeper's back stays in the hall.
func on_flood() -> void:
	in_hall += carrying
	carrying = 0
	carrying_eleonora = false


func can_help(npc: String) -> bool:
	var need := {"npc_knud": 4, "npc_einar": 6}
	return need.has(npc) and not helpers.has(npc) and Game.flag("twenty_found") and in_hall > 0 \
		and Relationships.hearts_of(npc) >= int(need[npc])


func help(npc: String) -> String:
	if not can_help(npc):
		return ""
	helpers.append(npc)
	var n := mini(5, in_hall)
	in_hall -= n
	for i in n:
		_spawn(_next_id())
		carried_out += 1
	Events.quest_event.emit("twenty_out", str(carried_out))
	return Loc.t("twenty.help.%s" % npc.substr(4))


func _spawn(tid: String) -> Dictionary:
	var info := Data.by_id("the_twenty", tid)
	if info.is_empty():
		return {}
	var reg := Graveyard.registry_entry("reg_" + tid)
	var id := "body_fortuna_%s" % str(info["key"])
	var b := Graveyard._new_body(id, reg, true, Graveyard._rng(97))
	b["visible"] = []
	b["hidden"] = (info["clues"] as Array).duplicate()
	b["where"] = "morgue"
	b["twenty"] = tid
	b["washed"] = true
	b["sewn"] = true
	b["items"] = []
	if tid == ELEONORA:
		b["identified_as"] = "reg_" + tid
		b["revealed"] = (info["clues"] as Array).duplicate()
		b["examined"] = true
	Graveyard.bodies.append(b)
	Events.body_spawned.emit(id)
	return b


# The crew list: every name of the roll not yet given to another skeleton.
func roll_candidates(b: Dictionary) -> Array:
	var out: Array = []
	for info in Data.all("the_twenty"):
		var reg_id := "reg_" + str(info["id"])
		if bool(info.get("last", false)) or Graveyard._assigned_elsewhere(reg_id, str(b["id"])):
			continue
		out.append(Graveyard.registry_entry(reg_id))
	return out


func _on_buried(id: String, _quality: int) -> void:
	var b := Graveyard.body(id)
	if not b.has("twenty") or buried.has(str(b["twenty"])):
		return
	buried.append(str(b["twenty"]))
	if str(b["identified_as"]) == str(b["registry"]):
		Knowledge.add_points("rest", 2)
	Events.quest_event.emit("twenty_buried", str(buried.size()))
	if str(b["twenty"]) == ELEONORA:
		Game.set_flag("eleonora_buried")
		Story.add_page(22)
		Game.set_flag("fortuna_choice")
	if buried.size() >= SKELETONS + 1 and not Game.flag("twenty_buried"):
		Game.set_flag("twenty_buried")
		Mail.send("twenty.done")
		Graveyard.recalc_peace()


func night() -> Array:
	return ["niche_open"] if niche_open() and not Game.flag("niche_told") else []


func serialize() -> Dictionary:
	return {"in_hall": in_hall, "carrying": carrying, "carrying_eleonora": carrying_eleonora, "carried_out": carried_out,
		"helpers": helpers, "buried": buried}


func deserialize(d: Dictionary) -> void:
	reset()
	in_hall = int(d.get("in_hall", SKELETONS))
	carrying = int(d.get("carrying", 0))
	carrying_eleonora = bool(d.get("carrying_eleonora", false))
	carried_out = int(d.get("carried_out", 0))
	helpers = d.get("helpers", []).duplicate()
	buried = d.get("buried", []).duplicate()
