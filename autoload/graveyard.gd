extends Node

var bodies: Array = []
var graves: Array = []
var peace: float = 0.0
# Drowned crews from wrecks waiting to wash ashore: {ship, arrive (day index), beach}.
var incoming: Array = []


func reset() -> void:
	bodies.clear()
	graves.clear()
	peace = 0.0
	incoming.clear()


func serialize() -> Dictionary:
	return {"bodies": bodies, "graves": graves, "peace": peace, "incoming": incoming}


func deserialize(d: Dictionary) -> void:
	bodies = d.get("bodies", [])
	graves = d.get("graves", [])
	peace = float(d.get("peace", 0.0))
	incoming.clear()
	for entry in d.get("incoming", []):
		incoming.append({"ship": str(entry["ship"]), "arrive": int(entry["arrive"]), "beach": str(entry["beach"])})
