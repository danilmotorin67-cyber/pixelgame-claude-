class_name Cold

# 8.3: Cold (0-100) per ten game minutes: winter outdoors +1, rain without the storm jacket +1, a blizzard (or a
# storm at sea) +3, underwater without the suit +2. The sweater and other clothes cut the gain (warmth), Stuzha's
# blessing halves it, a warm balm too; Whale Lungs keep the sea's cold out. A hearth or a stove close by (or a
# warm room) takes 5 off, warm food and drink 20 at once. At 50 every action costs a quarter more; at 100 comes
# the Shivers: -1 energy a minute and the tools go 20% slower.
const FIRES := ["hearth", "forge", "kitchen_stove"]
const FIRE_REACH := 48.0
const SHIVERS := 100.0


static func cfg(key: String, default: Variant) -> Variant:
	return Game.balance("cold", {}).get(key, default)


static func indoors(map_id: String) -> bool:
	return map_id.begins_with("lh_") or MapInfo.is_interior(map_id) or map_id == "cape_workshop"


static func underwater(map_id: String) -> bool:
	return map_id == "deep"


static func near_fire(map_id: String, at: Vector2) -> bool:
	for obj in Crafting.placed.get(map_id, []):
		if str(obj["id"]) in FIRES and at.distance_to(Vector2(float(obj["x"]), float(obj["y"]))) <= FIRE_REACH:
			return true
	return false


# What the keeper wears against it: 0 (nothing) to 0.9.
static func warmth() -> float:
	return clampf(Game.effect("warmth"), 0.0, 0.9)


# The raw gain per ten minutes where the keeper stands, before clothes and blessings.
static func raw_gain(map_id: String, weather: String, season: String) -> float:
	if underwater(map_id):
		return 0.0 if Skills.has_profession("whale_lungs") or Deep.gear() == "suit" else 2.0
	if indoors(map_id):
		return 0.0
	var gain := 0.0
	if season == "winter":
		gain += 1.0
	if weather in ["rain", "storm"] and Game.effect("rainproof") <= 0.0:
		gain += 1.0
	if weather == "blizzard" or (weather == "storm" and map_id == "sea"):
		gain += 3.0
	return gain


static func gain(map_id: String, weather: String, season: String) -> float:
	var g := raw_gain(map_id, weather, season)
	if g <= 0.0:
		return 0.0
	return g * (1.0 - warmth()) * Daughters.cold_mult() * (1.0 - clampf(Game.effect("cold"), 0.0, 0.9))


# The new Cold after `minutes` where the keeper is.
static func step(cold: float, minutes: int, map_id: String, at: Vector2, weather: String, season: String) -> float:
	var tens := float(minutes) / 10.0
	if indoors(map_id) or near_fire(map_id, at):
		return maxf(0.0, cold - 5.0 * tens)
	var g := gain(map_id, weather, season)
	if g <= 0.0:
		return maxf(0.0, cold - float(cfg("thaw", 1.0)) * tens)
	return minf(SHIVERS, cold + g * tens)


static func is_warm_food(id: String) -> bool:
	return id in cfg("warm_food", [])


static func shivering(cold: float) -> bool:
	return cold >= SHIVERS
