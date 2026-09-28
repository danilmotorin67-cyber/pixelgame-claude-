extends Node2D

const OUTLINE := Color("#2a2a30")
const STONE := Color("#c9c8c2")
const SHADE := Color("#9a9ca3")
const LIT := Color("#eadcb8")
const RED := Color("#9b2f2a")
const RED_LIGHT := Color("#c2412d")
# The lamp in the lit sprite (bottom centre is the node's origin).
const LAMP := Vector2(0, -100)
const BEAM_TURN := 0.55

# The lit lamp at night: a warm glow around the lantern room and the beam sweeping over the cape and the
# sea. They are Light2D, so they shine through the night tint of Daylight instead of being darkened by it.
var _glow: PointLight2D
var _beam: PointLight2D
var _beam_back: PointLight2D
var _time := 0.0


func _ready() -> void:
	Events.lamp_lit.connect(_on_lamp_lit)
	Events.day_started.connect(_on_day_started)
	_glow = _light(_radial(64), 1.4, Color("#ffd98a"), 0.9)
	_beam = _light(_wedge(), 3.2, Color("#ffe6a8"), 0.75)
	_beam_back = _light(_wedge(), 3.2, Color("#ffe6a8"), 0.55)
	_sync()


func _light(tex: Texture2D, scale_amount: float, color: Color, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = tex
	light.texture_scale = scale_amount
	light.color = color
	light.energy = energy
	light.position = LAMP
	add_child(light)
	return light


static func _radial(size: int) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	return tex


static var _wedge_tex: Texture2D


# A narrow cone from the centre to the right edge, fading with distance (built once).
static func _wedge() -> Texture2D:
	if _wedge_tex:
		return _wedge_tex
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y) - c
			var a := 0.0
			if d.x > 2.0:
				var spread := absf(atan2(d.y, d.x))
				var width := 0.13
				if spread < width:
					a = (1.0 - spread / width) * (1.0 - d.length() / (size / 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_wedge_tex = ImageTexture.create_from_image(img)
	return _wedge_tex


func _on_lamp_lit(_on_time: bool) -> void:
	_sync()
	queue_redraw()


func _on_day_started(_day_index: int) -> void:
	_sync()
	queue_redraw()


func _sync() -> void:
	var on := Lighthouse.lamp_on
	_glow.enabled = on
	_beam.enabled = on
	_beam_back.enabled = on


func _process(delta: float) -> void:
	if not Lighthouse.lamp_on:
		if _glow.enabled:
			_sync()
		return
	if not _glow.enabled:
		_sync()
	_time += delta
	# The lens turns; seen from above, the beam's spot runs flatter north-south than east-west.
	var angle := _time * BEAM_TURN
	_beam.rotation = angle
	_beam_back.rotation = angle + PI
	_beam.scale = Vector2(1.0, 0.55 + 0.45 * absf(cos(angle)))
	_beam_back.scale = _beam.scale
	_glow.energy = 0.85 + 0.1 * sin(_time * 7.0)


func _draw() -> void:
	# The lit sprite shows the beacon burning; the bottom position drives Y sorting.
	BuildingArt.draw(self, "lighthouse_lit" if Lighthouse.lamp_on else "lighthouse", Vector2(0, 4))
