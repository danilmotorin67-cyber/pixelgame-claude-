extends CanvasModulate

const NIGHT := Color("#394967")
const TWILIGHT := Color("#bb8c74")


func _process(_delta: float) -> void:
	var d := float(Clock.day - 1) / 27.0
	var dawn := 360.0
	var dusk := 1200.0
	match Clock.season:
		"spring":
			dawn = lerpf(360.0, 300.0, d)
			dusk = lerpf(1170.0, 1260.0, d)
		"summer":
			dawn = 270.0
			dusk = lerpf(1290.0, 1350.0, d)
		"autumn":
			dawn = lerpf(390.0, 450.0, d)
			dusk = lerpf(1200.0, 1020.0, d)
		"winter":
			dawn = lerpf(510.0, 570.0, d)
			dusk = lerpf(960.0, 900.0, d)
			if Clock.day >= 10 and Clock.day <= 20:
				dawn = 630.0
				dusk = 870.0
	var t := float(Clock.minutes)
	var daylight := smoothstep(dawn - 45.0, dawn + 45.0, t) * (1.0 - smoothstep(dusk - 45.0, dusk + 45.0, t))
	var twilight := maxf(1.0 - absf(t - dawn) / 100.0, 1.0 - absf(t - dusk) / 100.0)
	color = NIGHT.lerp(TWILIGHT, clampf(twilight, 0.0, 1.0)).lerp(Color.WHITE, daylight)
	if Clock.season == "summer" and Clock.day >= 8 and Clock.day <= 14:
		color = color.lerp(Color("#a5b3c4"), 0.35)
	if Weather.current in ["storm", "blizzard"]:
		color = color.darkened(0.18)
	elif Weather.current in ["cloud", "rain", "snow", "fog"]:
		color = color.darkened(0.07)
