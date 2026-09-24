extends Node

const TRANSLATIONS_CSV := "res://localization/strings.csv"

# Every key in load order; dialogue picks lines by prefix (npc.<name>.<category>.NN).
var keys: PackedStringArray = []
var _prefix_cache: Dictionary = {}
var _gender := RegEx.new()


func _ready() -> void:
	_gender.compile("\\{([^{}|]*)\\|([^{}|]*)\\}")
	var file := FileAccess.open(TRANSLATIONS_CSV, FileAccess.READ)
	if file == null:
		push_error("Missing translations: " + TRANSLATIONS_CSV)
		return
	var headers := file.get_csv_line()
	var translations: Array[Translation] = []
	for index in range(1, headers.size()):
		var translation := Translation.new()
		translation.locale = headers[index]
		translations.append(translation)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() != headers.size() or row[0].is_empty():
			continue
		keys.append(row[0])
		for index in translations.size():
			translations[index].add_message(row[0], row[index + 1])
	for translation in translations:
		TranslationServer.add_translation(translation)


func t(key: String) -> String:
	var trs := tr(key)
	if trs == key:
		return key
	return format(trs)


func has(key: String) -> bool:
	return tr(key) != key


# 2.4: the hero's name and grammatical gender, "{внук|внучка}".
func format(text: String) -> String:
	if not text.contains("{"):
		return text
	text = text.replace("{name}", str(Game.hero.get("name", "Смотритель")))
	var female := str(Game.hero.get("gender", "m")) == "f"
	return _gender.sub(text, "$2" if female else "$1", true)


func with_prefix(prefix: String) -> PackedStringArray:
	if _prefix_cache.has(prefix):
		return _prefix_cache[prefix]
	var out: PackedStringArray = []
	for key in keys:
		if key.begins_with(prefix):
			out.append(key)
	_prefix_cache[prefix] = out
	return out


func gender_form(male: String, female: String) -> String:
	return male if Game.hero.get("gender", "m") == "m" else female
