extends Node

var resolving: bool = false
var pending_report: Dictionary = {}


func end_day(fainted: bool = false) -> void:
	if resolving:
		return
	resolving = true
	Clock.paused = true
	var bedtime := Clock.minutes
	var current_scene := get_tree().current_scene
	var player: Player = null
	if current_scene:
		player = current_scene.get_node_or_null("Player") as Player
	if player:
		Game.player_state = player.serialize_state()
	var energy_fraction := 1.0
	if fainted:
		energy_fraction = 0.5
	elif bedtime < 60:
		energy_fraction = 0.9
	elif bedtime < 120:
		energy_fraction = 0.75
	var lost_money := 0
	if fainted:
		lost_money = mini(int(floor(float(Economy.money) * 0.1)), 1000)
		Economy.add(-lost_money)
	var light_report := Lighthouse.resolve_night()
	Clock.start_next_day()
	Farm.advance_day()
	var state := Game.player_state.duplicate(true)
	state["energy"] = 270.0 * energy_fraction
	state["cold"] = 0.0
	state["x"] = 600.0
	state["y"] = 360.0
	Game.player_state = state
	Router.current_map = "cape"
	Router.spawn = Vector2(600, 360)
	if player:
		player.restore_state(state)
	Game.add_stat("days_survived")
	var saved := Save.save_game()
	var report := {
		"day": Clock.day, "season": Clock.season, "weather": Weather.current,
		"tide": Clock.tide_height(), "moon": Clock.moon_name(),
		"money_lost": lost_money, "fainted": fainted, "saved": saved,
		"lighthouse": light_report,
	}
	if current_scene and current_scene.get("map_id") != "cape":
		pending_report = report
		Router.goto_map("cape", Vector2(600, 360))
	else:
		Events.night_resolved.emit(report)
	resolving = false
