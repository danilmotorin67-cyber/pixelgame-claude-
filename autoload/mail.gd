extends Node

# Letters in the cape mailbox: {id, text, args, money, items: [[id, n]], day, read}.
var letters: Array = []
var _next: int = 1


func reset() -> void:
	letters.clear()
	_next = 1


func send(text_key: String, args: Array = [], money: int = 0, items: Array = []) -> Dictionary:
	var letter := {"id": _next, "text": text_key, "args": args.duplicate(), "money": money,
		"items": items.duplicate(true), "day": Clock.day_index, "read": false}
	_next += 1
	letters.append(letter)
	return letter


func unread() -> int:
	var n := 0
	for letter in letters:
		if not bool(letter["read"]):
			n += 1
	return n


func text_of(letter: Dictionary) -> String:
	var template := Loc.t(str(letter["text"]))
	var args: Array = letter.get("args", [])
	return template % args if not args.is_empty() else template


# Reading a letter takes its attachments; items stay in the letter until there is room.
func read(letter: Dictionary) -> bool:
	if bool(letter["read"]):
		return true
	for entry in letter["items"]:
		if not Inventory.can_fit(str(entry[0]), int(entry[1])):
			return false
	for entry in letter["items"]:
		Inventory.add(str(entry[0]), int(entry[1]))
	if int(letter["money"]) > 0:
		Economy.add(int(letter["money"]))
	letter["read"] = true
	return true


func serialize() -> Dictionary:
	return {"letters": letters, "next": _next}


func deserialize(d: Dictionary) -> void:
	reset()
	for letter in d.get("letters", []):
		var items: Array = []
		for entry in letter.get("items", []):
			items.append([str(entry[0]), int(entry[1])])
		var args: Array = []
		for arg in letter.get("args", []):
			args.append(int(arg) if (arg is float and is_equal_approx(arg, roundf(arg))) else arg)
		letters.append({"id": int(letter["id"]), "text": str(letter["text"]), "args": args,
			"money": int(letter.get("money", 0)), "items": items, "day": int(letter.get("day", 0)),
			"read": bool(letter.get("read", false))})
	_next = maxi(int(d.get("next", letters.size() + 1)), 1)
