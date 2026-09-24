extends Node

var sea_pts: int = 0
var land_pts: int = 0
var rest_pts: int = 0
var unlocked: Dictionary = {"M1": true, "P1": true, "Z1": true, "S1": true, "R1": true, "T1": true}

func add_points(kind: String, n: int) -> void:
	match kind:
		"sea":
			sea_pts += n
		"land":
			land_pts += n
		"rest":
			rest_pts += n

func unlock(id: String) -> void:
	unlocked[id] = true
	Events.node_unlocked.emit(id)

func serialize() -> Dictionary:
	return {"sea_pts": sea_pts, "land_pts": land_pts, "rest_pts": rest_pts, "unlocked": unlocked}

func deserialize(d: Dictionary) -> void:
	sea_pts = int(d.get("sea_pts", 0))
	land_pts = int(d.get("land_pts", 0))
	rest_pts = int(d.get("rest_pts", 0))
	unlocked = d.get("unlocked", unlocked)
