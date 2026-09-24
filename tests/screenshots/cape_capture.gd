extends Node

# Renders a reproducible view of the actual cape scene for the project's screenshots.
func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	Game.reset()
	Game.world_seed = 42
	Clock.reset()
	Inventory.reset()
	Farm.reset()
	Inventory.add("seed_turnip", 15)
	Inventory.add("bread_rye", 3)
	Inventory.add("tool_hoe")
	Inventory.add("tool_can")
	Router.current_map = "cape"
	Router.spawn = Vector2(682, 245)
	for x in 7:
		for y in 4:
			var cell := Vector2i(x, y)
			Farm.till(cell)
			if (x + y) % 4 != 0:
				Farm.plant(cell, "seed_turnip")
				Farm.water(cell)
	for day in 4:
		Clock.start_next_day()
		Farm.advance_day()
		for x in 7:
			for y in 4:
				Farm.water(Vector2i(x, y))
	Weather.set_weather("clear")
	Clock.set_time(16, 20)
	Inventory.select_hotbar(2)
	var cape: Node2D = load("res://scenes/world/cape.tscn").instantiate()
	get_tree().root.add_child(cape)
	get_tree().current_scene = cape
	Clock.paused = true
	for frame in 30:
		await get_tree().process_frame
	var success: bool = await _save_frame("saltlight-cape.png")
	var player: Player = cape.get_node("Player")
	player.global_position = Vector2(658, 318)
	player.play_tool("can", Vector2(681, 318))
	player.tool_time = Player.TOOL_DURATION * 0.45
	player.tool_art.queue_redraw()
	for frame in 40:
		await get_tree().process_frame
	success = (await _save_frame("saltlight-action.png")) and success
	# A live evening view with the keeper's first portion of fuel burning.
	Lighthouse.reset()
	Inventory.add("fish_oil", 1)
	Lighthouse.refill()
	Clock.set_time(21, 20)
	Lighthouse.light_lamp()
	player.global_position = Vector2(706, 270)
	player.get_node("Camera2D").position = Vector2(0, -55)
	player.tool_time = 0.0
	player.tool_art.queue_redraw()
	for frame in 40:
		await get_tree().process_frame
	success = (await _save_frame("saltlight-lighthouse.png")) and success

	# The same coast from the same camera position at spring low and high tide.
	player.global_position = Vector2(720, 844)
	player.tool_time = 0.0
	player.tool_art.queue_redraw()
	player.get_node("Camera2D").position = Vector2(0, 51)
	Inventory.select_hotbar(0)
	Clock.day_index = 0
	Lighthouse.reset()
	Clock.set_time(15, 15)
	for frame in 40:
		await get_tree().process_frame
	success = (await _save_frame("saltlight-shore-low.png")) and success
	Clock.set_time(9, 2)
	for frame in 10:
		await get_tree().process_frame
	success = (await _save_frame("saltlight-shore-high.png")) and success
	get_tree().quit(0 if success else 1)


func _save_frame(filename: String) -> bool:
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot.is_empty():
		push_error("Godot did not render %s" % filename)
		return false
	if screenshot.get_width() < 1920:
		screenshot.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	var error := screenshot.save_png("res://" + filename)
	if error != OK:
		push_error("Could not save %s: %d" % [filename, error])
	return error == OK
