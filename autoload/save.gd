extends Node

const SLOT_COUNT := 3
const BACKUP_COUNT := 3
const SAVE_VERSION := 1
var current_slot: int = 0
var save_root: String = "user://saves"


func _slot_path(n: int) -> String:
	return "%s/slot_%d.json" % [save_root, n]


func has_save(slot: int = 0) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	for path in _candidate_paths(slot):
		if not _read_payload(path).is_empty():
			return true
	return false


func _candidate_paths(slot: int) -> Array[String]:
	var path := _slot_path(slot)
	var candidates: Array[String] = [path]
	for number in range(1, BACKUP_COUNT + 1):
		candidates.append("%s.bak%d" % [path, number])
	return candidates


func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != SAVE_VERSION:
		return {}
	for section in ["game", "clock", "weather", "inventory", "economy", "router"]:
		if not (d.get(section) is Dictionary):
			return {}
	return d


func _capture_player() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player")
	if player and player.has_method("serialize_state"):
		Game.player_state = player.serialize_state()


func save_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_slot
	if slot >= SLOT_COUNT:
		return false
	_capture_player()
	var payload := {
		"version": SAVE_VERSION,
		"header": {
			"name": Game.hero.get("name", ""),
			"day_index": Clock.day_index,
			"money": Economy.money,
			"playtime_sec": Game.playtime_sec,
		},
		"game": Game.serialize(),
		"clock": Clock.serialize(),
		"weather": Weather.serialize(),
		"router": Router.serialize(),
		"inventory": Inventory.serialize(),
		"economy": Economy.serialize(),
		"skills": Skills.serialize(),
		"knowledge": Knowledge.serialize(),
		"relationships": Relationships.serialize(),
		"quests": Quests.serialize(),
		"lighthouse": Lighthouse.serialize(),
		"graveyard": Graveyard.serialize(),
		"sea": Sea.serialize(),
		"farm": Farm.serialize(),
		"animals": Animals.serialize(),
		"settings": Settings.serialize(),
	}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_root)) != OK:
		return false
	var path := _slot_path(slot)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	if _read_payload(temporary).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	for number in range(BACKUP_COUNT, 0, -1):
		var source := path if number == 1 else "%s.bak%d" % [path, number - 1]
		var dest := "%s.bak%d" % [path, number]
		if FileAccess.file_exists(source):
			if FileAccess.file_exists(dest):
				if DirAccess.remove_absolute(ProjectSettings.globalize_path(dest)) != OK:
					return false
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(source),
					ProjectSettings.globalize_path(dest)) != OK:
				return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(path)) != OK:
		return false
	current_slot = slot
	return true


func load_game(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	var payload: Dictionary = {}
	for path in _candidate_paths(slot):
		payload = _read_payload(path)
		if not payload.is_empty():
			break
	if payload.is_empty():
		return false
	Game.deserialize(payload.get("game", {}))
	Clock.deserialize(payload.get("clock", {}))
	Weather.deserialize(payload.get("weather", {}))
	Router.deserialize(payload.get("router", {}))
	Inventory.deserialize(payload.get("inventory", {}))
	Economy.deserialize(payload.get("economy", {}))
	Skills.deserialize(payload.get("skills", {}))
	Knowledge.deserialize(payload.get("knowledge", {}))
	Relationships.deserialize(payload.get("relationships", {}))
	Quests.deserialize(payload.get("quests", {}))
	Lighthouse.deserialize(payload.get("lighthouse", {}))
	Graveyard.deserialize(payload.get("graveyard", {}))
	Sea.deserialize(payload.get("sea", {}))
	Farm.deserialize(payload.get("farm", {}))
	Animals.deserialize(payload.get("animals", {}))
	Settings.deserialize(payload.get("settings", {}))
	current_slot = slot
	Events.tide_changed.emit(Clock.tide_height())
	return true
