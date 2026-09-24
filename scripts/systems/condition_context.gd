class_name ConditionContext
extends RefCounted

# The only fields and functions data conditions may read (33.5). Expressions are parsed once and cached.
const INPUTS: PackedStringArray = ["season", "day", "weekday", "year", "day_index", "hour", "weather", "act",
	"money", "honor"]

static var _cache: Dictionary = {}
static var _ctx: ConditionContext


static func _values() -> Array:
	return [Clock.season, Clock.day, Clock.weekday, Clock.year, Clock.day_index, Clock.hour, Weather.current,
		Game.act, Economy.money, Game.honor]


static func parse(expr: String) -> Expression:
	if _cache.has(expr):
		return _cache[expr]
	var expression := Expression.new()
	if expression.parse(expr, INPUTS) != OK:
		push_error("Bad condition: %s (%s)" % [expr, expression.get_error_text()])
		expression = null
	_cache[expr] = expression
	return expression


# An empty condition holds; a broken one does not.
static func check(expr: String) -> bool:
	if expr.strip_edges() == "":
		return true
	var expression := parse(expr)
	if expression == null:
		return false
	if _ctx == null:
		_ctx = ConditionContext.new()
	var result: Variant = expression.execute(_values(), _ctx, false)
	return not expression.has_execute_failed() and bool(result)


static func valid(expr: String) -> bool:
	return expr.strip_edges() == "" or parse(expr) != null


func tide() -> float:
	return Clock.tide_height()


func moon() -> int:
	return Clock.moon()


func light() -> float:
	return Lighthouse.fire_power


func peace() -> float:
	return Graveyard.peace


func sea() -> float:
	return Sea.mercy


func flag(id: String) -> bool:
	return Game.flag(id)


func hearts(npc: String) -> int:
	return Relationships.hearts_of(npc)


func seen(event: String) -> bool:
	return Cutscenes.seen.has(event)


func has_item(id: String, n: int = 1) -> bool:
	return Inventory.count_of(id) >= n


func skill(id: String) -> int:
	return Skills.level(id)


func stat(name: String) -> int:
	return Game.stat(name)


func quest_state(id: String) -> String:
	return Quests.state(id)


func married_to() -> String:
	return Relationships.married_to


func blessings() -> int:
	return Sea.blessings.size()


func evidence() -> int:
	return Story.evidence_count()


func counter(name: String) -> int:
	return int(Game.counters.get(name, 0))


func page(n: int) -> bool:
	return Story.pages.has(n)


func pages() -> int:
	return Story.pages.size()


func fragment(n: int) -> bool:
	return Story.fragments.has(n)


func tale(n: int) -> bool:
	return Game.flag("tale_%d" % n)


func siege() -> bool:
	return Story.siege_night()


func neptune() -> String:
	return Community.neptune


func twenty_buried() -> int:
	return Twenty.buried_count()


func allies() -> int:
	return Story.allies.size()


func blessing(id: String) -> bool:
	return Sea.blessings.has(id)


func room(id: String) -> bool:
	return Community.room_done(id)


func rooms() -> int:
	return Community.rooms_done()


func ending() -> String:
	return Story.ending


func ghost_laid(id: String) -> bool:
	return Graveyard.laid_ghosts.has(id)


func has_seen(id: String) -> bool:
	return Cutscenes.seen.has(id)


func boat() -> String:
	return Sea.boat


func best_hearts() -> int:
	var best := 0
	for npc in Relationships.points:
		best = maxi(best, Relationships.hearts_of(str(npc)))
	return best


func dating(npc: String) -> bool:
	return Relationships.dating.has(npc)


func twenty_out() -> int:
	return Twenty.carried_out


func twenty_help(npc: String) -> bool:
	return Twenty.can_help(npc)


func has_evidence(id: String) -> bool:
	return Story.evidence.has(id)


func has_ally(npc: String) -> bool:
	return Story.allies.has(npc)


func step(quest_id: String, step_id: String) -> bool:
	return Quests.step_done(quest_id, step_id)


func resolution() -> String:
	return Story.resolution


func calm() -> bool:
	return Weather.calm


func aurora() -> bool:
	return Weather.aurora


func hmar_tonight() -> bool:
	return Weather.hmar_night and Clock.is_night()


func cats() -> int:
	return Cats.count()


func room_slot(room_id: String, slot_id: String) -> bool:
	return Community.slot_done(room_id, slot_id)


# The quality of the grave a story body lies in (-1 if not buried).
func grave_quality(body_id: String) -> int:
	var b := Graveyard.body(body_id)
	if b.is_empty() or not b.has("plot"):
		return -1
	return int(Graveyard.graves[int(b["plot"])]["quality"])


# Placed objects whose id starts with `prefix` within two tiles of the body's grave.
func near_grave(body_id: String, prefix: String) -> int:
	var b := Graveyard.body(body_id)
	if b.is_empty() or not b.has("plot"):
		return 0
	var at := Graveyard.plot_position(int(b["plot"]))
	var n := 0
	for obj in Crafting.placed.get("cape", []):
		if str(obj.get("item", "")).begins_with(prefix) and Vector2(float(obj["x"]), float(obj["y"])).distance_to(at) <= 40.0:
			n += 1
	return n


# 11.8 №8: the twins side by side (neighbouring plots) and a bench between them.
func twins_together() -> bool:
	var a := Graveyard.body("body_aaro")
	var e := Graveyard.body("body_elna")
	if not a.has("plot") or not e.has("plot"):
		return false
	var pa := Graveyard.plot_position(int(a["plot"]))
	var pe := Graveyard.plot_position(int(e["plot"]))
	if pa.distance_to(pe) > 40.0:
		return false
	var mid := (pa + pe) / 2.0
	for obj in Crafting.placed.get("cape", []):
		if str(obj.get("item", "")) in ["bench", "decor_plank_bench"] and Vector2(float(obj["x"]), float(obj["y"])).distance_to(mid) <= 32.0:
			return true
	return false


# 11.8 №14: the sailor with the dog tattoo lies named in the graveyard.
func dog_master_buried() -> bool:
	for b in Graveyard.bodies:
		if Graveyard.is_buried(b) and str(b["identified_as"]) != "" and str(b["identified_as"]) == str(b["registry"]) \
				and Graveyard.registry_entry(str(b["registry"])).get("clues", []).has("tattoo:dog"):
			return true
	return false
