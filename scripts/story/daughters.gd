class_name Daughters

# Rann's daughters and their blessings (12.4): each is a lasting effect and a lit stone in the Nine Maidens.
# Five of the eight bring Rann's Gills (Q3.11); the ninth, the Hmar's, is given only by the New Pact ending.
const ALL := ["zyb", "pena", "burun", "stuzha", "tish", "svetla", "priliva", "otliva"]


static func has(id: String) -> bool:
	return Sea.blessings.has(id)


static func grant(id: String) -> bool:
	if has(id) or not (id in ALL or id == "hmar"):
		return false
	Sea.blessings.append(id)
	Game.set_flag("blessing_" + id)
	Collections.mark("blessings", id)
	Knowledge.add_points("sea", 5)
	if id == "svetla":
		Inventory.add("svetla_spark", 1)
		Game.counters["svetla_year"] = Clock.year
	Events.blessing_gained.emit(id)
	return true


static func count() -> int:
	var n := 0
	for id in ALL:
		if has(id):
			n += 1
	return n


# ---- the effects spread across the systems ----

static func boat_speed_mult() -> float:
	return 1.1 if has("zyb") else 1.0


static func storm_hull_safe() -> bool:
	return has("burun")


static func cold_mult() -> float:
	var mult := 0.5 if has("stuzha") else 1.0
	if Game.effect("cold_resist") > 0.0:
		mult *= 1.0 - clampf(Game.effect("cold_resist"), 0.0, 0.9)
	return mult


static func gift_mult() -> float:
	return 1.25 if has("pena") else 1.0


# Svetla's sparks: one more every summer new moon after the first dance (two are needed: the Great Eye and the Torch).
static func svetla_night() -> bool:
	return Clock.season == "summer" and Clock.day >= 26 and (Clock.hour >= 21 or Clock.hour < 4)


static func svetla_spark() -> bool:
	if not has("svetla") or int(Game.counters.get("svetla_year", 0)) >= Clock.year or not svetla_night():
		return false
	Game.counters["svetla_year"] = Clock.year
	Inventory.add("svetla_spark", 1)
	return true


# Priliva waits at the Stone at the peak of a spring tide (day 1 or 15) for a flawless fish.
static func priliva_offering(item_id: String, quality: int) -> bool:
	if has("priliva") or not (Clock.day in [1, 15]) or quality < 3:
		return false
	if str(Data.by_id("items", item_id).get("category", "")) != "fish":
		return false
	if Clock.tide_height() < Clock.tide_amplitude() * 0.85:
		return false
	return grant("priliva")
