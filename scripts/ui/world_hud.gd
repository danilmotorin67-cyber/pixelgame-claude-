extends CanvasLayer

var _hint_text := ""
var _hint_seconds := 0.0
var _last_energy := -1.0

@onready var hint: Label = $Hint
@onready var energy_bar: EnergyHud = $EnergyBar


func _ready() -> void:
	# The HUD is laid out for 480×270 and shown ×2 at 960×540.
	scale = Vector2(Screen.ZOOM, Screen.ZOOM)


func _process(delta: float) -> void:
	if hint.text != _hint_text:
		_hint_text = hint.text
		_hint_seconds = 4.0
		hint.visible = not hint.text.is_empty()
	elif _hint_seconds > 0.0:
		_hint_seconds -= delta
		if _hint_seconds <= 0.0:
			hint.visible = false
	var player := get_parent().get_node_or_null("Player") as Player
	if player != null and not is_equal_approx(_last_energy, player.energy):
		_last_energy = player.energy
		energy_bar.set_energy(_last_energy, Game.max_energy())
	if player != null and not is_equal_approx(energy_bar.cold, player.cold):
		energy_bar.set_cold(player.cold)
