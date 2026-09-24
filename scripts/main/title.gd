extends Control

func _ready() -> void:
	Clock.paused = true
	$Menu/Continue.disabled = not Save.has_save()
	if $Menu/Continue.disabled:
		$Menu/NewGame.grab_focus()
	else:
		$Menu/Continue.grab_focus()


func _on_new_game() -> void:
	Game.reset()
	Clock.reset()
	Weather.reset()
	Weather.start_day(0)
	Economy.reset()
	Inventory.reset()
	Farm.reset()
	Lighthouse.reset()
	Sea.reset()
	Skills.reset()
	Crafting.reset()
	Graveyard.reset()
	Mail.reset()
	Knowledge.reset()
	Quests.reset()
	Collections.reset()
	Relationships.reset()
	Cutscenes.reset()
	NPCs.reset()
	Farm.scatter_rocks()
	Crafting.add_prefilled("cape", "chest", 664, 380, [["canvas", 1], ["thread", 2], ["rag", 3]])
	Farm.spawn_wild(0)
	Sea.generate_gifts(0, false)
	Inventory.add("fish_oil", 1)
	Inventory.add("seed_turnip", 15)
	Inventory.add("bread_rye", 3)
	Inventory.add("tea", 1)
	Inventory.add("tool_hoe", 1)
	Inventory.add("tool_can", 1)
	Inventory.add("tool_pick", 1)
	Inventory.add("tool_axe", 1)
	Inventory.add("tool_shovel", 1)
	Inventory.add("tool_scythe", 1)
	Inventory.add("lantern_tin", 1)
	Inventory.add("oar", 1)
	Router.current_map = "cape"
	Router.spawn = Vector2(600, 360)
	get_tree().change_scene_to_file("res://scenes/world/cape.tscn")


func _on_continue() -> void:
	if Save.load_game(0):
		Router.goto_map(Router.current_map)


func _on_quit() -> void:
	get_tree().quit()
