class_name SeaChart

const TILE := 16


static func cfg(key: String) -> Variant:
	return Game.balance("sea", {}).get(key)


static func boat_info(boat: String = "") -> Dictionary:
	return cfg("boats").get(boat if boat != "" else Sea.boat, {})


static func tile_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


static func place_pos(place: String) -> Vector2:
	var at: Array = cfg("places")[place]["at"]
	return Vector2(int(at[0]) * TILE + 8, int(at[1]) * TILE + 8)


static func zone_of(at: Vector2) -> int:
	var row := tile_of(at).y
	if row >= int(cfg("zone3_row")):
		return 3
	return 2 if row >= int(cfg("zone2_row")) else 1


static func is_land(at: Vector2) -> bool:
	var cell := tile_of(at)
	return cell.y < int(cfg("coast_rows"))


static func near_place(at: Vector2, radius_tiles: float = 5.0) -> String:
	var places: Dictionary = cfg("places")
	for place in places:
		if at.distance_to(place_pos(place)) <= radius_tiles * TILE:
			return place
	return ""


# Fishing tags of open water: the zone plus the named spots of 15.4.
static func tags_at(at: Vector2) -> Array:
	if is_land(at):
		return []
	var tags: Array = ["sea_z%d" % zone_of(at)]
	match near_place(at, 8.0):
		"teeth":
			tags.append("sea_teeth")
		"dead_fire":
			tags.append("dead_fire")
		"seal_rock":
			tags.append("seal_rock")
	return tags


# Direction the wind blows *to*: Weather.wind_direction counts eight points clockwise from north.
static func wind_to() -> Vector2:
	return Vector2.UP.rotated(TAU * float(Weather.wind_direction) / 8.0)


# 16.2: 0-40° into the wind stalls, 40-70° ×0.6, 70-110° ×1.0, 110-150° ×1.2, running ×1.0.
static func angle_multiplier(heading: Vector2) -> float:
	var from_wind := -wind_to()
	var angle := rad_to_deg(heading.normalized().angle_to(from_wind))
	angle = absf(angle)
	for row in cfg("wind_angles"):
		if angle < float(row[0]):
			return float(row[1])
	return 1.0


static func strength_multiplier() -> float:
	if Weather.calm:
		return 0.0
	var table: Array = cfg("wind_strength")
	return float(table[clampi(Weather.wind_strength, 0, table.size() - 1)])


static func sail_speed(heading: Vector2) -> float:
	return float(boat_info().get("sail", 0.0)) * angle_multiplier(heading) * strength_multiplier() \
		* (1.0 + 0.02 * float(Skills.level("seafaring"))) * (1.2 if Skills.has_profession("pilot") else 1.0)


static func chunk_key(at: Vector2) -> String:
	var size := int(cfg("chunk"))
	var cell := tile_of(at)
	return "%d,%d" % [floori(float(cell.x) / size), floori(float(cell.y) / size)]


static func reveal(at: Vector2) -> void:
	var radius := int(cfg("reveal_radius"))
	var size := int(cfg("chunk"))
	for dy in range(-radius, radius + 1, size):
		for dx in range(-radius, radius + 1, size):
			Sea.revealed[chunk_key(at + Vector2(dx, dy) * TILE)] = true
