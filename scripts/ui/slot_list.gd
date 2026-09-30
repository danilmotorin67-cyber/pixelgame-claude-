class_name SlotList
extends MenuWindow

# The three save slots (33.9) for «Новая игра» and «Загрузить»: who, which day, money and time played.
# A new game goes into an empty slot straight away and asks before taking a used one; a used slot can be
# deleted (asked too). `chosen(slot)` hands the slot to the title screen.
signal chosen(slot: int)

const SEASONS := {"spring": "Весна", "summer": "Лето", "autumn": "Осень", "winter": "Зима"}
var mode := "load"


func _init(for_mode: String) -> void:
	super("Новая игра" if for_mode == "new" else "Загрузить")
	mode = for_mode


func _ready() -> void:
	_list()
	super()


static func describe(info: Dictionary) -> String:
	var index := int(info.get("day_index", 0))
	var season := str(Clock.SEASONS[(index % Clock.DAYS_PER_YEAR) / Clock.DAYS_PER_SEASON])
	var minutes := int(info.get("playtime_sec", 0)) / 60
	var name := str(info.get("name", ""))
	return "%s · %s %d, год %d · %d кр · %d ч %02d мин" % [name if name != "" else "Смотритель", SEASONS[season],
		index % Clock.DAYS_PER_SEASON + 1, index / Clock.DAYS_PER_YEAR + 1, int(info.get("money", 0)), minutes / 60, minutes % 60]


func _list() -> void:
	clear_body()
	add_label("Выберите слот. Игра сохраняется, когда смотритель ложится спать." if mode == "new"
		else "Выберите сохранение.", UiKit.MUTED)
	for slot in Save.SLOT_COUNT:
		var info := Save.slot_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var pick := Button.new()
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.text = "%d. %s" % [slot + 1, describe(info) if not info.is_empty() else "пусто"]
		pick.disabled = mode == "load" and info.is_empty()
		pick.pressed.connect(_pick.bind(slot))
		row.add_child(pick)
		if not info.is_empty():
			var drop := Button.new()
			drop.text = "Удалить"
			drop.pressed.connect(_ask_delete.bind(slot))
			row.add_child(drop)
		body.add_child(row)
	refit()
	call_deferred("focus_first")


func _pick(slot: int) -> void:
	var info := Save.slot_info(slot)
	if mode == "new" and not info.is_empty():
		_ask("Слот %d занят: «%s». Новая игра заменит это сохранение, когда смотритель впервые ляжет спать. Начать?"
			% [slot + 1, describe(info)], "Начать заново", func() -> void: chosen.emit(slot))
		return
	chosen.emit(slot)


func _ask_delete(slot: int) -> void:
	_ask("Удалить сохранение слота %d «%s»? Вернуть его будет нельзя." % [slot + 1, describe(Save.slot_info(slot))],
		"Удалить", func() -> void:
			Save.delete_slot(slot)
			_list())


# A yes/no question in place of the list; «Нет» goes back to the list.
func _ask(question: String, yes: String, action: Callable) -> void:
	clear_body()
	add_label(question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var no := Button.new()
	no.text = "Нет"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_list)
	var ok := Button.new()
	ok.text = yes
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(action)
	row.add_child(no)
	row.add_child(ok)
	body.add_child(row)
	refit()
	no.call_deferred("grab_focus")
