extends Area2D
class_name RegionExit

@export var destination: String = ""
@export var arrival: Vector2 = Vector2.ZERO
@export var gate_day_index: int = 0
@export var needs_bridge: bool = false
@export var display_name: String = ""


func interact(_player: Player) -> void:
	if Clock.paused:
		return
	if Clock.day_index < gate_day_index:
		_message("Тропа откроется 5 Весны.")
		return
	if needs_bridge and not Game.flag("bird_bridge_built"):
		if Clock.season != "spring" or Clock.day != 24:
			_message("Путь открыт только на празднике или после постройки моста.")
			return
	if not Router.goto_map(destination, arrival):
		_message("Переход пока недоступен.")


func _message(text: String) -> void:
	var scene := get_tree().current_scene
	if scene:
		var hint := scene.get_node_or_null("HUD/Hint") as Label
		if hint:
			hint.text = text
