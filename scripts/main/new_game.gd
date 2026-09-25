class_name NewGame

# A fresh world (5.1): every system reset, Halvdan's basket and Agatha's tools, Spring 1 at 17:00 on the cape.
static func start(hero: Dictionary = {}) -> void:
	Game.reset()
	for key in hero:
		Game.hero[key] = hero[key]
	Clock.reset()
	Weather.reset()
	Weather.start_day(0)
	for system in [Economy, Inventory, Farm, Lighthouse, Sea, Skills, Crafting, Buildings, Animals, Deep, Grotto, Graveyard,
			Mail, Knowledge, Quests, Collections, Relationships, Cutscenes, NPCs, Dialogue, Achievements, Story, Twenty,
			Community, Festivals, Finale, Boards]:
		system.reset()
	Story.stern_phrase = str(hero.get("stern_phrase", ""))
	Game.set_flag("prologue_done", hero.has("stern_phrase"))
	Farm.scatter_rocks()
	Farm.scatter_field()
	Crafting.add_prefilled("cape", "chest", 664, 380, [["canvas", 1], ["thread", 2], ["rag", 3], ["agatha_hat", 1]])
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
