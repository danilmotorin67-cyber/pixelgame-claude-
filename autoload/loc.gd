extends Node

const TRANSLATIONS_CSV := "res://localization/strings.csv"


func _ready() -> void:
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
		for index in translations.size():
			translations[index].add_message(row[0], row[index + 1])
	for translation in translations:
		TranslationServer.add_translation(translation)


func t(key: String) -> String:
	var trs := tr(key)
	if trs == key:
		return key
	return trs

func gender_form(male: String, female: String) -> String:
	return male if Game.hero.get("gender", "m") == "m" else female
