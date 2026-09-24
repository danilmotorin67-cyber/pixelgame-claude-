extends Area2D
class_name DirectorateDesk

const OPEN := 8
const CLOSE := 17


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 20)
	collision.shape = shape
	add_child(collision)


static func unsent_letters() -> Array:
	var out: Array = []
	for b in Graveyard.bodies:
		if str(b["identified_as"]) != "" and not bool(b["letter_sent"]):
			out.append(b)
	return out


func interact(_player: Player) -> void:
	var hint: Label = get_tree().current_scene.get_node("HUD/Hint")
	if Clock.weekday == "sun" or Clock.hour < OPEN or Clock.hour >= CLOSE:
		hint.text = "Лоцманская управа открыта с 8 до 17, кроме воскресенья."
		return
	var crates := func(_panel: InfoPanel) -> String:
		var handed := Lighthouse.hand_in_crates()
		return "Олаф принял ящиков: %d. Честь +%d." % [handed, 3 * handed] if handed > 0 else "Ящиков с крушений нет."
	var letters := func(_panel: InfoPanel) -> String:
		var sent := 0
		for b in unsent_letters():
			if Graveyard.send_family_letter(b):
				sent += 1
		return "Отправлено писем семьям: %d (по 20 кр)." % sent if sent > 0 else "Некому писать или не хватает крон."
	var bottle := func(_panel: InfoPanel) -> String:
		if not Inventory.take("bottle_13", 1):
			return "Бутылки №13 при вас нет."
		Events.quest_event.emit("bottle_sent", "bottle_13")
		return "Олаф: «Отправлю с «Чайкой». Письма детей доходят быстрее, это я вам как почта говорю»."
	var body := func() -> String:
		return "Олаф: «Ящики с крушений, письма семьям, бутылки — всё сюда. Реестр пропавших — копия у вас в вахтенной»." \
			+ "\nОпознанных без письма: %d." % unsent_letters().size()
	InfoPanel.open(get_tree().current_scene.get_node("HUD"), "Лоцманская управа", body,
		[["Сдать ящики", crates], ["Письма семьям", letters], ["Бутылка №13", bottle]])
