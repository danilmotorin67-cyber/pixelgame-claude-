extends Control

func _ready() -> void:
	Clock.paused = true
	$Menu/Continue.disabled = not Save.has_save()
	if $Menu/Continue.disabled:
		$Menu/NewGame.grab_focus()
	else:
		$Menu/Continue.grab_focus()


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main/prologue.tscn")


func _on_continue() -> void:
	if Save.load_game(0):
		Router.goto_map(Router.current_map)


func _on_quit() -> void:
	get_tree().quit()
