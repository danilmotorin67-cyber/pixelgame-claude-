extends Area2D

const OIL_PRICE := 40


func interact(_player: Player) -> void:
	var hint: Label = get_tree().current_scene.get_node("HUD/Hint")
	if Clock.weekday == "wed":
		hint.text = "Лавка Бергов закрыта по средам"
		return
	if not Economy.can_pay(OIL_PRICE):
		hint.text = "Рыбий жир: 40 кр · не хватает денег"
		return
	if Inventory.add("fish_oil", 1) != 1:
		hint.text = "Рюкзак полон · освободите место для рыбьего жира"
		return
	Economy.pay(OIL_PRICE)
	hint.text = "Куплен рыбий жир за 40 кр · хватит на одну ночь"
