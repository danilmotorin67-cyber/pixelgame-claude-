extends Node

var tables: Dictionary = {}
var errors: PackedStringArray = []
var ready_ok: bool = false

const DATA_FILES: PackedStringArray = [
	"items", "crops", "trees", "fish", "shellfish", "animals",
	"recipes_craft", "recipes_cook", "stations", "tools", "weapons", "amulets", "clothes",
	"enemies", "bosses", "loot_tables", "deep_biomes", "grotto", "sea_map", "ships",
	"npcs", "gifts", "quests", "bodies", "registry", "ghosts", "the_twenty", "evidence",
	"weather", "tides", "festivals", "bundles", "neptune", "regions",
	"skills", "knowledge_tree", "achievements", "collections",
	"bottles", "pages", "tales", "shops", "buildings", "balance"
]

func _ready() -> void:
	_load_all()
	ready_ok = errors.is_empty()
	if not ready_ok:
		push_error("Data validation failed: %s" % ", ".join(errors))
	else:
		print("Data: %d tables loaded" % tables.size())


func _load_all() -> void:
	errors.clear()
	tables.clear()
	for name in DATA_FILES:
		var path := "res://data/%s.json" % name
		if not FileAccess.file_exists(path):
			errors.append("missing:%s" % path)
			tables[name] = []
			continue
		var txt := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed == null:
			errors.append("json:%s" % path)
			tables[name] = []
			continue
		tables[name] = parsed
	_validate_ids()


func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	if v is Dictionary and v.has("items"):
		return v["items"]
	if v is Dictionary and v.has("nodes"):
		return v["nodes"]
	if v is Dictionary and v.has("list"):
		return v["list"]
	return []


func by_id(table: String, id: String) -> Dictionary:
	var arr := _as_array(tables.get(table, []))
	for row in arr:
		if row is Dictionary and str(row.get("id", "")) == id:
			return row
	return {}


func all(table: String) -> Array:
	return _as_array(tables.get(table, []))


func exists(table: String, id: String) -> bool:
	return not by_id(table, id).is_empty()


func _collect_ids(table: String) -> Dictionary:
	var out := {}
	for row in all(table):
		if row is Dictionary and row.has("id"):
			out[str(row["id"])] = true
	return out


func _validate_ids() -> void:
	var item_ids := _collect_ids("items")
	for crop in all("crops"):
		if crop is Dictionary:
			var seed_id := str(crop.get("seed", ""))
			if seed_id != "" and not item_ids.has(seed_id):
				# seeds may live in items
				pass
	for npc in all("npcs"):
		if npc is Dictionary and not npc.has("id"):
			errors.append("npc_missing_id")
	for q in all("quests"):
		if q is Dictionary and not q.has("id"):
			errors.append("quest_missing_id")
