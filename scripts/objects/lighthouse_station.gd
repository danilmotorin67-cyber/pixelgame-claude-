extends Area2D

const LIGHT_SECONDS := 2.0
const STORM_SECONDS := 4.0
const REACH := 38.0

var _keeper: Player
var _held: float = 0.0


func interact(player: Player) -> void:
	if Clock.paused:
		return
	var hint: Label = get_parent().get_node("HUD/Hint")
	if Lighthouse.lamp_on:
		hint.text = "Маяк горит · сила огня %d · топливо до утра" % int(Lighthouse.current_power)
		return
	if Lighthouse.fuel <= 0.0:
		if Lighthouse.refill():
			hint.text = "Резервуар заправлен на 1 ночь · удерживайте E, чтобы зажечь"
		else:
			hint.text = "Маяку нужен рыбий жир · положите его в рюкзак"
		return
	_keeper = player
	_held = 0.0
	_show_progress()


func _process(delta: float) -> void:
	if _keeper == null:
		return
	if Clock.paused or not Input.is_action_pressed("interact") or \
			_keeper.global_position.distance_to(global_position) > REACH:
		_cancel_hold()
		return
	_held += delta
	if _held >= hold_seconds():
		if Lighthouse.light_lamp():
			get_parent().get_node("HUD/Hint").text = "Огонь зажжён · сила %d · до утра хватит топлива" % int(Lighthouse.current_power)
		_keeper = null
		_held = 0.0
	else:
		_show_progress()


func hold_seconds() -> float:
	return STORM_SECONDS if Weather.current == "storm" else LIGHT_SECONDS


func _show_progress() -> void:
	get_parent().get_node("HUD/Hint").text = "Удерживайте E: зажечь огонь %.1f / %.0f с" % [_held, hold_seconds()]


func _cancel_hold() -> void:
	_keeper = null
	_held = 0.0
	get_parent().get_node("HUD/Hint").text = "Огонь не зажжён · удерживайте E у двери маяка"
