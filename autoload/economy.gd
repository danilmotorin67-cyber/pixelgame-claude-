extends Node

var money: int = 500

func add(n: int) -> void:
	money = maxi(0, money + n)
	Events.money_changed.emit(money)

func can_pay(n: int) -> bool:
	return money >= n

func pay(n: int) -> bool:
	if not can_pay(n):
		return false
	add(-n)
	return true

func serialize() -> Dictionary:
	return {"money": money}

func deserialize(d: Dictionary) -> void:
	money = int(d.get("money", 500))
