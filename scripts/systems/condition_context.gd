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
	var n := 0
	for key in Game.flags:
		if str(key).begins_with("evidence_") and Game.flag(str(key)):
			n += 1
	return n


func dating(npc: String) -> bool:
	return Relationships.dating.has(npc)
