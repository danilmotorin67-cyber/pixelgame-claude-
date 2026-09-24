extends Node

var lamp_on: bool = false
var fuel: float = 0.0
var cleanliness: float = 6.0
var fire_power: float = 0.0 # Average of the last seven nights.
var current_power: float = 0.0
var lit_at_minutes: int = -1
var nightly_powers: Array[float] = []
var last_report: Dictionary = {}


func reset() -> void:
	lamp_on = false
	fuel = 0.0
	cleanliness = 6.0
	fire_power = 0.0
	current_power = 0.0
	lit_at_minutes = -1
	nightly_powers.clear()
	last_report.clear()


func refill() -> bool:
	if lamp_on or fuel > 0.0 or not Inventory.take("fish_oil", 1):
		return false
	fuel = 1.0
	return true


func sunset_minutes() -> int:
	var d := float(Clock.day - 1) / 27.0
	match Clock.season:
		"spring":
			return int(round(lerpf(1170.0, 1260.0, d)))
		"summer":
			return int(round(lerpf(1290.0, 1350.0, d)))
		"autumn":
			return int(round(lerpf(1200.0, 1020.0, d)))
		"winter":
			return int(round(lerpf(960.0, 900.0, d)))
	return 1200


func light_lamp() -> bool:
	if lamp_on or fuel <= 0.0:
		return false
	lamp_on = true
	lit_at_minutes = Clock.minutes
	# Starter equipment: lens 10, lamp 8, raw oil 3, glass 6, tower 8.
	current_power = clampf(29.0 + cleanliness, 0.0, 100.0)
	Events.lamp_lit.emit(Clock.minutes <= sunset_minutes() + 60)
	return true


func resolve_night() -> Dictionary:
	var power := 0.0
	if lamp_on and fuel > 0.0:
		power = current_power
		var sunset := sunset_minutes()
		if lit_at_minutes > sunset + 60 or lit_at_minutes < 360:
			power *= 0.8
		if lit_at_minutes > sunset + 120 or lit_at_minutes < 360:
			var lit_minute := lit_at_minutes if lit_at_minutes >= 360 else lit_at_minutes + 1440
			power *= clampf(float(1560 - lit_minute) / float(1560 - sunset), 0.0, 1.0)
		fuel = maxf(0.0, fuel - 1.0)
		if Weather.current == "fog":
			power *= 0.6
	power = clampf(power, 0.0, 100.0)
	nightly_powers.append(power)
	if nightly_powers.size() > 7:
		nightly_powers.pop_front()
	var total := 0.0
	for score in nightly_powers:
		total += score
	fire_power = total / float(nightly_powers.size())
	last_report = {"power": power, "light": fire_power, "lit": lamp_on}
	lamp_on = false
	current_power = 0.0
	lit_at_minutes = -1
	return last_report.duplicate(true)

func serialize() -> Dictionary:
	return {"lamp_on": lamp_on, "fuel": fuel, "cleanliness": cleanliness,
		"fire_power": fire_power, "current_power": current_power,
		"lit_at_minutes": lit_at_minutes, "nightly_powers": nightly_powers,
		"last_report": last_report}

func deserialize(d: Dictionary) -> void:
	reset()
	lamp_on = bool(d.get("lamp_on", false))
	fuel = clampf(float(d.get("fuel", 1.0)), 0.0, 1.0)
	cleanliness = clampf(float(d.get("cleanliness", 6.0)), 0.0, 10.0)
	fire_power = clampf(float(d.get("fire_power", 0.0)), 0.0, 100.0)
	current_power = clampf(float(d.get("current_power", 29.0 + cleanliness if lamp_on else 0.0)), 0.0, 100.0)
	lit_at_minutes = int(d.get("lit_at_minutes", 1170 if lamp_on else -1))
	var loaded: Variant = d.get("nightly_powers", [])
	if loaded is Array:
		for value in loaded.slice(maxi(0, loaded.size() - 7)):
			nightly_powers.append(clampf(float(value), 0.0, 100.0))
	last_report = d.get("last_report", {}) if d.get("last_report", {}) is Dictionary else {}
