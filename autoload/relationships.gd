extends Node

var hearts: Dictionary = {}
var gifts_today: Dictionary = {}
var married_to: String = ""

func hearts_of(npc: String) -> int:
	return int(hearts.get(npc, 0))

func add_friendship(npc: String, pts: int) -> void:
	var h := hearts_of(npc) + pts
	hearts[npc] = clampi(h, 0, 14)

func serialize() -> Dictionary:
	return {"hearts": hearts, "married_to": married_to}

func deserialize(d: Dictionary) -> void:
	hearts = d.get("hearts", {})
	married_to = str(d.get("married_to", ""))
