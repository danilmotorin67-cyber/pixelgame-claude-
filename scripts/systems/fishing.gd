class_name Fishing

const TILE := 16
const TRASH := ["old_boot", "soggy_paper", "broken_lantern", "snag", "neptune_can", "net_scrap"]
const TRASH_CHANCE := 0.08
const LEGEND_CHANCE := 0.03
const BASE_TAGS := {"cape": ["coast", "rocky"], "village": ["pier", "coast"], "seal_shore": ["coast", "sand"],
	"wreck_bay": ["coast"], "lagoon": ["lagoon"]}


static func _region(map_id: String) -> Dictionary:
	return Data.tables.get("regions", {}).get(map_id, {})


static func _landmark(map_id: String, kind: String) -> Array:
	for item in _region(map_id).get("landmarks", []):
		if str(item.get("kind", "")) == kind:
			var at: Array = item["at"]
			var size: Array = item["size"]
			return [int(at[0]), int(at[1]), int(size[0]), int(size[1])]
	return []


static func _in_rect(cell: Vector2i, rect: Array) -> bool:
	return not rect.is_empty() and cell.x >= rect[0] and cell.x < rect[0] + rect[2] \
		and cell.y >= rect[1] and cell.y < rect[1] + rect[3]


static func lagoon_frozen() -> bool:
	return Clock.season == "winter" and Clock.day >= 5 and Clock.day <= 25


# Salt water is wherever the tide covers the shore (row elevation as in the tide cells) or deeper.
static func _sea_water(map_id: String, cell: Vector2i) -> bool:
	var row0 := 54 if map_id == "cape" else int(_region(map_id).get("coast_row", -1))
	if row0 < 0 or cell.y < row0:
		return false
	var row := cell.y - row0
	return row >= 6 or Clock.tide_height() >= Sea.row_elevation(cell.x, row)


static func is_water(map_id: String, at: Vector2) -> bool:
	var cell := Vector2i(floori(at.x / TILE), floori(at.y / TILE))
	if map_id == "moor":
		return _in_rect(cell, _landmark("moor", "lake"))
	if map_id == "birch":
		return _in_rect(cell, _landmark("birch", "stream"))
	if map_id == "sea":
		return not SeaChart.is_land(at)
	return _sea_water(map_id, cell)


# The kinds of water a float lands in (15.4 "where").
static func spot_tags(map_id: String, at: Vector2) -> Array:
	if not is_water(map_id, at):
		return []
	var cell := Vector2i(floori(at.x / TILE), floori(at.y / TILE))
	match map_id:
		"sea":
			return SeaChart.tags_at(at)
		"moor":
			return ["lake"]
		"birch":
			var stream := _landmark("birch", "stream")
			return ["stream", "estuary"] if cell.y >= int(stream[1]) + int(stream[3]) * 2 / 3 else ["stream"]
		"lagoon":
			return ["ice", "lagoon"] if lagoon_frozen() else ["lagoon"]
		"seal_shore":
			var tags: Array = BASE_TAGS["seal_shore"].duplicate()
			var rock := _landmark("seal_shore", "stones")
			if not rock.is_empty() and Vector2(cell).distance_to(Vector2(rock[0] + rock[2] / 2.0, rock[1] + rock[3] / 2.0)) < 8.0:
				tags.append_array(["rocky", "seal_rock"])
			return tags
	return BASE_TAGS.get(map_id, []).duplicate()


static func _hour_ok(windows: Array, hour: int) -> bool:
	for window in windows:
		var a := int(window[0])
		var b := int(window[1])
		if (hour >= a and hour < b) or (hour + 24 >= a and hour + 24 < b):
			return true
	return false


static func context(tags: Array, lantern: bool = false) -> Dictionary:
	return {"tags": tags, "season": Clock.season, "day": Clock.day, "hour": Clock.hour, "weather": Weather.current,
		"tide": Clock.tide_height(), "rising": Clock.tide_rising(), "lantern": lantern and Clock.is_night(),
		"hmar": Weather.hmar_night}


# Whether a fish bites under the given conditions (15.4, tide rules of 7.5).
static func bites(fish: Dictionary, ctx: Dictionary) -> bool:
	var here := false
	for tag in fish.get("where", []):
		here = here or ctx["tags"].has(tag)
	if not here or str(ctx["season"]) not in fish.get("seasons", []):
		return false
	if fish.has("days") and (int(ctx["day"]) < int(fish["days"][0]) or int(ctx["day"]) > int(fish["days"][1])):
		return false
	if not _hour_ok(fish.get("hours", [[0, 24]]), int(ctx["hour"])):
		return false
	var weather := str(fish.get("weather", "any"))
	if weather != "any" and weather != str(ctx["weather"]):
		return false
	match str(fish.get("tide", "any")):
		"high":
			if not (float(ctx["tide"]) >= 0.3 or bool(ctx["rising"])):
				return false
		"low":
			if float(ctx["tide"]) > -0.3:
				return false
	if bool(fish.get("lantern", false)) and not bool(ctx["lantern"]):
		return false
	if bool(fish.get("hmar", false)) and not bool(ctx["hmar"]):
		return false
	if bool(fish.get("legendary", false)) and Game.flag("caught_" + str(fish["id"])):
		return false
	return true


static func available(ctx: Dictionary) -> Array:
	var out: Array = []
	for fish in Data.all("fish"):
		if bites(fish, ctx):
			out.append(fish)
	return out


# Chooses the catch: sometimes rubbish, rarely a legend, otherwise easier fish more often.
static func pick(ctx: Dictionary, rng: RandomNumberGenerator, legend_lure: bool = false) -> Dictionary:
	var pool := available(ctx)
	if pool.is_empty() or rng.randf() < TRASH_CHANCE:
		return {"id": TRASH[rng.randi_range(0, TRASH.size() - 1)], "trash": true}
	var legends: Array = []
	var common: Array = []
	for fish in pool:
		(legends if bool(fish.get("legendary", false)) else common).append(fish)
	if not legends.is_empty() and (common.is_empty() or rng.randf() < LEGEND_CHANCE * (2.0 if legend_lure else 1.0)):
		return legends[rng.randi_range(0, legends.size() - 1)]
	var total := 0.0
	for fish in common:
		total += 100.0 / (float(fish["difficulty"]) + 10.0)
	var roll := rng.randf() * total
	for fish in common:
		roll -= 100.0 / (float(fish["difficulty"]) + 10.0)
		if roll <= 0.0:
			return fish
	return common[-1]


static func difficulty(fish: Dictionary) -> float:
	var value := float(fish.get("difficulty", 30))
	if bool(fish.get("legendary", false)) and Sea.mercy >= 80.0:
		value -= 10.0
	return value


static func rod(id: String) -> Dictionary:
	return Data.by_id("items", id).get("rod", {})


# The best bait in the backpack, if the rod takes bait: live capelin, then fish bait, then worms.
static func bait_for(rod_id: String) -> String:
	if int(rod(rod_id).get("bait", 0)) <= 0:
		return ""
	for id in ["fish_capelin", "bait", "worms"]:
		if Inventory.count_of(id) > 0:
			return id
	return ""


static func tackles_for(rod_id: String) -> Array:
	var out: Array = []
	var slots := int(rod(rod_id).get("tackle", 0))
	for index in Inventory.capacity:
		var id := str(Inventory.slots[index]["id"])
		if out.size() < slots and str(Data.by_id("items", id).get("category", "")) == "tackle" and not out.has(id):
			out.append(id)
	return out


static func tackle_bonus(tackles: Array, key: String, fallback: float) -> float:
	for id in tackles:
		var info: Dictionary = Data.by_id("items", str(id)).get("tackle", {})
		if info.has(key):
			return float(info[key])
	return fallback


static func wait_seconds(rod_id: String, bait: String, rng: RandomNumberGenerator) -> float:
	var seconds := rng.randf_range(3.0, 15.0) * float(rod(rod_id).get("wait", 1.0))
	if bait != "":
		seconds *= float(Data.by_id("items", bait).get("bait", 1.0))
	if Sea.mercy >= 40.0:
		seconds *= 0.95
	if Game.flag("listen_water"): # Hedda's lesson at 14 hearts (4.3)
		seconds *= 0.9
	return seconds


static func sim_options(rod_id: String, tackles: Array, fish: Dictionary, rng_seed: int) -> Dictionary:
	return {"seed": rng_seed, "level": Skills.level("fishing"), "difficulty": difficulty(fish),
		"green": float(rod(rod_id).get("green", 0)) + tackle_bonus(tackles, "green", 0.0),
		"reel": float(rod(rod_id).get("reel", 1.0)), "sinking": tackle_bonus(tackles, "sinking", 1.0),
		"chest": tackle_bonus(tackles, "chest", 1.0), "assist": Settings.fishing_assist}


# Puts the catch in the backpack and pays out XP, notes and the collection (15.2, 15.6, 26.1).
static func land(fish: Dictionary, perfect: bool, tackles: Array, bait: String, extra: int = 0) -> Dictionary:
	var id := str(fish["id"])
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 31 + Clock.day_index * 977 + Clock.minutes * 13 + int(Game.counters.get("fish_total", 0)), 2147483647)
	if bait != "":
		Inventory.take(bait, 1)
	if bool(fish.get("trash", false)):
		Inventory.add(id, 1)
		return {"id": id, "trash": true}
	var size_range: Array = fish.get("size_cm", [20, 40])
	var size := rng.randf_range(float(size_range[0]), float(size_range[1]))
	var fraction := (size - float(size_range[0])) / maxf(1.0, float(size_range[1]) - float(size_range[0]))
	var quality := 1 if fraction > 0.66 else 0
	if perfect:
		quality = mini(quality + 1, 2)
	var count := 1 + extra
	if Inventory.add(id, count, quality) <= 0:
		return {}
	var xp := 3 + int(fish.get("difficulty", 30)) / 2
	Skills.add_xp("fishing", int(round(float(xp) * (1.5 if perfect else 1.0))))
	var total := int(Game.counters.get("fish_total", 0)) + count
	Game.counters["fish_total"] = total
	Game.counters["fish_today"] = int(Game.counters.get("fish_today", 0)) + count
	if total / 10 > (total - count) / 10:
		Knowledge.add_points("sea", 1)
	if not Game.flag("caught_" + id):
		Game.set_flag("caught_" + id)
		Knowledge.add_points("sea", 2)
		Collections.mark("fish", id)
	for tackle in tackles:
		var key := "tackle_wear_" + str(tackle)
		Game.counters[key] = int(Game.counters.get(key, 0)) + 1
		if int(Game.counters[key]) >= 20:
			Inventory.take(str(tackle), 1)
			Game.counters[key] = 0
	Events.fish_caught.emit(id, quality, size)
	return {"id": id, "quality": quality, "size": size, "count": count}
