extends Node

@onready var label: Label = $CanvasLayer/Label


func _ready() -> void:
	label.text = "СОЛЁНЫЙ СВЕТ"
	await get_tree().create_timer(0.6).timeout
	if not Data.ready_ok:
		label.text = "DATA ERROR\n" + "\n".join(Data.errors)
		return
	get_tree().change_scene_to_file("res://scenes/main/title.tscn")
